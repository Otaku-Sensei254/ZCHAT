defmodule VibeflowWeb.UserRegistrationLive do
  use VibeflowWeb, :live_view

  alias Vibeflow.Accounts
  alias Vibeflow.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="min-h-[80vh] flex flex-col justify-center py-12 sm:px-6 lg:px-8">

      <div class="sm:mx-auto sm:w-full sm:max-w-md text-center mb-8 animate-in fade-in slide-in-from-top-4 duration-500">
        <span class="text-4xl">🚀</span>
        <h2 class="mt-4 text-3xl font-extrabold text-gray-900 dark:text-white tracking-tight">
          Create an account
        </h2>
        <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
          Already have an account?
          <.link navigate={~p"/users/log_in"} class="font-medium text-indigo-600 hover:text-indigo-500 dark:text-indigo-400 hover:underline transition-all">
            Log in here
          </.link>
        </p>
      </div>

      <div class="mt-2 sm:mx-auto sm:w-full sm:max-w-md animate-in fade-in slide-in-from-bottom-8 duration-700">
        <div class="bg-white dark:bg-zinc-900 py-8 px-6 shadow-xl rounded-2xl sm:px-10 border border-gray-100 dark:border-zinc-800 relative overflow-hidden">

          <div class="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-orange-400 via-pink-500 to-purple-500"></div>

          <.simple_form
            for={@form}
            id="registration_form"
            phx-submit="save"
            phx-change="validate"
            phx-trigger-action={@trigger_submit}
            action={~p"/users/log_in?_action=registered"}
            method="post"
            class="space-y-6"
          >
            <.error :if={@check_errors}>
              <div class="p-3 rounded-lg bg-red-50 dark:bg-red-900/30 text-red-600 dark:text-red-400 text-sm font-medium border border-red-100 dark:border-red-900/50">
                Oops, something went wrong! Please check the errors below.
              </div>
            </.error>

            <div>
              <.input field={@form[:username]} type="text" label="Username" required
                class="block w-full rounded-lg border-gray-300 dark:border-zinc-700 dark:bg-zinc-800 focus:border-indigo-500 focus:ring-orange-500 sm:text-sm shadow-sm transition-all"
                placeholder="johndoe"
              />
            </div>

            <div>
              <.input field={@form[:email]} type="email" label="Email address" required
                class="block w-full rounded-lg border-gray-300 dark:border-zinc-700 dark:bg-zinc-800 focus:border-indigo-500 focus:ring-orange-500 sm:text-sm shadow-sm transition-all"
                placeholder="you@example.com"
              />
            </div>

            <div>
              <.input field={@form[:password]} type="password" label="Password" required
                class="block w-full rounded-lg border-gray-300 dark:border-zinc-700 dark:bg-zinc-800 focus:border-indigo-500 focus:ring-orange-500 sm:text-sm shadow-sm transition-all"
                placeholder="••••••••"
              />
              <p class="mt-1 text-xs text-gray-500 dark:text-gray-400">Must be at least 8 characters</p>
            </div>

            <div class="pt-4">
              <.button phx-disable-with="Creating account..." class="w-full flex justify-center py-2.5 px-4 border border-transparent rounded-xl shadow-md text-sm font-bold text-white bg-gradient-to-r from-orange-500 to-orange-600 hover:from-orange-600 hover:to-orange-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-orange-500 transition-all duration-200 transform hover:-translate-y-0.5 hover:shadow-lg">
                Create account <span aria-hidden="true" class="ml-2">→</span>
              </.button>
            </div>
          </.simple_form>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        changeset = Accounts.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
