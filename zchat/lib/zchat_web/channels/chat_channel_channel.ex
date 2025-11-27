defmodule ZchatWeb.ChatChannelChannel do
  use ZchatWeb, :channel
  alias Zchat.Chat
  alias Zchat.Accounts.User

  @impl true
  def join("chat_topic", _params, socket) do
    # Only authenticated users can join the global chat topic
    if socket.assigns.current_user do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Join a specific chat room (for public/group chat rooms)
  @impl true
  def join("chat_room:" <> room_id, _params, socket) do
    user = socket.assigns.current_user

    # You can add room-specific authorization here
    # For now, allow any authenticated user to join any room
    if user do
      socket = assign(socket, :room_id, room_id)
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Handle typing indicators
  @impl true
  def handle_in("typing", %{"is_typing" => is_typing}, socket) do
    user = socket.assigns.current_user
    room_id = socket.assigns[:room_id] || "global"

    broadcast(socket, "user_typing", %{
      user_id: user.id,
      username: user.username,
      is_typing: is_typing,
      room_id: room_id
    })

    {:noreply, socket}
  end

  # Handle public chat messages (not conversation-specific)
  @impl true
  def handle_in("public_message", %{"content" => content}, socket) do
    user = socket.assigns.current_user

    if String.trim(content) != "" do
      message_data = %{
        id: generate_message_id(),
        content: String.trim(content),
        user: %{
          id: user.id,
          username: user.username,
          avatar_url: user.avatar_url
        },
        inserted_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        room_id: socket.assigns[:room_id] || "global"
      }

      broadcast(socket, "new_public_message", message_data)
      {:noreply, socket}
    else
      {:reply, {:error, %{errors: "Message cannot be empty"}}, socket}
    end
  end

  # Handle user presence (online/offline status)
  @impl true
  def handle_in("presence_update", %{"status" => status}, socket) do
    user = socket.assigns.current_user

    broadcast(socket, "presence_change", %{
      user_id: user.id,
      username: user.username,
      status: status, # "online", "offline", "away"
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })

    {:noreply, socket}
  end

  # Legacy ping handler - keep for compatibility
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # Legacy shout handler - redirect to public_message
  @impl true
  def handle_in("shout", payload, socket) do
    handle_in("public_message", payload, socket)
  end

  # Generate a unique message ID for public messages
  defp generate_message_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
