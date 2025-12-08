defmodule ZchatWeb.Chat.ChatLive do
  use ZchatWeb, :live_view

  alias Zchat.Chat
  alias Zchat.Accounts
  alias Zchat.Chat.Message
  alias Zchat.Chat.Conversation
  alias ZchatWeb.Presence

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Zchat.PubSub, "user_sidebar:#{current_user.id}")

      Presence.track(self(), "users:online", current_user.id, %{
        username: current_user.username,
        online_at: inspect(System.system_time(:second))
      })
      ZchatWeb.Endpoint.subscribe("users:online")
    end

    conversations = Chat.list_user_conversations(current_user.id)
    online_users = Presence.list("users:online")

    {:ok,
     socket
     |> assign(:conversations, conversations)
     |> assign(:conversation, nil)
     |> assign(:typing_users, %{})
     |> assign(:online_users, online_users)
     |> assign(:other_last_read_at, nil)
     |> stream(:messages, [])}
  end

  # 1. SPECIFIC CHAT SELECTED
  @impl true
  def handle_params(%{"id" => conversation_id}, _uri, socket) do
    current_user_id = socket.assigns.current_user.id
    conversation = Chat.get_conversation!(conversation_id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Zchat.PubSub, "conversation:#{conversation.id}")
    end

    # A. Mark as Read
    Chat.mark_conversation_as_read(current_user_id, conversation.id)

    # B. RE-FETCH Sidebar List (so red badge clears)
    conversations = Chat.list_user_conversations(current_user_id)

    # C. Get View Details
    other_member = Enum.find(conversation.conversation_members, fn m -> m.user_id != current_user_id end)
    other_last_read_at = if other_member, do: other_member.last_read_at, else: nil
    messages = Chat.list_messages(conversation)

    {:noreply,
      socket
      |> assign(:conversations, conversations)
      |> assign(:conversation, conversation)
      |> assign(:other_last_read_at, other_last_read_at)
      |> stream(:messages, messages, reset: true)}
  end

  # 2. DEFAULT ROUTE (No ID) - Just stay on the page (empty state)
  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  # --- HANDLERS ---

  # New Message Logic
  @impl true
  def handle_info({:new_message, message}, socket) do
    socket =
      socket
      |> stream_insert(:messages, message)
      |> push_event("scroll-to-bottom", %{})

    active_conversation = socket.assigns.conversation
    current_user_id = socket.assigns.current_user.id

    # Auto-Read Logic - Enhanced for real-time read status
    if active_conversation &&
       message.conversation_id == active_conversation.id &&
       message.user_id != current_user_id do

      # Mark the entire conversation as read immediately
      # This updates last_read_at and broadcasts to sender in real-time
      Chat.mark_conversation_as_read(current_user_id, message.conversation_id)
    end

    {:noreply, socket}
  end

  # Read Receipt Logic
  @impl true
  def handle_info({:message_read, %{last_read_at: last_read_at, user_id: reader_id}}, socket) do
    if reader_id != socket.assigns.current_user.id do
      messages = Chat.list_messages(socket.assigns.conversation.id)
      {:noreply,
       socket
       |> assign(:other_last_read_at, last_read_at)
       |> stream(:messages, messages, reset: true)}
    else
      {:noreply, socket}
    end
  end

  # Sidebar Logic
  @impl true
  def handle_info(:update_sidebar, socket) do
    conversations = Chat.list_user_conversations(socket.assigns.current_user.id)
    {:noreply, assign(socket, :conversations, conversations)}
  end

  # Typing Logic
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "typing", payload: payload}, socket) do
    user_id = payload.user.id
    username = payload.user.username
    is_typing = payload.typing
    current_user_id = socket.assigns.current_user.id

    if user_id != current_user_id do
      typing_users = socket.assigns.typing_users
      new_typing_users = if is_typing, do: Map.put(typing_users, user_id, username), else: Map.delete(typing_users, user_id)
      {:noreply, assign(socket, :typing_users, new_typing_users)}
    else
      {:noreply, socket}
    end
  end

  # Presence Logic
  @impl true
  def handle_info(%{topic: "users:online", event: "presence_diff"}, socket) do
    online_users = ZchatWeb.Presence.list("users:online")
    {:noreply, assign(socket, :online_users, online_users)}
  end

  # Notification Logic
  @impl true
  def handle_info(:update_notifications, socket) do
    send_update(ZchatWeb.Components.NotificationsModal, id: "notifications-modal-desktop")
    {:noreply, socket}
  end

  # Catch-all
  def handle_info(_, socket), do: {:noreply, socket}

  # Client Events
  @impl true
  def handle_event("display_new_message", _, socket), do: {:noreply, socket}

  @impl true
  def handle_event("update_typing_indicator", _, socket), do: {:noreply, socket}

  # Helpers
  defp get_typing_text(typing_users) do
    case map_size(typing_users) do
      0 -> nil
      1 -> "#{Enum.at(Map.values(typing_users), 0)} is typing..."
      2 -> "#{Enum.at(Map.values(typing_users), 0)} and #{Enum.at(Map.values(typing_users), 1)} are typing..."
      n when n > 2 -> "#{n} people are typing..."
    end
  end
   defp content_cut(nil, _), do: ""
  defp content_cut(content, length) do
    if String.length(content) > length do
      String.slice(content, 0, length) <> "..."
    else
      content
    end
  end
end
