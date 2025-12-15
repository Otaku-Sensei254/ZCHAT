defmodule ZchatWeb.UI.FeedLive do
  use ZchatWeb, :live_view
  alias Zchat.Posts
  alias Zchat.Posts.Post
  alias Zchat.Notifications
  alias Zchat.Socials
  alias Zchat.Accounts

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
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
        has_more: true,
        search_term: nil,
        category: nil,
        search_results: [],
        show_search: false,
        data_loaded: false,
        pending_posts: [],
        # --- SHARE MODAL STATE ---
        show_share_modal: false,
        post_to_share: nil,
        friends_list: []
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
        |> stream(:posts, [], reset: true)
        |> load_posts()
        |> load_trending()
      else
        socket
      end

    {:noreply, socket}
  end

  # --- SHARE HANDLERS ---

  @impl true
  def handle_info({:open_share_modal, post_id}, socket) do
    # 1. Fetch the user's friends list (needed for the share modal)
    # Using Accounts.list_friends as established in your Accounts context
    friends = Zchat.Accounts.list_friends(socket.assigns.current_user)

    # 2. Update the socket to show the modal and store the post ID
    {:noreply,
     socket
     |> assign(:show_share_modal, true)
     |> assign(:post_to_share, post_id)
     |> assign(:friends_list, friends)}
  end

  @impl true
  def handle_event("close_share_modal", _, socket) do
    {:noreply, assign(socket, :show_share_modal, false)}
  end

  @impl true
  def handle_event("confirm_share", %{"recipient_id" => recipient_id}, socket) do
    current_user_id = socket.assigns.current_user.id
    post_id = socket.assigns.post_to_share
    recipient_int_id = String.to_integer(recipient_id)

    # Call the chat context to send the link
    # Make sure Zchat.Chat.share_posts_to_friend/3 exists in your Chat context
    # If your function is named share_post_to_friend (singular), change it here.
    case Zchat.Chat.share_posts_to_friend(current_user_id, recipient_int_id, post_id) do
      {:ok, _msg} ->
        {:noreply,
         socket
         |> put_flash(:info, "Sent to chat!")
         |> assign(:show_share_modal, false)} # Close modal on success
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not send.")}
    end
  end

  # --- INFINITE SCROLL EVENT ---

  @impl true
  def handle_event("load-more", _, socket) do
    if !socket.assigns.loading and socket.assigns.has_more do
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

  @impl true
  def handle_info({:post_created, post}, socket) do
    post = Zchat.Repo.preload(post, [:user, :likes, comments: :user])
    {:noreply, assign(socket, :pending_posts, [post | socket.assigns.pending_posts])}
  end

  @impl true
  def handle_event("load_new_posts", _params, socket) do
    pending = socket.assigns.pending_posts
    socket =
      Enum.reduce(pending, socket, fn post, acc ->
        stream_insert(acc, :posts, post, at: 0)
      end)
    {:noreply, assign(socket, :pending_posts, [])}
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
  def handle_info({:new_notification,_notif} , socket) do
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
    {:noreply, socket}
  end

  @impl true
  def handle_info(:update_notifications, socket) do
    send_update(ZchatWeb.Components.NotificationsModal, id: "notifications-modal-desktop")
    {:noreply, socket}
  end

  @impl true
  def handle_info({:update_sidebar, _message}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_sidebar_message, _}, socket), do: {:noreply, socket}

  # --- CORE HELPERS ---

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

    has_more = length(posts) == per_page

    socket
    |> assign(loading: false, has_more: has_more, page: page + 1)
    |> update_stream_based_on_page(page, posts)
  end

  defp update_stream_based_on_page(socket, 1, posts) do
    stream(socket, :posts, posts, reset: true)
  end

  defp update_stream_based_on_page(socket, _page, posts) do
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
