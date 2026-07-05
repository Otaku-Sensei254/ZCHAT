defmodule VibeflowWeb.RelayChannel do
  use VibeflowWeb, :channel
  alias VibeflowWeb.Presence

  def join("relay:user", _payload, socket) do
    user_id = socket.assigns.current_user.id
    Phoenix.PubSub.subscribe(Vibeflow.PubSub, "notifications:#{user_id}")
    Phoenix.PubSub.subscribe(Vibeflow.PubSub, "user_sidebar:#{user_id}")
    Phoenix.PubSub.subscribe(Vibeflow.PubSub, "users:online")

    send(self(), :after_join_user)

    {:ok, socket}
  end

  def handle_info(:after_join_user, socket) do
    user = socket.assigns.current_user

    VibeflowWeb.Presence.track(self(), "users:online", user.id, %{
      online_at: inspect(System.system_time(:second)),
      username: user.username,
      avatar: user.avatar_url
    })

    push(socket, "presence_state", VibeflowWeb.Presence.list("users:online"))

    {:noreply, socket}
  end

  def join("relay:feed", _payload, socket) do
    Phoenix.PubSub.subscribe(Vibeflow.PubSub, "posts")
    {:ok, socket}
  end

  def join("relay:post:" <> post_uuid, _payload, socket) do
    post = Vibeflow.Posts.get_post_by_uuid(post_uuid)
    if post do
      Phoenix.PubSub.subscribe(Vibeflow.PubSub, "post:#{post.id}")
      Phoenix.PubSub.subscribe(Vibeflow.PubSub, "post_comments:#{post.id}")
      {:ok, socket}
    else
      {:error, %{reason: "not found"}}
    end
  end

  def handle_info({:new_notification, notif}, socket) do
    push(socket, "new_notification", %{
      id: notif.id,
      type: notif.type,
      user_id: notif.user_id,
      actor_id: notif.actor_id,
      post_id: notif.post_id,
      read_at: notif.read_at,
      inserted_at: notif.inserted_at,
      actor: notif.actor && %{
        id: notif.actor.id,
        username: notif.actor.username,
        avatar_url: notif.actor.avatar_url
      },
      post: notif.post && %{
        uuid: notif.post.uuid,
        title: notif.post.title
      }
    })
    {:noreply, socket}
  end

  def handle_info(:update_notifications, socket) do
    push(socket, "update_notifications", %{})
    {:noreply, socket}
  end

  def handle_info({:new_sidebar_message, message}, socket) do
    push(socket, "new_sidebar_message", %{
      id: message.id,
      content: message.content,
      conversation_uuid: message.conversation_uuid,
      conversation_id: message.conversation_id,
      user_id: message.user_id,
      inserted_at: message.inserted_at,
      user: message.user && %{
        id: message.user.id,
        username: message.user.username,
        avatar_url: message.user.avatar_url
      }
    })
    {:noreply, socket}
  end

  def handle_info(:update_sidebar, socket) do
    push(socket, "update_sidebar", %{})
    {:noreply, socket}
  end

  def handle_info({:post_liked, like}, socket) do
    push(socket, "post_liked", %{
      post_id: like.likeable_id,
      user_id: like.user_id,
      id: like.id
    })
    {:noreply, socket}
  end

  def handle_info({:post_unliked, payload}, socket) do
    push(socket, "post_unliked", %{
      post_id: payload.post_id,
      user_id: payload.user_id
    })
    {:noreply, socket}
  end

  def handle_info({:new_comment, comment}, socket) do
    push(socket, "new_comment", %{
      id: comment.id,
      content: comment.content,
      pinned: comment.pinned,
      post_id: comment.post_id,
      user_id: comment.user_id,
      inserted_at: comment.inserted_at,
      user: comment.user && %{
        id: comment.user.id,
        username: comment.user.username,
        avatar_url: comment.user.avatar_url
      }
    })
    {:noreply, socket}
  end

  def handle_info({:comment_updated, comment}, socket) do
    push(socket, "comment_updated", %{
      id: comment.id,
      content: comment.content,
      pinned: comment.pinned,
      post_id: comment.post_id,
      user_id: comment.user_id,
      inserted_at: comment.inserted_at,
      user: comment.user && %{
        id: comment.user.id,
        username: comment.user.username,
        avatar_url: comment.user.avatar_url
      }
    })
    {:noreply, socket}
  end

  def handle_info({:comment_pinned, comment}, socket) do
    push(socket, "comment_pinned", %{
      id: comment.id,
      post_id: comment.post_id
    })
    {:noreply, socket}
  end

  def handle_info({:comment_deleted, comment_id, post_id}, socket) do
    push(socket, "comment_deleted", %{id: comment_id, post_id: post_id})
    {:noreply, socket}
  end

  def handle_info({:new_post, post}, socket) do
    push(socket, "new_post", %{
      id: post.id,
      uuid: post.uuid,
      title: post.title,
      user_id: post.user_id
    })
    {:noreply, socket}
  end

  def handle_info({:post_deleted, post}, socket) do
    push(socket, "post_deleted", %{uuid: post.uuid, id: post.id})
    {:noreply, socket}
  end

  def handle_info({:repost_added, repost}, socket) do
    push(socket, "repost_added", %{
      post_id: repost.post_id,
      user_id: repost.user_id
    })
    {:noreply, socket}
  end

  def handle_info({:unreposted, post}, socket) do
    push(socket, "unreposted", %{post_id: post.id})
    {:noreply, socket}
  end

  def handle_info({:post_saved, payload}, socket) do
    push(socket, "post_saved", %{
      post_id: payload.post_id,
      user_id: payload.user_id
    })
    {:noreply, socket}
  end

  def handle_info({:post_unsaved, payload}, socket) do
    push(socket, "post_unsaved", %{
      post_id: payload.post_id,
      user_id: payload.user_id
    })
    {:noreply, socket}
  end

  def handle_info({:points_awarded, payload}, socket) do
    push(socket, "points_awarded", %{
      amount: payload.amount,
      user_id: payload.user_id
    })
    {:noreply, socket}
  end

  def handle_info(%{topic: "users:online", event: "presence_diff"}, socket) do
    # Mirror what LiveView does: push the full authoritative list on every diff
    push(socket, "presence_state", VibeflowWeb.Presence.list("users:online"))
    {:noreply, socket}
  end

  # Allow React client to request a fresh presence snapshot any time (e.g. after reconnect)
  def handle_in("get_presence", _payload, socket) do
    {:reply, {:ok, VibeflowWeb.Presence.list("users:online")}, socket}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end
end