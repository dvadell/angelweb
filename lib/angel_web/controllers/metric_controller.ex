defmodule AngelWeb.MetricController do
  use AngelWeb, :controller
  alias Angel.Events
  alias Angel.Graphs
  alias Angel.Metrics
  alias Angel.Repo
  alias AngelWeb.Schemas
  alias DateTime
  alias Jason

  require Logger

  def create(conn, metric_params) do
    short_name = Map.get(metric_params, "short_name")
    graph_value = Map.get(metric_params, "graph_value")
    min_value = Map.get(metric_params, "min_value")
    max_value = Map.get(metric_params, "max_value")
    graph_type = Map.get(metric_params, "graph_type")

    with changeset <-
           Schemas.Graph.changeset(%AngelWeb.Schemas.Graph{}, metric_params),
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

      # Check if graph_value is below min_value or above max_value
      cond do
        graph.min_value && metric.graph_value < graph.min_value ->
          Events.create_event(%{
            for_graph: graph.short_name,
            text: "Value #{metric.graph_value} is below min_value #{graph.min_value}"
          })

        graph.max_value && metric.graph_value > graph.max_value ->
          Events.create_event(%{
            for_graph: graph.short_name,
            text: "Value #{metric.graph_value} is above max_value #{graph.max_value}"
          })

        true ->
          :ok
      end

      # Replace raw SQL with Ecto insert
      current_timestamp = DateTime.utc_now() # Revert to original
      metrics_changeset = Angel.Metrics.changeset(%Angel.Metrics{}, %{
        timestamp: current_timestamp,
        name: graph.short_name,
        value: metric.graph_value
      })

      case Repo.insert(metrics_changeset) do
        {:ok, _res} -> :ok
        {:error, e} ->
          Logger.error("Error inserting metric: #{inspect(e)}")
          {:error, e}
      end

      Phoenix.PubSub.broadcast(
        Angel.PubSub,
        "new_metric:#{graph.short_name}",
        {:new_metric, metric, current_timestamp}
      )

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

  end
