class DbIdeController < ApplicationController
  MAX_ROWS = 50

  before_action :ensure_development!

  def index
    prepare_state
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

  private

  def ensure_development!
    return if Rails.env.development?

    head :forbidden
  end

  def prepare_state
    @tables = fetch_tables
    @selected_table = params[:table].presence || @tables.first
    @table_result = load_table_rows(@selected_table) if @selected_table
    @query ||= default_query(@selected_table)
  end

  def fetch_tables
    connection.tables.reject { |name| name.start_with?("pg_") || name == "schema_migrations" }
  end

  def load_table_rows(table_name)
    return unless table_name

    quoted = connection.quote_table_name(table_name)
    connection.exec_query("SELECT * FROM #{quoted} LIMIT #{MAX_ROWS}")
  end

  def default_query(table_name)
    return "" unless table_name

    "SELECT * FROM #{connection.quote_table_name(table_name)} LIMIT #{MAX_ROWS};"
  end

  def run_query(sql)
    connection.exec_query(sql)
  end

  def connection
    ActiveRecord::Base.connection
  end
end
