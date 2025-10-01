defmodule AngelWeb.IndexLive.ShowTest do
  use AngelWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mox

  # Define a behaviour for our HTTP client. This is what Mox will mock.
  defmodule HTTPClientBehaviour do
    @callback post(url :: String.t(), body :: String.t(), headers :: list()) ::
                {:ok, %HTTPoison.Response{}} | {:error, %HTTPoison.Error{}}
  end

  # Define the mock based on the behaviour
  Mox.defmock(HTTPoison.Mock, for: HTTPClientBehaviour)

  setup do
    # Configure the application to use our mocks instead of the real modules
    # for the duration of this test.
    Application.put_env(:angel, :http_client, HTTPoison.Mock)
    Application.put_env(:angel, :graphs, Angel.Graphs.Mock)
    Application.put_env(:angel, :events, Angel.Events.Mock)
    Application.put_env(:angel, :junior, Angel.Junior.Mock)

    # The on_exit callback ensures the configuration is restored after the test.
    on_exit(fn ->
      Application.delete_env(:angel, :http_client)
      Application.delete_env(:angel, :graphs)
      Application.delete_env(:angel, :events)
      Application.delete_env(:angel, :junior)
    end)

    :ok
  end

  describe "Forecasting Feature" do
    test "sends combined historical and forecast data on successful fetch", %{conn: conn} do
      graph_name = "test_metric"
      graph = %Angel.Graphs.Index{short_name: graph_name, title: "Test Graph", graph_type: "line"}

      # Stub trace calls
      stub(Angel.Junior.Mock, :trace, fn _trace_name, val ->
        if is_function(val, 0), do: val.(), else: val
      end)

      # Mocks for mount
      expect(Angel.Graphs.Mock, :get_by_short_name, 2, fn _graph_name -> graph end)
      expect(Angel.Graphs.Mock, :count_metrics, 2, fn _metric_count_arg -> 100 end)
      expect(Angel.Graphs.Mock, :first_metric_timestamp, 2, fn _timestamp_arg -> DateTime.utc_now() end)
      expect(Angel.Graphs.Mock, :last_metric_timestamp, 2, fn _timestamp_arg -> DateTime.utc_now() end)
      expect(Angel.Events.Mock, :for_graph, 2, fn _graph_arg -> [] end)

      # Mock historical data fetch on mount
      historical_timestamp = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
      historical_data = [%{target: graph_name, datapoints: [[100, historical_timestamp]]}]

      expect(
        Angel.Graphs.Mock,
        :fetch_timescaledb_data,
        2,
        fn _graph_name, _start_time, _end_time -> {:ok, historical_data} end
      )

      # Mount the LiveView
      {:ok, view, _html} = live(conn, "/graphs/#{graph_name}")

      # Assert initial data load (no forecast)
      assert_receive {_, {:push_event, "chart:data_loaded", %{data: initial_data}}}
      assert length(initial_data[:dates]) == 1
      assert initial_data[:actual] == [100]
      assert initial_data[:forecast] == [nil]

      # Mock the forecast service call
      forecast_timestamp = DateTime.utc_now() |> DateTime.add(3600, :second)
      forecast_iso = forecast_timestamp |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      forecast_points = [
        %{
          "timestamp" => forecast_iso,
          "predicted_value" => 110,
          "lower_bound" => 105,
          "upper_bound" => 115
        }
      ]

      forecast_response_body = Jason.encode!(%{"forecast_points" => forecast_points})

      expect(HTTPoison.Mock, :post, fn _url, _body, _headers ->
        {:ok, %HTTPoison.Response{status_code: 200, body: forecast_response_body}}
      end)

      # Trigger the forecast
      view |> element("button", "Show Forecast") |> render_click()

      # Assert the new data load with forecast
      assert_receive {_, {:push_event, "chart:data_loaded", %{data: forecast_data}}}

      assert forecast_data[:actual_label] == graph_name
      assert length(forecast_data[:dates]) == 2

      h_idx = Enum.find_index(forecast_data[:dates], &(&1 == historical_timestamp))
      f_timestamp = DateTime.to_unix(forecast_timestamp, :millisecond)
      f_idx = Enum.find_index(forecast_data[:dates], &(&1 == f_timestamp))

      # Assert values at their respective indexes
      assert Enum.at(forecast_data[:actual], h_idx) == 100
      assert Enum.at(forecast_data[:forecast], h_idx) == nil

      assert Enum.at(forecast_data[:actual], f_idx) == nil
      assert Enum.at(forecast_data[:forecast], f_idx) == 110
      assert Enum.at(forecast_data[:lower_bound], f_idx) == 105
      assert Enum.at(forecast_data[:upper_bound], f_idx) == 115
    end

    test "sends only historical data when forecast service fails", %{conn: conn} do
      graph_name = "test_metric_http_error"
      graph = %Angel.Graphs.Index{short_name: graph_name, title: "Test Graph", graph_type: "line"}

      # Stub trace calls. The `trace` function is used to wrap other functions,
      # but is also called by telemetry with non-function arguments. This stub
      # handles both cases, preventing the test process from crashing on exit.
      stub(Angel.Junior.Mock, :trace, fn _trace_name, val ->
        if is_function(val, 0) do
          val.()
        else
          val
        end
      end)

      # Mock calls made during mount. They are called twice: once for the initial
      # static render and once for the connected LiveView.
      expect(Angel.Graphs.Mock, :get_by_short_name, 2, fn _graph_name -> graph end)
      expect(Angel.Graphs.Mock, :count_metrics, 2, fn _metric_count_arg -> 100 end)
      expect(Angel.Graphs.Mock, :first_metric_timestamp, 2, fn _timestamp_arg -> DateTime.utc_now() end)
      expect(Angel.Graphs.Mock, :last_metric_timestamp, 2, fn _timestamp_arg -> DateTime.utc_now() end)
      expect(Angel.Events.Mock, :for_graph, 2, fn _graph_arg -> [] end)

      # Mock the database call for the event
      historical_timestamp = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
      historical_data = [%{target: graph_name, datapoints: [[100, historical_timestamp]]}]

      expect(Angel.Graphs.Mock, :fetch_timescaledb_data, 2, fn _graph_name_arg, _start_time_arg, _end_time_arg ->
        {:ok, historical_data}
      end)

      # Mock the forecast service to return an error
      expect(HTTPoison.Mock, :post, fn _url, _body, _headers -> {:error, %HTTPoison.Error{reason: :econnrefused}} end)

      # Mount the LiveView. The `mounted` hook will trigger the data fetch.
      {:ok, view, _html_content} = live(conn, "/graphs/#{graph_name}")

      # Assert that the event was pushed and capture the payload
      assert_receive {_, {:push_event, "chart:data_loaded", %{data: data}}}

      assert data[:actual_label] == graph_name
      # Only the historical point
      assert length(data[:dates]) == 1
      assert data[:actual] == [100]
      assert data[:forecast] == [nil]
      assert data[:lower_bound] == [nil]
      assert data[:upper_bound] == [nil]

      # Now, click the button to try and fetch the forecast
      view |> element("button", "Show Forecast") |> render_click()

      # Assert that we get another data loaded event, but still with no forecast data
      assert_receive {_, {:push_event, "chart:data_loaded", %{data: data_after_fail}}}
      assert length(data_after_fail[:dates]) == 1
      assert data_after_fail[:actual] == [100]
      assert data_after_fail[:forecast] == [nil]
    end

    test "removes forecast data when toggling off", %{conn: conn} do
      graph_name = "test_metric"
      graph = %Angel.Graphs.Index{short_name: graph_name, title: "Test Graph", graph_type: "line"}

      # Stub trace calls
      stub(Angel.Junior.Mock, :trace, fn _trace_name, val ->
        if is_function(val, 0), do: val.(), else: val
      end)

      # Mocks for mount
      expect(Angel.Graphs.Mock, :get_by_short_name, 2, fn _graph_name -> graph end)
      expect(Angel.Graphs.Mock, :count_metrics, 2, fn _metric_count_arg -> 100 end)
      expect(Angel.Graphs.Mock, :first_metric_timestamp, 2, fn _timestamp_arg -> DateTime.utc_now() end)
      expect(Angel.Graphs.Mock, :last_metric_timestamp, 2, fn _timestamp_arg -> DateTime.utc_now() end)
      expect(Angel.Events.Mock, :for_graph, 2, fn _graph_arg -> [] end)

      # Mock historical data fetch (3 times: mount, toggle on, toggle off)
      historical_timestamp = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
      historical_data = [%{target: graph_name, datapoints: [[100, historical_timestamp]]}]

      expect(
        Angel.Graphs.Mock,
        :fetch_timescaledb_data,
        3,
        fn _graph_name, _start_time, _end_time -> {:ok, historical_data} end
      )

      # Mount the LiveView
      {:ok, view, _html} = live(conn, "/graphs/#{graph_name}")

      # Assert initial data load
      assert_receive {_, {:push_event, "chart:data_loaded", _}}

      # Mock the forecast service call for toggling on
      forecast_timestamp = DateTime.utc_now() |> DateTime.add(3600, :second)
      forecast_iso = forecast_timestamp |> DateTime.to_naive() |> NaiveDateTime.to_iso8601()

      forecast_points = [
        %{
          "timestamp" => forecast_iso,
          "predicted_value" => 110,
          "lower_bound" => 105,
          "upper_bound" => 115
        }
      ]

      forecast_response_body = Jason.encode!(%{"forecast_points" => forecast_points})

      expect(HTTPoison.Mock, :post, fn _url, _body, _headers ->
        {:ok, %HTTPoison.Response{status_code: 200, body: forecast_response_body}}
      end)

      # Toggle forecast on
      view |> element("button", "Show Forecast") |> render_click()
      assert_receive {_, {:push_event, "chart:data_loaded", %{data: forecast_data}}}
      assert length(forecast_data[:dates]) == 2

      # Toggle forecast off
      view |> element("button", "Hide Forecast") |> render_click()
      assert_receive {_, {:push_event, "chart:data_loaded", %{data: no_forecast_data}}}

      # Assert that the forecast data is gone
      assert length(no_forecast_data[:dates]) == 1
      assert no_forecast_data[:actual] == [100]
      assert no_forecast_data[:forecast] == [nil]
    end
  end
end
