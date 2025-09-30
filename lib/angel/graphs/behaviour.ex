defmodule Angel.Graphs.Behaviour do
  @moduledoc "Angel.Graphs.Behaviour"
  @callback fetch_timescaledb_data(String.t(), DateTime.t(), DateTime.t()) ::
              {:ok, list()} | {:error, any()}
  @callback create_or_update_graph(map()) :: {:ok, map()} | {:error, any()}
  @callback get_by_short_name(String.t()) :: Angel.Graphs.Index.t() | nil
  @callback count_metrics(String.t()) :: integer()
  @callback first_metric_timestamp(String.t()) :: DateTime.t() | nil
  @callback last_metric_timestamp(String.t()) :: DateTime.t() | nil
end
