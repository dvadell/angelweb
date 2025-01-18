defmodule AngelWeb.MetricController do
  use AngelWeb, :controller

  def create(conn, metric_params) do
    with changeset <- AngelWeb.Schemas.Metric.changeset(%AngelWeb.Schemas.Metric{}, metric_params),
         true <- changeset.valid?,
         %{short_name: short_name, graph_value: graph_value, type: type} <- Ecto.Changeset.apply_changes(changeset) do
        send_to_graphite(short_name, graph_value, type)
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
    graphite_host = Application.get_env(:angel, :graphite_host) || {127,0,0,1}
    graphite_port = Application.get_env(:angel, :graphite_port) || 8125

    message = "jr.#{short_name}:#{graph_value}|#{type}"

    {:ok, socket} = :gen_udp.open(0)
    :gen_udp.send(socket, graphite_host, graphite_port,  message)
    :gen_udp.close(socket)
  end
end

