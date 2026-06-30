defmodule VibeflowWeb.Admin.ManagementLive do
  use VibeflowWeb, :live_view

  alias Vibeflow.Accounts
  alias Vibeflow.Notifications

  @impl true
  def mount(_params, _session, socket) do
    # This is already handled by the router pipeline, but as a double check
    if !Vibeflow.Accounts.user_has_role?(socket.assigns.current_user, "admin") do
      {:ok, socket |> put_flash(:error, "Unauthorized") |> redirect(to: "/")}
    else
      socket =
        socket
        |> assign(:page_title, "User Management")
        |> assign(:all_roles, Accounts.get_roles())
        |> assign(:search_query, "")
        |> assign(:sort_by, "joined_desc")

      {:ok, assign(socket, :users, fetch_users(socket))}
    end
  end

  defp fetch_users(socket) do
    opts = []
    opts = if socket.assigns.search_query != "", do: Keyword.put(opts, :search, socket.assigns.search_query), else: opts
    opts = Keyword.put(opts, :sort_by, socket.assigns.sort_by)

    Accounts.list_users(opts) |> Vibeflow.Repo.preload(:roles)
  end

  # removing a role from user
  @impl true
  def handle_event("remove_role", %{"user_id" => user_id, "role_id" => role_id}, socket) do
    u_id = String.to_integer(user_id)
    r_id = String.to_integer(role_id)

    case Accounts.remove_role_from_user(u_id, r_id) do
      {:ok, _} ->
        Notifications.create_notification(%{
          user_id: u_id,
          actor_id: socket.assigns.current_user.id,
          type: "role_change"
        })

        {:noreply,
         socket
         |> assign(:users, fetch_users(socket))
         |> put_flash(:info, "You have removed role successfully")}
    end
  end

  @impl true
  def handle_event("update_user_roles", %{"user_id" => u_id, "role_id" => r_id}, socket) do
    # 1. Setup variables
    target_user_id = String.to_integer(u_id)
    target_role_id = String.to_integer(r_id)
    current_user = socket.assigns.current_user

    # 2. Get the User Struct first (Required for your context function)
    user = Accounts.get_user!(target_user_id) |> Vibeflow.Repo.preload(:roles)

    # 3. Calculate the NEW list of role IDs (Toggle logic)
    current_role_ids = Enum.map(user.roles, & &1.id)

    # Check if we are adding or removing
    {new_role_ids, action} =
      if target_role_id in current_role_ids do
        {List.delete(current_role_ids, target_role_id), :removed}
      else
        {[target_role_id | current_role_ids], :added}
      end

    # 4. Call the function with the correct arguments: (%User{}, [List])
    case Accounts.update_user_roles(user, new_role_ids) do
      {:ok, _updated_user} ->
        # Create Notification
        Notifications.create_notification(%{
          user_id: user.id,
          actor_id: current_user.id,
          type: "role_change"
        })

        # Determine message based on action
        msg = if action == :added, do: "Role granted.", else: "Role removed."

        {:noreply, socket |> assign(:users, fetch_users(socket)) |> put_flash(:info, msg)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Operation failed.")}
    end
  end

  @impl true
  def handle_event("search", params, socket) do
    query = params["query"] || socket.assigns.search_query
    sort_by = params["sort_by"] || socket.assigns.sort_by

    socket =
      socket
      |> assign(:search_query, query)
      |> assign(:sort_by, sort_by)

    {:noreply, assign(socket, :users, fetch_users(socket))}
  end
end
