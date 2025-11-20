# lib/zchat_web/live/feed_live.ex
defmodule ZchatWeb.UI.FeedLive do
  use ZchatWeb, :live_view
  alias Zchat.Posts
  alias Zchat.Posts.Post

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Zchat.PubSub, "posts")

      # Subscribe to notifications if user is authenticated
      if socket.assigns[:current_user] do
        Phoenix.PubSub.subscribe(Zchat.PubSub, "notifications:#{socket.assigns.current_user.id}")
      end
    end

    socket =
      socket
      |> stream_configure(:posts, [])
      |> stream_configure(:trending, [])
      |> assign(page: 1, per_page: 10, loading: false)
      |> load_initial_data()

    {:ok, socket}
  end

  defp load_initial_data(socket) do
    socket
    |> load_posts()
    |> load_trending()
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # Reset page and stream when filters change to avoid appending old results
    filters_changed = params["search"] != socket.assigns[:search_term] or params["category"] != socket.assigns[:category]

    socket =
      if filters_changed do
        socket
        |> assign(:page, 1)
        |> stream(:posts, [], reset: true)
        
      else
        socket
      end

    {:noreply,
      socket
      |> assign(:category, params["category"])
      |> assign(:search_term, params["search"])
      |> load_posts()
      |> load_trending()}
  end

@impl true
def handle_event("search", %{"search" => search_term}, socket) do
  term = String.trim(search_term || "")
  # Only include the search param; no category in URL for search bar
  to = if term == "" do
    ~p"/feed"
  else
    ~p"/feed?#{[search: term]}"
  end
  {:noreply, push_patch(socket, to: to)}
end

  defp load_posts(socket) do
    %{page: page, per_page: per_page} = socket.assigns
    category = socket.assigns[:category]
    search_term = socket.assigns[:search_term]

    posts =
      Posts.list_posts(
        page: page,
        per_page: per_page,
        category: category,
        search: search_term,
        preload: [:user, :likes, comments: :user]
      )
    |> Enum.map(&Post.ensure_media_files/1)

    socket =
      if page == 1 do
        stream(socket, :posts, posts, reset: true, dom_id: &"post-#{&1.id}")
      else
        Enum.reduce(posts, socket, fn post, socket ->
          stream_insert(socket, :posts, post, at: -1, dom_id: &"post-#{&1.id}")
        end)
      end

    assign(socket,
      page: page + 1,
      loading: false,
      has_more: length(posts) == per_page
    )
  end

  defp load_trending(socket) do
    trending = Zchat.Posts.list_trending_posts(5)
    stream(socket, :trending, trending, reset: true)
  end

  @impl true
  def handle_event("load-more", _, socket) do
    if !socket.assigns.loading && socket.assigns.has_more do
      send(self(), :load_more)
      {:noreply, assign(socket, loading: true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_like", %{"post-id" => post_id}, socket) do
    if socket.assigns.current_user do
      case Zchat.Posts.toggle_like(socket.assigns.current_user.id, "Post", String.to_integer(post_id)) do
        {:ok, _} ->
          {:noreply, socket}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to toggle like")}
      end
    else
      {:noreply, put_flash(socket, :error, "You must be logged in to like posts")}
    end
  end

  def handle_event("toggle_like", _params, socket) do
    # Handle case where post-id is not provided
    {:noreply, put_flash(socket, :error, "Invalid request")}
  end

  @impl true
  def handle_event("mark_all_as_read", _params, socket) do
    if socket.assigns.current_user do
      Zchat.Notifications.mark_all_as_read(socket.assigns.current_user.id)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:load_more, socket) do
    {:noreply, load_posts(socket)}
  end

  @impl true
  # Handle new posts from PubSub
  def handle_info({:new_post, post}, socket) do
    post = Zchat.Repo.preload(post, [:user, :likes, comments: :user])
    {:noreply, stream_insert(socket, :posts, post, at: 0, dom_id: &"post-#{&1.id}")}
  end

  @impl true
  # Handle new notifications from PubSub
  def handle_info({:new_notification, notification}, socket) do
    # Send a push event to update the notifications modal
    {:noreply, push_event(socket, "new_notification", %{notification: notification})}
  end

  @impl true
  # Handle notifications read broadcast
  def handle_info(:notifications_read, socket) do
    # Refresh the notifications modal to show updated read status
    {:noreply, push_event(socket, "refresh_notifications", %{})}
  end

  # Handle like updates for posts in the feed
  def handle_info({:post_liked, like}, socket) do
    # Update the post in the stream if it exists
    if like.likeable_id do
      # Try to find the post in the stream
      case Zchat.Posts.get_post(like.likeable_id) do
        nil ->
          {:noreply, socket}
        post ->
          # Preload necessary associations
          post = Zchat.Repo.preload(post, [:user, :likes, comments: :user])
          # Update the likes count
          updated_post = %{post | likes_count: post.likes_count + 1}
          {:noreply, stream_insert(socket, :posts, updated_post, at: -1, dom_id: &"post-#{&1.id}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info({:post_unliked, %{post_id: post_id, user_id: user_id}}, socket) do
    # Update the post in the stream if it exists
    case Zchat.Posts.get_post(post_id) do
      nil ->
        {:noreply, socket}
      post ->
        # Preload necessary associations
        post = Zchat.Repo.preload(post, [:user, :likes, comments: :user])
        # Update the likes count
        updated_post = %{post | likes_count: post.likes_count - 1}
        {:noreply, stream_insert(socket, :posts, updated_post, at: -1)}
    end
  end


  #post deleting
  @impl true
  def handle_info({:post_deleted, post}, socket) do
    # Remove the post from the stream
    {:noreply, stream_delete(socket, :posts, post)}
  end
end
