defmodule ZchatWeb.UI.PostComponent do
  use ZchatWeb, :live_component
  alias Zchat.Posts
  alias Zchat.Posts.{Like, Comment}
  alias Zchat.Repo
  import Ecto.Query

  @default_avatar "/images/default-avatar.png"

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    # Determine if the current user liked this post
    current_like =
      if assigns[:current_user] do
        Repo.one(
          from l in Like,
          where: l.user_id == ^assigns.current_user.id
          and l.likeable_type == "Post"
          and l.likeable_id == ^assigns.post.id
        )
      else
        nil
      end

    # Get counts (Handle nil cases safely)
    like_count = assigns.post.likes_count || 0

    # We fetch comment count manually or use preloaded assoc if available
    comment_count =
      Repo.aggregate(
        from(c in Comment, where: c.post_id == ^assigns.post.id),
        :count
      ) || 0

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:current_like, current_like)
     |> assign(:like_count, like_count)
     |> assign(:comment_count, comment_count)}
  end

  # --- HANDLE EVENTS ---

  @impl true
  def handle_event("toggle_like", _, socket) do
    user = socket.assigns.current_user
    post = socket.assigns.post

    if user do
      # Optimistic UI update: Update the UI immediately before the DB result comes back
      # (Optional, but makes it feel faster. For now, we wait for the result to be safe).

      case Posts.toggle_like(user.id, "Post", post.id) do
        {:ok, %Like{} = like} ->
          # User Liked
          {:noreply,
           socket
           |> assign(:current_like, like)
           |> assign(:like_count, socket.assigns.like_count + 1)}

        {:ok, nil} ->
          # User Unliked
          {:noreply,
           socket
           |> assign(:current_like, nil)
           |> assign(:like_count, max(0, socket.assigns.like_count - 1))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Something went wrong")}
      end
    else
      {:noreply, put_flash(socket, :error, "You must be logged in to like posts")}
    end
  end

  # --- REAL-TIME UPDATES ---

  # If someone else likes this post, update the number
  @impl true
  def handle_info({:post_liked, like}, socket) do
    # Only update if it wasn't the current user (prevent double count)
    # and the like belongs to this post
    if like.likeable_id == socket.assigns.post.id and like.user_id != socket.assigns.current_user.id do
      {:noreply, assign(socket, :like_count, socket.assigns.like_count + 1)}
    else
      {:noreply, socket}
    end
  end

  # If someone else unlikes this post
  @impl true
  def handle_info({:post_unliked, %{post_id: post_id, user_id: user_id}}, socket) do
    if post_id == socket.assigns.post.id and user_id != socket.assigns.current_user.id do
      {:noreply, assign(socket, :like_count, max(0, socket.assigns.like_count - 1))}
    else
      {:noreply, socket}
    end
  end

  # If someone comments, update the number (even though we don't show the comment itself)
  @impl true
  def handle_info({:new_comment, comment}, socket) do
    if comment.post_id == socket.assigns.post.id do
      {:noreply, assign(socket, :comment_count, socket.assigns.comment_count + 1)}
    else
      {:noreply, socket}
    end
  end

  # Catch-all
  def handle_info(_, socket), do: {:noreply, socket}
end
