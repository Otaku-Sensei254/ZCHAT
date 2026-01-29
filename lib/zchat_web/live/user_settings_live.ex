defmodule ZchatWeb.UserSettingsLive do
  use ZchatWeb, :live_view
  alias Zchat.Infrastructure.UploadCloudinary
  alias Zchat.Accounts
  require Logger


  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    # We use push_navigate to satisfy the test expectation of :live_redirect
    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

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

    # 1. Consume the upload and upload to Cloudinary inside the callback.
    uploaded_urls =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
        case UploadCloudinary.upload_file(path) do
          {:ok, result} -> {:ok, result.url}
          {:error, reason} ->
            Logger.error("Failed to upload avatar: #{inspect(reason)}")
            {:error, reason}
        end
      end)

    # 2. If a file was uploaded, add the URL to params.
    user_params =
      case uploaded_urls do
        [url | _] -> Map.put(user_params, "avatar_url", url)
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
         |> push_navigate(to: ~p"/users/#{updated_user.username}")}

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
  def handle_info(%{topic: "users:online", event: "presence_diff"}, socket) do
    {:noreply, socket}
  end

@impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-8 sm:px-6 lg:px-8">
      <div class="mb-8">
        <h1 class="text-2xl font-bold tracking-tight text-gray-900 dark:text-white sm:text-3xl">
          Account Settings
        </h1>
        <p class="mt-2 text-sm text-gray-500 dark:text-gray-400">
          Manage your profile information and security preferences.
        </p>
      </div>

      <div class="space-y-8">
        <section class="bg-white dark:bg-zinc-900 shadow-sm ring-1 ring-gray-900/5 dark:ring-white/10 sm:rounded-xl overflow-hidden">
          <div class="px-4 py-6 sm:p-8">
            <div class="max-w-2xl">
              <h2 class="text-base font-semibold leading-7 text-gray-900 dark:text-white">Public Profile</h2>
              <p class="mt-1 text-sm leading-6 text-gray-500 dark:text-gray-400">This information will be displayed publicly so be careful what you share.</p>

              <.simple_form
                for={@profile_form}
                id="profile_form"
                phx-change="validate_profile"
                phx-submit="update_profile"
                class="mt-6 space-y-6"
              >
                <div class="flex items-center gap-x-8">
                  <div class="relative group">
                    <%= if @uploads.avatar.entries != [] do %>
                      <%= for entry <- @uploads.avatar.entries do %>
                        <.live_img_preview entry={entry} class="h-24 w-24 flex-none rounded-full bg-gray-50 object-cover ring-2 ring-gray-200 dark:ring-zinc-700" />
                      <% end %>
                    <% else %>
                      <%= if @current_user.avatar_url do %>
                        <img src={@current_user.avatar_url} class="h-24 w-24 flex-none rounded-full bg-gray-50 object-cover ring-2 ring-gray-200 dark:ring-zinc-700" />
                      <% else %>
                        <div class="h-24 w-24 flex-none rounded-full bg-orange-100 dark:bg-orange-900/30 text-orange-600 dark:text-orange-500 flex items-center justify-center text-3xl font-bold ring-2 ring-gray-200 dark:ring-zinc-700">
                          <%= String.first(@current_user.username || "?") |> String.upcase() %>
                        </div>
                      <% end %>
                    <% end %>
                  </div>

                  <div>
                    <label class="block text-sm font-medium leading-6 text-gray-900 dark:text-white">Profile photo</label>
                    <div class="mt-2 flex items-center gap-x-3">
                      <div class="relative">
                        <.live_file_input
                          upload={@uploads.avatar}
                          class="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10"
                        />
                        <button type="button" class="rounded-md bg-white dark:bg-zinc-800 px-3 py-2 text-sm font-semibold text-gray-900 dark:text-gray-200 shadow-sm ring-1 ring-inset ring-gray-300 dark:ring-zinc-600 hover:bg-gray-50 dark:hover:bg-zinc-700 relative pointer-events-none">
                          Change
                        </button>
                      </div>
                      <p class="text-[11px] text-gray-500 dark:text-gray-400">JPG/PNG, max 5MB</p>
                    </div>
                    <%= for entry <- @uploads.avatar.entries do %>
                      <%= for err <- upload_errors(@uploads.avatar, entry) do %>
                        <p class="text-red-500 text-xs mt-1"><%= error_to_string(err) %></p>
                      <% end %>
                    <% end %>
                  </div>
                </div>

                <div class="grid grid-cols-1 gap-x-6 gap-y-8 sm:grid-cols-6">
                  <div class="sm:col-span-4">
                    <.input field={@profile_form[:username]} type="text" label="Username" required />
                  </div>

                  <div class="col-span-full">
                    <.input field={@profile_form[:bio]} type="textarea" label="Bio" rows="3" placeholder="Tell us a little about yourself..." />
                    <p class="mt-2 text-sm text-gray-500 dark:text-gray-400">Brief description for your profile.</p>
                  </div>
                </div>

                <div class="flex items-center justify-end gap-x-6 border-t border-gray-900/10 dark:border-white/10 pt-6">
                  <.button phx-disable-with="Saving..." class="bg-orange-600 hover:bg-orange-500">Save Profile</.button>
                </div>
              </.simple_form>
            </div>
          </div>
        </section>

        <section class="bg-white dark:bg-zinc-900 shadow-sm ring-1 ring-gray-900/5 dark:ring-white/10 sm:rounded-xl overflow-hidden">
          <div class="px-4 py-6 sm:p-8">
            <div class="max-w-2xl">
              <h2 class="text-base font-semibold leading-7 text-gray-900 dark:text-white">Email Address</h2>
              <p class="mt-1 text-sm leading-6 text-gray-500 dark:text-gray-400">Update the email associated with your account.</p>

              <.simple_form
                for={@email_form}
                id="email_form"
                phx-submit="update_email"
                phx-change="validate_email"
                class="mt-6 space-y-6"
              >
                <div class="grid grid-cols-1 gap-x-6 gap-y-8 sm:grid-cols-6">
                  <div class="sm:col-span-4">
                    <.input field={@email_form[:email]} type="email" label="New Email" required />
                  </div>

                  <div class="sm:col-span-4">
                    <.input
                      field={@email_form[:current_password]}
                      name="current_password"
                      id="current_password_for_email"
                      type="password"
                      label="Current password"
                      value={@email_form_current_password}
                      required
                    />
                  </div>
                </div>

                <div class="flex items-center justify-end gap-x-6 border-t border-gray-900/10 dark:border-white/10 pt-6">
                  <.button phx-disable-with="Changing..." class="bg-orange-600 hover:bg-orange-500">Update Email</.button>
                </div>
              </.simple_form>
            </div>
          </div>
        </section>

        <section class="bg-white dark:bg-zinc-900 shadow-sm ring-1 ring-gray-900/5 dark:ring-white/10 sm:rounded-xl overflow-hidden">
          <div class="px-4 py-6 sm:p-8">
            <div class="max-w-2xl">
              <h2 class="text-base font-semibold leading-7 text-gray-900 dark:text-white">Change Password</h2>
              <p class="mt-1 text-sm leading-6 text-gray-500 dark:text-gray-400">Ensure your account is using a long, random password to stay secure.</p>

              <.simple_form
                for={@password_form}
                id="password_form"
                action={~p"/users/log_in?_action=password_updated"}
                method="post"
                phx-change="validate_password"
                phx-submit="update_password"
                phx-trigger-action={@trigger_submit}
                class="mt-6 space-y-6"
              >
                <input
                  name={@password_form[:email].name}
                  type="hidden"
                  id="hidden_user_email"
                  value={@current_email}
                />

                <div class="grid grid-cols-1 gap-x-6 gap-y-8 sm:grid-cols-6">
                  <div class="sm:col-span-3">
                    <.input field={@password_form[:password]} type="password" label="New password" required />
                  </div>
                  <div class="sm:col-span-3">
                    <.input
                      field={@password_form[:password_confirmation]}
                      type="password"
                      label="Confirm new password"
                    />
                  </div>
                  <div class="sm:col-span-6">
                    <.input
                      field={@password_form[:current_password]}
                      name="current_password"
                      type="password"
                      label="Current password"
                      id="current_password_for_password"
                      value={@current_password}
                      required
                    />
                  </div>
                </div>

                <div class="flex items-center justify-end gap-x-6 border-t border-gray-900/10 dark:border-white/10 pt-6">
                  <.button phx-disable-with="Changing..." class="bg-orange-600 hover:bg-orange-500">Update Password</.button>
                </div>
              </.simple_form>
            </div>
          </div>
        </section>
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
