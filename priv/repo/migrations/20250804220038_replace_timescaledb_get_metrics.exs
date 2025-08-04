defmodule Angel.Repo.Migrations.ReplaceTimescaledbGetMetrics do
  use Ecto.Migration

  @disable_ddl_transaction true

  def up do
    # Drop the old get_metrics function
    execute "DROP FUNCTION IF EXISTS get_metrics(TEXT, TIMESTAMPTZ, TIMESTAMPTZ);"

    # Create the new union-based get_metrics function
    execute """
    CREATE OR REPLACE FUNCTION get_metrics(metric_name TEXT, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ)
    RETURNS TABLE(metric_timestamp TIMESTAMPTZ, avg_value NUMERIC, max_value NUMERIC, min_value NUMERIC) AS $func$
    BEGIN
        RETURN QUERY
        (
            -- Recent data (last day) from raw table
            SELECT time_bucket('1 minute', m.timestamp) as metric_timestamp,
                   avg(m.value)::NUMERIC as avg_value,
                   max(m.value)::NUMERIC as max_value,
                   min(m.value)::NUMERIC as min_value
            FROM metrics m
            WHERE m.name = metric_name 
              AND m.timestamp BETWEEN start_time AND end_time
              AND m.timestamp >= NOW() - INTERVAL '1 day'
            GROUP BY time_bucket('1 minute', m.timestamp)
            
            UNION ALL
            
            -- Older data (1 day to 1 week) from minute aggregates
            SELECT m.bucket as metric_timestamp,
                   m.avg_value::NUMERIC,
                   m.max_value::NUMERIC,
                   m.min_value::NUMERIC
            FROM metrics_1min m
            WHERE m.name = metric_name 
              AND m.bucket BETWEEN start_time AND end_time
              AND m.bucket < NOW() - INTERVAL '1 day'
              AND m.bucket >= NOW() - INTERVAL '1 week'
            
            UNION ALL
            
            -- Very old data (older than 1 week) from hourly aggregates
            SELECT m.bucket as metric_timestamp,
                   m.avg_value::NUMERIC,
                   m.max_value::NUMERIC,
                   m.min_value::NUMERIC
            FROM metrics_1hour m
            WHERE m.name = metric_name 
              AND m.bucket BETWEEN start_time AND end_time
              AND m.bucket < NOW() - INTERVAL '1 week'
        )
        ORDER BY metric_timestamp;
    END;
    $func$ LANGUAGE plpgsql;
    """
  end

  def down do
    # Drop the new function
    execute "DROP FUNCTION IF EXISTS get_metrics(TEXT, TIMESTAMPTZ, TIMESTAMPTZ);"

    # Restore the old get_metrics function
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
end
