defmodule VibeflowWeb.Components.NotificationsModal do
  use VibeflowWeb, :live_component
  alias Vibeflow.Notifications

  @impl true
  def update(assigns, socket) do
    # We also subscribe here just to be safe if the global one misses
    if connected?(socket) && assigns[:current_user] do
      Phoenix.PubSub.subscribe(Vibeflow.PubSub, "notifications:#{assigns.current_user.id}")
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

  def handle_info(%{event: "notification_updated"}, socket) do
    {:noreply, assign_notifications(socket)}
  end

  # --- VIEW HELPERS ---
  def notification_link(%{type: "shared_post", conversation: %{uuid: uuid}}) do
    ~p"/chat/#{uuid}"
  end

  def notification_link(%{type: "shared_post", conversation_id: conv_id}) do
    case Vibeflow.Chat.get_conversation(conv_id) do
      %{uuid: uuid} -> ~p"/chat/#{uuid}"
      _ -> "/chat"
    end
  end

  def notification_link(%{post: %{uuid: uuid}}) do
    ~p"/posts/#{uuid}"
  end

  def notification_link(%{post_id: post_id} = n) when is_integer(post_id) do
    # Fallback if post not preloaded
    case Vibeflow.Posts.get_post!(post_id) do
      %{uuid: uuid} -> ~p"/posts/#{uuid}"
      _ -> ~p"/posts/#{post_id}"
    end
  end
  def notification_link(%{type: "follow", actor: %{username: username}}) do
    ~p"/users/#{username}"
  end

  def notification_link(%{type: "role_change", user: %{username: username}}) when is_binary(username) do

    ~p"/users/#{username}"
  end
    def notification_link(_unknown) do
    ~p"/"
  end


  def format_text(n) do
    case n.type do
      "like" -> "liked your post"
      "comment" -> "commented on your post"
      "follow" -> "started following you"
      "new_post" -> "posted something new"
      "role_change" -> "updated your role"
      "shared_post" -> "Shared a post with you"
      _ -> "sent a notification"
    end
  end
end
