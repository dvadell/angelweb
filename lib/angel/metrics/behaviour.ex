defmodule Angel.Metrics.Behaviour do
  @moduledoc "Angel Metrics Behaviour"
  @callback add_metric(map()) :: {:ok, map()} | {:error, map()}
end
