defmodule VibeflowWeb.UI.FeedLive do
  use VibeflowWeb, :live_view
  alias Vibeflow.Posts
  alias Vibeflow.Posts.Post
  alias Vibeflow.Notifications
  alias Vibeflow.Socials
  alias Vibeflow.Accounts
  alias Vibeflow.Waves

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Vibeflow.PubSub, "feed:global")

      if socket.assigns[:current_user] do
        Phoenix.PubSub.subscribe(Vibeflow.PubSub, "notifications:#{socket.assigns.current_user.id}")
      end
    end

    socket =
      socket
      |> stream_configure(:posts, dom_id: &"post-#{&1.id}")
      |> stream_configure(:trending, dom_id: &"trending-#{&1.id}")
      |> assign(:show_waves_modal, false)
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
        waves: [],
        # --- SHARE MODAL STATE ---
        show_share_modal: false,
        post_to_share: nil,
        friends_list: [],
        selected_friends: [],
        friends_filter: "",
        friends_list_filtered: nil
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
        |> load_waves()
      else
        socket
      end

    {:noreply, socket}
  end

  # --- EVENT HANDLERS ---

  @impl true
  def handle_event("filter_friends", %{"friend_search" => query}, socket) do
    q = String.trim(query || "")

    filtered =
      (socket.assigns.friends_list || [])
      |> Enum.filter(fn f ->
        username = to_string(f.username || "") |> String.downcase()
        email = to_string(f.email || "") |> String.downcase()

        String.contains?(username, String.downcase(q)) or
          String.contains?(email, String.downcase(q))
      end)

    {:noreply, assign(socket, friends_list_filtered: filtered, friends_filter: q)}
  end

  @impl true
  def handle_event("close_share_modal", _, socket) do
    {:noreply, assign(socket, :show_share_modal, false)}
  end

  @impl true
  def handle_event("confirm_share", %{"recipient_ids" => recipient_ids}, socket)
      when is_list(recipient_ids) do
    current_user_id = socket.assigns.current_user.id
    post_id = socket.assigns.post_to_share

    {oks, errs} =
      recipient_ids
      |> Enum.map(&String.to_integer/1)
      |> Enum.reduce({[], []}, fn recipient_int_id, {oks, errs} ->
        case Vibeflow.Chat.share_posts_to_friend(current_user_id, recipient_int_id, post_id) do
          {:ok, _} -> {[recipient_int_id | oks], errs}
          {:error, _} -> {oks, [recipient_int_id | errs]}
        end
      end)

    msg =
      if length(errs) == 0,
        do: "Sent to chat!",
        else: "Sent to #{length(oks)} users, #{length(errs)} failed."

    {:noreply,
     socket
     |> put_flash(:info, msg)
     |> assign(:show_share_modal, false)
     |> assign(:selected_friends, [])}
  end

  def handle_event("confirm_share", %{"recipient_id" => recipient_id}, socket) do
    handle_event("confirm_share", %{"recipient_ids" => [recipient_id]}, socket)
  end

  def handle_event("update_selected_friends", params, socket) do
    ids = params["recipient_ids"] || []
    ids = if is_list(ids), do: Enum.map(ids, &String.to_integer/1), else: [String.to_integer(ids)]
    {:noreply, assign(socket, :selected_friends, ids)}
  end

  def handle_event("select_all_friends", _params, socket) do
    ids = Enum.map(socket.assigns.friends_list || [], & &1.id)
    {:noreply, assign(socket, :selected_friends, ids)}
  end

  def handle_event("toggle_friend", %{"id" => id}, socket) do
    id_int = String.to_integer(id)
    current = socket.assigns.selected_friends || []

    new =
      if Enum.member?(current, id_int), do: List.delete(current, id_int), else: [id_int | current]

    {:noreply, assign(socket, :selected_friends, new)}
  end

  def handle_event("confirm_share", _params, socket) do
    recipient_ids = socket.assigns.selected_friends || []

    if recipient_ids == [] do
      {:noreply, socket}
    else
      current_user_id = socket.assigns.current_user.id
      post_id = socket.assigns.post_to_share

      {oks, errs} =
        Enum.reduce(recipient_ids, {[], []}, fn recipient_int_id, {oks, errs} ->
          case Vibeflow.Chat.share_posts_to_friend(current_user_id, recipient_int_id, post_id) do
            {:ok, _} -> {[recipient_int_id | oks], errs}
            {:error, _} -> {oks, [recipient_int_id | errs]}
          end
        end)

      msg =
        if length(errs) == 0,
          do: "Sent to chat!",
          else: "Sent to #{length(oks)} users, #{length(errs)} failed."

      {:noreply,
       socket
       |> put_flash(:info, msg)
       |> assign(:show_share_modal, false)
       |> assign(:selected_friends, [])}
    end
  end

  def handle_event("open_create_waves", _params, socket) do
    {:noreply, assign(socket, show_waves_modal: true)}
  end

  def handle_event("close_waves_modal", _params, socket) do
    {:noreply, assign(socket, show_waves_modal: false)}
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
  def handle_event("live_search", %{"search" => query}, socket) do
    results = Vibeflow.Search.global_search(query)
    show_search = length(results) > 0
    {:noreply, assign(socket, search_results: results, show_search: show_search)}
  end

  @impl true
  def handle_event("live_search", %{"value" => query}, socket) do
    results = Vibeflow.Search.global_search(query)
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
  def handle_event("load_new_posts", _params, socket) do
    pending = socket.assigns.pending_posts

    socket =
      Enum.reduce(pending, socket, fn post, acc ->
        stream_insert(acc, :posts, post, at: 0)
      end)

    {:noreply, assign(socket, :pending_posts, [])}
  end

  # --- INFO HANDLERS ---

  @impl true
  def handle_info({:open_share_modal, post_id}, socket) do
    # 1. Fetch the user's friends list (needed for the share modal)
    friends = Vibeflow.Accounts.list_friends(socket.assigns.current_user)
    # 2. Update the socket to show the modal and store the post ID
    {:noreply,
     socket
     |> assign(:show_share_modal, true)
     |> assign(:post_to_share, post_id)
     |> assign(:friends_list, friends)
     |> assign(:selected_friends, [])
     |> assign(:friends_list_filtered, friends)
     |> assign(:friends_filter, "")}
  end

  def handle_info(:waves_created, socket) do
    {:noreply,
     socket
     |> assign(show_waves_modal: false)
     |> put_flash(:info, "Wave shared successfully!")}
  end

  @impl true
  def handle_info(:load_more_data, socket) do
    {:noreply, load_posts(socket)}
  end

  @impl true
  def handle_info({:post_created, post}, socket) do
    post = Vibeflow.Repo.preload(post, [:user, :likes, comments: :user])
    {:noreply, assign(socket, :pending_posts, [post | socket.assigns.pending_posts])}
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
  def handle_info({:new_notification, _notif}, socket) do
    send_update(VibeflowWeb.Components.NotificationsModal, id: "notifications-modal-desktop")
    send_update(VibeflowWeb.Components.NotificationsModal, id: "notifications-modal-mobile")
    {:noreply, socket}
  end

  @impl true
  def handle_info(:notifications_read, socket) do
    send_update(VibeflowWeb.Components.NotificationsModal, id: "notifications-modal-desktop")
    send_update(VibeflowWeb.Components.NotificationsModal, id: "notifications-modal-mobile")
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{topic: "users:online", event: "presence_diff"}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(:update_notifications, socket) do
    send_update(VibeflowWeb.Components.NotificationsModal, id: "notifications-modal-desktop")
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

  defp load_waves(socket) do
    if socket.assigns.current_user do
      waves = Waves.list_active_waves(socket.assigns.current_user.id)
      assign(socket, :waves, waves)
    else
      socket
    end
  end
end
