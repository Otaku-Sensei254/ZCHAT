defmodule VibeflowWeb.Api.V1.NotificationController do
  use VibeflowWeb, :controller

  def index(conn, _params) do
    user = conn.assigns.current_user
    notifications = Vibeflow.Notifications.list_user_notifications(user.id)
    unread = Vibeflow.Notifications.unread_count(user.id)
    json(conn, %{
      data: %{
        notifications: Enum.map(notifications, &notification_json/1),
        unread_count: unread
      }
    })
  end

  def mark_read(conn, %{"id" => id}) do
    Vibeflow.Notifications.mark_as_read(String.to_integer(id))
    json(conn, %{data: %{message: "Marked as read"}})
  end

  def mark_all_read(conn, _params) do
    user = conn.assigns.current_user
    Vibeflow.Notifications.mark_all_read(user.id)
    json(conn, %{data: %{message: "All marked as read"}})
  end

  def clear(conn, _params) do
    user = conn.assigns.current_user
    Vibeflow.Notifications.clear_notifications(user.id)
    json(conn, %{data: %{message: "Notifications cleared"}})
  end

  defp notification_json(notif) do
    %{
      id: notif.id,
      type: notif.type,
      read_at: notif.read_at,
      actor: if(notif.actor, do: %{
        id: notif.actor.id,
        username: notif.actor.username,
        avatar_url: notif.actor.avatar_url
      }),
      post_id: notif.post_id,
      post_uuid: notif.post && notif.post.uuid,
      post_title: notif.post && notif.post.title,
      conversation_id: notif.conversation_id,
      conversation_uuid: notif.conversation && notif.conversation.uuid,
      inserted_at: notif.inserted_at
    }
  end
end
