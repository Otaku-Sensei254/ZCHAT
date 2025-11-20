defmodule ZchatWeb.Components.NotificationsModal do
  use ZchatWeb, :live_component
  alias Zchat.Notifications

  @impl true
  def update(assigns, socket) do
    # We also subscribe here just to be safe if the global one misses
    if connected?(socket) && assigns[:current_user] do
      Phoenix.PubSub.subscribe(Zchat.PubSub, "notifications:#{assigns.current_user.id}")
    end

    {:ok,
     socket
     |> assign(assigns)
     |> assign_notifications()}
  end

  defp assign_notifications(socket) do
    user = socket.assigns.current_user

    if user do
      notifications = Notifications.list_user_notifications(user.id, 10)
      unread_count = Notifications.unread_count(user.id)

      socket
      |> assign(:notifications, notifications)
      |> assign(:unread_count, unread_count)
    else
      assign(socket, notifications: [], unread_count: 0)
    end
  end

  # --- EVENTS ---

  @impl true
  def handle_event("mark_as_read", %{"id" => id}, socket) do
    # This triggers DB update -> Broadcast -> Global handle_info -> send_update -> refresh
    Notifications.mark_as_read(id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("mark_all_read", _, socket) do
    Notifications.mark_all_read(socket.assigns.current_user.id)
    {:noreply, socket}
  end

  # --- VIEW HELPERS ---

  defp notification_link(notification) do
    case notification.type do
      "follow" -> ~p"/users/#{notification.actor.username}"
      _ -> ~p"/posts/#{notification.post_id}"
    end
  end

  defp format_text(n) do
    case n.type do
      "like" -> "liked your post"
      "comment" -> "commented on your post"
      "follow" -> "followed you"
      "new_post" -> "posted something new"
      _ -> "sent a notification"
    end
  end

 
end
