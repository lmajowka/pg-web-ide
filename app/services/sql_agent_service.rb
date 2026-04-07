class SqlAgentService
  MAX_ITERATIONS = 10
  SAMPLE_LIMIT = 5

  def initialize(connection)
    @connection = connection
    @client = OpenAI::Client.new(api_key: ENV.fetch("OPENAI_API_KEY"))
  end

  def generate_sql(user_prompt)
    messages = [
      {
        role: "system",
        content: <<~PROMPT
          You are a PostgreSQL expert assistant. The user will describe a data query in natural language.
          Your job is to explore the database schema using the provided tools and then generate the correct SQL query.

          Guidelines:
          - Use list_tables to discover available tables
          - Use describe_table to understand column names and types
          - Use run_select_query to sample data and verify your understanding
          - Once you have enough context, respond with the final SQL query in a ```sql code block
          - Only generate SELECT queries unless the user explicitly asks for INSERT/UPDATE/DELETE
          - Do not include any explanation outside the code block in your final response; put everything in the SQL as comments if needed
        PROMPT
      },
      { role: "user", content: user_prompt }
    ]

    MAX_ITERATIONS.times do
      response = @client.chat.completions.create(
        model: "gpt-4o",
        messages: messages,
        tools: tools_definition,
        tool_choice: "auto"
      )

      choice = response.choices.first
      message = choice.message

      if message.tool_calls&.any?
        messages << serialize_assistant_message(message)

        message.tool_calls.each do |tool_call|
          tool_name = tool_call.function.name
          tool_args = JSON.parse(tool_call.function.arguments)
          result = execute_tool(tool_name, tool_args)

          messages << {
            role: "tool",
            tool_call_id: tool_call.id,
            content: result.to_s
          }
        end
      else
        content = message.content.to_s
        sql = extract_sql(content)
        return { sql: sql, explanation: content }
      end
    end

    { error: "Agent did not produce a result after #{MAX_ITERATIONS} iterations." }
  end

  private

  def tools_definition
    [
      {
        type: "function",
        function: {
          name: "list_tables",
          description: "List all tables available in the current database.",
          parameters: { type: "object", properties: {}, required: [] }
        }
      },
      {
        type: "function",
        function: {
          name: "describe_table",
          description: "Get column names, data types, nullability, and defaults for a given table.",
          parameters: {
            type: "object",
            properties: {
              table_name: { type: "string", description: "Name of the table to describe" }
            },
            required: [ "table_name" ]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "run_select_query",
          description: "Execute a read-only SELECT query to sample data. Only SELECT statements are permitted. A LIMIT is automatically enforced if omitted.",
          parameters: {
            type: "object",
            properties: {
              query: { type: "string", description: "A SELECT SQL query" }
            },
            required: [ "query" ]
          }
        }
      }
    ]
  end

  def execute_tool(tool_name, args)
    case tool_name
    when "list_tables"
      tables = @connection.tables.sort
      tables.empty? ? "No tables found." : tables.join(", ")

    when "describe_table"
      table = args["table_name"].to_s
      columns = @connection.columns(table)
      pk = @connection.primary_key(table)
      lines = columns.map do |c|
        parts = [ "#{c.name} #{c.sql_type}" ]
        parts << "PRIMARY KEY" if c.name == pk
        parts << "NOT NULL" unless c.null
        parts << "DEFAULT #{c.default}" if c.default
        parts.join(" ")
      end
      lines.join("\n")

    when "run_select_query"
      query = args["query"].to_s.strip
      unless query.match?(/\A\s*SELECT\b/i)
        return "Error: only SELECT queries are allowed."
      end
      # Enforce a small limit for exploration
      safe_query = query.match?(/\bLIMIT\b/i) ? query : "#{query} LIMIT #{SAMPLE_LIMIT}"
      result = @connection.exec_query(safe_query)
      rows = result.to_a
      return "No rows returned." if rows.empty?

      headers = rows.first.keys.join(" | ")
      body = rows.map { |r| r.values.map(&:to_s).join(" | ") }.join("\n")
      "#{headers}\n#{body}"

    else
      "Unknown tool: #{tool_name}"
    end
  rescue => e
    "Error executing #{tool_name}: #{e.message}"
  end

  def serialize_assistant_message(message)
    hash = { role: "assistant", content: message.content }
    if message.tool_calls&.any?
      hash[:tool_calls] = message.tool_calls.map do |tc|
        {
          id: tc.id,
          type: "function",
          function: {
            name: tc.function.name,
            arguments: tc.function.arguments
          }
        }
      end
    end
    hash
  end

  def extract_sql(content)
    if content =~ /```(?:sql)?\n(.*?)```/m
      $1.strip
    else
      content.strip
    end
  end
end
