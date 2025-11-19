defmodule ZchatWeb.Components.NotificationsModal do
  use ZchatWeb, :live_component

  alias Zchat.Notifications

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, socket
     |> assign(assigns)
     |> assign_notifications()}
  end

  defp assign_notifications(socket) do
    current_user = socket.assigns.current_user

    if current_user do
      notifications = Notifications.list_unread_notifications(current_user.id, limit: 10)
      unread_count = Notifications.get_unread_count(current_user.id)

      socket
      |> assign(:notifications, notifications)
      |> assign(:unread_count, unread_count)
    else
      socket
      |> assign(:notifications, [])
      |> assign(:unread_count, 0)
    end
  end

  def show_modal(), do: JS.show(to: "#notifications-modal")
  def hide_modal(), do: JS.hide(to: "#notifications-modal")

  @impl true
  def handle_event(event, params, socket) do
    case event do
      "load_notifications" ->
        current_user = socket.assigns.current_user
        notifications = Notifications.list_unread_notifications(current_user.id, limit: 10)

        {:noreply,
         socket
         |> assign(:notifications, notifications)
         |> assign(:unread_count, length(notifications))}

      "mark_as_read" ->
        notification_id = params["notification-id"]
        case Notifications.mark_as_read(notification_id) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign_notifications()
             |> push_patch(to: socket.assigns.patch)}
          {:error, _} ->
            {:noreply, socket}
        end

      "mark_all_as_read" ->
        current_user = socket.assigns.current_user
        Notifications.mark_all_as_read(current_user.id)

        {:noreply,
         socket
         |> assign_notifications()
         |> push_patch(to: socket.assigns.patch)}
      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("mark_all_as_read", _, socket) do
    current_user = socket.assigns.current_user
    Notifications.mark_all_as_read(current_user.id)

    {:noreply,
     socket
     |> assign_notifications()
     |> push_patch(to: socket.assigns.patch)}
  end

  defp format_notification_text(notification) do
    case notification.type do
      "like" -> "#{notification.actor.username} liked your post"
      "comment" -> "#{notification.actor.username} commented on your post"
      "follow" -> "#{notification.actor.username} started following you"
      "new_post" -> "#{notification.actor.username} made a new post"
      _ -> "New notification"
    end
  end

  defp notification_link(notification) do
    case notification.type do
      "like" -> ~p"/posts/#{notification.post_id}"
      "comment" -> ~p"/posts/#{notification.post_id}"
      "follow" -> ~p"/users/#{notification.actor.username}"
      "new_post" -> ~p"/posts/#{notification.post_id}"
      _ -> ~p"/feed"
    end
  end
end
