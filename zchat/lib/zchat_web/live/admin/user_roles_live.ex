defmodule ZchatWeb.Admin.UserRolesLive do
  use ZchatWeb, :live_view
  alias Zchat.Repo
  alias Zchat.Accounts
  alias Zchat.Accounts.User
  alias Zchat.Notifications

  @impl true
  def mount(%{"user_id" => user_id}, _session, socket) do
    user = Accounts.get_user!(user_id) |> Repo.preload(:roles)
    roles = Accounts.get_roles()
    changeset = User.roles_changeset(user)

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:roles, roles)
     |> assign(:changeset, changeset)}
  end

  @impl true
 def handle_event("toggle_role", %{"user_id" => u_id, "role_id" => r_id}, socket) do
    user_id = String.to_integer(u_id)
    role_id = String.to_integer(r_id)
    currentUser = socket.assigns.current_user

    case Accounts.update_user_role(user_id, role_id) do
      {:ok, :added} ->
        # 1. Logic for when role was GRANTED
        Notifications.create_notification(%{
          user_id: user_id,
          actor_id: currentUser.id,
          type: "role_granted"
        })

        # Refresh Data
        users = Accounts.list_users() |> Zchat.Repo.preload(:roles)
        {:noreply, socket |> assign(:users, users) |> put_flash(:info, "Role granted.")}

      {:ok, :removed} ->
        # 2. Logic for when role was REVOKED
        Notifications.create_notification(%{
          user_id: user_id,
          actor_id: currentUser.id,
          type: "role_revoked"
        })

        # Refresh Data
        users = Accounts.list_users() |> Zchat.Repo.preload(:roles)
        {:noreply, socket |> assign(:users, users) |> put_flash(:info, "Role removed.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Operation failed.")}
    end
  end
end
