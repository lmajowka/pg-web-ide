class DbIdeController < ApplicationController
  MAX_ROWS = 50

  before_action :ensure_development!

  def index
    prepare_state
  end

  def sql_runner
    @query ||= default_query(nil)
  end

  def execute
    prepare_state
    @query = params[:query].to_s

    if @query.present?
      @query_result = run_query(@query)
    end

    render :index
  rescue ActiveRecord::StatementInvalid => e
    @query_error = e.message
    render :index
  end

  def sql_runner_execute
    @query = params[:query].to_s

    if @query.present?
      @query_result = run_query(@query)
    end

    render :sql_runner
  rescue ActiveRecord::StatementInvalid => e
    @query_error = e.message
    render :sql_runner
  end

  def create
    table = params[:table].to_s

    unless table.present? && fetch_tables.include?(table)
      redirect_to db_ide_path, alert: "Unknown table."
      return
    end

    primary_key = primary_key_for(table)

    attributes = permitted_attributes(table, primary_key, include_primary: true)
    attributes = normalize_attributes(attributes)

    apply_insert(table, attributes)

    redirect_to db_ide_path(table: table), notice: "Row created successfully."
  rescue ActiveRecord::StatementInvalid => e
    redirect_to db_ide_path(table: table, new: true), alert: e.message
  end

  def update
    table = params[:table].to_s

    unless table.present? && fetch_tables.include?(table)
      redirect_to db_ide_path, alert: "Unknown table."
      return
    end

    primary_key = primary_key_for(table)

    unless primary_key
      redirect_to db_ide_path(table: table), alert: "Editing is not supported for this table."
      return
    end

    row_id = params[:id]

    unless row_id.present?
      redirect_to db_ide_path(table: table), alert: "Missing row identifier."
      return
    end

    attributes = permitted_attributes(table, primary_key)
    attributes = normalize_attributes(attributes)

    if attributes.empty?
      redirect_to db_ide_path(table: table, edit: row_id), alert: "Nothing to update."
      return
    end

    apply_update(table, primary_key, row_id, attributes)

    redirect_to db_ide_path(table: table), notice: "Row updated successfully."
  rescue ActiveRecord::StatementInvalid => e
    redirect_to db_ide_path(table: table, edit: params[:id]), alert: e.message
  end

  def destroy
    table = params[:table].to_s

    unless table.present? && fetch_tables.include?(table)
      redirect_to db_ide_path, alert: "Unknown table."
      return
    end

    primary_key = primary_key_for(table)

    unless primary_key
      redirect_to db_ide_path(table: table), alert: "Deleting is not supported for this table."
      return
    end

    row_id = params[:id]

    unless row_id.present?
      redirect_to db_ide_path(table: table), alert: "Missing row identifier."
      return
    end

    apply_delete(table, primary_key, row_id)

    redirect_to db_ide_path(table: table), notice: "Row deleted successfully."
  rescue ActiveRecord::StatementInvalid => e
    redirect_to db_ide_path(table: table), alert: e.message
  end

  private

  def ensure_development!
    return if Rails.env.development?

    head :forbidden
  end

  def prepare_state
    @tables = fetch_tables.sort
    @selected_table = params[:table].presence || @tables.first
    if @selected_table
      @table_primary_key = primary_key_for(@selected_table)
      @table_columns_info = columns_info_for(@selected_table)
      @sort_column = params[:sort].presence
      @sort_direction = params[:direction].presence&.downcase == "desc" ? "desc" : "asc"
      @table_result = load_table_rows(@selected_table, @sort_column, @sort_direction)
      @show_new_form = params[:new].present?
      @editable_row_id = @show_new_form ? nil : params[:edit].presence
      @editable_row = load_row(@selected_table, @table_primary_key, @editable_row_id)
      @new_row_template = blank_row(@table_columns_info)
    end
    @query ||= default_query(@selected_table)
  end

  def fetch_tables
    connection.tables
    #.reject { |name| name.start_with?("pg_") || name == "schema_migrations" }
  end

  def load_table_rows(table_name, sort_column = nil, sort_direction = "asc")
    return unless table_name

    quoted_table = connection.quote_table_name(table_name)
    sql = "SELECT * FROM #{quoted_table}"
    
    # Apply filters from URL parameters
    conditions = []
    values = []
    columns_info = columns_info_for(table_name)
    
    params.each do |key, value|
      if key.match(/^filter_\d+_column$/)
        filter_index = key.match(/^filter_(\d+)_column$/)[1]
        column = params["filter_#{filter_index}_column"]
        operator = params["filter_#{filter_index}_operator"]
        filter_value = params["filter_#{filter_index}_value"]
        
        if column.present? && operator.present? && (filter_value.present? || ['is_null', 'is_not_null'].include?(operator))
          if valid_column?(table_name, column)
            condition = build_filter_condition(column, operator, filter_value)
            if condition
              conditions << condition
              unless ['is_null', 'is_not_null'].include?(operator)
                column_info = columns_info.find { |col| col.name == column }
                formatted_value = format_filter_value(operator, filter_value, column_info&.type)
                values << formatted_value
              end
            end
          end
        end
      end
    end
    
    if conditions.any?
      sql += " WHERE #{conditions.join(' AND ')}"
    end
    
    if sort_column.present? && valid_column?(table_name, sort_column)
      quoted_column = connection.quote_column_name(sort_column)
      direction = sort_direction == "desc" ? "DESC" : "ASC"
      sql += " ORDER BY #{quoted_column} #{direction}"
    end
    
    sql += " LIMIT #{MAX_ROWS}"
    
    if values.any?
      connection.exec_query(sanitize_sql([sql, *values]))
    else
      connection.exec_query(sql)
    end
  end

  def load_row(table_name, primary_key, row_id)
    return unless table_name && primary_key && row_id

    quoted_table = connection.quote_table_name(table_name)
    quoted_pk = connection.quote_column_name(primary_key)
    sql = "SELECT * FROM #{quoted_table} WHERE #{quoted_pk} = #{connection.quote(row_id)} LIMIT 1"
    connection.exec_query(sql).to_a.first
  end

  def default_query(table_name)
    return "" unless table_name

    "SELECT * FROM #{connection.quote_table_name(table_name)} LIMIT #{MAX_ROWS};"
  end

  def run_query(sql)
    connection.exec_query(sql)
  end

  def primary_key_for(table_name)
    return unless table_name

    connection.primary_key(table_name)
  end

  def columns_info_for(table_name)
    return [] unless table_name

    connection.columns(table_name)
  end

  def blank_row(columns)
    Array(columns).each_with_object({}) do |column, memo|
      memo[column.name] = column.default
    end
  end

  def permitted_attributes(table_name, primary_key, include_primary: false)
    raw_params = params[:row]
    return {} unless raw_params.is_a?(ActionController::Parameters)

    allowed_columns = columns_info_for(table_name).map(&:name)
    permitted = raw_params.permit(*allowed_columns)
    attributes = permitted.to_h
    attributes.delete(primary_key) unless include_primary
    attributes
  end

  def normalize_attributes(attributes)
    attributes.transform_values do |value|
      value.is_a?(String) && value.empty? ? nil : value
    end
  end

  def apply_update(table_name, primary_key, row_id, attributes)
    return if attributes.blank?

    quoted_table = connection.quote_table_name(table_name)
    quoted_pk = connection.quote_column_name(primary_key)

    assignments = attributes.map do |column, value|
      "#{connection.quote_column_name(column)} = #{connection.quote(value)}"
    end

    sql = "UPDATE #{quoted_table} SET #{assignments.join(", ")} WHERE #{quoted_pk} = #{connection.quote(row_id)}"
    connection.execute(sql)
  end

  def apply_insert(table_name, attributes)
    quoted_table = connection.quote_table_name(table_name)
    sanitized = attributes

    if sanitized.blank?
      connection.execute("INSERT INTO #{quoted_table} DEFAULT VALUES")
      return
    end

    column_names = sanitized.keys
    quoted_columns = column_names.map { |column| connection.quote_column_name(column) }
    values = column_names.map { |column| connection.quote(sanitized[column]) }

    sql = "INSERT INTO #{quoted_table} (#{quoted_columns.join(", ")}) VALUES (#{values.join(", ")})"
    connection.execute(sql)
  end

  def apply_delete(table_name, primary_key, row_id)
    quoted_table = connection.quote_table_name(table_name)
    quoted_pk = connection.quote_column_name(primary_key)
    sql = "DELETE FROM #{quoted_table} WHERE #{quoted_pk} = #{connection.quote(row_id)}"
    connection.execute(sql)
  end

  def valid_column?(table_name, column_name)
    return false unless table_name && column_name
    
    columns_info_for(table_name).any? { |col| col.name == column_name }
  end

  def build_filter_condition(column, operator, value)
    quoted_column = connection.quote_column_name(column)
    column_info = columns_info_for(params[:table]).find { |col| col.name == column }
    
    case operator
    when 'contains'
      if column_info&.type == :string || column_info&.type == :text
        "#{quoted_column} ILIKE ?"
      else
        # For non-string columns, use equals instead
        "#{quoted_column} = ?"
      end
    when 'not_contains'
      if column_info&.type == :string || column_info&.type == :text
        "#{quoted_column} NOT ILIKE ?"
      else
        "#{quoted_column} != ?"
      end
    when 'equals'
      "#{quoted_column} = ?"
    when 'not_equals'
      "#{quoted_column} != ?"
    when 'starts_with'
      if column_info&.type == :string || column_info&.type == :text
        "#{quoted_column} ILIKE ?"
      else
        "#{quoted_column} = ?"
      end
    when 'ends_with'
      if column_info&.type == :string || column_info&.type == :text
        "#{quoted_column} ILIKE ?"
      else
        "#{quoted_column} = ?"
      end
    when 'greater_than'
      "#{quoted_column} > ?"
    when 'less_than'
      "#{quoted_column} < ?"
    when 'is_null'
      "#{quoted_column} IS NULL"
    when 'is_not_null'
      "#{quoted_column} IS NOT NULL"
    else
      nil
    end
  end

  def format_filter_value(operator, value, column_type)
    case operator
    when 'contains', 'not_contains'
      if column_type == :string || column_type == :text
        "%#{value}%"
      else
        value
      end
    when 'starts_with'
      if column_type == :string || column_type == :text
        "#{value}%"
      else
        value
      end
    when 'ends_with'
      if column_type == :string || column_type == :text
        "%#{value}"
      else
        value
      end
    else
      value
    end
  end

  def sanitize_sql(condition)
    if condition.is_a?(Array)
      ActiveRecord::Base.sanitize_sql(condition)
    else
      condition
    end
  end

  def connection
    ActiveRecord::Base.connection
  end
end
