defmodule ZchatWeb.Admin.UserRolesLive do
  use ZchatWeb, :live_view
  alias Zchat.Repo
  alias Zchat.Accounts
  alias Zchat.Accounts.User

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
  def handle_event("toggle_role", %{"role" => role_name}, socket) do
    user = socket.assigns.user |> Repo.preload(:roles)
    current_roles = user.roles || []

    updated_roles =
      if Enum.any?(current_roles, &(&1.name == role_name)) do
        Enum.reject(current_roles, &(&1.name == role_name))
      else
        role = Enum.find(socket.assigns.roles, &(&1.name == role_name))

        case role do
          nil -> current_roles
          _ -> [role | current_roles]
        end
      end

    changeset = User.roles_changeset(user, %{roles: updated_roles})

    case Accounts.update_user_roles(user, changeset) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:user, Repo.preload(updated_user, :roles))
         |> put_flash(:info, "Roles updated successfully")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end
