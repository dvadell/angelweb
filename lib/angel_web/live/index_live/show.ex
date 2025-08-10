defmodule AngelWeb.IndexLive.Show do
  use AngelWeb, :live_view
  alias Angel.Graphs
  alias Jason

  @impl true
  def mount(%{"id" => graph_name}, _session, socket) do
    shorter_graph_name = graph_name |> String.replace("stats.gauges.jr.", "")
    graph = Graphs.get_by_short_name(shorter_graph_name) || %Angel.Graphs.Index{short_name: shorter_graph_name, title: "", notes: ""}

    # Create the form changeset
    changeset = Angel.Graphs.Index.changeset(graph, %{})

    {:ok,
      socket
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
  def handle_event("get_initial_data", _params, socket) do
    graph_name = socket.assigns.graph_name
    
    end_time = DateTime.utc_now()
    start_time = DateTime.add(end_time, -86_400, :second) # 24 hours

    case Angel.Graphs.fetch_timescaledb_data(graph_name, start_time, end_time) do
      {:ok, data} ->
        {:noreply, push_event(socket, "chart:data_loaded", %{data: data})}
      {:error, _e} ->
        # Send empty data structure on error
        empty_data = [%{datapoints: [], target: graph_name}]
        {:noreply, push_event(socket, "chart:data_loaded", %{data: empty_data})}
    end
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

  @impl true
  def handle_event("get_more_data", %{"start_time" => start_time_str, "end_time" => end_time_str}, socket) do
    with {:ok, start_time, _} <- DateTime.from_iso8601(start_time_str),
         {:ok, end_time, _} <- DateTime.from_iso8601(end_time_str) do
      graph_name = socket.assigns.graph_name

      case Angel.Graphs.fetch_timescaledb_data(graph_name, start_time, end_time) do
        {:ok, new_data} ->
          {:noreply, push_event(socket, "chart:data_loaded", %{data: new_data})}
        {:error, _e} ->
          {:noreply, socket}
      end
    else
      _error ->
        {:noreply, socket}
    end
  end

  # Handle pan/zoom events from the chart
  @impl true
  def handle_event("chart_zoomed", %{"visible_range" => %{"min" => min_ms, "max" => max_ms}, "zoom_level" => level}, socket) do
    IO.inspect("CHART_ZOOMED")
    # Convert milliseconds to DateTime
    min_time = DateTime.from_unix!(trunc(min_ms), :millisecond)
    max_time = DateTime.from_unix!(trunc(max_ms), :millisecond)
    
    IO.inspect(%{min: min_time, max: max_time, zoom: level}, label: "Chart zoomed")
    
    # If zoomed in significantly (showing less than 6 hours), load higher resolution data
    time_span_hours = DateTime.diff(max_time, min_time, :hour)
    
    IO.inspect(time_span_hours, label: "Zoomed in significantly, loading detailed data for hours")
      
    # Add small buffer for zoomed data
    buffer_seconds = 300 # 5 minutes buffer
    expanded_min = DateTime.add(min_time, -buffer_seconds, :second)
    expanded_max = DateTime.add(max_time, buffer_seconds, :second)
      
    graph_name = socket.assigns.graph_name
      
    case Angel.Graphs.fetch_timescaledb_data(graph_name, expanded_min, expanded_max) do
      {:ok, new_data} ->
      IO.inspect(new_data, label: "Data points loaded")
        {:noreply, push_event(socket, "chart:data_loaded", %{data: new_data})}
      {:error, error} ->
        IO.inspect(error, label: "Error loading zoomed data")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("chart_panned", %{"visible_range" => %{"min" => min_ms, "max" => max_ms}}, socket) do
    IO.inspect("CHART_PANNED")
    # Convert milliseconds to DateTime
    min_time = DateTime.from_unix!(trunc(min_ms), :millisecond)
    max_time = DateTime.from_unix!(trunc(max_ms), :millisecond)
    
    # Add some buffer around the visible range to preload data
    buffer_seconds = 3600 # 1 hour buffer on each side
    expanded_min = DateTime.add(min_time, -buffer_seconds, :second)
    expanded_max = DateTime.add(max_time, buffer_seconds, :second)
    
    IO.inspect(%{min: min_time, max: max_time}, label: "Visible range")
    IO.inspect(%{min: expanded_min, max: expanded_max}, label: "Loading range with buffer")
    
    graph_name = socket.assigns.graph_name
    
    case Angel.Graphs.fetch_timescaledb_data(graph_name, expanded_min, expanded_max) do
      {:ok, new_data} ->
        IO.inspect(new_data, label: "Data points loaded")
        {:noreply, push_event(socket, "chart:data_loaded", %{data: new_data})}
      {:error, error} ->
        IO.inspect(error, label: "Error loading panned data")
        {:noreply, socket}
    end
  end
end
