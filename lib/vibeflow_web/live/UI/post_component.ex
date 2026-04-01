defmodule VibeflowWeb.UI.PostComponent do
  use VibeflowWeb, :live_component

  alias Vibeflow.Posts
  alias Vibeflow.Posts.{Like, Comment}
  alias Vibeflow.Powers
  alias Phoenix.PubSub
  import Ecto.Query
  import Canada

  # Use the app layout
  def layout(_assigns), do: {VibeflowWeb.Layouts, :app}

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :current_media_index, 0)}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)
    post = socket.assigns.post
    current_user = socket.assigns[:current_user]

    # Initialize mention modal state
    socket = assign(socket, [
      show_mention_modal: false,
      mention_search_results: [],
      mention_search_query: ""
    ])

    # Check if current user has liked this post
    current_like =
      if current_user && post.likes && Ecto.assoc_loaded?(post.likes) do
        Enum.find(post.likes, &(&1.user_id == current_user.id))
      else
        nil
      end

    # Check if current user has reposted this post
    current_repost =
      if current_user do
        Posts.get_repost_by_user_and_target(current_user.id, "Post", post.id)
      else
        nil
      end

    # Check if current user has saved this post
    current_save =
      if current_user do
        Posts.get_saved_post_by_user_and_post(current_user.id, post.id)
      else
        nil
      end

    {:ok,
     socket
     |> assign(:current_like, current_like)
     |> assign(:current_repost, current_repost)
     |> assign(:current_save, current_save)
     |> assign(:like_count, post.likes_count || 0)
     |> assign(:repost_count, post.reposts_count || 0)
     |> assign(:comment_count, post.comments_count || 0)
     |> assign_new(:current_media_index, fn -> 0 end)}
  end

  # --- MEDIA SLIDER EVENTS ---

  @impl true
  def handle_event("next_media", _, socket) do
    total_media = length(socket.assigns.post.media_files || [])
    current = socket.assigns.current_media_index

    # Calculate next index, looping back to 0 if at the end
    new_index = if total_media > 0, do: rem(current + 1, total_media), else: 0

    {:noreply, assign(socket, :current_media_index, new_index)}
  end

  @impl true
  def handle_event("prev_media", _, socket) do
    total_media = length(socket.assigns.post.media_files || [])
    current = socket.assigns.current_media_index

    # Calculate prev index, looping to the last item if at 0
    new_index =
      if total_media > 0 do
        if current - 1 < 0, do: total_media - 1, else: current - 1
      else
        0
      end

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
  @impl true
  def handle_event("toggle_like", _, socket) do
    user = socket.assigns.current_user
    post = socket.assigns.post

    if user do
      is_currently_liked = !!socket.assigns.current_like
      new_status = !is_currently_liked

      new_count =
        if new_status do
          socket.assigns.like_count + 1
        else
          max(0, socket.assigns.like_count - 1)
        end

      # DB call (broadcasts {:post_liked, like} or {:post_unliked, ...})
      Posts.toggle_like(user.id, "Post", post.id)

      {:noreply,
       socket
       |> assign(:current_like, new_status)
       |> assign(:like_count, new_count)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Log in to like")
       |> push_navigate(to: ~p"/users/log_in")}
    end
  end

  # --- REPOST FUNCTIONALITY ---
  @impl true
  def handle_event("repost_post", _, socket) do
    if socket.assigns.current_user do
      case Posts.toggle_repost(socket.assigns.current_user.id, socket.assigns.post.id) do
        {:ok, {:reposted, repost}} ->
          {:noreply,
           socket
           |> assign(:current_repost, repost)
           |> assign(:repost_count, socket.assigns.repost_count + 1)
           |> put_flash(:info, "You reposted this post!")}

        {:ok, {:unreposted, _post}} ->
          {:noreply,
           socket
           |> assign(:current_repost, nil)
           |> assign(:repost_count, max(0, socket.assigns.repost_count - 1))
           |> put_flash(:info, "Repost removed")}

        {:error, :post_not_found} ->
          {:noreply, put_flash(socket, :error, "Post not found")}
        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to repost post")}
      end
    else
      {:noreply,
           socket
           |> put_flash(:error, "Log in to repost")
           |> push_navigate(to: ~p"/users/log_in")}
    end
  end

  @impl true
  def handle_event("request_share", _, socket) do
    # We send a message to the process (FeedLive) identified by self()
    send(self(), {:open_share_modal, socket.assigns.post.id})
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_save", _, socket) do
    user = socket.assigns.current_user
    post = socket.assigns.post

    if user do
      Posts.toggle_save_post(user.id, post.id)

      {:noreply,
       socket
       |> assign(:current_save, !socket.assigns.current_save)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Log in to save posts")
       |> push_navigate(to: ~p"/users/log_in")}
    end
  end

  # --- MENTION MODAL EVENTS ---
  @impl true
  def handle_event("close_mention_modal", _, socket) do
    {:noreply, assign(socket, show_mention_modal: false, mention_search_results: [], mention_search_query: "")}
  end

  @impl true
  def handle_event("search_mentions", %{"query" => query}, socket) do
    if String.length(query) >= 2 do
      users = search_users_by_username(query)
      {:noreply, assign(socket, mention_search_results: users, mention_search_query: query)}
    else
      {:noreply, assign(socket, mention_search_results: [])}
    end
  end

  @impl true
  def handle_event("select_mention", %{"username" => username}, socket) do
    # This will be handled by JavaScript to insert the username
    {:noreply, assign(socket, show_mention_modal: false)}
  end

  @impl true
  def handle_event("stop_propagation", _, socket) do
    # Prevent modal from closing when clicking inside
    {:noreply, socket}
  end

  # --- HELPER FUNCTIONS ---
  defp content_cut(content, length \\ 250) do
    if String.length(content) > length do
      String.slice(content, 0, length) <> "..."
    else
      content
    end
  end

  defp search_users_by_username(query) do
    from(u in Vibeflow.Accounts.User,
      where: ilike(u.username, ^"#{query}%"),
      limit: 10,
      select: [:id, :username, :avatar_url, :bio]
    )
    |> Vibeflow.Repo.all()
  end
end
