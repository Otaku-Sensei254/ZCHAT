defmodule ZchatWeb.UserRegistrationLiveTest do
  use ZchatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Zchat.AccountsFixtures

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Create an account"
      assert html =~ "Log in"
    end

    test "redirects if already logged in", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      # When a LiveView redirects on mount, live/2 returns {:error, {:live_redirect, ...}}
      # follow_redirect can be called directly on that result.
      result = get(conn, ~p"/users/register")
      assert redirected_to(result) == ~p"/feed"
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "with spaces", "password" => "too short"})

      assert result =~ "Create account"
      assert result =~ "must have the @ sign and no spaces"
      assert result =~ "should be at least 12 character"
    end
  end

  describe "register user" do
    test "creates account and logs the user in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()
      form = form(lv, "#registration_form", user: valid_user_attributes(email: email))

      # 1. Submit the form to trigger the 'save' event in the LiveView
      render_submit(form)

      # 2. NOW the LiveView has updated the DOM with phx-trigger-action="true"
      # This helper will now find the attribute and perform the POST to /users/log_in
      conn = follow_trigger_action(form, conn)

      # 3. Verify the controller redirect to the feed
      assert redirected_to(conn) == ~p"/feed"

      # 4. Follow the redirect to the feed page
      conn = get(conn, ~p"/feed")
      response = html_response(conn, 200)

      # Check for logged-in elements
      assert response =~ "Settings"
      assert response =~ "Account created successfully"
    end

    test "renders errors for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture(%{email: "test@email.com"})

      result =
        lv
        |> form("#registration_form",
          user: %{"email" => user.email, "password" => "valid_password"}
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Log in")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log_in")

      assert login_html =~ "Log in"
    end
  end
end
