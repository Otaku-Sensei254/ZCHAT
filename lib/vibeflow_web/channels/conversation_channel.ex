defmodule VibeflowWeb.ConversationChannel do
  use VibeflowWeb, :channel
  alias Vibeflow.Chat

  def join("conversation:" <> conversation_id, _payload, socket) do
    user = socket.assigns.current_user
    conversation = Vibeflow.Chat.get_conversation!(conversation_id)

    {:ok, assign(socket, :conversation_id, conversation.id)}
  end

  def handle_in("new_message", %{"content" => content}, socket) do
    user = socket.assigns.current_user
    conversation_id = socket.assigns.conversation_id

    case Chat.create_message(%{
           content: content,
           conversation_id: conversation_id,
           user_id: user.id
         }) do
      {:ok, message} ->
        # broadcast!(socket, "new_message", %{
        #   id: message.id,
        #   content: message.content,
        #   conversation_id: message.conversation_id,
        #   inserted_at: message.inserted_at,
        #   user: %{
        #     id: user.id,
        #     username: user.username,
        #     avatar_url: user.avatar_url
        #   }
        # })

        {:reply, :ok, socket}

      {:error, _changeset} ->
        {:reply, {:error, %{error: "Failed to create message"}}, socket}
    end
  end



  def handle_info({:new_message, message}, socket) do
    push(socket, "new_message", %{
      id: message.id,
      content: message.content,
      conversation_id: message.conversation_id,
      # Format date safely for JS
      inserted_at: Calendar.strftime(message.inserted_at, "%Y-%m-%dT%H:%M:%SZ"),
      user: %{
        id: message.user.id,
        username: message.user.username,
        avatar_url: message.user.avatar_url
      }
    })

    {:noreply, socket}
  end


  #HANDLE READ SCRIPTS
  def handle_info({:message_read, _payload}, socket) do
    {:noreply, socket}
  end
  


  #SHOW TYPING ON USER UI
 def handle_in("typing", %{"typing" => is_typing}, socket) do
    user = socket.assigns.current_user

    broadcast_from!(socket, "typing", %{
      user: %{id: user.id, username: user.username},
      typing: is_typing
    })

    {:noreply, socket}
  end


end
