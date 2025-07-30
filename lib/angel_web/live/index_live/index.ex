defmodule AngelWeb.IndexLive.Index do
  use AngelWeb, :live_view
  alias Angel.Graphs

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :graphs, list_graphs())}
  end

  defp list_graphs() do
    Graphs.list_graphs()
  end
end
