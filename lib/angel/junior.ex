defmodule Angel.Junior do
  @moduledoc """
  A module for tracing function execution time and sending it as a metric.
  """

  alias Angel.Graphs
  alias Angel.Metrics
  alias DateTime

  @doc """
  Traces the execution time of a function and sends it as a metric.

  ## Examples

      iex> Angel.Junior.trace("my_function", fn -> 1 + 1 end)
      2

  """
  def trace(name, fun) when is_function(fun) do
    {time_in_microseconds, result} = :timer.tc(fun)
    time_in_milliseconds = time_in_microseconds / 1000

    if Mix.env() != :test do
      graph_params = %{
        "short_name" => name,
        "units" => "ms",
        "graph_type" => "time"
      }

      Graphs.create_or_update_graph(graph_params)

      Metrics.add_metric(%{
        timestamp: DateTime.utc_now(),
        name: name,
        value: time_in_milliseconds
      })
    end

    result
  end

  def trace(name, number) when is_number(number) do
    if Mix.env() != :test do
      graph_params = %{
        "short_name" => name,
        "units" => "ms",
        "graph_type" => "time"
      }

      Graphs.create_or_update_graph(graph_params)

      Metrics.add_metric(%{
        timestamp: DateTime.utc_now(),
        name: name,
        value: number
      })
    end
  end
end