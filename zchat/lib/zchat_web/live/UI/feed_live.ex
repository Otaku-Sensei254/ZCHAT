# lib/zchat_web/live/feed_live.ex
defmodule ZchatWeb.UI.FeedLive do
  use ZchatWeb, :live_view
  alias Zchat.Posts
  alias Zchat.Posts.Post

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Zchat.PubSub, "posts")
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
    {:noreply,
      socket
      |> assign(:category, params["category"])
      |> assign(page: 1, posts: [])
      |> load_posts()
    }
  end

  defp load_posts(socket) do
    %{page: page, per_page: per_page} = socket.assigns
    category = socket.assigns[:category]

    posts =
      Posts.list_posts(
        page: page,
        per_page: per_page,
        category: category,
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
  def handle_info(:load_more, socket) do
    {:noreply, load_posts(socket)}
  end

  @impl true
  # Handle new posts from PubSub
  def handle_info({:new_post, post}, socket) do
    post = Zchat.Repo.preload(post, [:user, :likes, comments: :user])
    {:noreply, stream_insert(socket, :posts, post, at: 0, dom_id: &"post-#{&1.id}")}
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
end
