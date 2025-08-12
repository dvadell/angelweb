defmodule AngelWeb.IndexLiveTest do
  use AngelWeb.ConnCase

  import Phoenix.LiveViewTest
  import Angel.GraphsFixtures

  @create_attrs %{short_name: "some_short_name"}
  @update_attrs %{short_name: "some updated short_name"}
  @invalid_attrs %{short_name: nil}

  defp create_index(_) do
    index = index_fixture()
    %{index: index}
  end

  

  describe "Index" do
    

    test "lists all graphs", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/graphs")

      assert html =~ "Graphs"
    end
  end
end