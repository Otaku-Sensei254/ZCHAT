defmodule ZchatWeb.UI.FeedLive do
  use ZchatWeb, :live_view
  alias Zchat.Posts
  alias Zchat.Posts.Post
  alias Zchat.Accounts
  alias Zchat.Notifications

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Zchat.PubSub, "posts")
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
        has_more: true,
        search_term: nil,
        category: nil,
        search_results: [],
        show_search: false,
        data_loaded: false
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
        |> assign(:page, 1)
        |> assign(:data_loaded, true)
        |> stream(:posts, [], reset: true) # 1. Clear OLD data
        |> load_posts()                    # 2. Load NEW data
        # FIXED: Removed the extra stream reset here that was deleting your posts!
        |> load_trending()
      else
        socket
      end

    {:noreply, socket}
  end

  # --- EVENTS ---

  # FIXED: Matches "search" because your HTML input has name="search"
  @impl true
  def handle_event("live_search", %{"search" => query}, socket) do
    # Use the Search helper directly
    results = Zchat.Search.global_search(query)
    show_search = length(results) > 0
    {:noreply, assign(socket, search_results: results, show_search: show_search)}
  end

  # Fallback for "value" (just in case)
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

  @impl true
  def handle_event("load-more", _, socket) do
    if !socket.assigns.loading and socket.assigns.has_more do
      send(self(), :load_more_data)
      {:noreply, assign(socket, loading: true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("mark_all_as_read", _, socket) do
    if socket.assigns.current_user do
      Notifications.mark_all_read(socket.assigns.current_user.id)
    end
    {:noreply, socket}
  end

  # --- HELPERS ---

  defp load_posts(socket) do
    %{page: page, per_page: per_page} = socket.assigns

    posts =
      Posts.list_posts(
        page: page,
        per_page: per_page,
        category: socket.assigns[:category],
        search: socket.assigns[:search_term],
        preload: [:user, :likes, comments: :user]
      )
      |> Enum.map(&Post.ensure_media_files/1)

    if page == 1 do
      assign(socket, has_more: length(posts) == per_page, page: page + 1, loading: false)
      |> stream(:posts, posts, reset: true)
    else
      assign(socket, has_more: length(posts) == per_page, page: page + 1, loading: false)
      |> stream_insert_many(posts)
    end
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

  # --- PUBSUB ---

  @impl true
  def handle_info(:load_more_data, socket), do: {:noreply, load_posts(socket)}

  @impl true
  def handle_info({:new_post, post}, socket) do
    post = Zchat.Repo.preload(post, [:user, :likes, comments: :user])
    {:noreply, stream_insert(socket, :posts, post, at: 0)}
  end

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
end
