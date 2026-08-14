defmodule VibeflowWeb.Api.V1.ChatController do
  use VibeflowWeb, :controller

  def conversations(conn, _params) do
    user = conn.assigns.current_user
    convos = Vibeflow.Chat.list_user_conversations(user)

    json(conn, %{
      data: %{
        conversations: Enum.map(convos, &conversation_json(&1, user.id))
      }
    })
  end

  def messages(conn, %{"uuid" => uuid}) do
    user = conn.assigns.current_user

    case Vibeflow.Chat.get_conversation_by_uuid(uuid) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Conversation not found"})

      conversation ->
        if Vibeflow.Chat.member_of_conversation?(user, conversation.id) do
          messages = Vibeflow.Chat.list_messages(conversation.id)
          # Find the other member's last_read_at for read receipts
          other_member =
            Enum.find(conversation.conversation_members || [], fn m -> m.user_id != user.id end)

          other_last_read = if other_member, do: other_member.last_read_at
          json(conn, %{data: %{messages: Enum.map(messages, &message_json(&1, other_last_read))}})
        else
          conn |> put_status(:forbidden) |> json(%{error: "Not a member"})
        end
    end
  end

  def create_message(conn, %{"uuid" => uuid, "message" => msg_params}) do
    user = conn.assigns.current_user

    case Vibeflow.Chat.get_conversation_by_uuid(uuid) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Conversation not found"})

      conversation ->
        if Vibeflow.Chat.member_of_conversation?(user, conversation.id) do
          params =
            Map.merge(msg_params, %{
              "user_id" => user.id,
              "conversation_id" => conversation.id
            })

          case Vibeflow.Chat.create_message(params) do
            {:ok, message} ->
              conn
              |> put_status(:created)
              |> json(%{data: %{message: message_json(message)}})

            {:error, changeset} ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{errors: format_changeset(changeset)})
          end
        else
          conn |> put_status(:forbidden) |> json(%{error: "Not a member"})
        end
    end
  end

  def start_conversation(conn, %{"username" => username}) do
    current_user = conn.assigns.current_user

    case Vibeflow.Accounts.get_user_by_username(username) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "User not found"})

      target ->
        case Vibeflow.Chat.find_or_create_direct_conversation(current_user.id, target.id) do
          {:ok, conversation} ->
            conversation = Vibeflow.Repo.preload(conversation, conversation_members: :user)

            conn
            |> put_status(:created)
            |> json(%{data: %{conversation: conversation_json(conversation, current_user.id)}})

          {:error, _reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "Could not start conversation"})
        end
    end
  end

  def create_group(conn, %{"group_name" => group_name, "user_ids" => user_ids}) do
    current_user = conn.assigns.current_user
    member_ids = Enum.map(user_ids || [], fn id -> String.to_integer(to_string(id)) end)

    if group_name != "" and length(member_ids) > 0 do
      case Vibeflow.Chat.create_group_conversation(current_user.id, group_name, member_ids) do
        {:ok, conversation} ->
          conversation = Vibeflow.Repo.preload(conversation, conversation_members: :user)

          Enum.each(member_ids, fn member_id ->
            if member_id != current_user.id do
              Phoenix.PubSub.broadcast(
                Vibeflow.PubSub,
                "user_sidebar:#{member_id}",
                :update_sidebar
              )
            end
          end)

          conn
          |> put_status(:created)
          |> json(%{data: %{conversation: conversation_json(conversation, current_user.id)}})

        {:error, reason} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "Failed to create group: #{inspect(reason)}"})
      end
    else
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{error: "Please provide a group name and select at least one member"})
    end
  end

  def throw_bottle(conn, %{"bottle" => bottle_params}) do
    current_user = conn.assigns.current_user

    params =
      bottle_params
      |> Map.put_new("content", "")

    case Vibeflow.Chat.BottleService.throw_bottle(params, current_user.id) do
      {:ok, %{conversation: conversation}} ->
        conversation = Vibeflow.Repo.preload(conversation, conversation_members: :user)

        conn
        |> put_status(:created)
        |> json(%{data: %{conversation: conversation_json(conversation, current_user.id)}})

      {:error, :bottle_access_required} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          error:
            "You need the Message in a Bottle item from the Wave Store before you can throw one."
        })

      {:error, :unsafe_bottle_message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Bottle messages cannot contain abusive or vulgar language."})

      {:error, :bottle_message_must_be_kind} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Bottle messages must be kind, comforting, or encouraging."})

      {:error, :empty_bottle_message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Add a kind message or an image before throwing the bottle."})

      {:error, {:bottle_cooldown, hours}} ->
        conn
        |> put_status(:too_many_requests)
        |> json(%{error: "You've already thrown a bottle today. Try again in #{hours} hours."})

      {:error, :no_recipient_available} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "No one is available to receive your bottle right now. Try again soon."})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Bottle send failed: #{inspect(reason)}"})
    end
  end

  def delete_message(conn, %{"uuid" => _uuid, "id" => id_str}) do
    user = conn.assigns.current_user
    id = String.to_integer(id_str)
    message = Vibeflow.Repo.get(Vibeflow.Chat.Message, id)

    if is_nil(message) do
      conn |> put_status(:not_found) |> json(%{error: "Message not found"})
    else
      if message.user_id == user.id do
        Vibeflow.Chat.delete_message(message)
        json(conn, %{data: %{deleted_id: id}})
      else
        conn |> put_status(:forbidden) |> json(%{error: "Not your message"})
      end
    end
  end

  def update_message(conn, %{"uuid" => _uuid, "id" => id_str, "content" => content}) do
    user = conn.assigns.current_user
    id = String.to_integer(id_str)
    message = Vibeflow.Repo.get(Vibeflow.Chat.Message, id)

    if is_nil(message) do
      conn |> put_status(:not_found) |> json(%{error: "Message not found"})
    else
      if message.user_id == user.id do
        case Vibeflow.Chat.update_message(message, %{content: content}) do
          {:ok, updated_msg} ->
            json(conn, %{data: %{message: message_json(updated_msg)}})

          {:error, _changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to update message"})
        end
      else
        conn |> put_status(:forbidden) |> json(%{error: "Not your message"})
      end
    end
  end

  def mark_read(conn, %{"uuid" => uuid}) do
    user = conn.assigns.current_user

    case Vibeflow.Chat.get_conversation_by_uuid(uuid) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Conversation not found"})

      conversation ->
        Vibeflow.Chat.mark_conversation_as_read(user.id, conversation.id)
        json(conn, %{data: %{message: "Marked as read"}})
    end
  end

  def unread_count(conn, _params) do
    user = conn.assigns.current_user
    count = Vibeflow.Chat.count_unread_conversations(user.id)
    json(conn, %{data: %{unread_count: count}})
  end

  def update_skin(conn, %{"uuid" => uuid, "skin" => skin}) do
    user = conn.assigns.current_user

    case Vibeflow.Chat.get_conversation_by_uuid(uuid) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Conversation not found"})

      conversation ->
        case Enum.find(conversation.conversation_members, fn m -> m.user_id == user.id end) do
          nil ->
            conn |> put_status(:forbidden) |> json(%{error: "Not a member"})

          member ->
            case member
                 |> Ecto.Changeset.change(%{message_skin: skin})
                 |> Vibeflow.Repo.update() do
              {:ok, _updated_member} ->
                VibeflowWeb.Endpoint.broadcast_from(
                  self(),
                  "conversation:#{conversation.uuid}",
                  "skin_changed",
                  %{user_id: user.id, skin: skin, username: user.username}
                )

                conn |> json(%{data: %{success: true, skin: skin}})

              {:error, _} ->
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{error: "Failed to update skin"})
            end
        end
    end
  end

  defp conversation_json(conv, user_id) do
    member = Enum.find(conv.conversation_members || [], fn m -> m.user_id != user_id end)
    my_member = Enum.find(conv.conversation_members || [], fn m -> m.user_id == user_id end)
    other_user = if member, do: member.user

    other_last_read =
      if member, do: member.last_read_at

    %{
      id: conv.id,
      uuid: conv.uuid,
      name: conv.name,
      type: conv.type,
      unread_count: Map.get(conv, :unread_count, 0),
      message_skin: if(my_member, do: my_member.message_skin || "default", else: "default"),
      other_user_message_skin: if(member, do: member.message_skin || "default", else: "default"),
      other_user:
        if(other_user,
          do: %{
            id: other_user.id,
            username: other_user.username,
            avatar_url: other_user.avatar_url,
            is_verified: other_user.is_verified
          }
        ),
      other_user_last_read_at: other_last_read,
      updated_at: conv.updated_at
    }
  end

  defp message_json(msg, other_last_read \\ nil) do
    media = msg.media_files || []

    is_read =
      if other_last_read && msg.inserted_at do
        msg_time =
          msg.inserted_at
          |> DateTime.from_naive!("Etc/UTC")
          |> DateTime.truncate(:second)

        other_time = DateTime.truncate(other_last_read, :second)
        DateTime.compare(msg_time, other_time) != :gt
      else
        false
      end

    post_data =
      if msg.shared_post do
        post = msg.shared_post
        post_user = post.user
        first_media = List.first(post.media_files || [])

        %{
          id: post.id,
          uuid: post.uuid,
          content: post.content,
          media_files: post.media_files,
          first_media: first_media,
          user: %{
            id: post_user.id,
            username: post_user.username,
            avatar_url: post_user.avatar_url
          }
        }
      end

    wave_data =
      if msg.shared_wave do
        wave = msg.shared_wave
        wave_user = wave.user

        %{
          id: wave.id,
          uuid: wave.uuid,
          media_url: wave.media_url,
          media_type: wave.media_type,
          caption: wave.caption,
          user: %{
            id: wave_user.id,
            username: wave_user.username,
            avatar_url: wave_user.avatar_url
          }
        }
      end

    reply_to_data =
      if msg.reply_to do
        replied = msg.reply_to
        replied_user = replied.user

        %{
          id: replied.id,
          content: replied.content,
          user:
            if(replied_user,
              do: %{
                id: replied_user.id,
                username: replied_user.username,
                avatar_url: replied_user.avatar_url
              }
            ),
          media_files: replied.media_files || []
        }
      end

    %{
      id: msg.id,
      content: msg.content,
      user_id: msg.user_id,
      user:
        if(msg.user,
          do: %{
            id: msg.user.id,
            username: msg.user.username,
            avatar_url: msg.user.avatar_url
          }
        ),
      media_files: media,
      reply_to_id: msg.reply_to_id,
      reply_to: reply_to_data,
      shared_post_id: msg.shared_post_id,
      shared_post: post_data,
      shared_wave_id: msg.shared_wave_id,
      shared_wave: wave_data,
      inserted_at: msg.inserted_at,
      updated_at: msg.updated_at,
      is_read: is_read,
      conversation_uuid: Map.get(msg, :conversation_uuid)
    }
  end

  defp format_changeset(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", format_error_value(value))
      end)
    end)
  end

  defp format_error_value(value) when is_list(value), do: Enum.join(value, ", ")
  defp format_error_value(value), do: to_string(value)
end
