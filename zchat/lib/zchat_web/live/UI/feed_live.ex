defmodule ZchatWeb.UI.FeedLive do
  use ZchatWeb, :live_view
  alias Zchat.Posts
  alias Zchat.Posts.Post
  alias Zchat.Notifications

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Listen for global posts (for the "New Posts" pill or auto-insert)
      Phoenix.PubSub.subscribe(Zchat.PubSub, "feed:global")

      if socket.assigns[:current_user] do
        Phoenix.PubSub.subscribe(Zchat.PubSub, "notifications:#{socket.assigns.current_user.id}")
      end
    end

    socket =
      socket
      |> stream_configure(:posts, dom_id: &"post-#{&1.id}")
      |> stream_configure(:trending, dom_id: &"trending-#{&1.id}")
      |> assign(
        page: 1,
        per_page: 10,
        loading: false,
        has_more: true, # Controls if the infinite scroll hook fires
        search_term: nil,
        category: nil,
        search_results: [],
        show_search: false,
        data_loaded: false,
        pending_posts: [] # For the "Show New Posts" pill logic
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    new_search = params["search"]
    new_category = params["category"]

    filters_changed =
      new_search != socket.assigns.search_term or
      new_category != socket.assigns.category

    socket =
      socket
      |> assign(:search_term, new_search)
      |> assign(:category, new_category)

    socket =
      if filters_changed or !socket.assigns.data_loaded do
        socket
        |> assign(:page, 1) # Reset to page 1
        |> assign(:data_loaded, true)
        |> stream(:posts, [], reset: true) # Clear old data from UI immediately
        |> load_posts() # Load fresh data
        |> load_trending()
      else
        socket
      end

    {:noreply, socket}
  end

  # --- INFINITE SCROLL EVENT ---

  @impl true
  def handle_event("load-more", _, socket) do
    # Only load if not currently loading AND we know there is more data
    if !socket.assigns.loading and socket.assigns.has_more do
      # Set loading: true immediately to prevent double-firing
      send(self(), :load_more_data)
      {:noreply, assign(socket, loading: true)}
    else
      {:noreply, socket}
    end
  end

  # --- ASYNC LOADING HANDLER ---

  @impl true
  def handle_info(:load_more_data, socket) do
    {:noreply, load_posts(socket)}
  end

  # --- SEARCH EVENTS ---

  @impl true
  def handle_event("live_search", %{"search" => query}, socket) do
    results = Zchat.Search.global_search(query)
    show_search = length(results) > 0
    {:noreply, assign(socket, search_results: results, show_search: show_search)}
  end

  # Fallback for search input name mismatch
  @impl true
  def handle_event("live_search", %{"value" => query}, socket) do
    results = Zchat.Search.global_search(query)
    show_search = length(results) > 0
    {:noreply, assign(socket, search_results: results, show_search: show_search)}
  end

  @impl true
  def handle_event("live_search", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("close_search", _, socket) do
    {:noreply, assign(socket, show_search: false, search_results: [])}
  end

  @impl true
  def handle_event("search", %{"search" => search_term}, socket) do
    term = String.trim(search_term || "")
    to = if term == "", do: ~p"/feed", else: ~p"/feed?#{[search: term]}"
    {:noreply, push_patch(socket, to: to)}
  end

  # --- REAL-TIME UPDATES (PubSub) ---

  # 1. New Post Created by someone else
  @impl true
  def handle_info({:post_created, post}, socket) do
    post = Zchat.Repo.preload(post, [:user, :likes, comments: :user])
    {:noreply, assign(socket, :pending_posts, [post | socket.assigns.pending_posts])}
  end

  # Event to flush pending posts (The Pill Click)
  @impl true
  def handle_event("load_new_posts", _params, socket) do
    pending = socket.assigns.pending_posts
    socket =
      Enum.reduce(pending, socket, fn post, acc ->
        stream_insert(acc, :posts, post, at: 0)
      end)
    {:noreply, assign(socket, :pending_posts, [])}
  end

  # 2. Interactions
  @impl true
  def handle_info({:post_deleted, post}, socket) do
    {:noreply, stream_delete(socket, :posts, post)}
  end

  @impl true
  def handle_info({:post_liked, like}, socket) do
    if like.likeable_id do
      post = Posts.get_post!(like.likeable_id, preload: [:user, :likes, comments: :user])
      {:noreply, stream_insert(socket, :posts, post)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:post_unliked, %{post_id: post_id}}, socket) do
    post = Posts.get_post!(post_id, preload: [:user, :likes, comments: :user])
    {:noreply, stream_insert(socket, :posts, post)}
  end

  @impl true
  def handle_info(:new_notification, socket) do
    send_update(ZchatWeb.Components.NotificationsModal, id: "notifications-modal-desktop")
    send_update(ZchatWeb.Components.NotificationsModal, id: "notifications-modal-mobile")
    {:noreply, socket}
  end

  @impl true
  def handle_info(:notifications_read, socket) do
    send_update(ZchatWeb.Components.NotificationsModal, id: "notifications-modal-desktop")
    send_update(ZchatWeb.Components.NotificationsModal, id: "notifications-modal-mobile")
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{topic: "users:online", event: "presence_diff"}, socket) do
    # We don't display online status on the feed, so just ignore it.
    {:noreply, socket}
  end

  @impl true
  def handle_info(:update_notifications, socket) do
    # Example: Send update to the Nav component or refresh assigns
    send_update(ZchatWeb.Components.NotificationsModal, id: "notifications-modal-desktop")
    {:noreply, socket}
  end

  def handle_info(:update_sidebar, socket) do
    {:noreply, socket}
  end
  # --- CORE HELPERS ---

  defp load_posts(socket) do
    %{page: page, per_page: per_page} = socket.assigns

    # Fetch Data
    # NOTE: If you implemented list_fresh_random_posts, call that here.
    # Otherwise, this calls your standard list_posts
    posts =
      Posts.list_posts(
        page: page,
        per_page: per_page,
        category: socket.assigns[:category],
        search: socket.assigns[:search_term],
        preload: [:user, :likes, comments: :user]
      )
      |> Enum.map(&Post.ensure_media_files/1)

    # Determine if we hit the end
    has_more = length(posts) == per_page

    socket
    |> assign(loading: false, has_more: has_more, page: page + 1)
    |> update_stream_based_on_page(page, posts)
  end

  defp update_stream_based_on_page(socket, 1, posts) do
    # If Page 1, RESET everything (New random batch or filter change)
    stream(socket, :posts, posts, reset: true)
  end

  defp update_stream_based_on_page(socket, _page, posts) do
    # If Page 2+, APPEND to bottom (-1)
    stream_insert_many(socket, posts)
  end

  defp stream_insert_many(socket, posts) do
    Enum.reduce(posts, socket, fn post, sock ->
      stream_insert(sock, :posts, post, at: -1)
    end)
  end

  defp load_trending(socket) do
    trending = Posts.list_trending_posts(5)
    stream(socket, :trending, trending, reset: true)
  end
end
