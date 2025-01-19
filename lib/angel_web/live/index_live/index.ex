defmodule AngelWeb.IndexLive.Index do
  use AngelWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :graph_data, fetch_graph_data())}
  end

  defp fetch_graph_data() do
    url = "http://localhost:80/render?target=stats.gauges.jr.load_avg&from=-24hours&format=json"
    response = HTTPoison.get!(url)
    Jason.decode!(response.body)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h1>Graphs</h1>
    <canvas id="myChart"></canvas>
    """
  end
end
