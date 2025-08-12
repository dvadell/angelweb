defmodule AngelWeb.MetricControllerTest do
  use AngelWeb.ConnCase

  

  test "show returns metric data for valid parameters", %{conn: conn} do
    Angel.Graphs.Mock
    |> expect(:fetch_timescaledb_data, fn "test.metric", _start_time, _end_time ->
      {:ok, [%{target: "test.metric", datapoints: [[10, 1678886400000], [20, 1678886460000]]}]}
    end)

    conn = get(conn, "/api/v1/graphs/test.metric?start_time=2023-03-15T00:00:00Z&end_time=2023-03-15T00:01:00Z")
    assert json_response(conn, 200) == [%{"target" => "test.metric", "datapoints" => [[10, 1678886400000], [20, 1678886460000]]}]
  end

  test "show returns bad request for invalid start_time", %{conn: conn} do
    conn = get(conn, "/api/v1/graphs/test.metric?start_time=invalid&end_time=2023-03-15T00:01:00Z")
    assert json_response(conn, 400) == %{"error" => "Invalid parameters or data not found"}
  end

  test "show returns bad request for invalid end_time", %{conn: conn} do
    conn = get(conn, "/api/v1/graphs/test.metric?start_time=2023-03-15T00:00:00Z&end_time=invalid")
    assert json_response(conn, 400) == %{"error" => "Invalid parameters or data not found"}
  end

  test "show returns empty data when fetch_timescaledb_data returns empty", %{conn: conn} do
    Angel.Graphs.Mock
    |> expect(:fetch_timescaledb_data, fn "test.metric", _start_time, _end_time ->
      {:ok, []}
    end)
    conn = get(conn, "/api/v1/graphs/test.metric?start_time=2023-03-15T00:00:00Z&end_time=2023-03-15T00:01:00Z")
    assert json_response(conn, 200) == []
  end

  test "show returns bad request when fetch_timescaledb_data returns error", %{conn: conn} do
    Angel.Graphs.Mock
    |> expect(:fetch_timescaledb_data, fn "test.metric", _start_time, _end_time ->
      {:error, :some_error}
    end)
    conn = get(conn, "/api/v1/graphs/test.metric?start_time=2023-03-15T00:00:00Z&end_time=invalid")
    assert json_response(conn, 400) == %{"error" => "Invalid parameters or data not found"}
  end

  test "create returns 201 for valid metric data", %{conn: conn} do
    Angel.Graphs.Mock
    |> expect(:create_or_update_graph, fn %{"short_name" => "jr.test.metric", "units" => "gauge"} ->
      {:ok, %{short_name: "jr.test.metric", units: "gauge"}}
    end)

    Angel.Events.Mock
    |> expect(:create_event, fn %{for_graph: "jr.test.metric", text: "Value: 123 g"} ->
      {:ok, %{}}
    end)

    Angel.Repo.Mock
    |> expect(:query, fn "INSERT INTO metrics(timestamp, name, value) VALUES (NOW(), $1, $2);", ["jr.test.metric", 123] ->
      {:ok, %{}}
    end)

    conn = post(conn, "/api/v1/metric", %{short_name: "test.metric", graph_value: 123, type: "g", reporter: "test_reporter"})
    assert json_response(conn, 201) == %{"message" => "Data sent to TimescaleDB"}
  end

  test "create returns 400 for missing short_name", %{conn: conn} do
    conn = post(conn, "/api/v1/metric", %{graph_value: 123, type: "g", reporter: "test_reporter"})
    assert json_response(conn, 400) == %{"error" => "Invalid data"}
  end

  test "create returns 400 for missing graph_value", %{conn: conn} do
    conn = post(conn, "/api/v1/metric", %{short_name: "test.metric", type: "g", reporter: "test_reporter"})
    assert json_response(conn, 400) == %{"error" => "Invalid data"}
  end

  test "create returns 201 for missing reporter", %{conn: conn} do
    Angel.Graphs.Mock
    |> expect(:create_or_update_graph, fn %{"short_name" => "jr.test.metric", "units" => "g"} ->
      {:ok, %{short_name: "jr.test.metric", units: "g"}}
    end)

    Angel.Events.Mock
    |> expect(:create_event, fn %{for_graph: "jr.test.metric", text: "Value: 123 g"} ->
      {:ok, %{}}
    end)

    Angel.Repo.Mock
    |> expect(:query, fn "INSERT INTO metrics(timestamp, name, value) VALUES (NOW(), $1, $2);", ["jr.test.metric", 123] ->
      {:ok, %{}}
    end)

    conn = post(conn, "/api/v1/metric", %{short_name: "test.metric", graph_value: 123, type: "g"})
    assert json_response(conn, 201) == %{"message" => "Data sent to TimescaleDB"}
  end

  test "create returns 400 for negative graph_value", %{conn: conn} do
    conn = post(conn, "/api/v1/metric", %{short_name: "test.metric", graph_value: -1, type: "g", reporter: "test_reporter"})
    assert json_response(conn, 400) == %{"error" => "Invalid data"}
  end

  test "create returns 400 for invalid type", %{conn: conn} do
    conn = post(conn, "/api/v1/metric", %{short_name: "test.metric", graph_value: 123, type: "invalid", reporter: "test_reporter"})
    assert json_response(conn, 400) == %{"error" => "Invalid data"}
  end

  test "create returns 400 for non-JSON content type", %{conn: conn} do
    conn = conn
           |> put_req_header("content-type", "text/plain")
           |> post("/api/v1/metric", "this is not json")
    assert json_response(conn, 400) == %{"error" => "Invalid data"}
  end

  test "create returns 400 for invalid metric data", %{conn: conn} do
    conn = post(conn, "/api/v1/metric", %{}) # Send empty map to trigger invalid data path
    assert json_response(conn, 400) == %{"error" => "Invalid data"}
  end
end