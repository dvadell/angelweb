defmodule AngelWeb.IndexLive.Show do
  use AngelWeb, :live_view
  alias Angel.Graphs
  alias Angel.Repo

  @impl true
  def mount(%{"id" => graph_name}, _session, socket) do
    shorter_graph_name = graph_name |> String.replace("stats.gauges.jr.", "")
    graph = Graphs.get_by_short_name(shorter_graph_name) || %Angel.Graphs.Index{short_name: shorter_graph_name, title: "", notes: ""}

    # Create the form changeset
    changeset = Angel.Graphs.Index.changeset(graph, %{})

    {:ok,
      socket
      |> assign(:graph_data, fetch_timescaledb_data(shorter_graph_name))
      |> assign(:events, Angel.Events.for_graph(shorter_graph_name))
      |> assign(:graph_name, shorter_graph_name)
      |> assign(:graph, graph)
      |> assign(:form, to_form(changeset))
      |> assign(:show_form, false)
      |> assign(:show_events, false)
      |> assign(:show_notes, false)
    }
  end

  @impl true
  def handle_event("validate", %{"index" => graph_params}, socket) do
    changeset = 
      socket.assigns.graph
      |> Angel.Graphs.Index.changeset(graph_params)
      |> Map.put(:action, :validate)
    
    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("toggle_form", _, socket) do
    {:noreply, assign(socket, :show_form, not socket.assigns.show_form)}
  end

  @impl true
  def handle_event("toggle_events", _, socket) do
    {:noreply, assign(socket, :show_events, not socket.assigns.show_events)}
  end

  @impl true
  def handle_event("toggle_notes", _, socket) do
    {:noreply, assign(socket, :show_notes, not socket.assigns.show_notes)}
  end

  @impl true
  def handle_event("save", %{"index" => graph_params}, socket) do
    # Add the short_name to the params since it's needed for save
    graph_params = Map.put(graph_params, "short_name", socket.assigns.graph_name)
    
    case Graphs.create_or_update_graph(graph_params) do
      {:ok, graph} ->
        # Update both the graph and create a new clean form
        changeset = Angel.Graphs.Index.changeset(graph, graph_params)
        {:noreply, 
         socket
         |> assign(:graph, graph)
         |> assign(:form, to_form(changeset))
         |> assign(:show_form, false)
         |> put_flash(:info, "Graph saved successfully!")
        }
      {:error, changeset} ->
        # Show validation errors in the form
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def fetch_timescaledb_data(graph_name_with_prefix) do
    # The name in the metrics table likely has the "jr." prefix, so we use it directly.
    end_time = DateTime.utc_now()
    start_time = DateTime.add(end_time, -86_400, :second) # 24 hours

    query = "SELECT * FROM get_metrics($1, $2, $3);"

    case Repo.query(query, ["jr." <> graph_name_with_prefix, start_time, end_time]) do
      {:ok, %Postgrex.Result{rows: rows}} ->
        datapoints = 
          Enum.map(rows, fn [timestamp, avg_value, _max, _min] ->
            # The JS graph wants milliseconds since epoch
            unix_timestamp = DateTime.to_unix(timestamp, :millisecond)
            # Handle nil values for avg_value, which can happen for empty time buckets.
            value = if avg_value, do: Decimal.to_float(avg_value), else: nil
            [value, unix_timestamp]
          end)

        result = [%{target: graph_name_with_prefix, datapoints: datapoints}]
        Jason.encode!(result)

      {:error, e} ->
        IO.inspect(e, label: "Error fetching data from TimescaleDB")
        Jason.encode!([%{target: graph_name_with_prefix, datapoints: []}])
    end
  end
end
