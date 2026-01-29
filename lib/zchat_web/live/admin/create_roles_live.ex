defmodule ZchatWeb.Admin.CreateRolesLive do
  use ZchatWeb, :live_view
  alias Zchat.Accounts
  alias Zchat.Accounts.Role

  def mount(_params, _session, socket) do
    # 1. Load all available permissions to display options
    all_permissions = Accounts.list_permissions()

    # 2. Create an empty changeset for the form
    changeset = Accounts.Role.changeset(%Role{}, %{})

    {:ok,
     socket
     |> assign(:all_permissions, all_permissions)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("save", %{"role" => role_params}, socket) do
    # The form returns permissions as a map or list depending on input type.
    # We extract the list of IDs directly from the params.
    # Note: If no boxes are checked, "permission_ids" might be missing, so default to []
    permission_ids = role_params["permission_ids"] || []

    case Accounts.create_role(role_params, permission_ids) do
      {:ok, _role} ->
        {:noreply,
         socket
         |> put_flash(:info, "Role created successfully")
         |> push_navigate(to: ~p"/admin/roles")} # Redirect wherever you want

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
