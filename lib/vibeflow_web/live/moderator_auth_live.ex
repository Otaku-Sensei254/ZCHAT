defmodule VibeflowWeb.ModeratorAuthLive do
  import Phoenix.LiveView
  alias Vibeflow.Accounts

  def on_mount(:ensure_moderator, _params, _session, socket) do
    case socket.assigns[:current_user] do
      nil ->
        socket =
          socket
          |> put_flash(:error, "You must be logged in to access this page.")
          |> redirect(to: "/users/log_in")

        {:halt, socket}

      user ->
        if Accounts.user_has_role?(user, "moderator") do
          {:cont, socket}
        else
          socket =
            socket
            |> put_flash(:error, "You don't have permission to access this page.")
            |> redirect(to: "/feed")

          {:halt, socket}
        end
    end
  end
end
