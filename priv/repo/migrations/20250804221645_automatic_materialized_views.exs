defmodule Angel.Repo.Migrations.AutomaticMaterializedViews do
  use Ecto.Migration

  def up do
    execute """
    SELECT add_continuous_aggregate_policy('metrics_1min',
        start_offset => INTERVAL '2 hours',
        end_offset => INTERVAL '1 minute',
        schedule_interval => INTERVAL '1 minute',
        if_not_exists => TRUE);
    """

    execute """
    SELECT add_continuous_aggregate_policy('metrics_1hour',
        start_offset => INTERVAL '3 hours',
        end_offset => INTERVAL '30 minutes', 
        schedule_interval => INTERVAL '30 minutes',
        if_not_exists => TRUE);
    """
  end
end
