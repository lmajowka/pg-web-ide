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

    if attributes.empty?
      redirect_to db_ide_path(table: table, edit: row_id), alert: "Nothing to update."
      return
    end

    apply_update(table, primary_key, row_id, attributes)

    redirect_to db_ide_path(table: table), notice: "Row updated successfully."
  rescue ActiveRecord::StatementInvalid => e
    redirect_to db_ide_path(table: table, edit: params[:id]), alert: e.message
  end

  private

  def ensure_development!
    return if Rails.env.development?

    head :forbidden
  end

  def prepare_state
    @tables = fetch_tables
    @selected_table = params[:table].presence || @tables.first
    if @selected_table
      @table_primary_key = primary_key_for(@selected_table)
      @table_columns_info = columns_info_for(@selected_table)
      @table_result = load_table_rows(@selected_table)
      @editable_row_id = params[:edit].presence
      @editable_row = load_row(@selected_table, @table_primary_key, @editable_row_id)
    end
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

  def permitted_attributes(table_name, primary_key)
    raw_params = params[:row]
    return {} unless raw_params.is_a?(ActionController::Parameters)

    allowed_columns = columns_info_for(table_name).map(&:name)
    permitted = raw_params.permit(*allowed_columns)
    permitted.to_h.except(primary_key)
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

  def connection
    ActiveRecord::Base.connection
  end
end
