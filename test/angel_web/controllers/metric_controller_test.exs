defmodule AngelWeb.MetricControllerTest do
  use AngelWeb.ConnCase
  import Mox

  

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
    conn = get(conn, "/api/v1/graphs/test.metric?start_time=2023-03-15T00:00:00Z&end_time=2023-03-15T00:01:00Z")
    assert json_response(conn, 400) == %{"error" => "Invalid parameters or data not found"}
  end
end