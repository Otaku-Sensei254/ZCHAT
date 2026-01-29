defmodule VibeflowWeb.UI.NotificationsLive do
  use VibeflowWeb, :live_view

  alias Vibeflow.Accounts
  alias Vibeflow.Notifications

  @impl true
  def mount(_params, session, socket) do
    socket = VibeflowWeb.UserAuth.mount_current_user(socket, session)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Vibeflow.PubSub, "notifications:#{socket.assigns.current_user.id}")
    end

    notifications = Notifications.list_user_notifications(socket.assigns.current_user.id)

    {:ok,
     socket
     |> assign(:notifications, notifications)}
  end

  @impl true
  def handle_info({:new_notification, notification}, socket) do
    {:noreply,
     socket
     |> assign(:notifications, [notification | socket.assigns.notifications])}
  end
end
  