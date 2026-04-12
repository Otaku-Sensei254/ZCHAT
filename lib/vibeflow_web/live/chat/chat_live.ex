defmodule VibeflowWeb.Chat.ChatLive do
  use VibeflowWeb, :live_view
  require Logger

  alias Vibeflow.Chat
  alias Vibeflow.Store
  alias VibeflowWeb.Presence
  import Phoenix.HTML.Form

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      # 1. Subscribe to Sidebar updates
      Phoenix.PubSub.subscribe(Vibeflow.PubSub, "user_sidebar:#{current_user.id}")

      # 2. Subscribe to user settings changes (including skin)
      Phoenix.PubSub.subscribe(Vibeflow.PubSub, "user:#{current_user.id}:settings")

      # 3. Track Presence
      Presence.track(self(), "users:online", current_user.id, %{
        username: current_user.username,
        online_at: inspect(System.system_time(:second))
      })

      VibeflowWeb.Endpoint.subscribe("users:online")

      # 4. Async load sidebar
      send(self(), :load_sidebar_data)
    end

    # Initial Assigns
    {:ok,
     socket
     # Will load async
     |> assign(:conversations, [])
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
     |> assign(:recording, false)
     |> assign(:audio_retry_count, 0)
     |> assign(:active_message_skin, current_user.active_message_skin || "default")
     |> stream(:messages, [])
     |> allow_upload(:media_file,
       accept: ~w(.jpg .jpeg .png .gif .mp4 .mp3 .wav .ogg .flac),
       max_entries: 3,
       chunk_size: 64_000,
       max_file_size: 50_000_000,
       auto_upload: true
     )
     |> allow_upload(:audio,
       accept: ~w(.mp3 .wav .ogg .flac .webm),
       max_entries: 1,
       chunk_size: 64_000,
       max_file_size: 20_000_000,
       auto_upload: true
     )}
  end

  # ===========================================================================
  # HELPERS
  # ===========================================================================

  def get_user_skin_for_conversation(conversation, user_id) do
    case Enum.find(conversation.conversation_members, fn m -> m.user_id == user_id end) do
      nil -> "default"
      member -> member.message_skin || "default"
    end
  end

  def message_skin_classes(active_skin, is_me) do
    base_classes = "max-w-[75%] px-6 py-5 text-sm break-words relative leading-relaxed word-wrap"

    # Apply skin based on the sender's preference for this conversation
    case active_skin do
      "Glassmorphism Pro" ->
        glassmorphism_classes(is_me)

      "Matrix Rain" ->
        matrix_rain_classes(is_me)

      "Holographic Foil" ->
        holographic_foil_classes(is_me)

      "Vantablack" ->
        vantablack_classes(is_me)

      _ ->
        default_classes(is_me)
    end
  end

  def reply_skin_classes(active_skin, is_me) do
    # Apply skin based on the sender's preference for this conversation
    case active_skin do
      "Glassmorphism Pro" ->
        "bg-white/20 border-l-4 border-white/60 text-white px-3 py-2"

      "Matrix Rain" ->
        "bg-green-900/30 border-l-4 border-green-400/80 text-green-300 px-3 py-2"

      "Holographic Foil" ->
        "bg-purple-900/30 border-l-4 border-purple-400/80 text-purple-200 px-3 py-2"

      "Vantablack" ->
        "bg-gray-800/50 border-l-4 border-gray-600 text-gray-300 px-3 py-2"

      _ ->
        if is_me do
          "bg-blue-100/20 border-l-4 border-blue-500 text-blue-700 dark:text-blue-300 px-3 py-2"
        else
          "bg-gray-200/30 dark:bg-gray-700/30 border-l-4 border-gray-400 text-gray-600 dark:text-gray-300 px-3 py-2"
        end
    end
  end

  defp glassmorphism_classes(is_me) do
    if is_me do
      "bg-purple/40 p-3 backdrop-blur-xl border border-blue/40 text-blue-500 rounded-3xl rounded-br-none shadow-xl shadow-white/10 hover:shadow-white/20 transition-shadow before:content-[''] before:absolute before:bottom-0 before:right-[-8px] before:w-0 before:h-0 before:border-l-[10px] before:border-r-[10px] before:border-t-[10px] before:border-l-transparent before:border-r-transparent before:border-t-white/40 before:border-b-0"
    else
      "bg-purple/15 p-3 backdrop-blur-lg border border-white/30 text-gray-900 dark:text-gray-100 rounded-3xl rounded-bl-none shadow-xl shadow-white/5 hover:shadow-white/15 transition-shadow before:content-[''] before:absolute before:bottom-0 before:left-[-8px] before:w-0 before:h-0 before:border-l-[10px] before:border-r-[10px] before:border-t-[10px] before:border-l-transparent before:border-r-transparent before:border-t-white/30 before:border-b-0"
    end
  end

  defp matrix_rain_classes(is_me) do
    if is_me do
      "bg-black/95 p-3 w-fit border-2 border-green-500/50 text-green-400 rounded-2xl rounded-br-none shadow-2xl shadow-green-500/30 hover:shadow-green-500/50 transition-shadow font-mono before:content-[''] before:absolute before:bottom-0 before:right-[-10px] before:w-0 before:h-0 before:border-l-[12px] before:border-r-[12px] before:border-t-[12px] before:border-l-transparent before:border-r-transparent before:border-t-green-500/50 before:border-b-0"
    else
      "bg-black/90 p-3 border-2 border-green-500/30 text-green-300 rounded-2xl rounded-bl-none shadow-2xl shadow-green-500/20 hover:shadow-green-500/40 transition-shadow font-mono before:content-[''] before:absolute before:bottom-0 before:left-[-10px] before:w-0 before:h-0 before:border-l-[12px] before:border-r-[12px] before:border-t-[12px] before:border-l-transparent before:border-r-transparent before:border-t-green-500/30 before:border-b-0"
    end
  end

  defp holographic_foil_classes(is_me) do
    if is_me do
      "bg-gradient-to-br from-purple-600/90 via-pink-600/90 to-blue-600/90 p-3 text-white rounded-3xl rounded-br-none shadow-2xl shadow-purple-500/40 hover:shadow-purple-500/60 transition-shadow backdrop-blur-sm before:content-[''] before:absolute before:bottom-0 before:right-[-10px] before:w-0 before:h-0 before:border-l-[12px] before:border-r-[12px] before:border-t-[12px] before:border-l-transparent before:border-r-transparent before:border-t-blue-600/90 before:border-b-0"
    else
      "bg-gradient-to-br from-purple-500/80 via-pink-500/80 to-blue-500/80 p-3 text-white rounded-3xl rounded-bl-none shadow-2xl shadow-purple-500/30 hover:shadow-purple-500/50 transition-shadow backdrop-blur-sm before:content-[''] before:absolute before:bottom-0 before:left-[-10px] before:w-0 before:h-0 before:border-l-[12px] before:border-r-[12px] before:border-t-[12px] before:border-l-transparent before:border-r-transparent before:border-t-purple-500/80 before:border-b-0"
    end
  end

  defp vantablack_classes(is_me) do
    if is_me do
      "bg-black/95 p-3 border-2 border-gray-700 text-gray-200 rounded-3xl rounded-br-none shadow-2xl shadow-black/60 hover:shadow-black/80 transition-shadow before:content-[''] before:absolute before:bottom-0 before:right-[-10px] before:w-0 before:h-0 before:border-l-[12px] before:border-r-[12px] before:border-t-[12px] before:border-l-transparent before:border-r-transparent before:border-t-gray-700 before:border-b-0"
    else
      "bg-gray-900/95 p-3 border-2 border-gray-700 text-gray-300 rounded-3xl rounded-bl-none shadow-2xl shadow-black/50 hover:shadow-black/70 transition-shadow before:content-[''] before:absolute before:bottom-0 before:left-[-10px] before:w-0 before:h-0 before:border-l-[12px] before:border-r-[12px] before:border-t-[12px] before:border-l-transparent before:border-r-transparent before:border-t-gray-700 before:border-b-0"
    end
  end

  defp default_classes(is_me) do
    if is_me do
      "bg-blue-800 p-3 text-white rounded-3xl rounded-br-none shadow-lg hover:shadow-xl transition-shadow before:content-[''] before:absolute before:bottom-0 before:right-[-8px] before:w-0 before:h-0 before:border-l-[10px] before:border-r-[10px] before:border-t-[10px] before:border-l-transparent before:border-r-transparent before:border-t-blue-500 before:border-b-0"
    else
      "bg-gray-100 p-3 dark:bg-zinc-700 text-gray-800 dark:text-gray-100 rounded-3xl rounded-bl-none shadow-lg hover:shadow-xl transition-shadow before:content-[''] before:absolute before:bottom-0 before:left-[-8px] before:w-0 before:h-0 before:border-l-[10px] before:border-r-[10px] before:border-t-[10px] before:border-l-transparent before:border-r-transparent before:border-t-gray-100 dark:before:border-t-zinc-700 before:border-b-0"
    end
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
        Phoenix.PubSub.unsubscribe(
          Vibeflow.PubSub,
          "conversation:#{socket.assigns.conversation.uuid}"
        )
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
     # Reset typing when switching chats
     |> assign(:typing_users, %{})
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
      consume_uploaded_entries(socket, :media_file, fn %{path: path}, entry ->
        case Vibeflow.Infrastructure.UploadCloudinary.upload_file(path, upload_kind_for(entry)) do
          {:ok, %{url: url, resource_type: type}} ->
            {:ok, %{"url" => url, "type" => normalize_media_type(type, entry)}}

          {:error, _reason} ->
            {:ok, nil}
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

  def handle_event("start_recording", _params, socket) do
    {:noreply, assign(socket, :recording, true)}
  end

  def handle_event("stop_recording", _params, socket) do
    entries = socket.assigns.uploads.audio.entries
    ready = Enum.filter(entries, &(&1.progress == 100))

    Logger.debug(
      ">>> VOICENOTE: stop_recording triggered. Total: #{length(entries)}, Ready: #{length(ready)}"
    )

    socket =
      if length(ready) > 0 do
        send_audio_message(socket)
      else
        if length(entries) > 0 do
          Process.send_after(self(), :retry_audio_upload, 300)
        end

        socket
      end

    {:noreply, socket |> assign(:recording, false) |> assign(:audio_retry_count, 0)}
  end

  def handle_event("cancel_recording", _params, socket) do
    {:noreply, assign(socket, :recording, false)}
  end

  defp consume_audio_uploads(socket) do
    consume_uploaded_entries(socket, :audio, fn %{path: path}, entry ->
      case Vibeflow.Infrastructure.UploadCloudinary.upload_file(path, upload_kind_for(entry)) do
        {:ok, %{url: url, resource_type: type}} ->
          {:ok, %{"url" => url, "type" => normalize_media_type(type, entry)}}

        {:error, reason} ->
          Logger.error(">>> VOICENOTE: Cloudinary failed: #{inspect(reason)}")
          {:ok, nil}
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  defp upload_kind_for(entry) do
    client_type = entry.client_type || ""
    client_name = entry.client_name || ""
    ext = client_name |> String.downcase() |> Path.extname()

    audio_exts = [".mp3", ".wav", ".ogg", ".flac", ".webm", ".m4a", ".aac", ".opus"]
    image_exts = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".avif"]

    cond do
      String.starts_with?(client_type, "audio/") -> :raw
      ext in audio_exts -> :raw
      String.starts_with?(client_type, "image/") -> :image
      ext in image_exts -> :image
      true -> :auto
    end
  end

  defp normalize_media_type(resource_type, entry) do
    client_type = entry.client_type || ""
    client_name = entry.client_name || ""
    ext = client_name |> String.downcase() |> Path.extname()

    audio_exts = [".mp3", ".wav", ".ogg", ".flac", ".webm", ".m4a", ".aac", ".opus"]

    cond do
      String.starts_with?(client_type, "audio/") -> "audio"
      ext in audio_exts -> "audio"
      true -> resource_type
    end
  end

  defp send_audio_message(socket) do
    conversation = socket.assigns.conversation
    current_user = socket.assigns.current_user
    audio_files = consume_audio_uploads(socket)

    if audio_files != [] do
      Chat.create_message(%{
        "conversation_id" => conversation.id,
        "user_id" => current_user.id,
        "media_files" => audio_files,
        "content" => ""
      })
    end

    socket
  end

  def handle_info(:retry_audio_upload, socket) do
    entries = socket.assigns.uploads.audio.entries
    ready = Enum.filter(entries, &(&1.progress == 100))

    cond do
      length(ready) > 0 ->
        socket = send_audio_message(socket)
        {:noreply, assign(socket, :audio_retry_count, 0)}

      length(entries) > 0 and socket.assigns.audio_retry_count < 20 ->
        Process.send_after(self(), :retry_audio_upload, 300)
        {:noreply, assign(socket, :audio_retry_count, socket.assigns.audio_retry_count + 1)}

      length(entries) > 0 ->
        {:noreply,
         socket
         |> assign(:audio_retry_count, 0)
         |> put_flash(:error, "Audio upload still processing. Please try again.")}

      true ->
        {:noreply, assign(socket, :audio_retry_count, 0)}
    end
  end

  # get to the replied messo
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
        |> Enum.map(fn r ->
          %{
            id: r.id,
            username: r.title,
            avatar_url: r.image,
            is_verified: Map.get(r, :is_verified, false)
          }
        end)

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
    target_user_id = String.to_integer(target_user_id)

    {:ok, conversation} =
      Chat.get_or_create_private_conversation(socket.assigns.current_user.id, target_user_id)

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
    message =
      Vibeflow.Repo.get!(Vibeflow.Chat.Message, message_id) |> Vibeflow.Repo.preload([:user])

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
        user: %{
          id: socket.assigns.current_user.id,
          username: socket.assigns.current_user.username
        },
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
  # ======to check out the media shared=====
  def handle_event("preview_entry", %{"ref" => ref}, socket) do
    check =
      socket.assigns.uploads.media_file.entries
      |> Enum.find(fn ck -> ck.ref == ref end)

    {:noreply, assign(socket, preview_entry: check)}
  end

  @impl true
  # close the preview modal
  def handle_event("close_preview", _params, socket) do
    {:noreply, assign(socket, preview_entry: nil)}
  end

  @impl true
  # Handle clicking an image in the chat history
  def handle_event("zoom_image", params, socket) do
    {:noreply, assign(socket, zoomed_image: params)}
  end

  @impl true
  # Handle closing the full-screen view
  def handle_event("close_zoom", _params, socket) do
    {:noreply, assign(socket, zoomed_image: nil)}
  end

  @impl true
  def handle_event("close_modals", %{"key" => "Escape"}, socket) do
    {:noreply,
     socket
     |> assign(:zoomed_image, nil)
     |> assign(:preview_entry, nil)}
  end

  @impl true
  def handle_event("close_modals", _, socket), do: {:noreply, socket}
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
          |> Vibeflow.Repo.preload(user: [], reply_to: [:user])

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

          username = (message_user && message_user.username) || "Someone"

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

  # 8. SKIN CHANGED
  @impl true
  def handle_info({:skin_changed, new_skin}, socket) do
    {:noreply, assign(socket, :active_message_skin, new_skin)}
  end

  # Handle skin change broadcasts from conversation settings
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "skin_changed", payload: payload}, socket) do
    # Only update if this is about the other user in the conversation
    if payload.user_id != socket.assigns.current_user.id do
      # Force a re-render of messages by refreshing the stream
      messages = Chat.list_messages(socket.assigns.conversation)

      {:noreply,
       socket
       |> stream(:messages, messages, reset: true)}
    else
      {:noreply, socket}
    end
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
    if String.length(content) > length,
      do: String.slice(content, 0, length) <> "...",
      else: content
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

  # Helper function to get user's skin for a specific conversation
  def get_user_skin_for_conversation(conversation, user_id) do
    case Enum.find(conversation.conversation_members, fn m -> m.user_id == user_id end) do
      nil -> "default"
      member -> member.message_skin || "default"
    end
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

      property_first =
        ~r/<meta[^>]+(?:property|name)=["']#{escaped}["'][^>]+content=["']([^"']+)["'][^>]*>/i

      content_first =
        ~r/<meta[^>]+content=["']([^"']+)["'][^>]*(?:property|name)=["']#{escaped}["'][^>]*>/i

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
