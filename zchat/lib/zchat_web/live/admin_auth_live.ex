defmodule ZchatWeb.AdminAuthLive do
  import Phoenix.Component
  import Phoenix.LiveView
  use ZchatWeb, :verified_routes
  alias ZchatWeb.Router.Helpers, as: Routes

  def on_mount(:ensure_admin, _params, _session, socket) do
    user = socket.assigns.current_user

    # Check if user exists AND has the admin role
    if user && user.role == "admin" do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "Unauthorized access. Admins only.")
       |> redirect(to: ~p"/feed")}
    end
  end
end
