defmodule AngelWeb.IndexLiveTest do
  use AngelWeb.ConnCase

  import Phoenix.LiveViewTest
  import Angel.GraphsFixtures

  @create_attrs %{short_name: "some short_name"}
  @update_attrs %{short_name: "some updated short_name"}
  @invalid_attrs %{short_name: nil}

  defp create_index(_) do
    index = index_fixture()
    %{index: index}
  end

  describe "Index" do
    setup [:create_index]

    test "lists all graphs", %{conn: conn, index: index} do
      {:ok, _index_live, html} = live(conn, ~p"/graphs")

      assert html =~ "Listing Graphs"
      assert html =~ index.short_name
    end

    test "saves new index", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/graphs")

      assert index_live |> element("a", "New Index") |> render_click() =~
               "New Index"

      assert_patch(index_live, ~p"/graphs/new")

      assert index_live
             |> form("#index-form", index: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#index-form", index: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/graphs")

      html = render(index_live)
      assert html =~ "Index created successfully"
      assert html =~ "some short_name"
    end

    test "updates index in listing", %{conn: conn, index: index} do
      {:ok, index_live, _html} = live(conn, ~p"/graphs")

      assert index_live |> element("#graphs-#{index.id} a", "Edit") |> render_click() =~
               "Edit Index"

      assert_patch(index_live, ~p"/graphs/#{index}/edit")

      assert index_live
             |> form("#index-form", index: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#index-form", index: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/graphs")

      html = render(index_live)
      assert html =~ "Index updated successfully"
      assert html =~ "some updated short_name"
    end

    test "deletes index in listing", %{conn: conn, index: index} do
      {:ok, index_live, _html} = live(conn, ~p"/graphs")

      assert index_live |> element("#graphs-#{index.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#graphs-#{index.id}")
    end
  end

  describe "Show" do
    setup [:create_index]

    test "displays index", %{conn: conn, index: index} do
      {:ok, _show_live, html} = live(conn, ~p"/graphs/#{index}")

      assert html =~ "Show Index"
      assert html =~ index.short_name
    end

    test "updates index within modal", %{conn: conn, index: index} do
      {:ok, show_live, _html} = live(conn, ~p"/graphs/#{index}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Index"

      assert_patch(show_live, ~p"/graphs/#{index}/show/edit")

      assert show_live
             |> form("#index-form", index: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#index-form", index: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/graphs/#{index}")

      html = render(show_live)
      assert html =~ "Index updated successfully"
      assert html =~ "some updated short_name"
    end
  end
end
