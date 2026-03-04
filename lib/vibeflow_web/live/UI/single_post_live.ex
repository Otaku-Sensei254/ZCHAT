defmodule VibeflowWeb.UI.SinglePostLive do
  use VibeflowWeb, :live_view

  alias Vibeflow.Posts
  alias Vibeflow.Posts.Comment
  alias VibeflowWeb.UserAuth

  # Use the app layout
  def layout(_assigns), do: {VibeflowWeb.Layouts, :app}

  @impl true
  def mount(_params, session, socket) do
    socket = UserAuth.mount_current_user(socket, session)

    {:ok,
     socket
     |> assign(:replying_to, nil)
     |> assign(:editing_comment_id, nil)
     |> assign(:comment_form, to_form(Posts.change_comment(%Comment{})))
     |> assign(:current_like, nil)
     |> assign(:like_count, 0)
    #  |> assign(:hide_bottom_nav, true)
     |> assign(:show_comments_modal, false)
     |> assign(:current_media_index, 0)
    #  FIX: Initialize BOTH streams here
     |> stream(:comments, [])

     |> stream(:mobile_comments, [])}
  end

  @impl true
  def handle_params(%{"uuid" => uuid}, _uri, socket) do
    post = Posts.get_post!(uuid, preload: [:user, :likes, comments: :user])

    # Ensure your Posts.list_comments returns newest first (inserted_at: :desc)
    # so it matches the prepend behavior of stream_insert
    comments = Posts.list_comments(post_id: post.id, preload: [:user])

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Vibeflow.PubSub, "post:#{post.id}")
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
     |> assign(:current_media_index, 0)
     |> assign(:like_count, post.likes_count || 0)
     |> assign(:current_like, current_like)
     |> assign(:comment_count, length(comments))

     # 1. Desktop Stream: Uses standard IDs (e.g., "comments-1")
     |> stream(:comments, comments, reset: true)

     # 2. Mobile Stream: Uses custom IDs (e.g., "mobile-comment-1") to prevent DOM conflicts
     |> stream(:mobile_comments, comments, reset: true, dom_id: fn c -> "mobile-comment-#{c.id}" end)}
  end

  # --- MEDIA CAROUSEL ---

  @impl true
  def handle_event("next_media", _, socket) do
    total_media = length(socket.assigns.post.media_files)
    new_index = rem(socket.assigns.current_media_index + 1, total_media)
    {:noreply, assign(socket, :current_media_index, new_index)}
  end

  @impl true
  def handle_event("prev_media", _, socket) do
    total_media = length(socket.assigns.post.media_files)
    current = socket.assigns.current_media_index
    new_index = if current == 0, do: total_media - 1, else: current - 1
    {:noreply, assign(socket, :current_media_index, new_index)}
  end

  @impl true
  def handle_event("go_to_media", %{"index" => index}, socket) do
    {:noreply, assign(socket, :current_media_index, String.to_integer(index))}
  end

  # --- INTERACTIONS ---

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
      attrs = Map.merge(comment_params, %{
          "user_id" => socket.assigns.current_user.id,
          "post_id" => socket.assigns.post.id,
          "parent_id" => socket.assigns.replying_to
        })

      case Posts.create_comment(attrs) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:comment_form, to_form(Posts.change_comment(%Comment{})))
           |> assign(:replying_to, nil)
           |> put_flash(:info, "Comment posted!")}
        {:error, changeset} ->
          {:noreply, assign(socket, :comment_form, to_form(changeset))}
      end
    else
      {:noreply, put_flash(socket, :error, "Login required")}
    end
  end

  @impl true
  def handle_event("toggle_like", _, socket) do
    if socket.assigns.current_user do
      Posts.toggle_like(socket.assigns.current_user.id, "Post", socket.assigns.post.id)
      {:noreply, socket}
    else
      {:noreply, push_navigate(socket, to: ~p"/users/log_in")}
    end
  end

 @impl true
 def handle_event("share_post", _, socket) do
   post_url = VibeflowWeb.Endpoint.url() <> "/posts/#{socket.assigns.post.uuid}"
    {:noreply,
     socket
     |> push_event("share_post", %{
       title: "Check out this post by #{socket.assigns.post.user.username}",
       text: socket.assigns.post.content,
       url: post_url
     })}
  end

  @impl true
  def handle_event("toggle_follow", %{"user-id" => user_id}, socket) do
    if socket.assigns.current_user do
      # Prevent following yourself
      if String.to_integer(user_id) == socket.assigns.current_user.id do
        {:noreply, put_flash(socket, :error, "You cannot follow yourself")}
      else
        # Toggle follow logic would go here
        # For now, just show a success message
        {:noreply, put_flash(socket, :info, "Follow functionality coming soon!")}
      end
    else
      {:noreply, put_flash(socket, :error, "Login required to follow users")}
    end
  end

  @impl true
  def handle_event("show_comments", _, socket) do
    comments = Posts.list_comments(post_id: socket.assigns.post.id, preload: [:user])

    {:noreply,
     socket
     |> assign(:show_comments_modal, true)
     |> stream(:mobile_comments, comments, reset: true, dom_id: fn c -> "mobile-comment-#{c.id}" end)}
  end


  @impl true
  def handle_event("close_comments_modal", _, socket), do: {:noreply, assign(socket, :show_comments_modal, false)}

  # --- REALTIME UPDATES ---

  @impl true
  def handle_info({:new_comment, comment}, socket) do
    socket = socket
      # FIX: Insert new comment into BOTH streams at the top
      |> stream_insert(:comments, comment, at: 0)
      |> stream_insert(:mobile_comments, comment, at: 0)
      |> update(:comment_count, &(&1 + 1))
    {:noreply, socket}
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
  def handle_info({:post_unliked, %{post_id: pid, user_id: uid}}, socket) do
    if pid == socket.assigns.post.id do
      current_like =
        if socket.assigns.current_user && uid == socket.assigns.current_user.id do
          nil
        else
          socket.assigns.current_like
        end
      {:noreply, assign(socket, like_count: max(0, socket.assigns.like_count - 1), current_like: current_like)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}
end
