defmodule VibeflowWeb.Chat.ChatLive do
  use VibeflowWeb, :live_view

  alias Vibeflow.Chat
  alias VibeflowWeb.Presence
  import Phoenix.HTML.Form

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      # 1. Subscribe to Sidebar updates
      Phoenix.PubSub.subscribe(Vibeflow.PubSub, "user_sidebar:#{current_user.id}")

      # 2. Track Presence
      Presence.track(self(), "users:online", current_user.id, %{
        username: current_user.username,
        online_at: inspect(System.system_time(:second))
      })
      VibeflowWeb.Endpoint.subscribe("users:online")

      # 3. Async load sidebar
      send(self(), :load_sidebar_data)
    end

    # Initial Assigns
    {:ok,
     socket
     |> assign(:conversations, []) # Will load async
     |> assign(:loading_sidebar, true)
     |> assign(:conversation, nil)
     |> assign(:typing_users, %{})
     |> assign(:online_users, Presence.list("users:online"))
     |> assign(:other_last_read_at, nil)
     |> assign(:user_search_query, "")
     |> assign(:user_search_results, [])
     |> assign(:replying_to, nil)
     |> assign(:preview_entry, nil)
     |> assign(:zoomed_image, nil)
     |> assign(:link_previews, %{})
     |> assign(:link_preview_loading, MapSet.new())
     |> stream(:messages, [])
     |> allow_upload(:media_file,
       accept: ~w(.jpg .jpeg .png .gif .mp4 .mp3 .wav .ogg .flac),
       max_entries: 3,
       chunk_size: 64_000,
       max_file_size: 50_000_000,
       auto_upload: true
     )
    }
  end

  # ===========================================================================
  # HANDLE PARAMS (Routing) - Grouped
  # ===========================================================================

  @impl true
  def handle_params(%{"uuid" => conversation_uuid}, _uri, socket) do
    current_user_id = socket.assigns.current_user.id
    conversation = Chat.get_conversation!(conversation_uuid)

    if connected?(socket) do
      # Unsubscribe from previous if exists
      if socket.assigns.conversation do
        Phoenix.PubSub.unsubscribe(Vibeflow.PubSub, "conversation:#{socket.assigns.conversation.uuid}")
      end
      Phoenix.PubSub.subscribe(Vibeflow.PubSub, "conversation:#{conversation.uuid}")
    end

    # Mark as Read
    Chat.mark_conversation_as_read(current_user_id, conversation.id)

    # RE-FETCH Sidebar List immediately to clear badges
    conversations = Chat.list_user_conversations(current_user_id)

    other_member =
      Enum.find(conversation.conversation_members, fn m -> m.user_id != current_user_id end)

    other_last_read_at = if other_member, do: other_member.last_read_at, else: nil
    messages = Chat.list_messages(conversation)

  {:noreply,
   socket
   |> assign(:conversations, conversations)
   |> assign(:conversation, conversation)
   |> assign(:other_last_read_at, other_last_read_at)
   |> assign(:replying_to, nil)
   |> assign(:typing_users, %{}) # Reset typing when switching chats
   |> schedule_link_previews(messages)
   |> stream(:messages, messages, reset: true)
   |> assign(:hide_bottom_nav, true)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :hide_bottom_nav, false)}
  end

  # ===========================================================================
  # HANDLE EVENTS - All grouped together
  # ===========================================================================

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => message_params}, socket) do
    conversation = socket.assigns.conversation
    current_user = socket.assigns.current_user
    replying_to = socket.assigns.replying_to

    # 1. Handle Uploads
    uploaded_files =
      consume_uploaded_entries(socket, :media_file, fn %{path: path}, _entry ->
        case Vibeflow.Infrastructure.UploadCloudinary.upload_file(path) do
          {:ok, %{url: url, resource_type: type}} -> {:ok, %{"url" => url, "type" => type}}
          {:error, _reason} -> {:ok, nil}
        end
      end)
      |> Enum.filter(&(&1 != nil))

    # 2. Build Params
    final_params =
      message_params
      |> Map.put("conversation_id", conversation.id)
      |> Map.put("user_id", current_user.id)
      |> Map.put("media_files", uploaded_files)
      |> Map.put_new("content", "")

    # Add Reply ID if exists
    final_params =
      if replying_to, do: Map.put(final_params, "reply_to_id", replying_to.id), else: final_params

    # 3. Create
    if final_params["content"] != "" || uploaded_files != [] do
      case Chat.create_message(final_params) do
        {:ok, _message} ->
          {:noreply,
           socket
           |> assign(:replying_to, nil)
           |> push_event("clear-input", %{})}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to send message.")}
      end
    else
      {:noreply, socket}
    end
  end
