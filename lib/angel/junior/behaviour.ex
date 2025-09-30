defmodule Angel.Junior.Behaviour do
  @moduledoc """
  A behaviour for tracing function execution time and sending it as a metric.
  """

  @callback trace(String.t(), number()) :: any()
  @callback trace(String.t(), (-> any())) :: any()
end
