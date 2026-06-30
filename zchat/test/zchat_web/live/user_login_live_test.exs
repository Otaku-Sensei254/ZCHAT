defmodule ZchatWeb.UserLoginLiveTest do
  use ZchatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Zchat.AccountsFixtures

  describe "Log in page" do
    test "renders log in page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log_in")

      assert html =~ "Log in"
      assert html =~ "Sign up"
      assert html =~ "Forgot password?"
    end

test "redirects if already logged in", %{conn: conn} do
  user = user_fixture()
  conn = log_in_user(conn, user)

  # DEBUG: If this returns {:ok, lv, html}, it means NO redirect happened.
  # If it redirects, it will return {:error, {:live_redirect, %{to: "/feed"}}}
  case live(conn, ~p"/users/log_in") do
    {:ok, _lv, _html} ->
      flunk("The login page rendered instead of redirecting. Check if UserAuth.on_mount is correctly finding the user.")



    {:error, {:redirect, %{to: path}}} ->
      assert path == ~p"/feed"

    other ->
      flunk("Unexpected return: #{inspect(other)}")
  end
end


  end

  describe "user login" do
    test "redirects if user login with valid credentials", %{conn: conn} do
      password = "123456789abcd"
      user = user_fixture(%{password: password})

      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      form =
        form(lv, "#login_form", user: %{email: user.email, password: password, remember_me: true})

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/feed"
    end

    test "redirects to login page with a flash error if there are no valid credentials", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      form =
        form(lv, "#login_form",
          user: %{email: "test@email.com", password: "123456", remember_me: true}
        )

      conn = submit_form(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"

      assert redirected_to(conn) == "/users/log_in"
    end
  end

  describe "login navigation" do
    test "redirects to registration page when the Register button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log_in")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Sign up for free")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/register")

      assert login_html =~ "Sign up"
    end

  test "redirects to forgot password page when the Forgot Password button is clicked", %{
  conn: conn
} do
  {:ok, lv, _html} = live(conn, ~p"/users/log_in")

  # 1. Use the actual text "Forgot password?"
  # 2. Match on the 3-element tuple {:ok, _view, html}
  {:ok, conn} =
    lv
    |> element("a", "Forgot password?")
    |> render_click()
    |> follow_redirect(conn, ~p"/users/reset_password")

  # 3. Assert against the html string
  assert conn.resp_body =~ "Forgot your password?"
end

  end
end
