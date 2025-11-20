defmodule ZchatWeb.UserSettingsLive do
  use ZchatWeb, :live_view

  alias Zchat.Accounts

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)
    profile_changeset = Accounts.change_user_profile(user) # <--- New

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:profile_form, to_form(profile_changeset)) # <--- New
      |> assign(:trigger_submit, false)
      |> allow_upload(:avatar, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1, max_file_size: 5_000_000)

    {:ok, socket}
  end

  # --- PROFILE HANDLERS ---

  def handle_event("validate_profile", %{"user" => user_params}, socket) do
    profile_form =
      socket.assigns.current_user
      |> Accounts.change_user_profile(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, profile_form: profile_form)}
  end

  def handle_event("update_profile", %{"user" => user_params}, socket) do
    user = socket.assigns.current_user

    # 1. Handle File Upload (if any)
    uploaded_files =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
        dest_dir = Path.join(["priv", "static", "uploads", "avatars"])
        File.mkdir_p!(dest_dir)

        filename = "#{user.id}-#{Path.basename(path)}"
        dest = Path.join(dest_dir, filename)

        File.cp!(path, dest)
        {:ok, "/uploads/avatars/#{filename}"}
      end)

    # 2. Update params with new avatar URL if a file was uploaded
    user_params =
      if List.first(uploaded_files) do
        Map.put(user_params, "avatar_url", List.first(uploaded_files))
      else
        user_params
      end

    # 3. Save to Database
    case Accounts.update_user_profile(user, user_params) do
      {:ok, updated_user} ->
        info = "Profile updated successfully."
        {:noreply,
         socket
         |> put_flash(:info, info)
         |> assign(:current_user, updated_user)
         |> assign(:profile_form, to_form(Accounts.change_user_profile(updated_user)))
         |> push_navigate(to: ~p"/users/#{updated_user.username}")}


      {:error, changeset} ->
        {:noreply, assign(socket, :profile_form, to_form(changeset))}
    end
  end

  # ... (Keep your existing email/password handlers below) ...
  # Note: You can delete the old `save_avatar` handler since we merged it.

  # KEEP: handle_event("validate_email"...)
  # KEEP: handle_event("update_email"...)
  # KEEP: handle_event("validate_password"...)
  # KEEP: handle_event("update_password"...)

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Account Settings
      <:subtitle>Manage your profile and security preferences</:subtitle>
    </.header>

    <div class="max-w-2xl mx-auto space-y-12 divide-y divide-gray-100 mt-8">

      <div class="pt-4">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Public Profile</h2>

        <.simple_form
          for={@profile_form}
          id="profile_form"
          phx-change="validate_profile"
          phx-submit="update_profile"
        >
          <div class="flex items-center gap-6 mb-4">
            <div class="relative">
              <%= if @uploads.avatar.entries != [] do %>
                <%= for entry <- @uploads.avatar.entries do %>
                  <.live_img_preview entry={entry} class="h-24 w-24 rounded-full object-cover border-2 border-gray-200" />
                <% end %>
              <% else %>
                <%= if @current_user.avatar_url do %>
                  <img src={@current_user.avatar_url} class="h-24 w-24 rounded-full object-cover border-2 border-gray-200" />
                <% else %>
                  <div class="h-24 w-24 rounded-full bg-orange-100 text-orange-600 flex items-center justify-center text-3xl font-bold border-2 border-white shadow-sm">
                    <%= String.first(@current_user.username || "?") |> String.upcase() %>
                  </div>
                <% end %>
              <% end %>
            </div>

            <div class="flex-1">
              <label class="block text-sm font-medium text-gray-700 mb-2">Profile Picture</label>
              <.live_file_input upload={@uploads.avatar} class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-orange-50 file:text-orange-700 hover:file:bg-orange-100"/>
              <p class="text-xs text-gray-500 mt-1">JPG or PNG. Max 5MB.</p>

              <%= for entry <- @uploads.avatar.entries do %>
                <%= for err <- upload_errors(@uploads.avatar, entry) do %>
                  <p class="text-red-500 text-xs mt-1"><%= error_to_string(err) %></p>
                <% end %>
              <% end %>
            </div>
          </div>

          <.input field={@profile_form[:username]} type="text" label="Username" required />
          <.input field={@profile_form[:bio]} type="textarea" label="Bio" rows="3" placeholder="Tell us a little about yourself..." />

          <:actions>
            <.button phx-disable-with="Saving...">Save Profile</.button>
          </:actions>
        </.simple_form>
      </div>

      <div class="pt-10">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Email Address</h2>
        <.simple_form
          for={@email_form}
          id="email_form"
          phx-submit="update_email"
          phx-change="validate_email"
        >
          <.input field={@email_form[:email]} type="email" label="Email" required />
          <.input
            field={@email_form[:current_password]}
            name="current_password"
            id="current_password_for_email"
            type="password"
            label="Current password"
            value={@email_form_current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Changing...">Change Email</.button>
          </:actions>
        </.simple_form>
      </div>

      <div class="pt-10 pb-10">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Change Password</h2>
        <.simple_form
          for={@password_form}
          id="password_form"
          action={~p"/users/log_in?_action=password_updated"}
          method="post"
          phx-change="validate_password"
          phx-submit="update_password"
          phx-trigger-action={@trigger_submit}
        >
          <input
            name={@password_form[:email].name}
            type="hidden"
            id="hidden_user_email"
            value={@current_email}
          />
          <.input field={@password_form[:password]} type="password" label="New password" required />
          <.input
            field={@password_form[:password_confirmation]}
            type="password"
            label="Confirm new password"
          />
          <.input
            field={@password_form[:current_password]}
            name="current_password"
            type="password"
            label="Current password"
            id="current_password_for_password"
            value={@current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Changing...">Change Password</.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end

  # ... existing code ...

  defp error_to_string(:too_large), do: "Image too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  defp error_to_string(_), do: "Something went wrong"

end
