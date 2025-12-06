defmodule ZchatWeb.Admin.ManagementLive do
  use ZchatWeb, :live_view

  alias GenLSP.Notifications
  alias Zchat.Accounts
  alias Zchat.Accounts.Role
  alias Zchat.Notifications


  def mount(_params, _session, socket) do

    # This is already handled by the router pipeline, but as a double check
    if !Zchat.Accounts.user_has_role?(socket.assigns.current_user, "admin") do
      {:ok, socket |> put_flash(:error, "Unauthorized") |> redirect(to: "/")}
    else
      # Important preload
      users = Accounts.list_users() |> Zchat.Repo.preload(:roles)
      all_roles = Accounts.get_roles()

      {:ok,
       socket
       |> assign(:page_title, "User Management")
       |> assign(:users, users)

       |> assign(:all_roles, all_roles)
       |> assign(:search_query, "")
      }
    end
  end


#removing a role from user
def handle_event("remove_role",%{"user_id"=> user_id, "role_id"=> role_id}, socket) do
  u_id = String.to_integer(user_id)
  r_id = String.to_integer(role_id)

  case Accounts.remove_role_from_user(u_id, r_id) do
    {:ok, _} ->
      Notifications.create_notification(%{
        user_id: u_id,
        actor: socket.assigns.current_user.id,
        type: "role_change"
      })

      users = Accounts.list_users() |> Zchat.Repo.preload(:roles)

      {:noreply, socket
          |>assign(:users, users)
          |> put_flash(:info, "you have removed role successfully")
      }
  end
end
  @impl true
 def handle_event("toggle_user_role", %{"user_id" => u_id, "role_id" => r_id}, socket) do
    user_id = String.to_integer(u_id)
    role_id = String.to_integer(r_id)
    currentUser = socket.assigns.current_user

    case Accounts.toggle_user_role(user_id, role_id) do
      {:ok, :added} ->
        # 1. Logic for when role was GRANTED
        Notifications.create_notification(%{
          user_id: user_id,
          actor_id: currentUser.id,
          type: "role_change"
        })

        # Refresh Data
        users = Accounts.list_users() |> Zchat.Repo.preload(:roles)
        {:noreply, socket |> assign(:users, users) |> put_flash(:info, "Role granted.")}

      {:ok, :removed} ->
        # 2. Logic for when role was REVOKED
        Notifications.create_notification(%{
          user_id: user_id,
          actor_id: currentUser.id,
          type: "role_change"
        })

        # Refresh Data
        users = Accounts.list_users() |> Zchat.Repo.preload(:roles)
        {:noreply, socket |> assign(:users, users) |> put_flash(:info, "Role removed.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Operation failed.")}
    end
  end

  # def handle_event("update_user_roles", %{"user-id" => user_id, "roles" => role_ids, "role"=> role_id}, socket) do
  #   user = Accounts.get_user!(user_id)
  #   # The role_ids from the form are strings, so we need to convert them to integers
  #   role_ids = Enum.map(role_ids, &String.to_integer/1)
  #   case Accounts.update_user_roles(user, role_ids) do
  #     {:ok, updated_user} ->
  #       # Create a notification for the user
  #       Notifications.create_notification(%{
  #         user_id: updated_user.id,
  #         actor_id: socket.assigns.current_user.id,
  #         type: "role_change"
  #       })
  #       # Refetch users to update the UI
  #       users = Accounts.list_users() |> Zchat.Repo.preload(:roles)

  #       {:noreply,
  #        socket
  #        |> assign(:users, users)
  #        |> put_flash(:info, "User roles updated successfully.")}

  #       {:error, _}->
  #         {
  #           :noreply, put_flash(socket, :error, "Erro, could not remove role")
  #       }

  #     {:error, changeset} ->
  #       {:noreply, socket |> put_flash(:error, "Error updating roles: #{inspect(changeset)}")}
  #   end
  # end

  #search users
def handle_event("search", %{"query" => query}, socket) do
  users =
    if query == "" do
      Zchat.Accounts.list_users()
    else
      Zchat.Accounts.search_users(query)
    end

  {:noreply, assign(socket, users: users, search_query: query)}
end
end
