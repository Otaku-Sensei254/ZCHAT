defmodule VibeflowWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use VibeflowWeb, :controller
      use VibeflowWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: VibeflowWeb.Layouts]

      import Plug.Conn
      import VibeflowWeb.Gettext
      import Canada.Can
      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {VibeflowWeb.Layouts, :app}

        unquote(html_helpers())
        import Canada.Can
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent
      unquote(html_helpers())
      import Canada.Can
      @impl true
      def handle_info(:new_notification, socket) do
        # Tell the components (Desktop AND Mobile) to update
        send_update(VibeflowWeb.Components.NotificationsModal, id: "notifications-modal-desktop")
        send_update(VibeflowWeb.Components.NotificationsModal, id: "notifications-modal-mobile")
        {:noreply, socket}
      end

      @impl true
      def handle_info(:update_notifications, socket) do
        send_update(VibeflowWeb.Components.NotificationsModal, id: "notifications-modal-desktop")
        send_update(VibeflowWeb.Components.NotificationsModal, id: "notifications-modal-mobile")
        {:noreply, socket}
      end
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components and translation
      import VibeflowWeb.CoreComponents
      import VibeflowWeb.Gettext

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: VibeflowWeb.Endpoint,
        router: VibeflowWeb.Router,
        statics: VibeflowWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
