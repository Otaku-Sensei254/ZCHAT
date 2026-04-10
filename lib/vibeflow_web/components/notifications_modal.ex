defmodule VibeflowWeb.Components.NotificationsModal do
  use VibeflowWeb, :live_component
  alias Vibeflow.Accounts
  alias Vibeflow.Notifications
  alias Vibeflow.Socials

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

  @impl true
  def handle_event("clear_notifications", _, socket) do
    Notifications.clear_notifications(socket.assigns.current_user.id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("follow_back", %{"user-id" => user_id}, socket) do
    current_user = socket.assigns.current_user

    with %{} <- current_user,
         {actor_id, ""} <- Integer.parse(user_id),
         true <- actor_id != current_user.id do
      case Socials.create_follow(%{follower_id: current_user.id, following_id: actor_id}) do
        {:ok, _follow} ->
          {:noreply, assign_notifications(socket)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Unable to follow user")}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  # --- VIEW HELPERS ---
  def notification_link(%{type: "shared_post", conversation: %{uuid: uuid}}, _current_user) do
    ~p"/chat/#{uuid}"
  end

  def notification_link(%{type: "shared_post", conversation_id: conv_id}, _current_user) do
    case Vibeflow.Chat.get_conversation(conv_id) do
      %{uuid: uuid} -> ~p"/chat/#{uuid}"
      _ -> "/chat"
    end
  end

  def notification_link(%{post: %{uuid: uuid}}, _current_user) do
    ~p"/posts/#{uuid}"
  end

  def notification_link(%{post_id: post_id}, _current_user) when is_integer(post_id) do
    # Fallback if post not preloaded - USE SAFE get_post (no bang)
    case Vibeflow.Posts.get_post(post_id) do
      %{uuid: uuid} -> ~p"/posts/#{uuid}"
      _ -> "#"
    end
  end
  def notification_link(%{type: "follow", actor: %{username: username}}, _current_user) do
    ~p"/users/#{username}"
  end
    def notification_link(%{post_id: post_id, type: "repost", actor: %{username: username}}, _current_user) do
    case Vibeflow.Posts.get_post(post_id) do
      %{uuid: uuid} -> ~p"/posts/#{uuid}"
      _ -> "#"
    end
  end

  def notification_link(%{type: "role_change", user: %{username: username}}, _current_user) when is_binary(username) do

    ~p"/users/#{username}"
  end
  def notification_link(%{type: "verification_request"}, current_user) do
    cond do
      Accounts.user_has_role?(current_user, "admin") -> "/admin/verification-requests"
      Accounts.user_has_role?(current_user, "moderator") -> "/moderator/verification-requests"
      true -> ~p"/"
    end
  end

  def notification_link(%{type: "verification_approved"}, current_user) do
    ~p"/users/#{current_user.username}"
  end

  def notification_link(%{type: "verification_rejected"}, current_user) do
    ~p"/users/#{current_user.username}"
  end

  def notification_link(_unknown, _current_user) do
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
      "verification_request" -> "requested verification"
      "verification_approved" -> "approved your verification"
      "verification_rejected" -> "rejected your verification"
      "repost" -> "reposted your post"
      _ -> "sent a notification"
    end
  end

  def follow_back?(%{type: "follow", actor_id: actor_id}, current_user) do
    current_user &&
      actor_id &&
      actor_id != current_user.id &&
      !Socials.following?(current_user.id, actor_id)
  end

  def follow_back?(_notif, _current_user), do: false
end
