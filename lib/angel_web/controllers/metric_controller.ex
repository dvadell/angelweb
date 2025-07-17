defmodule AngelWeb.MetricController do
  use AngelWeb, :controller
  alias Angel.Events
  alias Angel.Graphs

  def create(conn, metric_params = %{"short_name" => short_name, "graph_value" => graph_value}) do
    with changeset <- AngelWeb.Schemas.Metric.changeset(%AngelWeb.Schemas.Metric{}, metric_params),
         true <- changeset.valid?,
         metric <- Ecto.Changeset.apply_changes(changeset) do

      {:ok, graph} = Graphs.create_or_update_graph(metric_params)

      Events.create_event( %{for_graph: "jr.#{short_name}", text: "Value: #{graph_value} #{graph.units}"} )

      send_to_graphite(metric.short_name, metric.graph_value, metric.type)
      conn
      |> put_status(:created)
      |> json(%{message: "Data sent to Graphite"})
    else
      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid data"})
    end
  end

  defp send_to_graphite(short_name, graph_value, type) do
    conf = Application.get_env(:angel, AngelWeb.MetricController, [graphite_host: "localhost", graphite_port: 8125] )

    # Erlang's UDP socket needs hostname as charlist.
    graphite_host = conf[:graphite_host] |> Kernel.to_charlist
    graphite_port = conf[:graphite_port]

    message = "jr.#{short_name}:#{graph_value}|#{type}"

    {:ok, socket} = :gen_udp.open(0)
    :gen_udp.send(socket, graphite_host, graphite_port,  message)
    :gen_udp.close(socket)
  end
end

