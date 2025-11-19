defmodule ZchatWeb.UI.NotificationsLive do
  use ZchatWeb, :live_view

  alias Zchat.Accounts
  alias Zchat.Notifications

  @impl true
  def mount(_params, session, socket) do
    socket = ZchatWeb.UserAuth.mount_current_user(socket, session)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Zchat.PubSub, "notifications:#{socket.assigns.current_user.id}")
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
  