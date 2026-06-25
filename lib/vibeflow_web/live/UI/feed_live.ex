defmodule VibeflowWeb.UI.FeedLive do
  use VibeflowWeb, :live_view
  alias Vibeflow.Posts
  alias Vibeflow.Posts.Post
  alias Vibeflow.Waves

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Vibeflow.PubSub, "feed:global")
      Phoenix.PubSub.subscribe(Vibeflow.PubSub, "posts")

      if socket.assigns[:current_user] do
        Phoenix.PubSub.subscribe(
          Vibeflow.PubSub,
          "notifications:#{socket.assigns.current_user.id}"
        )
      end
    end

    socket =
      socket
      |> stream_configure(:posts, dom_id: &"post-#{&1.uuid}")
      |> stream_configure(:trending, dom_id: &"trending-#{&1.uuid}")
      |> assign(:show_waves_modal, false)
      |> assign(
        page: 1,
        per_page: 20,
        loading: false,
        has_more: true,
        search_term: nil,
        category: nil,
        highlight_post_uuid: nil,
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
    highlight_post_uuid = params["highlight_post"]

    filters_changed =
      new_search != socket.assigns.search_term or
        new_category != socket.assigns.category

    socket =
      socket
      |> assign(:search_term, new_search)
      |> assign(:category, new_category)
      |> assign(:highlight_post_uuid, highlight_post_uuid)

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

    if highlight_post_uuid do
      Process.send_after(self(), :clear_highlight_post_url, 0)
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
  def handle_event(
        "confirm_share",
        %{"recipient_ids" => recipient_ids, "share_message" => message},
        socket
      )
      when is_list(recipient_ids) do
    current_user_id = socket.assigns.current_user.id
    post_id = socket.assigns.post_to_share

    # Share the post with optional message
    case Vibeflow.Chat.share_post_to_friends(current_user_id, post_id, recipient_ids, message) do
      {:ok, _shared_post} ->
        msg =
          case length(recipient_ids) do
            1 -> "Post shared successfully!"
            n -> "Post shared to #{n} friends!"
          end

        {:noreply,
         socket
         |> put_flash(:info, msg)
         |> assign(:show_share_modal, false)
         |> assign(:selected_friends, [])}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to share post: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("confirm_share", %{"recipient_ids" => recipient_ids}, socket)
      when is_list(recipient_ids) do
    # Handle case where no message is provided
    handle_event(
      "confirm_share",
      %{"recipient_ids" => recipient_ids, "share_message" => ""},
      socket
    )
  end

  def handle_event("confirm_share", %{"recipient_id" => recipient_id}, socket) do
    handle_event("confirm_share", %{"recipient_ids" => [recipient_id]}, socket)
  end

  def handle_event("update_selected_friends", params, socket) do
    ids = params["recipient_ids"] || []
    ids = if is_list(ids), do: Enum.map(ids, &String.to_integer/1), else: [String.to_integer(ids)]
    {:noreply, assign(socket, :selected_friends, ids)}
  end

  def handle_event("update_selected_friends", _params, socket) do
    {:noreply, assign(socket, :selected_friends, [])}
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
  def handle_info({:open_share_modal, post_id_or_uuid}, socket) do
    # 1. Fetch the user's friends list (needed for the share modal)
    friends = Vibeflow.Accounts.list_friends(socket.assigns.current_user)
    # 2. Update the socket to show the modal and store the post ID
    {:noreply,
     socket
     |> assign(:show_share_modal, true)
     |> assign(:post_to_share, post_id_or_uuid)
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
  def handle_info(:clear_highlight_post_url, socket) do
    {:noreply, push_patch(socket, to: feed_path(socket))}
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
  def handle_info(:update_notifications, socket) do
    send_update(VibeflowWeb.Components.NotificationsModal, id: "notifications-modal-desktop")
    {:noreply, socket}
  end

  @impl true
  def handle_info(_event, socket), do: {:noreply, socket}

  # --- CORE HELPERS ---

  defp load_posts(socket) do
    %{page: page, per_page: per_page} = socket.assigns

    posts =
      if socket.assigns[:current_user] do
        _ =
          Vibeflow.Posts.Seeder.backfill_followed_posts_for_user(
            socket.assigns.current_user.id,
            per_page * 3
          )

        Posts.list_feed_for_user(
          socket.assigns.current_user.id,
          page: page,
          per_page: per_page,
          category: socket.assigns[:category],
          search: socket.assigns[:search_term]
        )
      else
        Posts.list_posts(
          page: page,
          per_page: per_page,
          category: socket.assigns[:category],
          search: socket.assigns[:search_term]
        )
      end
      |> Enum.map(&Post.ensure_media_files/1)
      |> maybe_prioritize_post(socket.assigns[:highlight_post_uuid])
      |> maybe_shuffle_first_page(page, socket.assigns[:highlight_post_uuid])

    has_more = length(posts) == per_page

    # Check if this might be fallback content for a new user
    is_fallback_content =
      page == 1 and not is_nil(socket.assigns[:current_user]) and
        length(posts) > 0 and
        not has_content_from_followed_users(posts, socket.assigns.current_user.id)

    socket
    |> assign(
      loading: false,
      has_more: has_more,
      page: page + 1,
      is_fallback_content: is_fallback_content
    )
    |> update_stream_based_on_page(page, posts)
  end

  defp maybe_shuffle_first_page(posts, 1, nil), do: Enum.shuffle(posts)
  defp maybe_shuffle_first_page(posts, _page, _highlight_post_uuid), do: posts

  defp maybe_prioritize_post(posts, nil), do: posts

  defp maybe_prioritize_post(posts, highlight_post_uuid) do
    case Enum.split_with(posts, fn post -> to_string(post.uuid) == to_string(highlight_post_uuid) end) do
      {[highlight_post | _], rest} -> [highlight_post | rest]
      {[], _} -> posts
    end
  end

  defp has_content_from_followed_users(posts, user_id) do
    Enum.any?(posts, fn post ->
      post.user_id == user_id or
        Vibeflow.Posts.get_post_seed(post.id, user_id) != nil
    end)
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
    trending = Posts.list_trending_posts(20)
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

  defp feed_path(socket) do
    params = []

    params =
      if socket.assigns[:search_term] in [nil, ""] do
        params
      else
        Keyword.put(params, :search, socket.assigns.search_term)
      end

    params =
      if socket.assigns[:category] in [nil, ""] do
        params
      else
        Keyword.put(params, :category, socket.assigns.category)
      end

    if params == [], do: ~p"/feed", else: ~p"/feed?#{params}"
  end
end
