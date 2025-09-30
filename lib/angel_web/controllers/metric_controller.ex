defmodule AngelWeb.MetricController do
  use AngelWeb, :controller

  import Ecto.Changeset, only: [traverse_errors: 2]

  alias Angel.Events
  alias Angel.Graphs
  alias Angel.Graphs.Index
  alias Angel.Metrics
  alias AngelWeb.Schemas.IncomingMetricPayload
  alias DateTime
  alias Jason

  require Logger

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, metric_params) do
    current_timestamp = DateTime.utc_now()

    with {:ok, metric} <- validate_metric(metric_params),
         {:ok, graph} <- create_or_update_graph(metric, metric_params),
         :ok <- check_metric_range(graph, metric),
         {:ok, _metric} <- add_metric(graph, metric, current_timestamp) do
      broadcast_metric(graph, metric, current_timestamp)

      conn
      |> put_status(:created)
      |> json(%{message: "Data sent to TimescaleDB"})
    else
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})
    end
  end

  @spec validate_metric(map()) :: {:ok, IncomingMetricPayload.t()} | {:error, map()}
  defp validate_metric(metric_params) do
    changeset = IncomingMetricPayload.changeset(%IncomingMetricPayload{}, metric_params)
    if changeset.valid?, do: handle_valid_changeset(changeset), else: handle_invalid_changeset(changeset)
  end

  @spec handle_valid_changeset(Ecto.Changeset.t()) :: {:ok, IncomingMetricPayload.t()}
  defp handle_valid_changeset(changeset) do
    {:ok, Ecto.Changeset.apply_changes(changeset)}
  end

  @spec handle_invalid_changeset(Ecto.Changeset.t()) :: {:error, map()}
  defp handle_invalid_changeset(changeset) do
    errors =
      traverse_errors(changeset, fn {msg, _opts} -> msg end)

    {:error, errors}
  end

  @spec create_or_update_graph(IncomingMetricPayload.t(), map()) ::
          {:ok, Index.t()} | {:error, Ecto.Changeset.t()}
  defp create_or_update_graph(metric, metric_params) do
    graph_params = %{
      "short_name" => Map.get(metric_params, "short_name"),
      "units" => metric.type,
      "min_value" => Map.get(metric_params, "min_value"),
      "max_value" => Map.get(metric_params, "max_value"),
      "graph_type" => Map.get(metric_params, "graph_type")
    }

    Graphs.create_or_update_graph(graph_params)
  end

  @spec check_metric_range(Index.t(), IncomingMetricPayload.t()) :: :ok
  defp check_metric_range(graph, metric) do
    case within_range?(graph.max_value, graph.min_value, metric.graph_value) do
      {:error, message} ->
        case Events.create_event(%{for_graph: graph.short_name, text: message}) do
          {:ok, _event} ->
            :ok

          {:error, changeset} ->
            Logger.error("Failed to create event: #{inspect(changeset)}")
            :ok
        end

      :ok ->
        :ok
    end
  end

  @spec add_metric(Index.t(), IncomingMetricPayload.t(), DateTime.t()) ::
          {:ok, Metrics.t()} | {:error, Ecto.Changeset.t()}
  defp add_metric(graph, metric, timestamp) do
    Metrics.add_metric(%{
      timestamp: timestamp,
      name: graph.short_name,
      value: metric.graph_value
    })
  end

  @spec broadcast_metric(Index.t(), IncomingMetricPayload.t(), DateTime.t()) :: :ok
  defp broadcast_metric(graph, metric, timestamp) do
    Phoenix.PubSub.broadcast(
      Angel.PubSub,
      "new_metric:#{graph.short_name}",
      {:new_metric, metric, timestamp}
    )
  end

  @spec within_range?(number() | nil, number() | nil, number()) :: :ok | {:error, String.t()}
  defp within_range?(max, min, value) do
    cond do
      min && value < min -> {:error, "Value #{value} is below min_value #{min}"}
      max && value > max -> {:error, "Value #{value} is above max_value #{max}"}
      true -> :ok
    end
  end
end
