defmodule ZchatWeb.UI.SinglePostLive do
  use ZchatWeb, :live_view

  alias Zchat.Posts
  alias Zchat.Posts.{Like, Comment}
  alias ZchatWeb.UserAuth

  @impl true
  def mount(_params, session, socket) do
    socket = UserAuth.mount_current_user(socket, session)

    {:ok,
     socket
     |> assign(:replying_to, nil)
     |> assign(:comment_form, Posts.change_comment(%Comment{}))
     |> stream(:comments, [])
     |> assign(:current_like, nil)
     |> assign(:like_count, 0)
     # Initialize slider index
     |> assign(:current_media_index, 0)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    post = Posts.get_post!(id)
    comments = Posts.list_comments(post_id: post.id)

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
     |> assign(:current_like, current_like)}
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
      attrs = Map.merge(comment_params, %{
        "user_id" => socket.assigns.current_user.id,
        "post_id" => socket.assigns.post.id,
        "parent_id" => socket.assigns.replying_to
      })

      case Posts.create_comment(attrs) do
        {:ok, _comment} ->
          {:noreply,
           socket
           |> assign(:comment_form, Posts.change_comment(%Comment{}))
           |> assign(:replying_to, nil)}

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
    # Placeholder
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_like", _, socket) do
    if socket.assigns.current_user do
      post_id = socket.assigns.post.id
      current_user = socket.assigns.current_user

      case Posts.toggle_like(current_user.id, "Post", post_id) do
        {:ok, %Like{} = like} ->
          {:noreply, assign(socket, current_like: like, like_count: socket.assigns.like_count + 1)}
        {:ok, nil} ->
          {:noreply, assign(socket, current_like: nil, like_count: max(0, socket.assigns.like_count - 1))}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Error liking post")}
      end
    else
      {:noreply, put_flash(socket, :error, "You must be logged in to like posts")}
    end
  end

  @impl true
  def handle_info({:new_comment, comment}, socket) do
    {:noreply, stream_insert(socket, :comments, comment, at: 0)}
  end

  @impl true
  def handle_info({:post_liked, like}, socket) do
    if like.likeable_id == socket.assigns.post.id do
      new_count = socket.assigns.like_count + 1
      current = if socket.assigns.current_user && like.user_id == socket.assigns.current_user.id, do: like, else: socket.assigns.current_like
      {:noreply, assign(socket, like_count: new_count, current_like: current)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:post_unliked, %{post_id: post_id, user_id: user_id}}, socket) do
    if post_id == socket.assigns.post.id do
      new_count = max(0, socket.assigns.like_count - 1)
      current = if socket.assigns.current_user && user_id == socket.assigns.current_user.id, do: nil, else: socket.assigns.current_like
      {:noreply, assign(socket, like_count: new_count, current_like: current)}
    else
      {:noreply, socket}
    end
  end
end
