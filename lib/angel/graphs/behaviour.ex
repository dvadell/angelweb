defmodule Angel.Graphs.Behaviour do
  @callback fetch_timescaledb_data(String.t(), DateTime.t(), DateTime.t()) ::
              {:ok, list()} | {:error, any()}
  @callback create_or_update_graph(map()) :: {:ok, map()} | {:error, any()}
end
