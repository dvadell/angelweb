defmodule AngelWeb.PageControllerTest do
  use AngelWeb.ConnCase
  import Mox

  setup do
    stub(Angel.Junior.Mock, :trace, fn _a, _b -> :ok end)
    :ok
  end

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Peace of mind from prototype to production"
  end
end
