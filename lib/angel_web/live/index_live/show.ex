defmodule AngelWeb.IndexLive.Show do
  use AngelWeb, :live_view

  @impl true
  def mount(%{"id" => graph_name}, _session, socket) do
    {:ok, assign(socket, :graph_data, fetch_graph_data(graph_name))}
  end

  defp fetch_graph_data(graph_name) do
    url = "http://localhost:80/render?target=#{graph_name}&from=-24hours&format=json"
    response = HTTPoison.get!(url)
    response.body
  end
end
