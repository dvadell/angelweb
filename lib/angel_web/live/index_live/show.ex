defmodule AngelWeb.IndexLive.Show do
  use AngelWeb, :live_view

  alias Angel.Graphs.Index
  alias Jason

  require Logger

  defp graphs_module, do: Application.get_env(:angel, :graphs, Angel.Graphs)
  defp events_module, do: Application.get_env(:angel, :events, Angel.Events)
  defp junior_module, do: Application.get_env(:angel, :junior, Angel.Junior)
  defp http_client_module, do: Application.get_env(:angel, :http_client, HTTPoison)

  @impl true
  def mount(%{"id" => graph_name}, _session, socket) do
    graph =
      graphs_module().get_by_short_name(graph_name) ||
        %Index{short_name: graph_name, title: "", notes: ""}

    changeset = Index.changeset(graph, %{})

    socket =
      socket
      |> assign(:events, events_module().for_graph(graph_name))
      |> assign(:graph_name, graph_name)
      |> assign(:graph, graph)
      |> assign(:form, to_form(changeset))
      |> assign(:show_form, false)
      |> assign(:show_events, false)
      |> assign(:show_notes, false)
      |> assign(:show_debug, false)
      |> assign(:metrics_count, graphs_module().count_metrics(graph_name))
      |> assign(:first_metric_at, graphs_module().first_metric_timestamp(graph_name))
      |> assign(:last_metric_at, graphs_module().last_metric_timestamp(graph_name))
      |> assign(:chart_is_playing, true)

    socket =
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Angel.PubSub, "new_metric:#{graph_name}")

        end_time = DateTime.utc_now()
        # 24 hours
        start_time = DateTime.add(end_time, -86_400, :second)
        fetch_and_push_data(socket, start_time, end_time)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"index" => graph_params}, socket) do
    changeset =
      socket.assigns.graph
      |> Index.changeset(graph_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("toggle_form", _params, socket) do
    {:noreply, assign(socket, :show_form, not socket.assigns.show_form)}
  end

  @impl true
  def handle_event("toggle_events", _params, socket) do
    {:noreply, assign(socket, :show_events, not socket.assigns.show_events)}
  end

  @impl true
  def handle_event("toggle_notes", _params, socket) do
    {:noreply, assign(socket, :show_notes, not socket.assigns.show_notes)}
  end

  @impl true
  def handle_event("toggle_debug", _params, socket) do
    {:noreply, assign(socket, :show_debug, not socket.assigns.show_debug)}
  end

  @impl true
  def handle_event("toggle_chart_play", _params, socket) do
    {:noreply, assign(socket, :chart_is_playing, not socket.assigns.chart_is_playing)}
  end

  @impl true
  def handle_event("set_range", %{"range" => "hour"}, socket) do
    end_time = DateTime.utc_now()
    start_time = DateTime.add(end_time, -3600, :second)
    {:noreply, fetch_and_push_data(socket, start_time, end_time)}
  end

  @impl true
  def handle_event("set_range", %{"range" => "day"}, socket) do
    end_time = DateTime.utc_now()
    start_time = DateTime.add(end_time, -86_400, :second)
    {:noreply, fetch_and_push_data(socket, start_time, end_time)}
  end

  @impl true
  def handle_event("set_range", %{"range" => "week"}, socket) do
    end_time = DateTime.utc_now()
    start_time = DateTime.add(end_time, -604_800, :second)
    {:noreply, fetch_and_push_data(socket, start_time, end_time)}
  end

  @impl true
  def handle_event("set_range", %{"range" => "month"}, socket) do
    end_time = DateTime.utc_now()
    start_time = DateTime.add(end_time, -2_592_000, :second)
    {:noreply, fetch_and_push_data(socket, start_time, end_time)}
  end

  @impl true
  def handle_event("save", %{"index" => graph_params}, socket) do
    graph_params = Map.put(graph_params, "short_name", socket.assigns.graph_name)
    graph_params = Map.update(graph_params, "notes", "", &HtmlSanitizeEx.markdown_html/1)

    case graphs_module().create_or_update_graph(graph_params) do
      {:ok, graph} ->
        changeset = Index.changeset(graph, graph_params)

        {:noreply,
         socket
         |> assign(:graph, graph)
         |> assign(:form, to_form(changeset))
         |> assign(:show_form, false)
         |> put_flash(:info, "Graph saved successfully!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event(
        "get_more_data",
        %{"start_time" => start_time_str, "end_time" => end_time_str},
        socket
      ) do
    with {:ok, start_time, _utc_offset} <- DateTime.from_iso8601(start_time_str),
         {:ok, end_time, _utc_offset} <- DateTime.from_iso8601(end_time_str) do
      graph_name = socket.assigns.graph_name

      case junior_module().trace("angel_graphs_fetch_timescaledb_data", fn ->
             graphs_module().fetch_timescaledb_data(graph_name, start_time, end_time)
           end) do
        {:ok, new_data} ->
          graph = socket.assigns.graph

          payload = prepare_chart_payload(new_data, [], graph)
          {:noreply, push_event(socket, "chart:data_loaded", %{data: payload})}

        {:error, _e} ->
          {:noreply, socket}
      end
    else
      _error ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "chart_zoomed",
        %{"visible_range" => %{"min" => min_ms, "max" => max_ms}, "zoom_level" => _level},
        socket
      ) do
    min_time = DateTime.from_unix!(trunc(min_ms), :millisecond)
    max_time = DateTime.from_unix!(trunc(max_ms), :millisecond)

    buffer_seconds = 300
    expanded_min = DateTime.add(min_time, -buffer_seconds, :second)
    expanded_max = DateTime.add(max_time, buffer_seconds, :second)

    graph_name = socket.assigns.graph_name

    case junior_module().trace("angel_graphs_fetch_timescaledb_data", fn ->
           graphs_module().fetch_timescaledb_data(graph_name, expanded_min, expanded_max)
         end) do
      {:ok, new_data} ->
        graph = socket.assigns.graph

        payload = prepare_chart_payload(new_data, [], graph)
        {:noreply, push_event(socket, "chart:data_loaded", %{data: payload})}

      {:error, _error} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "chart_panned",
        %{"visible_range" => %{"min" => min_ms, "max" => max_ms}},
        socket
      ) do
    min_time = DateTime.from_unix!(trunc(min_ms), :millisecond)
    max_time = DateTime.from_unix!(trunc(max_ms), :millisecond)

    buffer_seconds = 3600
    expanded_min = DateTime.add(min_time, -buffer_seconds, :second)
    expanded_max = DateTime.add(max_time, buffer_seconds, :second)

    graph_name = socket.assigns.graph_name

    case junior_module().trace("angel_graphs_fetch_timescaledb_data", fn ->
           graphs_module().fetch_timescaledb_data(graph_name, expanded_min, expanded_max)
         end) do
      {:ok, new_data} ->
        graph = socket.assigns.graph

        payload = prepare_chart_payload(new_data, [], graph)
        {:noreply, push_event(socket, "chart:data_loaded", %{data: payload})}

      {:error, _error} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:new_metric, metric, timestamp}, socket) do
    if socket.assigns.chart_is_playing do
      {:noreply,
       push_event(socket, "chart:new_data", %{
         value: metric.graph_value,
         timestamp: DateTime.to_unix(timestamp, :millisecond)
       })}
    else
      {:noreply, socket}
    end
  end

  # Fetches and prepares data, then pushes it to the client.
  defp fetch_and_push_data(socket, start_time, end_time) do
    graph_name = socket.assigns.graph_name

    case junior_module().trace("angel_graphs_fetch_timescaledb_data", fn ->
           graphs_module().fetch_timescaledb_data(graph_name, start_time, end_time)
         end) do
      {:ok, historical_data} ->
        forecast_points =
          case fetch_forecast_data(graph_name) do
            {:ok, points} ->
              Logger.info("Successfully fetched forecast data for #{graph_name}")
              points

            {:error, reason} ->
              Logger.error("Failed to fetch forecast data for #{graph_name}: #{inspect(reason)}")
              []
          end

        payload = prepare_chart_payload(historical_data, forecast_points, socket.assigns.graph)
        push_event(socket, "chart:data_loaded", %{data: payload})

      {:error, _e} ->
        payload = build_empty_chart_data(graph_name, socket.assigns.graph)
        push_event(socket, "chart:data_loaded", %{data: payload})
    end
  end

  defp prepare_chart_payload(historical_data, forecast_points, graph) do
    actual_series = List.first(historical_data)

    actual_map =
      Enum.into(actual_series.datapoints, %{}, fn [value, timestamp] -> {timestamp, value} end)

    forecast_maps = transform_forecast_points(forecast_points)

    all_timestamps =
      (Map.keys(actual_map) ++ Map.keys(forecast_maps.predicted))
      |> Enum.uniq()
      |> Enum.sort()

    %{
      dates: all_timestamps,
      actual: Enum.map(all_timestamps, &Map.get(actual_map, &1)),
      forecast: Enum.map(all_timestamps, &Map.get(forecast_maps.predicted, &1)),
      lower_bound: Enum.map(all_timestamps, &Map.get(forecast_maps.lower, &1)),
      upper_bound: Enum.map(all_timestamps, &Map.get(forecast_maps.upper, &1)),
      actual_label: actual_series.target,
      graph_type: graph.graph_type,
      min_value: graph.min_value,
      max_value: graph.max_value
    }
  end

  defp transform_forecast_points(forecast_points) do
    Enum.reduce(forecast_points, %{predicted: %{}, lower: %{}, upper: %{}}, fn point, acc ->
      {:ok, dt, 0} = DateTime.from_iso8601(point["timestamp"] <> "Z")
      timestamp = DateTime.to_unix(dt, :millisecond)

      predicted_map = Map.put(acc.predicted, timestamp, point["predicted_value"])
      lower_map = Map.put(acc.lower, timestamp, point["lower_bound"])
      upper_map = Map.put(acc.upper, timestamp, point["upper_bound"])

      %{predicted: predicted_map, lower: lower_map, upper: upper_map}
    end)
  end

  defp build_empty_chart_data(graph_name, graph) do
    [
      %{
        datapoints: [],
        target: graph_name,
        min_value: graph.min_value,
        max_value: graph.max_value,
        graph_type: graph.graph_type
      }
    ]
  end

  defp fetch_forecast_data(graph_name) do
    url = "http://forecasting:8000/forecast/#{graph_name}"
    body = Jason.encode!(%{"hours_ahead" => 24, "confidence_interval" => 0.95})
    headers = [{"Content-Type", "application/json"}]

    case http_client_module().post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"forecast_points" => points}} ->
            {:ok, points}

          _unmatched_json ->
            {:error, :json_parsing}
        end

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, {:http_error, status_code}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end
end
