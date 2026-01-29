defmodule ZchatWeb.UserLoginLive do
  use ZchatWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="min-h-[80vh] flex flex-col justify-center py-12 sm:px-6 lg:px-8">

      <div class="sm:mx-auto sm:w-full sm:max-w-md text-center mb-8 animate-in fade-in slide-in-from-top-4 duration-500">
        <span class="text-4xl">👋</span>
        <h2 class="mt-4 text-3xl font-extrabold text-gray-900 dark:text-white tracking-tight">
          Welcome back
        </h2>
        <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
          Don't have an account?
          <.link navigate={~p"/users/register"} class="font-medium text-orange-600 hover:text-orange-500 dark:text-orange-400 hover:underline transition-all">
            Sign up for free
          </.link>
        </p>
      </div>

      <div class="mt-2 sm:mx-auto sm:w-full sm:max-w-md animate-in fade-in slide-in-from-bottom-8 duration-700">
        <div class="bg-white dark:bg-zinc-900 py-8 px-6 shadow-xl rounded-2xl sm:px-10 border border-gray-100 dark:border-zinc-800 relative overflow-hidden">

          <div class="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-orange-400 via-pink-500 to-purple-500"></div>

          <.simple_form for={@form} id="login_form" action={~p"/users/log_in"} phx-update="ignore" class="space-y-6">

            <div>
              <.input field={@form[:email]} type="email" label="Email address" required
                class="block w-full rounded-lg border-gray-300 dark:border-zinc-700 dark:bg-zinc-800 focus:border-orange-500 focus:ring-orange-500 sm:text-sm transition-shadow shadow-sm"
              />
            </div>

            <div>
              <.input field={@form[:password]} type="password" label="Password" required
                class="block w-full rounded-lg border-gray-300 dark:border-zinc-700 dark:bg-zinc-800 focus:border-orange-500 focus:ring-orange-500 sm:text-sm transition-shadow shadow-sm"
              />
            </div>

            <div class="flex items-center justify-between pt-2">
              <div class="flex items-center">
                <.input field={@form[:remember_me]} type="checkbox" label="Remember me"
                  class="h-4 w-4 rounded border-gray-300 text-orange-600 focus:ring-orange-500 bg-gray-50 dark:bg-zinc-800"
                />
              </div>

              <div class="text-sm">
                <.link href={~p"/users/reset_password"} class="font-medium text-orange-600 hover:text-orange-500 dark:text-orange-400 transition-colors">
                  Forgot password?
                </.link>
              </div>
            </div>

            <div class="pt-2">
              <.button phx-disable-with="Logging in..." class="w-full flex justify-center py-2.5 px-4 border border-transparent rounded-xl shadow-md text-sm font-bold text-white bg-gradient-to-r from-orange-500 to-orange-600 hover:from-orange-600 hover:to-orange-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-orange-500 transition-all duration-200 transform hover:-translate-y-0.5 hover:shadow-lg">
                Log in <span aria-hidden="true" class="ml-2">→</span>
              </.button>
            </div>

          </.simple_form>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")

    if socket.assigns[:current_user] do
      {:ok, redirect(socket, to: ~p"/feed")}
    else
      {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
    end
  end
end

