defmodule Angel.TelemetryTest do
  use AngelWeb.ConnCase

  import Mox

  alias Angel.Telemetry

  setup do
    :telemetry.detach("phoenix-endpoint-stop")
    Telemetry.setup()

    :ok
  end

  test "traces the duration of the endpoint stop event", %{conn: conn} do
    expect(Angel.Junior.Mock, :trace, fn name, duration ->
      assert name == "phoenix_endpoint_stop"
      assert is_number(duration)
    end)

    :telemetry.execute(
      [:phoenix, :endpoint, :stop],
      %{duration: 1_000_000},
      %{
        conn: conn,
        status: 200,
        params: %{},
        path: "/",
        view: {AngelWeb.PageHTML, "index.html"},
        plug: AngelWeb.PageController
      }
    )

    verify!()
  end
end
