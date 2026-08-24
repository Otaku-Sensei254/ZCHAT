defmodule VibeflowWeb.ConversationChannel do
  use VibeflowWeb, :channel

  intercept(["typing", "skin_changed"])

  def join("conversation:" <> conversation_id, _payload, socket) do
    conversation = Vibeflow.Chat.get_conversation!(conversation_id)
    Phoenix.PubSub.subscribe(Vibeflow.PubSub, "conversation:#{conversation.uuid}")
    {:ok, assign(socket, :conversation_id, conversation.id)}
  end

  def handle_in("new_message", %{"content" => content}, socket) do
    user = socket.assigns.current_user
    conversation_id = socket.assigns.conversation_id

    case Vibeflow.Chat.create_message(%{
           content: content,
           conversation_id: conversation_id,
           user_id: user.id
         }) do
      {:ok, _message} ->
        {:reply, :ok, socket}

      {:error, _changeset} ->
        {:reply, {:error, %{error: "Failed to create message"}}, socket}
    end
  end

  def handle_in("typing", %{"typing" => is_typing}, socket) do
    user = socket.assigns.current_user

    broadcast_from!(socket, "typing", %{
      user: %{id: user.id, username: user.username},
      typing: is_typing
    })

    {:noreply, socket}
  end

  def handle_out("typing", payload, socket) do
    push(socket, "typing", payload)
    {:noreply, socket}
  end

  def handle_out("skin_changed", payload, socket) do
    push(socket, "skin_changed", payload)
    {:noreply, socket}
  end

  def handle_info({:new_message, message}, socket) do
    {user, media} = {message.user, message.media_files || []}

    post_data =
      if message.shared_post do
        p = message.shared_post
        pu = p.user
        %{
          id: p.id, uuid: p.uuid, content: p.content,
          media_files: p.media_files || [],
          first_media: List.first(p.media_files || []),
          user: pu && %{id: pu.id, username: pu.username, avatar_url: pu.avatar_url}
        }
      end

    wave_data =
      if message.shared_wave do
        w = message.shared_wave
        wu = w.user
        %{
          id: w.id, uuid: w.uuid, media_url: w.media_url, media_type: w.media_type, caption: w.caption,
          user: wu && %{id: wu.id, username: wu.username, avatar_url: wu.avatar_url}
        }
      end

    reply_data =
      if message.reply_to do
        r = message.reply_to
        ru = r.user
        %{
          id: r.id, content: r.content,
          user: ru && %{id: ru.id, username: ru.username, avatar_url: ru.avatar_url},
          media_files: r.media_files || []
        }
      end

    payload = %{
      id: message.id,
      content: message.content,
      user_id: message.user_id,
      user: user && %{id: user.id, username: user.username, avatar_url: user.avatar_url},
      media_files: media,
      reply_to_id: message.reply_to_id,
      reply_to: reply_data,
      shared_post_id: message.shared_post_id,
      shared_post: post_data,
      shared_wave_id: message.shared_wave_id,
      shared_wave: wave_data,
      inserted_at: message.inserted_at,
      is_read: false,
      conversation_uuid: Map.get(message, :conversation_uuid)
    }

    push(socket, "new_message", payload)
    {:noreply, socket}
  end

  def handle_info({:message_read, payload}, socket) do
    push(socket, "message_read", %{
      user_id: payload.user_id,
      last_read_at: payload.last_read_at
    })
    {:noreply, socket}
  end

  def handle_info({:message_deleted, message}, socket) do
    push(socket, "message_deleted", %{id: message.id})
    {:noreply, socket}
  end

  def handle_info({:message_updated, message}, socket) do
    push(socket, "message_updated", %{
      id: message.id,
      content: message.content,
      updated_at: message.updated_at
    })
    {:noreply, socket}
  end
end
