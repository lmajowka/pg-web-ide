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
      @table_result = load_table_rows(@selected_table)
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

  def connection
    ActiveRecord::Base.connection
  end
end
