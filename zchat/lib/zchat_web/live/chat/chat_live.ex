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

      Presence.track(self(), "online_users", current_user.id, %{
        username: current_user.username,
        online_at: inspect(System.system_time(:second))
      })
      ZchatWeb.Endpoint.subscribe("online_users")
    end

    conversations = Chat.list_user_conversations(current_user.id)
    online_users = Presence.list("online_users")

    {:ok,
     socket
     |> assign(:conversations, conversations)
     |> assign(:conversation, nil)
     |> assign(:typing_users, %{})
     |> assign(:online_users, online_users)
     |> assign(:other_last_read_at, nil)
     |> stream(:messages, [])}
  end

  @impl true
  def handle_params(%{"id" => conversation_id}, _uri, socket) do
    current_user_id = socket.assigns.current_user.id
    conversation = Chat.get_conversation!(conversation_id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Zchat.PubSub, "conversation:#{conversation.id}")
    end

    Chat.mark_conversation_as_read(current_user_id, conversation.id)

    other_member = Enum.find(conversation.conversation_members, fn m -> m.user_id != current_user_id end)
    other_last_read_at = if other_member, do: other_member.last_read_at, else: nil

    conversations = Chat.list_user_conversations(current_user_id)
    messages = Chat.list_messages(conversation)

    socket =
      socket
      |> assign(:conversations, conversations)
      |> assign(:conversation, conversation)
      |> assign(:other_last_read_at, other_last_read_at)
      |> stream(:messages, messages, reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    case socket.assigns.conversations do
      [first_conversation | _] ->
        {:noreply, push_patch(socket, to: ~p"/chat/#{first_conversation.id}")}
      [] ->
        {:noreply, socket}
    end
  end

  # --- HANDLERS ---

  @impl true
  def handle_info(:update_sidebar, socket) do
    conversations = Chat.list_user_conversations(socket.assigns.current_user.id)
    {:noreply, assign(socket, :conversations, conversations)}
  end

  @impl true
  def handle_info({:message_read, %{user_id: user_id, last_read_at: last_read_at}}, socket) do
    current_user_id = socket.assigns.current_user.id

    if user_id != current_user_id do
      socket = assign(socket, :other_last_read_at, last_read_at)
      messages = Chat.list_messages(socket.assigns.conversation.id)
      {:noreply, stream(socket, :messages, messages, reset: true)}
    else
      {:noreply, socket}
    end
  end

  # --- FIX IS HERE: HANDLE TYPING BROADCAST FROM CHANNEL ---
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "typing", payload: payload}, socket) do
    user_id = payload.user.id
    username = payload.user.username
    is_typing = payload.typing
    current_user_id = socket.assigns.current_user.id

    if user_id != current_user_id do
      typing_users = socket.assigns.typing_users

      new_typing_users = if is_typing do
        Map.put(typing_users, user_id, username)
      else
        Map.delete(typing_users, user_id)
      end

      {:noreply, assign(socket, :typing_users, new_typing_users)}
    else
      {:noreply, socket}
    end
  end

  # Catch-all for other broadcasts (like "new_message" which JS handles)
  def handle_info({:new_message, _msg}, socket), do: {:noreply, socket}

  # Catch-all for Broadcast structs we don't care about
  def handle_info(%Phoenix.Socket.Broadcast{}, socket), do: {:noreply, socket}

  @impl true
  def handle_info(%{topic: "online_users", event: "presence_diff", payload: _diff}, socket) do
    online_users = ZchatWeb.Presence.list("online_users")
    {:noreply, assign(socket, :online_users, online_users)}
  end

  # --- CLIENT EVENTS ---

  @impl true
  def handle_event("display_new_message", message, socket) do
    message_struct = %Message{
      id: message["id"],
      content: message["content"],
      inserted_at: Timex.parse!(message["inserted_at"], "{ISO:Extended:Z}"),
      user_id: message["user"]["id"],
      user: %Zchat.Accounts.User{
        id: message["user"]["id"],
        username: message["user"]["username"],
        avatar_url: message["user"]["avatar_url"]
      }
    }

    {:noreply,
      socket
      |> stream_insert(:messages, message_struct)
      |> push_event("scroll-to-bottom", %{})}
  end

  # We keep this for redundancy, or you can remove the JS pushEvent for typing
  # since handle_info now does the job!
  @impl true
  def handle_event("update_typing_indicator", %{"user_id" => user_id, "username" => username, "is_typing" => is_typing}, socket) do
    current_user_id = socket.assigns.current_user.id

    if user_id != current_user_id do
      typing_users = socket.assigns.typing_users
      new_typing_users = if is_typing, do: Map.put(typing_users, user_id, username), else: Map.delete(typing_users, user_id)
      {:noreply, assign(socket, :typing_users, new_typing_users)}
    else
      {:noreply, socket}
    end
  end

  # --- UI HELPERS ---

  defp get_typing_text(typing_users) do
    case map_size(typing_users) do
      0 -> nil
      1 -> "#{Enum.at(Map.values(typing_users), 0)} is typing..."
      2 -> "#{Enum.at(Map.values(typing_users), 0)} and #{Enum.at(Map.values(typing_users), 1)} are typing..."
      n when n > 2 -> "#{n} people are typing..."
    end
  end
end
