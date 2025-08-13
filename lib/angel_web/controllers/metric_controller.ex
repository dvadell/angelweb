defmodule AngelWeb.MetricController do
  use AngelWeb, :controller
  alias Angel.Events
  alias Angel.Graphs
  alias Angel.Repo
  alias Jason
  alias DateTime

  def create(conn, metric_params) do
    short_name = Map.get(metric_params, "short_name")
    graph_value = Map.get(metric_params, "graph_value")
    min_value = Map.get(metric_params, "min_value")
    max_value = Map.get(metric_params, "max_value")
    with changeset <- AngelWeb.Schemas.Metric.changeset(%AngelWeb.Schemas.Metric{}, metric_params),
         true <- changeset.valid?,
         metric <- Ecto.Changeset.apply_changes(changeset) do

      prefixed_short_name = "jr.#{short_name}"

      graph_params = %{"short_name" => prefixed_short_name, "units" => metric.type, "min_value" => min_value, "max_value" => max_value}
      {:ok, graph} = Graphs.create_or_update_graph(graph_params)

      Events.create_event( %{for_graph: prefixed_short_name, text: "Value: #{graph_value} #{graph.units}"} )

      Repo.query("INSERT INTO metrics(timestamp, name, value) VALUES (NOW(), $1, $2);", [prefixed_short_name, metric.graph_value])
      conn
      |> put_status(:created)
      |> json(%{message: "Data sent to TimescaleDB"})
    else
      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid data"})
    end
  end

  def show(conn, %{"name" => name, "start_time" => start_time_str, "end_time" => end_time_str}) do
    with {:ok, start_time, _} <- DateTime.from_iso8601(start_time_str),
         {:ok, end_time, _} <- DateTime.from_iso8601(end_time_str),
         {:ok, data} <- Application.get_env(:angel, Angel.Graphs).fetch_timescaledb_data(name, start_time, end_time) do
      conn
      |> put_status(:ok)
      |> json(data)
    else
      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid parameters or data not found"})
    end
  end
end

