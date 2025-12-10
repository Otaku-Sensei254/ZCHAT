defmodule ZchatWeb.UserSettingsLive do
  use ZchatWeb, :live_view

  alias Zchat.Accounts

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)
    profile_changeset = Accounts.change_user_profile(user)

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:profile_form, to_form(profile_changeset))
      |> assign(:trigger_submit, false)
      |> allow_upload(:avatar, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1, max_file_size: 5_000_000)

    {:ok, socket}
  end

  # --- PROFILE HANDLERS ---

  @impl true
  def handle_event("validate_profile", %{"user" => user_params}, socket) do
    profile_form =
      socket.assigns.current_user
      |> Accounts.change_user_profile(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, profile_form: profile_form)}
  end

  @impl true
  def handle_event("update_profile", %{"user" => user_params}, socket) do
    user = socket.assigns.current_user

    # 1. Consume the upload to get the temp file path.
    # We DO NOT copy the file manually anymore. We just get the path.
    uploaded_files =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
        {:ok, path}
      end)

    # 2. If a file was uploaded, add the path to params.
    # The Accounts context will handle uploading this path to Cloudinary.
    user_params =
      case uploaded_files do
        [path | _] -> Map.put(user_params, "avatar_url", path)
        [] -> user_params
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
         # Redirect ensures the header/sidebar avatar updates immediately
         |> push_navigate(to: ~p"/users/settings")}

      {:error, changeset} ->
        {:noreply, assign(socket, :profile_form, to_form(changeset))}
    end
  end

  # --- EMAIL & PASSWORD HANDLERS (Unchanged) ---

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  @impl true
  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  @impl true
  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  @impl true
  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  @impl true
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

  defp error_to_string(:too_large), do: "Image too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  defp error_to_string(_), do: "Something went wrong"

  @impl true
  def handle_info(:update_notifications, socket) do
    {:noreply, socket}
  end
end
