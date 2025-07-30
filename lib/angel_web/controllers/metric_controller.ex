defmodule AngelWeb.MetricController do
  use AngelWeb, :controller
  alias Angel.Events
  alias Angel.Graphs
  alias Angel.Repo

  def create(conn, metric_params = %{"short_name" => short_name, "graph_value" => graph_value}) do
    with changeset <- AngelWeb.Schemas.Metric.changeset(%AngelWeb.Schemas.Metric{}, metric_params),
         true <- changeset.valid?,
         metric <- Ecto.Changeset.apply_changes(changeset) do

      prefixed_short_name = "jr.#{short_name}"

      graph_params = %{"short_name" => prefixed_short_name, "units" => metric.type}
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
end

