defmodule VibeflowWeb.Chat.ChatLive do
  use VibeflowWeb, :live_view
  require Logger

  alias Vibeflow.Chat
  alias Vibeflow.Chat.BottleService
  alias Vibeflow.Store
  alias Vibeflow.Accounts
  alias VibeflowWeb.Presence
  import Phoenix.HTML.Form
  import Ecto.Changeset

  @impl true
  def mount(params, _session, socket) do
    current_user = socket.assigns.current_user

    socket =
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

        # 4. Subscribe to the active conversation immediately.
        # handle_params still loads the conversation, but this keeps the socket hot.
        case params["uuid"] do
          nil -> socket
          uuid -> subscribe_to_conversation(socket, uuid)
        end
      else
        socket
      end

    # Load sidebar data synchronously
    conversations = visible_conversations(current_user.id, "all")

    # Initial Assigns
    {:ok,
     socket
     |> assign(:conversations, conversations)
     |> assign(:loading_sidebar, false)
     |> assign(:conversation, nil)
     |> assign(:pending_local_message_id, nil)
     |> assign(:typing_users, %{})
     |> assign(:self_typing, false)
     |> assign(:online_users, Presence.list("users:online"))
     |> assign(:other_last_read_at, nil)
     |> assign(:user_search_query, "")
     |> assign(:user_search_results, [])
     |> assign(:replying_to, nil)
     |> assign(:composer_content, "")
     |> assign(:preview_entry, nil)
     |> assign(:zoomed_image, nil)
     |> assign(:link_previews, %{})
     |> assign(:link_preview_loading, MapSet.new())
     |> assign(:recording, false)
     |> assign(:audio_retry_count, 0)
     |> assign(:active_call, nil) # {status: :calling | :ringing | :ongoing, from_user: user, conversation: convo}
     |> assign(:active_message_skin, current_user.active_message_skin || "default")
     |> assign(:messages, [])
     |> assign(:show_new_chat_actions, false)
     |> assign(:show_new_chat_modal, false)
     |> assign(:show_direct_chat_modal, false)
     |> assign(:show_chat_menu, false)
     |> assign(:show_group_modal, false)
     |> assign(:show_bottle_modal, false)
     |> assign(:selected_tab, "followers")
     |> assign(:filtered_users, [])
     |> assign(:direct_search_query, "")
     |> assign(:direct_search_results, [])
     |> assign(:group_search_query, "")
     |> assign(:group_search_results, [])
     |> assign(:selected_group_members, [])
     |> assign(:group_name, "")
     |> assign(:bottle_content, "")
     |> assign(:chat_filter, "all")
     |> allow_upload(:media_file,
       accept: ~w(.jpg .jpeg .png .gif .webp .mp4 .mov .webm .avi .mp3 .wav .ogg .flac),
       max_entries: 5,
       chunk_size: 64_000,
       max_file_size: 100_000_000,
       auto_upload: true
     )
     |> allow_upload(:audio,
       accept: ~w(.mp3 .wav .ogg .flac .webm .m4a .aac .opus),
       max_entries: 1,
       chunk_size: 64_000,
       max_file_size: 20_000_000,
       auto_upload: true
     )
     |> allow_upload(:bottle_image,
       accept: ~w(.jpg .jpeg .png .webp .gif),
       max_entries: 1,
       chunk_size: 64_000,
       max_file_size: 5_000_000,
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
    # Reply bubbles use lighter/softer tones to distinguish from main message
    case active_skin do
      "Glassmorphism Pro" ->
        "bg-white/40 border-l-4 border-white/70 text-white/90 px-3 py-2"

      "Matrix Rain" ->
        "bg-green-400/20 border-l-4 border-green-400/50 text-green-200 px-3 py-2"

      "Holographic Foil" ->
        "bg-pink-300/30 border-l-4 border-pink-300/60 text-pink-100 px-3 py-2"

      "Vantablack" ->
        "bg-gray-700/60 border-l-4 border-gray-500/60 text-gray-200 px-3 py-2"

      _ ->
        if is_me do
          "bg-blue-300/40 dark:bg-blue-400/30 border-l-4 border-blue-300 text-blue-800 dark:text-blue-100 px-3 py-2"
        else
          "bg-gray-100 dark:bg-gray-600/40 border-l-4 border-gray-300 dark:border-gray-500 text-gray-700 dark:text-gray-200 px-3 py-2"
        end
    end
  end

  defp glassmorphism_classes(is_me) do
    if is_me do
      "max-w-[50vw] w-fit min-w-0 break-words bg-blue-400/20 px-4 py-2 border border-blue-300/40 text-blue-700 dark:text-white rounded-2xl rounded-br-none shadow-xl shadow-white/10 hover:shadow-white/20 transition-shadow"
    else
      "max-w-[50vw] w-fit min-w-0 break-words  bg-blue-500/40 px-4 py-2 border border-white/30 text-black dark:text-gray-100 rounded-2xl rounded-bl-none shadow-xl shadow-white/5 hover:shadow-white/15 transition-shadow"
    end
  end

  defp matrix_rain_classes(is_me) do
    if is_me do
      "max-w-[50vw] w-fit min-w-0 break-words  bg-black/95 px-4 py-2 border-2 border-green-500/50 text-green-400 rounded-2xl rounded-br-none shadow-2xl shadow-green-500/30 hover:shadow-green-500/50 transition-shadow font-mono"
    else
      "max-w-[50vw] w-fit min-w-0 break-words  bg-black/90 px-4 py-2 border-2 border-green-500/30 text-green-300 rounded-2xl rounded-bl-none shadow-2xl shadow-green-500/20 hover:shadow-green-500/40 transition-shadow font-mono"
    end
  end

  defp holographic_foil_classes(is_me) do
    if is_me do
      "max-w-[50vw] w-fit min-w-0 break-words  bg-gradient-to-br from-purple-600/90 via-pink-600/90 to-blue-600/90 px-4 py-2 text-white rounded-2xl rounded-br-none shadow-2xl shadow-purple-500/40 hover:shadow-purple-500/60 transition-shadow"
    else
      "max-w-[50vw] w-fit min-w-0 break-words  bg-gradient-to-br from-purple-500/80 via-pink-500/80 to-blue-500/80 px-4 py-2 text-white rounded-2xl rounded-bl-none shadow-2xl shadow-purple-500/30 hover:shadow-purple-500/50 transition-shadow"
    end
  end

  defp vantablack_classes(is_me) do
    if is_me do
      "max-w-[50vw] w-fit min-w-0 break-words  bg-black/95 px-4 py-2 border-2 border-gray-700 text-gray-200 rounded-2xl rounded-br-none shadow-2xl shadow-black/60 hover:shadow-black/80 transition-shadow"
    else
      "max-w-[50vw] w-fit min-w-0 break-words  bg-gray-900/95 px-4 py-2 border-2 border-gray-700 text-gray-300 rounded-2xl rounded-bl-none shadow-2xl shadow-black/50 hover:shadow-black/70 transition-shadow"
    end
  end

  defp default_classes(is_me) do
    if is_me do
      "max-w-[50vw] w-fit min-w-0 break-words bg-blue-600 px-4 py-2 text-white rounded-2xl rounded-br-none shadow-lg hover:shadow-xl transition-shadow"
    else
      "max-w-[50vw] w-fit min-w-0 break-words bg-gray-100 dark:bg-zinc-700 px-4 py-2 text-black  rounded-bl dark:text-gray-100 rounded-2xl shadow-lg hover:shadow-xl transition-shadow"
    end
  end

  defp bottle_skin_classes() do
    "max-w-[50vw] w-fit min-w-0 break-words " <>
    "bg-gradient-to-br from-blue-600 via-cyan-500 to-teal-400 " <>
    "px-5 py-4 text-white rounded-2xl rounded-bl-none rounded-br-none " <>
    "shadow-xl shadow-cyan-500/40 hover:shadow-cyan-500/60 transition-all " <>
    "relative overflow-hidden border-t-4 border-white/40 " <>
    "before:absolute before:inset-0 before:bg-gradient-to-t before:from-white/20 before:to-transparent before:opacity-50"
  end

  # ===========================================================================
  # HANDLE PARAMS (Routing) - Grouped
  # ===========================================================================

  @impl true
  def handle_params(%{"uuid" => conversation_uuid}, _uri, socket) do
    current_user_id = socket.assigns.current_user.id
    conversation = Chat.get_conversation!(conversation_uuid)

    socket =
      if connected?(socket) do
        subscribe_to_conversation(socket, conversation.uuid)
      else
        socket
      end

    # Mark as Read
    Chat.mark_conversation_as_read(current_user_id, conversation.id)

    # RE-FETCH Sidebar List immediately to clear badges
    conversations = visible_conversations(current_user_id, socket.assigns[:chat_filter] || "all")

    other_member =
      Enum.find(conversation.conversation_members, fn m -> m.user_id != current_user_id end)

    other_last_read_at = if other_member, do: other_member.last_read_at, else: nil

    # If this is a bottle conversation and current user is not the sender, reveal sender identity
    if conversation.type == "bottle" do
      # Check if there's an unfound bottle message in this conversation
      case BottleService.find_unfound_bottle_in_conversation(conversation.id, current_user_id) do
        {:ok, message} when message.user_id != current_user_id ->
          # Receiver opened the bottle - reveal sender
          BottleService.reveal_bottle_sender(message.id)
        _ ->
          :ok
      end
    end

    messages = Chat.list_messages(conversation)

    {:noreply,
     socket
     |> assign(:conversations, conversations)
     |> assign(:conversation, conversation)
     |> assign(:other_last_read_at, other_last_read_at)
     |> assign(:replying_to, nil)
     # Reset typing when switching chats
     |> assign(:typing_users, %{})
     |> assign(:self_typing, false)
     |> schedule_link_previews(messages)
     |> assign(:messages, messages)
     |> push_event("scroll-to-bottom", %{})
     |> assign(:hide_bottom_nav, true)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket =
      if connected?(socket) and socket.assigns[:subscribed_conversation_uuid] do
        Phoenix.PubSub.unsubscribe(
          Vibeflow.PubSub,
          "conversation:#{socket.assigns.subscribed_conversation_uuid}"
        )

        assign(socket, :subscribed_conversation_uuid, nil)
      else
        socket
      end

    {:noreply, assign(socket, :hide_bottom_nav, false)}
  end

  # ===========================================================================
  # HANDLE EVENTS - All grouped together
  # ===========================================================================

  @impl true
  def handle_event("start_call", _params, socket) do
    conversation = socket.assigns.conversation
    current_user = socket.assigns.current_user

    if conversation.type == "direct" do
      # Find the target user (the other member)
      target_member = Enum.find(conversation.conversation_members, &(&1.user_id != current_user.id))
      target_user = target_member.user

      # Broadcast to the RECIPIENT'S global topic
      VibeflowWeb.Endpoint.broadcast("user_calls:#{target_user.id}", "incoming_call", %{
        from_user_id: current_user.id,
        from_username: current_user.username,
        conversation_uuid: conversation.uuid
      })

      # Subscribe globally for signaling (in case we navigate)
      Phoenix.PubSub.subscribe(Vibeflow.PubSub, "conversation:#{conversation.uuid}")

      # For the initiator, the "display user" is the target_user
      active_call = %{
        status: :calling,
        display_user: target_user,
        conversation_uuid: conversation.uuid,
        start_time: nil
      }

      {:noreply, assign(socket, :active_call, active_call)}
    else
      {:noreply, put_flash(socket, :error, "Voice calls only supported in direct chats for now.")}
    end
  end

  @impl true
  def handle_event("validate", %{"message" => %{"content" => content}}, socket) do
    {:noreply, assign(socket, :composer_content, content || "")}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_typing_indicator", %{"is_typing" => is_typing}, socket) do
    current_user = socket.assigns.current_user
    conversation = socket.assigns.conversation

    if conversation do
      # Broadcast typing status to other users in the conversation
      VibeflowWeb.Endpoint.broadcast_from(self(), "conversation:#{conversation.uuid}", "typing", %{
        user: %{id: current_user.id, username: current_user.username},
        typing: is_typing
      })
    end

    {:noreply, assign(socket, :self_typing, is_typing)}
  end

  @impl true
  def handle_event("change_conversation_skin", %{"skin" => skin}, socket) do
    current_user_id = socket.assigns.current_user.id
    conversation = socket.assigns.conversation

    case Enum.find(conversation.conversation_members, fn m -> m.user_id == current_user_id end) do
      nil ->
        {:noreply, socket}

      member ->
        changeset = member |> Ecto.Changeset.change(message_skin: skin)

        case Vibeflow.Repo.update(changeset) do
          {:ok, _updated_member} ->
            Logger.info("Broadcasting skin change for user #{current_user_id} to skin #{skin} in conversation #{conversation.uuid}")
            VibeflowWeb.Endpoint.broadcast_from(self(), "conversation:#{conversation.uuid}", "skin_changed", %{
              user_id: current_user_id,
              skin: skin
            })

            # Refresh the conversation to show the new skin
            updated_conversation = Chat.get_conversation!(conversation.uuid)
            {:noreply, assign(socket, :conversation, updated_conversation)}

          {:error, _} ->
            {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("preview_entry", %{"ref" => ref}, socket) do
    entry =
      socket.assigns.uploads.media_file.entries
      |> Enum.find(fn e -> e.ref == ref end)

    {:noreply, assign(socket, preview_entry: entry)}
  end

  @impl true
  def handle_event("close_preview", _params, socket) do
    {:noreply, assign(socket, preview_entry: nil)}
  end

  @impl true
  def handle_event("zoom_image", %{"url" => url, "type" => type}, socket) do
    {:noreply, assign(socket, zoomed_image: %{"url" => url, "type" => type})}
  end

  @impl true
  def handle_event("zoom_image", %{"url" => url}, socket) do
    {:noreply, assign(socket, zoomed_image: %{"url" => url, "type" => "image"})}
  end

  @impl true
  def handle_event("close_zoom", _params, socket) do
    {:noreply, assign(socket, zoomed_image: nil)}
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
  def handle_event("cancel-bottle-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :bottle_image, ref)}
  end

  @impl true
  def handle_event("send_message", %{"message" => message_params}, socket) do
    conversation = socket.assigns.conversation
    current_user = socket.assigns.current_user
    replying_to = socket.assigns.replying_to

    # 1. Handle Uploads
    uploaded_files =
      consume_uploaded_entries(socket, :media_file, fn %{path: path}, entry ->
        case Vibeflow.Infrastructure.UploadCloudinary.upload_file(
               path,
               upload_kind_for(entry),
               filename: entry.client_name,
               content_type: entry.client_type
             ) do
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
          messages = Chat.list_messages(conversation)

          {:noreply,
           socket
           |> assign(:replying_to, nil)
           |> assign(:composer_content, "")
           |> assign(:messages, messages)
           |> schedule_link_previews(messages)
           |> push_event("scroll-to-bottom", %{})
           |> assign(:self_typing, false)
           |> push_event("clear-input", %{})}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to send message.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("start_recording", _params, socket) do
    {:noreply, assign(socket, :recording, true)}
  end

  @impl true
  def handle_event("stop_recording", _params, socket) do
    entries = socket.assigns.uploads.audio.entries
    ready = Enum.filter(entries, &(&1.progress == 100))

    Logger.debug(
      ">>> VOICENOTE: stop_recording triggered. Total: #{length(entries)}, Ready: #{length(ready)}"
    )

    socket =
      cond do
        length(ready) > 0 ->
          send_audio_message(socket)

        length(entries) > 0 or socket.assigns.audio_retry_count < 10 ->
          Process.send_after(self(), :retry_audio_upload, 500)
          assign(socket, :audio_retry_count, socket.assigns.audio_retry_count + 1)

        true ->
          socket
      end

    {:noreply, assign(socket, :recording, false)}
  end

  @impl true
  def handle_event("cancel_recording", _params, socket) do
    {:noreply, assign(socket, :recording, false) |> assign(:audio_retry_count, 0)}
  end

  @impl true
  def handle_event("toggle_new_chat_actions", _, socket) do
    {:noreply, assign(socket, :show_new_chat_actions, not socket.assigns.show_new_chat_actions)}
  end

  @impl true
  def handle_event("close_new_chat_overlays", _, socket) do
    {:noreply,
     socket
     |> assign(:show_new_chat_actions, false)
     |> assign(:show_direct_chat_modal, false)
     |> assign(:show_group_modal, false)
     |> assign(:show_bottle_modal, false)}
  end

  @impl true
  def handle_event("open_direct_chat_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_new_chat_actions, false)
     |> assign(:show_direct_chat_modal, true)
     |> assign(:show_group_modal, false)
     |> assign(:show_bottle_modal, false)
     |> assign(:direct_search_query, "")
     |> assign(:direct_search_results, [])}
  end

  @impl true
  def handle_event("open_group_chat_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_new_chat_actions, false)
     |> assign(:show_direct_chat_modal, false)
     |> assign(:show_group_modal, true)
     |> assign(:show_bottle_modal, false)
     |> assign(:group_search_query, "")
     |> assign(:group_search_results, [])
     |> assign(:selected_group_members, [])
     |> assign(:group_name, "")}
  end

  @impl true
  def handle_event("open_bottle_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_new_chat_actions, false)
     |> assign(:show_direct_chat_modal, false)
     |> assign(:show_group_modal, false)
     |> assign(:show_bottle_modal, true)
     |> assign(:bottle_content, "")}
  end

  @impl true
  def handle_event("search_direct_users", %{"query" => query}, socket) do
    current_user = socket.assigns.current_user

    results =
      if String.length(String.trim(query)) >= 2 do
        Accounts.search_users(query, current_user.id)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:direct_search_query, query)
     |> assign(:direct_search_results, results)}
  end

  @impl true
  def handle_event("search_group_users", %{"query" => query}, socket) do
    current_user = socket.assigns.current_user

    results =
      if String.length(String.trim(query)) >= 2 do
        Accounts.search_users(query, current_user.id)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:group_search_query, query)
     |> assign(:group_search_results, results)}
  end

  @impl true
  def handle_event("update_bottle_content", %{"bottle" => %{"content" => content}}, socket) do
    {:noreply, assign(socket, :bottle_content, content || "")}
  end

  @impl true
  def handle_event("throw_bottle", %{"bottle" => bottle_params}, socket) do
    current_user = socket.assigns.current_user
    uploaded_files = consume_bottle_uploads(socket)

    params =
      bottle_params
      |> Map.put("media_files", uploaded_files)
      |> Map.put_new("content", "")

    case BottleService.throw_bottle(params, current_user.id) do
      {:ok, %{conversation: conversation}} ->
        {:noreply,
         socket
         |> assign(:show_bottle_modal, false)
         |> assign(:bottle_content, "")
         |> assign(:conversations, visible_conversations(current_user.id, socket.assigns[:chat_filter] || "all"))
         |> put_flash(:info, "Your bottle is out at sea.")
         |> push_patch(to: ~p"/chat/#{conversation.uuid}")}

      {:error, :bottle_access_required} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "You need the Message in a Bottle item from the Wave Store before you can throw one."
         )}

      {:error, :unsafe_bottle_message} ->
        {:noreply,
         put_flash(socket, :error, "Bottle messages cannot contain abusive or vulgar language.")}

      {:error, :bottle_message_must_be_kind} ->
        {:noreply,
         put_flash(socket, :error, "Bottle messages must be kind, comforting, or encouraging.")}

      {:error, :empty_bottle_message} ->
        {:noreply,
         put_flash(socket, :error, "Add a kind message or an image before throwing the bottle.")}

      {:error, {:bottle_cooldown, hours}} ->
        {:noreply,
         put_flash(socket, :error, "You've already thrown a bottle today. Try again in #{hours} hours.")}

      {:error, :bottle_access_required} ->
        {:noreply,
         put_flash(socket, :error, "You need a Message Bottle to do that. Visit the store!")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Bottle send failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("toggle_new_chat_modal", _, socket) do
    current_user = socket.assigns.current_user

    # Load user's followers and following
    followers = Accounts.get_user_followers(current_user.id)
    following = Accounts.get_user_following(current_user.id)

    # Set initial filtered users based on selected tab
    filtered_users = if socket.assigns.selected_tab == "followers", do: followers, else: following

    {:noreply,
     socket
     |> assign(:show_new_chat_modal, not socket.assigns.show_new_chat_modal)
     |> assign(:followers, followers)
     |> assign(:following, following)
     |> assign(:filtered_users, filtered_users)
    |> put_flash(:info, "Select users to start a new chat or create a group!")
  }
  end

  @impl true
  def handle_event("select_user_tab", %{"tab" => tab}, socket) do
    current_user = socket.assigns.current_user

    # Load users based on selected tab
    filtered_users = case tab do
      "followers" -> Accounts.get_user_followers(current_user.id)
      "following" -> Accounts.get_user_following(current_user.id)
      _ -> []
    end

    {:noreply,
     socket
     |> assign(:selected_tab, tab)
     |> assign(:filtered_users, filtered_users)}
  end

  @impl true
  def handle_event("search_users_in_modal", %{"_target" => ["query"], "query" => query}, socket) do
    current_user = socket.assigns.current_user

    search_results = if String.length(query) >= 2 do
      Accounts.search_users(query, current_user.id)
    else
      # Return empty list when query is too short
      []
    end

    {:noreply,
     socket
     |> assign(:filtered_users, search_results)}
  end

  @impl true
  def handle_event("search_users_in_modal", %{}, socket) do
    # Handle empty search - return default list
    current_user = socket.assigns.current_user

    default_users = case socket.assigns.selected_tab do
      "followers" -> Accounts.get_user_followers(current_user.id)
      "following" -> Accounts.get_user_following(current_user.id)
      _ -> []
    end

    {:noreply, assign(socket, :filtered_users, default_users)}
  end

  @impl true
  def handle_event("search_new_chat", %{"query" => query}, socket) do
    current_user = socket.assigns.current_user

    search_results = if String.length(query) >= 2 do
      Accounts.search_users(query, current_user.id)
    else
      []
    end

    {:noreply,
     socket
     |> assign(:user_search_query, query)
     |> assign(:user_search_results, search_results)}
  end

  @impl true
  def handle_event("clear_user_search", _, socket) do
    {:noreply,
     socket
     |> assign(:user_search_query, "")
     |> assign(:user_search_results, [])}
  end

  @impl true
  def handle_event("toggle_chat_menu", _, socket) do
    {:noreply, assign(socket, :show_chat_menu, not socket.assigns.show_chat_menu)}
  end

  @impl true
  def handle_event("toggle_group_modal", _, socket) do
    current_user = socket.assigns.current_user

    # Load user's followers and following for group creation
    followers = Accounts.get_user_followers(current_user.id)
    following = Accounts.get_user_following(current_user.id)

    # Set initial filtered users based on selected tab
    filtered_users = if socket.assigns.selected_tab == "followers", do: followers, else: following

    {:noreply,
     socket
     |> assign(:show_group_modal, not socket.assigns.show_group_modal)
     |> assign(:show_chat_menu, false)  # Close dropdown when opening modal
     |> assign(:followers, followers)
     |> assign(:following, following)
     |> assign(:filtered_users, filtered_users)
     |> put_flash(:info, "Create a new group chat!")}
  end

  @impl true
  def handle_event("start_new_chat", %{"user_id" => user_id}, socket) do
    current_user = socket.assigns.current_user
    target_user_id = String.to_integer(user_id)

    # Check if conversation already exists
    case Chat.find_or_create_direct_conversation(current_user.id, target_user_id) do
      {:ok, conversation} ->
        {:noreply,
         socket
         |> assign(:show_direct_chat_modal, false)
         |> assign(:user_search_query, "")
         |> assign(:user_search_results, [])
         |> push_patch(to: ~p"/chat/#{conversation.uuid}")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to start chat: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("toggle_user_selection", %{"user-id" => user_id}, socket) do
    require Logger
    Logger.info("toggle_user_selection called with user_id=#{user_id}")

    current_members = socket.assigns.selected_group_members || []
    user_id = String.to_integer(user_id)

    new_members = if user_id in current_members do
      List.delete(current_members, user_id)
    else
      [user_id | current_members]
    end

    Logger.info("Selected members updated: #{inspect(new_members)}")

    {:noreply, assign(socket, :selected_group_members, new_members)}
  end

  @impl true
  def handle_event("update_group_name", %{"group_name" => group_name}, socket) do
    {:noreply, assign(socket, :group_name, group_name)}
  end

  @impl true
  def handle_event("reset_group_form", _, socket) do
    {:noreply,
     socket
     |> assign(:group_name, "")
     |> assign(:selected_group_members, [])}
  end

  @impl true
  def handle_event("create_group", %{"group_name" => group_name}, socket) do
    current_user = socket.assigns.current_user
    selected_members = socket.assigns.selected_group_members || []

    if group_name != "" and length(selected_members) > 0 do
      # Create new group conversation
      case Chat.create_group_conversation(current_user.id, group_name, selected_members) do
        {:ok, conversation} ->
          # Notify all users in real-time
          Enum.each(selected_members, fn member_id ->
            if member_id != current_user.id do
              VibeflowWeb.Endpoint.broadcast_from(
                self(),
                "user:#{member_id}",
                "group_invitation",
                %{
                  conversation_id: conversation.id,
                  conversation_name: group_name,
                  invited_by: current_user.username,
                  invited_by_id: current_user.id
                }
              )
            end
          end)

          {:noreply,
           socket
           |> assign(:show_group_modal, false)
           |> assign(:show_chat_menu, false)
           |> assign(:group_name, "")
           |> assign(:group_search_query, "")
           |> assign(:group_search_results, [])
           |> assign(:selected_group_members, [])
           |> put_flash(:info, "Group '#{group_name}' created successfully!")
           |> push_patch(to: ~p"/chat/#{conversation.uuid}")}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to create group: #{inspect(reason)}")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Please provide a group name and select at least one member")}
    end
  end

  @impl true
  def handle_event("prepare_reply", %{"id" => message_id}, socket) do
    # Find the message to reply to
    message = Enum.find(socket.assigns.messages, fn message ->
      message.id == String.to_integer(message_id)
    end)

    if message do
      {:noreply, assign(socket, :replying_to, message |> Vibeflow.Repo.preload([:user]))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_reply", _params, socket) do
    {:noreply, assign(socket, :replying_to, nil)}
  end

  @impl true
  def handle_event("delete_message", %{"id" => message_id}, socket) do
    message_id = String.to_integer(message_id)
    message = Chat.get_message!(message_id)
    current_user = socket.assigns.current_user

    if message.user_id == current_user.id do
      Chat.delete_message(message)
      messages = Chat.list_messages(socket.assigns.conversation)

      {:noreply,
       socket
       |> assign(:messages, messages)
       |> assign(:replying_to, nil)}
    else
      {:noreply, put_flash(socket, :error, "You can only delete your own messages.")}
    end
  end

  @impl true
  def handle_event("filter_chats", %{"filter" => filter}, socket) do
    current_user_id = socket.assigns.current_user.id

    {:noreply,
     socket
     |> assign(:chat_filter, filter)
     |> assign(:conversations, visible_conversations(current_user_id, filter))}
  end

  @impl true
  def handle_event("start_chat_with_user", %{"user_id" => user_id}, socket) do
    current_user = socket.assigns.current_user
    target_user_id = String.to_integer(user_id)

    # Check if conversation already exists
    case Chat.find_or_create_direct_conversation(current_user.id, target_user_id) do
      {:ok, conversation} ->
        {:noreply,
         socket
         |> assign(:show_new_chat_modal, false)
         |> assign(:show_direct_chat_modal, false)
         |> assign(:direct_search_query, "")
         |> assign(:direct_search_results, [])
         |> push_patch(to: ~p"/chat/#{conversation.uuid}")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to start chat: #{inspect(reason)}")}
    end
  end

  # ===========================================================================
  # HANDLE INFO - All grouped together
  # ===========================================================================

  @impl true
  def handle_info(:retry_audio_upload, socket) do
    entries = socket.assigns.uploads.audio.entries
    ready = Enum.filter(entries, &(&1.progress == 100))

    Logger.debug(
      ">>> VOICENOTE: retry_audio_upload. Total: #{length(entries)}, Ready: #{length(ready)}, Count: #{socket.assigns.audio_retry_count}"
    )

    cond do
      length(ready) > 0 ->
        socket = send_audio_message(socket)
        {:noreply, assign(socket, :audio_retry_count, 0)}

      socket.assigns.audio_retry_count < 25 ->
        Process.send_after(self(), :retry_audio_upload, 400)
        {:noreply, assign(socket, :audio_retry_count, socket.assigns.audio_retry_count + 1)}

      true ->
        {:noreply, assign(socket, :audio_retry_count, 0)}
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    active_conversation = socket.assigns.conversation
    current_user_id = socket.assigns.current_user.id

    # Check if we are currently looking at this conversation
    is_current_chat = active_conversation && active_conversation.uuid == message.conversation_uuid

    # Note: We don't reveal bottle sender here - only when receiver opens the chat

    if is_current_chat do
      message =
        message
        |> Vibeflow.Repo.preload(user: [], reply_to: [:user])

      if message.user_id != current_user_id do
        Chat.mark_conversation_as_read(current_user_id, message.conversation_id)
      end

      messages = Chat.list_messages(active_conversation)

      {:noreply,
       socket
       |> assign(:messages, messages)
       |> schedule_link_previews(messages)
       |> push_event("scroll-to-bottom", %{})
       |> assign(:typing_users, %{})
       |> assign(:self_typing, false)
       |> assign(
         :conversations,
         visible_conversations(current_user_id, socket.assigns[:chat_filter] || "all")
       )}
    else
      socket =
        assign(
          socket,
          :conversations,
          visible_conversations(current_user_id, socket.assigns[:chat_filter] || "all")
        )

      if message.user_id != current_user_id do
        message_user =
          case message.user do
            %Vibeflow.Accounts.User{} = u -> u
            _ -> Vibeflow.Repo.get(Vibeflow.Accounts.User, message.user_id)
          end

        username = (message_user && message_user.username) || "Someone"

        {:noreply, put_flash(socket, :info, "New message from #{username}")}
      else
        {:noreply, socket}
      end
    end
  end

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

  @impl true
  def handle_info({:update_sidebar, _message}, socket) do
    conversations =
      visible_conversations(
        socket.assigns.current_user.id,
        socket.assigns[:chat_filter] || "all"
      )

    {:noreply, assign(socket, :conversations, conversations)}
  end

  @impl true
  def handle_info({:new_sidebar_message, _message}, socket) do
    current_user_id = socket.assigns.current_user.id

    # Note: We don't reveal bottle sender here - only when receiver opens the chat
    conversations =
      visible_conversations(
        current_user_id,
        socket.assigns[:chat_filter] || "all"
      )

    {:noreply, assign(socket, :conversations, conversations)}
  end

  @impl true
  def handle_info({:message_read, %{last_read_at: last_read_at, user_id: reader_id}}, socket) do
    # Only update if someone ELSE read messages while I am in the chat
    if reader_id != socket.assigns.current_user.id && socket.assigns.conversation do
      messages = Chat.list_messages(socket.assigns.conversation)

      {:noreply,
       socket
       |> assign(:other_last_read_at, last_read_at)
       |> schedule_link_previews(messages)
       |> assign(:messages, messages)}
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

  @impl true
  def handle_info({:message_deleted, message}, socket) do
    if socket.assigns.conversation &&
         socket.assigns.conversation.id == message.conversation_id do
      messages = Chat.list_messages(socket.assigns.conversation)

      {:noreply,
       socket
       |> assign(:messages, messages)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%{topic: "users:online", event: "presence_diff"}, socket) do
    online_users = VibeflowWeb.Presence.list("users:online")
    
    # Auto-hangup if other user leaves during a call
    socket = if socket.assigns.active_call do
      other_user_id = to_string(socket.assigns.active_call.display_user.id)
      if !Map.has_key?(online_users, other_user_id) do
        # Trigger local cleanup
        Process.send(self(), %Phoenix.Socket.Broadcast{event: "call_ended", payload: %{}}, [])
        put_flash(socket, :info, "Call ended: User disconnected.")
      else
        socket
      end
    else
      socket
    end

    {:noreply, assign(socket, :online_users, online_users)}
  end

  @impl true
  def handle_info({:skin_changed, new_skin}, socket) do
    {:noreply, assign(socket, :active_message_skin, new_skin)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "skin_changed", payload: payload}, socket) do
    Logger.info("Received skin change broadcast: user_id=#{payload.user_id}, skin=#{payload.skin}, current_user=#{socket.assigns.current_user.id}")

    # Always update conversation data for any skin change (including current user's)
    updated_conversation = Chat.get_conversation!(socket.assigns.conversation.uuid)
    messages = Chat.list_messages(updated_conversation)

    Logger.info("Updating conversation with new skin for user #{payload.user_id}")

    {:noreply,
     socket
     |> assign(:conversation, updated_conversation)
     |> assign(:messages, messages)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "bottle_found", payload: payload}, socket) do
    require Logger
    Logger.info("Received bottle_found broadcast for message #{payload.message_id}")
    # Reload messages to show updated is_found status
    if socket.assigns.conversation do
      messages = Chat.list_messages(socket.assigns.conversation)
      Logger.info("Reloaded #{length(messages)} messages after bottle found")
      {:noreply, assign(socket, :messages, messages)}
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

  def format_date_separator(message_datetime) do
    message_date = case message_datetime do
      %DateTime{} -> DateTime.to_date(message_datetime)
      %NaiveDateTime{} -> NaiveDateTime.to_date(message_datetime)
      _ -> Date.utc_today()
    end

    today = Date.utc_today()
    yesterday = Date.add(today, -1)

    case message_date do
      ^today -> "Today"
      ^yesterday -> "Yesterday"
      date ->
        if Date.diff(today, date) < 7 do
          day_names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
          day_number = Date.day_of_week(date)
          Enum.at(day_names, day_number - 1)
        else
          Calendar.strftime(date, "%B %d, %Y")
        end
    end
  end

  def should_show_date_separator?(current_message, previous_message) do
    case {current_message, previous_message} do
      {nil, _} -> false
      {_, nil} -> true  # Always show date for first message
      {curr, prev} ->
        curr_date = case curr.inserted_at do
          %DateTime{} -> DateTime.to_date(curr.inserted_at)
          %NaiveDateTime{} -> NaiveDateTime.to_date(curr.inserted_at)
          _ -> Date.utc_today()
        end
        prev_date = case prev.inserted_at do
          %DateTime{} -> DateTime.to_date(prev.inserted_at)
          %NaiveDateTime{} -> NaiveDateTime.to_date(prev.inserted_at)
          _ -> Date.utc_today()
        end
        Date.compare(curr_date, prev_date) != :eq
    end
  end

  defp get_skin_change_notification(current_message, previous_message, conversation) do
    case {current_message, previous_message} do
      {nil, _} -> nil
      {_, nil} -> nil
      {curr, prev} ->
        curr_skin = get_user_skin_for_conversation(conversation, curr.user_id)
        prev_skin = get_user_skin_for_conversation(conversation, prev.user_id)

        if curr_skin != prev_skin and curr_skin != "default" and curr.user_id == prev.user_id do
          "changed to #{curr_skin}"
        else
          nil
        end
    end
  end

  defp process_messages_with_separators(messages, conversation) do
    messages
    |> Enum.with_index()
    |> Enum.map(fn {message, index} ->
      previous_message = if index > 0, do: Enum.at(messages, index - 1), else: nil

      %{
        message: message,
        show_date_separator: should_show_date_separator?(message, previous_message),
        date_separator_text: if should_show_date_separator?(message, previous_message) do
          format_date_separator(message.inserted_at)
        end,
        skin_change_notification: get_skin_change_notification(message, previous_message, conversation)
      }
    end)
  end

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

  def bottle_sender_visible?(messages, current_user_id) do
    case bottle_message(messages) do
      %{is_found: true, user_id: sender_id, user: %Vibeflow.Accounts.User{}}
      when sender_id != current_user_id ->
        true

      _ ->
        false
    end
  end

  def bottle_sender_name(messages, current_user_id) do
    case bottle_message(messages) do
      %{is_found: true, user_id: sender_id, user: %Vibeflow.Accounts.User{username: username}}
      when sender_id != current_user_id ->
        username

      _ ->
        "Message in a Bottle"
    end
  end

  def bottle_sender_avatar(messages, current_user_id) do
    case bottle_message(messages) do
      %{is_found: true, user_id: sender_id, user: %Vibeflow.Accounts.User{avatar_url: avatar_url}}
      when sender_id != current_user_id ->
        avatar_url

      _ ->
        nil
    end
  end

  def display_message_author(message, current_user_id) do
    cond do
      message.is_bottle == true && message.is_found != true && message.user_id != current_user_id ->
        "Anonymous"

      match?(%Vibeflow.Accounts.User{}, message.user) && message.user.username ->
        message.user.username

      true ->
        "Someone"
    end
  end

  defp bottle_message(messages) do
    Enum.find(messages, & &1.is_bottle)
  end

  defp visible_conversations(user_id, filter) do
    user_id
    |> Chat.list_user_conversations()
    |> apply_chat_filter(filter)
  end

  defp apply_chat_filter(conversations, filter) do
    case filter do
      "direct" -> Enum.filter(conversations, &(&1.type == "direct"))
      "groups" -> Enum.filter(conversations, &(&1.type == "group"))
      "bottles" -> Enum.filter(conversations, &(&1.type == "bottle"))
      _ -> conversations
    end
  end

  defp subscribe_to_conversation(socket, conversation_uuid) when is_binary(conversation_uuid) do
    current_uuid = socket.assigns[:subscribed_conversation_uuid]

    if current_uuid == conversation_uuid do
      socket
    else
      if current_uuid do
        Phoenix.PubSub.unsubscribe(Vibeflow.PubSub, "conversation:#{current_uuid}")
      end

      Phoenix.PubSub.subscribe(Vibeflow.PubSub, "conversation:#{conversation_uuid}")
      assign(socket, :subscribed_conversation_uuid, conversation_uuid)
    end
  end

  defp subscribe_to_conversation(socket, _), do: socket

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

  defp normalize_media_type(resource_type, entry) do
    client_type = entry.client_type || ""
    client_name = entry.client_name || ""
    ext = client_name |> String.downcase() |> Path.extname()

    audio_exts = [".mp3", ".wav", ".ogg", ".flac", ".webm", ".m4a", ".aac", ".opus"]
    video_exts = [".mp4", ".mov", ".webm", ".avi", ".m4v"]

    cond do
      String.starts_with?(client_type, "audio/") -> "audio"
      ext in audio_exts -> "audio"
      String.starts_with?(client_type, "video/") -> "video"
      ext in video_exts -> "video"
      true -> resource_type
    end
  end

  defp upload_kind_for(entry) do
    client_type = entry.client_type || ""
    client_name = entry.client_name || ""
    ext = client_name |> String.downcase() |> Path.extname()

    audio_exts = [".mp3", ".wav", ".ogg", ".flac", ".webm", ".m4a", ".aac", ".opus"]
    image_exts = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".avif"]
    video_exts = [".mp4", ".mov", ".webm", ".avi", ".m4v"]

    cond do
      String.starts_with?(client_type, "audio/") -> :audio
      ext in audio_exts -> :audio
      String.starts_with?(client_type, "image/") -> :image
      ext in image_exts -> :image
      String.starts_with?(client_type, "video/") -> :video
      ext in video_exts -> :video
      true -> :auto
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

  defp consume_audio_uploads(socket) do
    consume_uploaded_entries(socket, :audio, fn %{path: path}, entry ->
      case Vibeflow.Infrastructure.UploadCloudinary.upload_file(
             path,
             upload_kind_for(entry),
             filename: entry.client_name,
             content_type: entry.client_type
           ) do
        {:ok, %{url: url, resource_type: type}} ->
          {:ok, %{"url" => url, "type" => normalize_media_type(type, entry)}}

        {:error, reason} ->
          Logger.error(">>> VOICENOTE: Cloudflare R2 failed: #{inspect(reason)}")
          {:ok, nil}
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  defp consume_bottle_uploads(socket) do
    consume_uploaded_entries(socket, :bottle_image, fn %{path: path}, entry ->
      case Vibeflow.Infrastructure.UploadCloudinary.upload_file(
             path,
             upload_kind_for(entry),
             filename: entry.client_name,
             content_type: entry.client_type
           ) do
        {:ok, %{url: url, resource_type: type}} ->
          {:ok, %{"url" => url, "type" => normalize_media_type(type, entry)}}

        {:error, _reason} ->
          {:ok, nil}
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end
end
