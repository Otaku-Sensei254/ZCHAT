defmodule VibeflowWeb.UserResetPasswordLiveTest do
  use VibeflowWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Vibeflow.AccountsFixtures

  alias Vibeflow.Accounts

  setup do
    user = user_fixture()

    token =
      extract_user_token(fn url ->
        Accounts.deliver_user_reset_password_instructions(user, url)
      end)

    %{token: token, user: user}
  end

  describe "Reset password page" do
    test "renders reset password with valid token", %{conn: conn, token: token} do
      {:ok, _lv, html} = live(conn, ~p"/users/reset_password/#{token}")

      assert html =~ "Reset Password"
    end

    test "does not render reset password with invalid token", %{conn: conn} do
      {:error, {:redirect, to}} = live(conn, ~p"/users/reset_password/invalid")

      assert to == %{
               flash: %{"error" => "Reset password link is invalid or it has expired."},
               to: ~p"/"
             }
    end

    test "renders errors for invalid data", %{conn: conn, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset_password/#{token}")

      result =
        lv
        |> element("#reset_password_form")
        |> render_change(
          user: %{"password" => "secret12", "password_confirmation" => "secret123456"}
        )

      assert result =~ "should be at least 12 character"
      assert result =~ "does not match password"
    end
  end

  describe "Reset Password" do
    test "resets password once", %{conn: conn, token: token, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset_password/#{token}")

      {:ok, conn} =
        lv
        |> form("#reset_password_form",
          user: %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        )
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log_in")

      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Password reset successfully"
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "does not reset password on invalid data", %{conn: conn, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset_password/#{token}")

      result =
        lv
        |> form("#reset_password_form",
          user: %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        )
        |> render_submit()

      assert result =~ "Reset Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end
  end

  describe "Reset password navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn, token: token} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset_password/#{token}")

      # Use the 3-item tuple here
      {:ok, _login_lv, html} =
        lv
        |> element("header a", "Log in")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log_in")

      # Assert against the HTML string, not conn.resp_body
      assert html =~ "Log in"
    end

    test "redirects to registration page when the Sign up button is clicked", %{
      conn: conn,
      token: token
    } do
      {:ok, lv, _html} = live(conn, ~p"/users/reset_password/#{token}")

      # Destructure the 3-element tuple returned by follow_redirect for LiveViews
      {:ok, _registration_lv, html} =
        lv
        |> element("a", "Sign up")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/register")

      # Assert against the 'html' variable instead of 'conn.resp_body'
      assert html =~ "Sign up"
    end
  end
end
