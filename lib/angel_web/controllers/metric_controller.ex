defmodule AngelWeb.MetricController do
  use AngelWeb, :controller
  alias Angel.Events
  alias Angel.Graphs
  alias Angel.Metrics
  alias AngelWeb.Schemas.IncomingMetricPayload
  alias DateTime
  alias Jason

  require Logger

  def create(conn, metric_params) do
    short_name = Map.get(metric_params, "short_name")
    min_value = Map.get(metric_params, "min_value")
    max_value = Map.get(metric_params, "max_value")
    graph_type = Map.get(metric_params, "graph_type")
    current_timestamp = DateTime.utc_now()

    with changeset <- IncomingMetricPayload.changeset(%IncomingMetricPayload{}, metric_params),
         true <- changeset.valid?,
         metric <- Ecto.Changeset.apply_changes(changeset) do
      graph_params = %{
        "short_name" => short_name,
        "units" => metric.type,
        "min_value" => min_value,
        "max_value" => max_value,
        "graph_type" => graph_type
      }

      {:ok, graph} = Graphs.create_or_update_graph(graph_params)

      send_event_if_not_within_range(short_name, graph.max_value, graph.min_value, metric.graph_value)

      {:ok, _changeset} =
        Metrics.add_metric(%{timestamp: current_timestamp, name: graph.short_name, value: metric.graph_value})

      Phoenix.PubSub.broadcast(Angel.PubSub, "new_metric:#{graph.short_name}", {:new_metric, metric, current_timestamp})

      conn
      |> put_status(:created)
      |> json(%{message: "Data sent to TimescaleDB"})
    else
      _error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid data"})
    end
  end

  defp send_event_if_not_within_range(short_name, max, min, value) do
    is_within_range? = fn max, min, value ->
      # Check if graph_value is below min_value or above max_value
      cond do
        min && value < min -> {:error, "Value #{value} is below min_value #{min}"}
        max && value > max -> {:error, "Value #{value} is above max_value #{max}"}
        true -> :ok
      end
    end

    case is_within_range?.(max, min, value) do
      {:error, message} -> Events.create_event(%{for_graph: short_name, text: message})
      :ok -> nil
    end
  end
end
