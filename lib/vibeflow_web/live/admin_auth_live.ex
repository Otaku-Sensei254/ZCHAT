defmodule VibeflowWeb.AdminAuthLive do
  import Phoenix.LiveView
  alias Vibeflow.Accounts

  def on_mount(:ensure_admin, _params, _session, socket) do
    user = socket.assigns[:current_user]

    # FIX: Use the Accounts helper we made, or check the list manually.
    # Do NOT use user.role (singular)
    if user && Accounts.user_has_role?(user, "admin") do
      {:cont, socket}
    else
      {:halt,
       socket
       |> put_flash(:error, "You must be an admin to access this page.")
       |> redirect(to: "/")}
    end
  end

  # def on_mount(:ensure_sale_executive, _params, _session, socket) do
  #     user = socket.assigns[:current_user]

  #     # FIX: Use the Accounts helper we made, or check the list manually.
  #     # Do NOT use user.role (singular)
  #     if user && Accounts.user_has_role?(user, "sales_executive") do
  #       {:cont, socket}
  #     else
  #       {:halt,
  #        socket
  #        |> put_flash(:error, "You must be a sales executive to access this page.")
  #        |> redirect(to: "/")}
  #     end
  #   end
end
