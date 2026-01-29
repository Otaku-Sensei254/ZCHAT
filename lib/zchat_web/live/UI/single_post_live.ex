defmodule ZchatWeb.UI.SinglePostLive do
  use ZchatWeb, :live_view

  alias Zchat.Posts
  alias Zchat.Posts.Comment
  alias ZchatWeb.UserAuth

  def layout(_assigns), do: {ZchatWeb.Layouts, :app}

  @impl true
  def mount(_params, session, socket) do
    socket = UserAuth.mount_current_user(socket, session)

    {:ok,
     socket
     |> assign(:replying_to, nil)
     |> assign(:editing_comment_id, nil)
     |> assign(:comment_form, to_form(Posts.change_comment(%Comment{})))
     |> stream(:comments, [])
     |> assign(:current_like, nil)
     |> assign(:like_count, 0)
     # Initialize slider index
     |> assign(:current_media_index, 0)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    post = Posts.get_post!(id, preload: [:user, :likes, comments: :user])
    comments = Posts.list_comments(post_id: post.id, preload: [:user])

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Zchat.PubSub, "post:#{post.id}")
      # Track view if user is logged in
      if socket.assigns.current_user && socket.assigns.current_user.id != post.user_id do
        Posts.track_view(post.id, socket.assigns.current_user.id)
      end
    end

    current_like =
      if socket.assigns.current_user do
        Posts.get_like_by_user_and_target(socket.assigns.current_user.id, "Post", post.id)
      else
        nil
      end

    {:noreply,
     socket
     |> assign(:post, post)
     # Reset slider when loading a new post
     |> assign(:current_media_index, 0)
     |> stream(:comments, comments, reset: true)
     |> assign(:like_count, post.likes_count || 0)
     |> assign(:current_like, current_like)
     |> assign(:comment_count, length(post.comments || []))}
  end

  # --- CAROUSEL LOGIC ---

  @impl true
  def handle_event("next_media", _, socket) do
    total_media = length(socket.assigns.post.media_files)
    current = socket.assigns.current_media_index
    new_index = rem(current + 1, total_media)
    {:noreply, assign(socket, :current_media_index, new_index)}
  end

  @impl true
  def handle_event("prev_media", _, socket) do
    total_media = length(socket.assigns.post.media_files)
    current = socket.assigns.current_media_index
    new_index = if current - 1 < 0, do: total_media - 1, else: current - 1
    {:noreply, assign(socket, :current_media_index, new_index)}
  end

  @impl true
  def handle_event("go_to_media", %{"index" => index}, socket) do
    {:noreply, assign(socket, :current_media_index, String.to_integer(index))}
  end

  # --- EXISTING HANDLERS ---

  @impl true
  def handle_event("validate", %{"comment" => params}, socket) do
    changeset =
      %Comment{}
      |> Posts.change_comment(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :comment_form, to_form(changeset))}
  end

  @impl true
  def handle_event("add_comment", %{"comment" => comment_params}, socket) do
    if socket.assigns.current_user do
      attrs =
        Map.merge(comment_params, %{
          "user_id" => socket.assigns.current_user.id,
          "post_id" => socket.assigns.post.id,
          "parent_id" => socket.assigns.replying_to
        })

      case Posts.create_comment(attrs) do
        {:ok, _comment} ->
          # FIX: Ensure clear_flash happens inside the tuple, before the closing brace '}'
          {:noreply,
           socket
           |> assign(:comment_form, to_form(Posts.change_comment(%Comment{})))
           |> assign(:replying_to, nil)
           |> clear_flash()
           |> put_flash(:info, "Comment added successfully 💬 !")}

        {:error, changeset} ->
          {:noreply, assign(socket, :comment_form, to_form(changeset))}
      end
    else
      {:noreply, put_flash(socket, :error, "You must be logged in to comment.")}
    end
  end

  @impl true
  def handle_event("reply_to", %{"parent_id" => parent_id}, socket) do
    {:noreply, assign(socket, :replying_to, parent_id)}
  end

  @impl true
  def handle_event("cancel_reply", _, socket) do
    {:noreply, assign(socket, :replying_to, nil)}
  end

  @impl true
  def handle_event("like_comment", %{"comment_id" => _id}, socket) do

    {:noreply, socket}
  end
  #edit comment
  def handle_event("edit_comment", %{"id" => comment_id}, socket) do
    {:noreply, assign(socket, editing_comment_id: String.to_integer(comment_id))}
  end
  #cancel the comment edit
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing_coment_id: nil)}
  end

  #save your editted comment

  def handle_event("save_comment_edit", %{"comment" => comment_params}, socket) do
    comment_id = comment_params["id"]
    new_comment = comment_params["content"]

    comment = Enum.find(socket.assigns.comments, &(&1.id == String.to_integer(comment_id)))
    case Zchat.Posts.update_comment(comment, %{"content"=>  new_comment}) do
      {:ok, _updated_comment} ->
        {:noreply, socket
      |>assign(:editing_comment_id, nil)
      |>put_flash(:info, "Comment updated successfully")
    }
    end
  end

  @impl true
  def handle_event("toggle_like", _, socket) do
    if socket.assigns.current_user do
      post_id = socket.assigns.post.id
      user_id = socket.assigns.current_user.id

      # 1. Check if we are currently liking or unliking based on existing state
      was_liked = socket.assigns.current_like != nil

      case Posts.toggle_like(user_id, "Post", post_id) do
        {:ok, _result} ->
          msg = if was_liked, do: "Unliked post 💔", else: "Liked post ❤️"

          {:noreply,
           socket
           |> clear_flash()
           |> put_flash(:info, msg)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Error toggling like")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "You must be logged in to like posts")
       |> push_navigate(to: ~p"/users/log_in")}
    end
  end


  @impl true
  def handle_info({:new_comment, comment}, socket) do
    socket =
      socket
      |> stream_insert(:comments, comment, at: 0)
      |> update(:like_count, & &1)
    {:noreply, socket}
  end

  def handle_info({:comment_updated, updated_comment}, socket) do
    #replace old comment with updated comment
    updated_comment_list =
    Enum.map(socket.assigns.comments, fn current_comment ->
      if current_comment.id == updated_comment do
        updated_comment
      else
        current_comment
      end
    end)

    {:noreply, assign(socket, comments: updated_comment_list)}
  end

  @impl true
  def handle_info({:post_liked, like}, socket) do
    if like.likeable_id == socket.assigns.post.id do
      new_count = socket.assigns.like_count + 1

      current_like =
        if socket.assigns.current_user && like.user_id == socket.assigns.current_user.id do
          like
        else
          socket.assigns.current_like
        end

      {:noreply, assign(socket, like_count: new_count, current_like: current_like)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:post_unliked, %{post_id: post_id, user_id: user_id}}, socket) do
    if post_id == socket.assigns.post.id do
      new_count = max(0, socket.assigns.like_count - 1)

      current_like =
        if socket.assigns.current_user && user_id == socket.assigns.current_user.id do
          nil
        else
          socket.assigns.current_like
        end

      {:noreply, assign(socket, like_count: new_count, current_like: current_like)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:new_notification, socket) do
    {:noreply, socket}
  end
   @impl true
  def handle_info(:new_notification, socket) do
    send_update(ZchatWeb.Components.NotificationsModal, id: "notifications-modal-desktop")
    send_update(ZchatWeb.Components.NotificationsModal, id: "notifications-modal-mobile")
    {:noreply, socket}
  end

@impl true
  def handle_info(%{topic: "users:online", event: "presence_diff"}, socket) do
    {:noreply, socket}
  end
  
  @impl true
  def handle_info(:notifications_read, socket) do
    send_update(ZchatWeb.Components.NotificationsModal, id: "notifications-modal-desktop")
    send_update(ZchatWeb.Components.NotificationsModal, id: "notifications-modal-mobile")
    {:noreply, socket}
  end

  @impl true
  def handle_info(:update_notifications, socket) do
    # Example: Send update to the Nav component or refresh assigns
    send_update(ZchatWeb.Components.NotificationsModal, id: "notifications-modal-desktop")
    {:noreply, socket}
  end
end