#get to the replied messo
def handle_event("scroll_to_message", _params, socket) do
  # The server doesn't need to do anything, but it must acknowledge the event.
  {:noreply, socket}
end
  @impl true
  def handle_event("search_new_chat", %{"query" => query}, socket) do
    if String.length(query) >= 2 do
      current_user_id = socket.assigns.current_user.id
      results =
        Vibeflow.Search.global_search(query)
        |> Enum.filter(fn result -> Map.get(result, :type) == :user end)
        |> Enum.filter(&(&1.id != current_user_id))
        |> Enum.map(fn r -> %{id: r.id, username: r.title, avatar_url: r.image} end)

      {:noreply, assign(socket, user_search_results: results, user_search_query: query)}
    else
      {:noreply, assign(socket, user_search_results: [], user_search_query: query)}
    end
  end

  @impl true
  def handle_event("clear_user_search", _, socket) do
    {:noreply, assign(socket, user_search_results: [], user_search_query: "")}
  end

  @impl true
  def handle_event("start_new_chat", %{"user_id" => target_user_id}, socket) do
    {:ok, conversation} = Chat.get_or_create_private_conversation(socket.assigns.current_user.id, target_user_id)
    {:noreply,
     socket
     |> assign(user_search_results: [], user_search_query: "")
     |> push_patch(to: ~p"/chat/#{conversation.uuid}")}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    socket =
    if socket.assigns.preview_entry && socket.assigns.preview_entry.ref == ref do
      assign(socket, preview_entry: nil)
    else
      socket
    end
    {:noreply, cancel_upload(socket, :media_file, ref)}
  end

  @impl true
  def handle_event("prepare_reply", %{"id" => message_id}, socket) do
    message = Vibeflow.Repo.get!(Vibeflow.Chat.Message, message_id) |> Vibeflow.Repo.preload([:user])
    {:noreply, assign(socket, :replying_to, message)}
  end

  @impl true
  def handle_event("cancel_reply", _, socket) do
    {:noreply, assign(socket, :replying_to, nil)}
  end

  @impl true
  def handle_event("delete_message", %{"id" => message_id}, socket) do
    message = Vibeflow.Repo.get(Vibeflow.Chat.Message, message_id)
    if message && message.user_id == socket.assigns.current_user.id do
      Chat.delete_message(message)
    end
    {:noreply, socket}
  end

  # TYPING EVENT (Sent by the client Hook)
  @impl true
  def handle_event("update_typing_indicator", params, socket) do
    # Only broadcast if we are in a conversation
    if socket.assigns.conversation do
      is_typing = Map.get(params, "is_typing", false)
      topic = "conversation:#{socket.assigns.conversation.uuid}"

      payload = %{
        user: %{id: socket.assigns.current_user.id, username: socket.assigns.current_user.username},
        typing: is_typing
      }
      # Broadcast to everyone else in the topic
      VibeflowWeb.Endpoint.broadcast_from(self(), topic, "typing", payload)
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("display_new_message", _, socket), do: {:noreply, socket}


  @impl true
  #======to check out the media shared=====
    def handle_event("preview_entry", %{"ref" => ref}, socket) do
      check =
        socket.assigns.uploads.media_file.entries
        |> Enum.find(fn ck -> ck.ref == ref end)
        {:noreply, assign(socket, preview_entry: check)}
    end

    #close the preview modal
     def handle_event("close_preview", _params, socket) do
      {:noreply, assign(socket, preview_entry: nil)}
     end

     # Handle clicking an image in the chat history
  @impl true
  def handle_event("zoom_image", %{"url" => url}, socket) do
    {:noreply, assign(socket, zoomed_image: url)}
  end

  # Handle closing the full-screen view
  @impl true
  def handle_event("close_zoom", _params, socket) do
    {:noreply, assign(socket, zoomed_image: nil)}
  end
  # ===========================================================================
  # HANDLE INFO - All grouped together
  # ===========================================================================

  # 1. NEW MESSAGE
  @impl true
  def handle_info({:new_message, message}, socket) do
    active_conversation = socket.assigns.conversation
    current_user_id = socket.assigns.current_user.id

    # Check if we are currently looking at this conversation
    is_current_chat = active_conversation && active_conversation.uuid == message.conversation_uuid

    socket =
      if is_current_chat do

        message =
          message
          |> Vibeflow.Repo.preload([user: [], reply_to: [:user]])
        # We are in the chat:
        # 1. Mark as read immediately if from someone else
        if message.user_id != current_user_id do
          Chat.mark_conversation_as_read(current_user_id, message.conversation_id)
        end

        # 2. Insert message and scroll
        socket
        |> schedule_link_previews([message])
        |> stream_insert(:messages, message)
        |> push_event("scroll-to-bottom", %{})
        # 3. Stop typing indicator for the sender (since they sent a msg)
        |> remove_typing_indicator(message.user_id)
      else
        # We are NOT in the chat:
        if message.user_id != current_user_id do
          # Safely determine username even if message.user wasn't preloaded
          message_user =
            case message.user do
              %Vibeflow.Accounts.User{} = u -> u
              _ -> Vibeflow.Repo.get(Vibeflow.Accounts.User, message.user_id)
            end

          username = message_user && message_user.username || "Someone"

          # 1. Show flash notification (ONLY here)
          put_flash(socket, :info, "New message from #{username}")
        else
          socket
        end
      end

    {:noreply, socket}
  end

  # 2. TYPING INDICATOR (Received Broadcast)
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "typing", payload: payload}, socket) do
    user_id = payload.user.id
    username = payload.user.username
    is_typing = payload.typing

    # STRICT CHECK: Don't show typing for myself
    if user_id != socket.assigns.current_user.id do
      new_typing_users =
        if is_typing do
          Map.put(socket.assigns.typing_users, user_id, username)
        else
          Map.delete(socket.assigns.typing_users, user_id)
        end

      {:noreply, assign(socket, :typing_users, new_typing_users)}
    else
      {:noreply, socket}
    end
  end

  # 3. SIDEBAR UPDATE
  @impl true
  def handle_info({:update_sidebar, _message}, socket) do
    conversations = Chat.list_user_conversations(socket.assigns.current_user.id)
    {:noreply, assign(socket, :conversations, conversations)}
  end

  # 4. READ RECEIPT
  @impl true
  def handle_info({:message_read, %{last_read_at: last_read_at, user_id: reader_id}}, socket) do
    # Only update if someone ELSE read messages while I am in the chat
    if reader_id != socket.assigns.current_user.id && socket.assigns.conversation do
      messages = Chat.list_messages(socket.assigns.conversation)
      {:noreply,
       socket
       |> assign(:other_last_read_at, last_read_at)
       |> schedule_link_previews(messages)
       |> stream(:messages, messages, reset: true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:link_preview_fetched, url, preview}, socket) do
    {:noreply,
     socket
     |> update(:link_preview_loading, &MapSet.delete(&1, url))
     |> maybe_store_link_preview(url, preview)}
  end

  # 5. MESSAGE DELETED
  @impl true
  def handle_info({:message_deleted, message}, socket) do
    {:noreply, stream_delete(socket, :messages, message)}
  end

  # 6. LOAD SIDEBAR ASYNC (Fixed assign/4 error)
  @impl true
  def handle_info(:load_sidebar_data, socket) do
    conversations = Chat.list_user_conversations(socket.assigns.current_user.id)
    # FIX: Use keyword list for assign/2
    {:noreply, assign(socket, conversations: conversations, loading_sidebar: false)}
  end

  # 7. PRESENCE
  @impl true
  def handle_info(%{topic: "users:online", event: "presence_diff"}, socket) do
    online_users = Presence.list("users:online")
    {:noreply, assign(socket, :online_users, online_users)}
  end

  @impl true
  def handle_info(:update_notifications, socket) do
    send_update(VibeflowWeb.Components.NotificationsModal, id: "notifications-modal-desktop")
    {:noreply, socket}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  # ===========================================================================
  # HELPERS
  # ===========================================================================
  @url_regex ~r/(https?:\/\/[^\s<]+)/u

  defp remove_typing_indicator(socket, user_id) do
    new_typing = Map.delete(socket.assigns.typing_users, user_id)
    assign(socket, :typing_users, new_typing)
  end

  defp get_typing_text(typing_users) do
    case map_size(typing_users) do
      0 -> nil
      1 -> "#{Enum.at(Map.values(typing_users), 0)} is typing..."
      n -> "#{n} people are typing..."
    end
  end

  defp content_cut(nil, _), do: ""
  defp content_cut(content, length) do
    if String.length(content) > length, do: String.slice(content, 0, length) <> "...", else: content
  end

  defp message_segments(nil), do: []

  defp message_segments(content) when is_binary(content) do
    @url_regex
    |> Regex.split(content, include_captures: true, trim: true)
    |> Enum.map(fn segment ->
      if Regex.match?(@url_regex, segment), do: {:link, segment}, else: {:text, segment}
    end)
  end

  defp first_link(nil), do: nil

  defp first_link(content) when is_binary(content) do
    case Regex.run(@url_regex, content) do
      [url | _] -> url
      _ -> nil
    end
  end

  defp link_domain(url) when is_binary(url) do
    uri = URI.parse(url)
    uri.host || url
  end

  defp schedule_link_previews(socket, messages) when is_list(messages) do
    Enum.reduce(messages, socket, fn message, acc ->
      schedule_link_preview(acc, first_link(message.content || ""))
    end)
  end

  defp schedule_link_preview(socket, nil), do: socket

  defp schedule_link_preview(socket, url) do
    cond do
      not connected?(socket) ->
        socket

      Map.has_key?(socket.assigns.link_previews, url) ->
        socket

      MapSet.member?(socket.assigns.link_preview_loading, url) ->
        socket

      true ->
        parent = self()

        Task.start(fn ->
          send(parent, {:link_preview_fetched, url, fetch_link_preview(url)})
        end)

        update(socket, :link_preview_loading, &MapSet.put(&1, url))
    end
  end

  defp maybe_store_link_preview(socket, _url, nil), do: socket

  defp maybe_store_link_preview(socket, url, preview) do
    update(socket, :link_previews, &Map.put(&1, url, preview))
  end

  defp fetch_link_preview(url) do
    with {:ok, uri} <- validate_preview_url(url),
         {:ok, response} <-
           Req.get(
             url: url,
             redirect: [max_redirects: 5],
             receive_timeout: 4_000,
             connect_options: [timeout: 3_000],
             headers: [{"user-agent", "Mozilla/5.0 (compatible; VibeflowLinkPreview/1.0)"}]
           ),
         true <- is_binary(response.body) do
      html = String.slice(response.body, 0, 200_000)

      title =
        meta_content(html, ["og:title", "twitter:title"]) ||
          extract_title(html)

      description =
        meta_content(html, ["og:description", "twitter:description", "description"])

      image =
        meta_content(html, ["og:image", "twitter:image"])
        |> absolutize_url(uri)

      if title || description || image do
        %{
          title: title,
          description: description,
          image: image,
          domain: uri.host
        }
      else
        nil
      end
    else
      _ -> nil
    end
  end

  defp validate_preview_url(url) do
    uri = URI.parse(url)
    host = String.downcase(uri.host || "")

    cond do
      uri.scheme not in ["http", "https"] -> :error
      uri.host in [nil, ""] -> :error
      host in ["localhost", "127.0.0.1", "::1"] -> :error
      true -> {:ok, uri}
    end
  end

  defp meta_content(html, keys) when is_list(keys) do
    Enum.find_value(keys, fn key ->
      escaped = Regex.escape(key)
      property_first = ~r/<meta[^>]+(?:property|name)=["']#{escaped}["'][^>]+content=["']([^"']+)["'][^>]*>/i
      content_first = ~r/<meta[^>]+content=["']([^"']+)["'][^>]*(?:property|name)=["']#{escaped}["'][^>]*>/i

      case Regex.run(property_first, html, capture: :all_but_first) ||
             Regex.run(content_first, html, capture: :all_but_first) do
        [content] -> content |> String.trim() |> html_unescape()
        _ -> nil
      end
    end)
  end

  defp extract_title(html) do
    case Regex.run(~r/<title[^>]*>(.*?)<\/title>/is, html, capture: :all_but_first) do
      [title] ->
        title
        |> String.replace(~r/<[^>]*>/, "")
        |> String.replace(~r/\s+/, " ")
        |> String.trim()
        |> html_unescape()

      _ ->
        nil
    end
  end

  defp html_unescape(nil), do: nil

  defp html_unescape(value) do
    value
    |> String.replace("&amp;", "&")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace("&apos;", "'")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&nbsp;", " ")
  end

  defp absolutize_url(nil, _base_uri), do: nil

  defp absolutize_url(url, base_uri) do
    parsed = URI.parse(url)

    cond do
      parsed.scheme in ["http", "https"] ->
        url

      String.starts_with?(url, "//") ->
        "#{base_uri.scheme}:#{url}"

      true ->
        base_uri
        |> Map.put(:query, nil)
        |> Map.put(:fragment, nil)
        |> URI.merge(url)
        |> to_string()
    end
  rescue
    _ -> nil
  end
end
