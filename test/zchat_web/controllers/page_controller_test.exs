defmodule VibeflowWeb.PageControllerTest do
  use VibeflowWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Posts"
  end
end
