defmodule Angel.Repo.Migrations.CreateTimescaledbAggregates do
  use Ecto.Migration

  @disable_ddl_transaction true

  def up do
    execute """
    CREATE TABLE IF NOT EXISTS metrics (
      timestamp TIMESTAMPTZ NOT NULL,
      name TEXT NOT NULL,
      value DOUBLE PRECISION NOT NULL
    );
    """

    execute "SELECT create_hypertable('metrics', 'timestamp', if_not_exists => TRUE);"

    # Drop views in case they exist from a previous failed migration
    execute "DROP MATERIALIZED VIEW IF EXISTS metrics_1hour;"
    execute "DROP MATERIALIZED VIEW IF EXISTS metrics_1min;"

    # Create continuous aggregate for minute-level data
    execute """
    CREATE MATERIALIZED VIEW metrics_1min
    WITH (timescaledb.continuous) AS
    SELECT time_bucket('1 minute', timestamp) AS bucket,
           name,
           avg(value) as avg_value,
           max(value) as max_value,
           min(value) as min_value
    FROM metrics
    GROUP BY bucket, name;
    """

    # Create continuous aggregate for hourly data
    execute """
    CREATE MATERIALIZED VIEW metrics_1hour
    WITH (timescaledb.continuous) AS
    SELECT time_bucket('1 hour', bucket) AS bucket,
           name,
           avg(avg_value) as avg_value,
           max(max_value) as max_value,
           min(min_value) as min_value
    FROM metrics_1min
    GROUP BY time_bucket('1 hour', bucket), name;
    """

    # Add retention policies
    execute "SELECT add_retention_policy('metrics', INTERVAL '1 day', if_not_exists => TRUE);"

    execute "SELECT add_retention_policy('metrics_1min', INTERVAL '1 week', if_not_exists => TRUE);"

    execute "SELECT add_retention_policy('metrics_1hour', INTERVAL '1 month', if_not_exists => TRUE);"

    # Create the get_metrics function
    execute """
    CREATE OR REPLACE FUNCTION get_metrics(metric_name TEXT, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ)
    RETURNS TABLE(metric_timestamp TIMESTAMPTZ, avg_value NUMERIC, max_value NUMERIC, min_value NUMERIC) AS $func$
    BEGIN
        IF start_time >= NOW() - INTERVAL '1 day' THEN
            -- Use raw data, bucketed to minutes
            RETURN QUERY
            SELECT time_bucket('1 minute', m.timestamp) as metric_timestamp,
                   avg(m.value)::NUMERIC as avg_value,
                   max(m.value)::NUMERIC as max_value,
                   min(m.value)::NUMERIC as min_value
            FROM metrics m
            WHERE m.name = metric_name AND m.timestamp BETWEEN start_time AND end_time
            GROUP BY time_bucket('1 minute', m.timestamp)
            ORDER BY metric_timestamp;
        ELSIF start_time >= NOW() - INTERVAL '1 week' THEN
            -- Use minute data
            RETURN QUERY
            SELECT m.bucket as metric_timestamp,
                   m.avg_value::NUMERIC,
                   m.max_value::NUMERIC,
                   m.min_value::NUMERIC
            FROM metrics_1min m
            WHERE m.name = metric_name AND m.bucket BETWEEN start_time AND end_time
            ORDER BY metric_timestamp;
        ELSE
            -- Use hourly data
            RETURN QUERY
            SELECT m.bucket as metric_timestamp,
                   m.avg_value::NUMERIC,
                   m.max_value::NUMERIC,
                   m.min_value::NUMERIC
            FROM metrics_1hour m
            WHERE m.name = metric_name AND m.bucket BETWEEN start_time AND end_time
            ORDER BY metric_timestamp;
        END IF;
    END;
    $func$ LANGUAGE plpgsql;
    """
  end

  def down do
    # Drop the function
    execute "DROP FUNCTION IF EXISTS get_metrics(TEXT, TIMESTAMPTZ, TIMESTAMPTZ);"

    # Drop materialized views (this also removes retention policies)
    execute "DROP MATERIALIZED VIEW IF EXISTS metrics_1hour;"
    execute "DROP MATERIALIZED VIEW IF EXISTS metrics_1min;"

    execute "DROP TABLE IF EXISTS metrics;"
  end
end
