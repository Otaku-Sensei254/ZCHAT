defmodule VibeflowWeb.Plugs.EnsureModerator do
  import Plug.Conn
  import Phoenix.Controller
  alias Vibeflow.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_flash(:error, "You must be logged in to access this page.")
        |> redirect(to: "/users/log_in")
        |> halt()

      user ->
        if Accounts.user_has_role?(user, "moderator") do
          conn
        else
          conn
          |> put_flash(:error, "You don't have permission to access this page.")
          |> redirect(to: "/feed")
          |> halt()
        end
    end
  end
end
