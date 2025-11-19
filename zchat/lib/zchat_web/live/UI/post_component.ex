defmodule ZchatWeb.UI.PostComponent do
  use ZchatWeb, :live_component
  alias Zchat.Posts
  alias Zchat.Posts.{Like, Comment}
  alias Zchat.Repo
  import Ecto.Query

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    # 1. Check if the current user has liked this post
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

    # 2. Get Counts
    like_count = assigns.post.likes_count || 0
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
     |> assign(:comment_count, comment_count)
     # 3. Initialize Media Slider Index (Start at the first image: 0)
     |> assign(:current_media_index, 0)}
  end

  # --- MEDIA SLIDER EVENTS ---

  @impl true
  def handle_event("next_media", _, socket) do
    total_media = length(socket.assigns.post.media_files)
    current = socket.assigns.current_media_index

    # Calculate next index, looping back to 0 if at the end
    new_index = rem(current + 1, total_media)

    {:noreply, assign(socket, :current_media_index, new_index)}
  end

  @impl true
  def handle_event("prev_media", _, socket) do
    total_media = length(socket.assigns.post.media_files)
    current = socket.assigns.current_media_index

    # Calculate prev index, looping to the last item if at 0
    new_index = if current - 1 < 0, do: total_media - 1, else: current - 1

    {:noreply, assign(socket, :current_media_index, new_index)}
  end

  @impl true
  def handle_event("go_to_media", %{"index" => index}, socket) do
    {:noreply, assign(socket, :current_media_index, String.to_integer(index))}
  end

  # --- DELETE EVENT ---
  @impl true
  def handle_event("delete_post", _, socket) do
    post = socket.assigns.post
    user = socket.assigns.current_user

    if can_manage?(user, post) do
      case Posts.delete_post(post) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Post deleted successfully")
           |> push_navigate(to: ~p"/feed")} # Refresh or redirect
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not delete post")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  # --- LIKE EVENTS ---

  @impl true
  def handle_event("toggle_like", _, socket) do
    user = socket.assigns.current_user
    post = socket.assigns.post

    if user do
      case Posts.toggle_like(user.id, "Post", post.id) do
        {:ok, %Like{} = like} ->
          # Successfully Liked
          {:noreply,
           socket
           |> assign(:current_like, like)
           |> assign(:like_count, socket.assigns.like_count + 1)}

        {:ok, nil} ->
          # Successfully Unliked
          {:noreply,
           socket
           |> assign(:current_like, nil)
           |> assign(:like_count, max(0, socket.assigns.like_count - 1))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Error toggling like")}
      end
    else
      {:noreply, put_flash(socket, :error, "You must be logged in to like posts")}
    end
  end

  # --- AUTHORIZATION HELPER ---
  # Returns true if user is the owner OR an admin
  defp can_manage?(%Zchat.Accounts.User{} = user, %Zchat.Posts.Post{} = post) do
    user.id == post.user_id or user.role == "admin"
  end

  # Handle nil user (not logged in)
  defp can_manage?(_, _), do: false


  # --- REAL-TIME UPDATES ---
  # These handle updates broadcasted by other users

  @impl true
  def handle_info({:post_liked, like}, socket) do
    # If someone else liked this post, increment count
    if like.likeable_id == socket.assigns.post.id and like.user_id != socket.assigns.current_user.id do
      {:noreply, assign(socket, :like_count, socket.assigns.like_count + 1)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:post_unliked, %{post_id: post_id, user_id: user_id}}, socket) do
    # If someone else unliked this post, decrement count
    if post_id == socket.assigns.post.id and user_id != socket.assigns.current_user.id do
      {:noreply, assign(socket, :like_count, max(0, socket.assigns.like_count - 1))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:new_comment, comment}, socket) do
    # If someone commented, increment count
    if comment.post_id == socket.assigns.post.id do
      {:noreply, assign(socket, :comment_count, socket.assigns.comment_count + 1)}
    else
      {:noreply, socket}
    end
  end

  # Ignore other messages
  def handle_info(_, socket), do: {:noreply, socket}

  #--------cut off some blog post content to view --------
  defp content_cut(content, length \\ 250) do
    if String.length(content) > length do
      String.slice(content, 0, length) <> "..."
    else
      content
    end
  end
end
