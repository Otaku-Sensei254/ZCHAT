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
     |> stream(:comments, []) # Start with empty stream
     |> assign(:current_like, nil)
     |> assign(:like_count, 0)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    post = Posts.get_post!(id)
    comments = Posts.list_comments(post_id: post.id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Zchat.PubSub, "post:#{post.id}")
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
     # Reset stream with fetched comments
     |> stream(:comments, comments, reset: true)
     |> assign(:like_count, post.likes_count || 0)
     |> assign(:current_like, current_like)}
  end

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
        "parent_id" => socket.assigns.replying_to # Include parent_id if replying
      })

      case Posts.create_comment(attrs) do
        {:ok, _comment} ->
          {:noreply,
           socket
           |> assign(:comment_form, Posts.change_comment(%Comment{}))
           |> assign(:replying_to, nil)} # Reset reply state

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

  # NEW: Handle cancelling a reply
  @impl true
  def handle_event("cancel_reply", _, socket) do
    {:noreply, assign(socket, :replying_to, nil)}
  end

  # NEW: Placeholder for liking comments to prevent crashes
  @impl true
  def handle_event("like_comment", %{"comment_id" => _id}, socket) do
    # TODO: Implement comment liking logic here
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_like", _params, socket) do
    if socket.assigns.current_user do
      post_id = socket.assigns.post.id
      current_user = socket.assigns.current_user

      case Posts.toggle_like(current_user.id, "Post", post_id) do
        {:ok, %Like{} = like} ->
          {:noreply, assign(socket, current_like: like)}
        {:ok, nil} ->
          {:noreply, assign(socket, current_like: nil)}
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
