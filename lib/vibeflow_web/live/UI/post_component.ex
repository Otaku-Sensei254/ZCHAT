defmodule VibeflowWeb.UI.PostComponent do
  use VibeflowWeb, :live_component
  alias Vibeflow.Posts
  alias Vibeflow.Posts.{Like, Comment}
  alias Vibeflow.Repo
  alias Vibeflow.Powers
  import Ecto.Query

  import Canada

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    # 1. Check if the current user has liked this post (from preloaded data)
    current_like =
      if assigns[:current_user] && assigns.post.likes do
        Enum.find(assigns.post.likes, fn like ->
          like.user_id == assigns.current_user.id && like.likeable_type == "Post"
        end)
      else
        nil
      end

    # 2. Get Counts from preloaded data
    like_count = assigns.post.likes_count || length(assigns.post.likes || [])
    comment_count = assigns.post.comments_count || length(assigns.post.comments || [])

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:current_like, current_like)
     |> assign(:like_count, like_count)
     |> assign(:comment_count, comment_count)
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

    if user && (user |> can?(:delete, post)) do
      case Posts.delete_post(post) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Post deleted successfully")
           |> push_navigate(to: ~p"/feed")}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not delete post")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized")}
    end
  end

  # --- LIKE EVENTS ---

  # FIX: One single event for liking. No local updates. No sending messages to parent.

 @impl true
  def handle_event("toggle_like", _, socket) do
    user = socket.assigns.current_user
    post = socket.assigns.post

    if user do
      # 1. CALCULATE NEW STATE (Optimistic UI)
      # Check if currently liked (truthy check works for struct or true)
      is_currently_liked = !!socket.assigns.current_like

      # Flip the status
      new_status = !is_currently_liked

      # Calculate the new number
      new_count =
        if new_status do
          socket.assigns.like_count + 1
        else
          max(0, socket.assigns.like_count - 1)
        end

      # We don't wait for the result to update the UI. We assume it works.
      Vibeflow.Posts.toggle_like(user.id, "Post", post.id)

      # 3. UPDATE UI IMMEDIATELY
      {:noreply,
       socket
       |> assign(:current_like, new_status) # Sets to true/false
       |> assign(:like_count, new_count)}   # Updates number
    else
      {:noreply,
       socket
       |> put_flash(:error, "Log in to like")
       |> push_navigate(to: ~p"/users/log_in")}
    end
  end
#handles the share function
  @impl true
  def handle_event("request_share", _, socket) do
    # We send a message to the process (FeedLive) identified by self()
    # The message is a tuple: {:open_share_modal, post_uuid}
    send(self(), {:open_share_modal, socket.assigns.post.uuid})
    {:noreply, socket}
  end
# --- AUTHORIZATION HELPERS ---

  # 1. Main entry point
  # defp can_manage?(%Vibeflow.Accounts.User{} = user, %Vibeflow.Posts.Post{} = post) do
  #   is_owner?(user, post) or is_admin?(user)
  # end

  # # Fallback for guests (nil user)
  # defp can_manage?(nil, _), do: false

  # # 2. Check if user owns the post
  # defp is_owner?(user, post) do
  #   user.id == post.user_id
  # end

  # # 3. Check if user has admin role (Safely handles missing preloads)
  # defp is_admin?(%Vibeflow.Accounts.User{roles: roles}) when is_list(roles) do
  #   Enum.any?(roles, fn r -> r.name == "admin" end)
  # end

  # # If roles are #Ecto.Association.NotLoaded<...>, this clause catches it and returns false
  # defp is_admin?(_), do: false

  # --- REAL-TIME UPDATES ---
  # These handle updates broadcasted by other users

  # def handle_info({:post_liked, like}, socket) do
  #   # If someone else liked this post, increment count
  #   if like.likeable_id == socket.assigns.post.id and like.user_id != socket.assigns.current_user.id do
  #     {:noreply, assign(socket, :like_count, socket.assigns.like_count + 1)}
  #   else
  #     {:noreply, socket}
  #   end
  # end

  # def handle_info({:post_unliked, %{post_id: post_id, user_id: user_id}}, socket) do
  #   # If someone else unliked this post, decrement count
  #   if post_id == socket.assigns.post.id and user_id != socket.assigns.current_user.id do
  #     {:noreply, assign(socket, :like_count, max(0, socket.assigns.like_count - 1))}
  #   else
  #     {:noreply, socket}
  #   end
  # end

  # def handle_info({:new_comment, comment}, socket) do
  #   # If someone commented, increment count
  #   if comment.post_id == socket.assigns.post.id do
  #     {:noreply, assign(socket, :comment_count, socket.assigns.comment_count + 1)}
  #   else
  #     {:noreply, socket}
  #   end
  # end

  #--------cut off some blog post content to view --------
  defp content_cut(content, length \\ 250) do
    if String.length(content) > length do
      String.slice(content, 0, length) <> "..."
    else
      content
    end
  end
end
