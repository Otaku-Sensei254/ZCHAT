defmodule Vibeflow.Chat do
  import Ecto.Query, warn: false
  alias Vibeflow.Repo
  alias Vibeflow.Chat.{Message, Conversation, ConversationMember}
  alias Vibeflow.Accounts.User
  alias Vibeflow.Notifications
  alias Vibeflow.Posts
  # --- CONVERSATIONS ---

  def get_conversation_by_uuid!(uuid) do
    Conversation
    |> Repo.get_by!(uuid: uuid)
    |> Repo.preload(conversation_members: :user)
  end

  def get_conversation_by_uuid(uuid) do
    Conversation
    |> Repo.get_by(uuid: uuid)
    |> Repo.preload(conversation_members: :user)
  end

  def get_conversation!(id_or_uuid) do
    case Ecto.UUID.cast(id_or_uuid) do
      {:ok, uuid} ->
        get_conversation_by_uuid!(uuid)
      :error ->
        Conversation
        |> Repo.get!(id_or_uuid)
        |> Repo.preload(conversation_members: :user)
    end
  end

  def list_user_conversations(%User{} = user), do: list_user_conversations(user.id)

  def list_user_conversations(user_id) do
    # Define query first to avoid compilation errors
    query =
      from(c in Conversation,
        join: convom in assoc(c, :conversation_members),
        where: convom.user_id == ^user_id,
        left_join: m in assoc(c, :messages),
        # Count unread messages (newer than last_read_at, not from self)
        on:
          m.conversation_id == c.id and m.inserted_at > convom.last_read_at and
            m.user_id != ^user_id,
        preload: [conversation_members: :user],
        group_by: [c.id, convom.id],
        order_by: [desc: c.updated_at],
        select: %{c | unread_count: count(m.id)}
      )

    Repo.all(query)
  end

  def get_or_create_private_conversation(user_id_1, user_id_2) do
    case find_private_conversation(user_id_1, user_id_2) do
      nil -> create_private_conversation(user_id_1, user_id_2)
      conversation -> {:ok, conversation}
    end
  end

  defp create_private_conversation(uid1, uid2) do
    Repo.transaction(fn ->
      conv = Repo.insert!(%Conversation{type: "direct"})
      Repo.insert!(%ConversationMember{conversation_id: conv.id, user_id: uid1})
      Repo.insert!(%ConversationMember{conversation_id: conv.id, user_id: uid2})
      conv
    end)
  end

  defp find_private_conversation(u1, u2) do
    query =
      from(cm in ConversationMember,
        where: cm.user_id in [^u1, ^u2],
        group_by: cm.conversation_id,
        having: count(cm.user_id) == 2,
        select: cm.conversation_id
      )

    case Repo.one(query) do
      nil -> nil
      id -> Repo.get(Conversation, id)
    end
  end

  def subscribe_to_conversation(conversation) do
    Phoenix.PubSub.subscribe(Vibeflow.PubSub, "conversation:#{conversation.uuid}")
  end

  # --- MESSAGES ---

  def get_message!(id) do
    Repo.get!(Message, id)
    |> Repo.preload([:user])
  end

  def list_messages(conversation_id)
      when is_binary(conversation_id) or is_integer(conversation_id) do
    from(m in Message,
      where: m.conversation_id == ^conversation_id,
      order_by: [asc: m.inserted_at],
      preload: [:user, shared_post: :user, reply_to: :user]
    )
    |> Repo.all()
  end

  def list_messages(%Conversation{} = conversation), do: list_messages(conversation.id)

  def create_message(attrs) do
    result =
      %Message{}
      |> Message.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, message} ->
        # 1. Bump the conversation's "updated_at" so it jumps to top
        touch_conversation(message.conversation_id)
        convo = Repo.get!(Conversation, message.conversation_id)
        broadcast_message(convo, message)
        notify_sidebar_members(message.conversation_id, message)
        {:ok, message}

      error ->
        error
    end
  end

  # [NEW] Added Delete Functionality
  def delete_message(message) do
    # 1. Delete from DB
    Repo.delete(message)
    convo = Repo.get!(Conversation, message.conversation_id)

    # 2. Broadcast to LiveView so it disappears instantly
    Phoenix.PubSub.broadcast(
      Vibeflow.PubSub,
      "conversation:#{convo.uuid}",
      {:message_deleted, message}
    )
  end

  defp notify_sidebar_members(conversation_id, message) do
    members =
      from(convom in ConversationMember,
        where: convom.conversation_id == ^conversation_id,
        select: convom.user_id
      )
      |> Repo.all()
    # Ensure the message has its associations preloaded (user, shared_post, reply_to)
    preloaded_message =
      Repo.get(Message, message.id)
      |> Repo.preload([:user, shared_post: :user, reply_to: :user])

    Enum.each(members, fn user_id ->
      # Broadcast a "new_sidebar_message" event so the universal
      # UserActivityHook can show a popup AND refresh the unread count
      # regardless of which LiveView/page the recipient is on.
      Phoenix.PubSub.broadcast(
        Vibeflow.PubSub,
        "user_sidebar:#{user_id}",
        {:new_sidebar_message, preloaded_message}
      )
    end)
  end

  defp touch_conversation(conversation_id) do
    from(c in Conversation, where: c.id == ^conversation_id)
    |> Repo.update_all(set: [updated_at: DateTime.utc_now()])
  end

  def broadcast_message(conversation, message) do
    # Preload user so the LiveView can display avatar/username immediately
    message = Repo.preload(message, [:user, shared_post: :user, reply_to: :user])

    # Include conversation_uuid in the message map for easier routing in LiveView
    message_with_uuid = Map.put(message, :conversation_uuid, conversation.uuid)

    Phoenix.PubSub.broadcast(
      Vibeflow.PubSub,
      "conversation:#{conversation.uuid}",
      {:new_message, message_with_uuid}
    )
  end

  def mark_message_as_read(message_id) do
    Repo.get(Message, message_id)
    |> Ecto.Changeset.change(read_at: DateTime.utc_now())
    |> Repo.update()
  end

  def member_of_conversation?(user, conversation_id) do
    query =
      from(convom in ConversationMember,
        where: convom.user_id == ^user.id and convom.conversation_id == ^conversation_id
      )

    Repo.exists?(query)
  end

  def mark_conversation_as_read(user_id, conversation_id) do
    from(convom in ConversationMember,
      where: convom.user_id == ^user_id and convom.conversation_id == ^conversation_id
    )
    |> Repo.one()
    |> case do
      nil ->
        {:error, :not_found}

      member ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        convo = Repo.get!(Conversation, conversation_id)

        {:ok, updated_member} =
          member
          |> Ecto.Changeset.change(last_read_at: now)
          |> Repo.update()

        Phoenix.PubSub.broadcast(
          Vibeflow.PubSub,
          "conversation:#{convo.uuid}",
          {:message_read,
           %{user_id: user_id, conversation_id: conversation_id, last_read_at: now}}
        )

        Phoenix.PubSub.broadcast(
          Vibeflow.PubSub,
          "user_sidebar:#{user_id}",
          :update_sidebar
        )

        {:ok, updated_member}
    end
  end

  # check for unread convos
  def count_unread_conversations(user_id) do
    from(convo in Conversation,
      join: convom in assoc(convo, :conversation_members),
      join: messo in assoc(convo, :messages),
      where: convom.user_id == ^user_id,
      where: messo.inserted_at > convom.last_read_at and messo.user_id != ^user_id,
      select: count(convo.id, :distinct)
    )
    |> Repo.one() || 0
  end

  # sharing reels/posts
  def share_posts_to_friend(sender_id, friend_id, post_id) do
    {:ok, conversation} = get_or_create_private_conversation(sender_id, friend_id)
    # now get the post
    post =
      Repo.get!(Vibeflow.Posts.Post, post_id)
      |> Repo.preload(:user)

    content = "Shared a post"

    {:ok, message} =
      create_message(%{
        content: content,
        user_id: sender_id,
        conversation_id: conversation.id,
        shared_post_id: post_id
      })

    Notifications.create_notification(%{
      user_id: friend_id,
      actor_id: sender_id,
      type: "shared_post",
      post_id: post_id,
      conversation_id: conversation.id
    })

    {:ok, message}
  end

  # Share post to multiple friends with optional message
  def share_post_to_friends(sender_id, post_id, recipient_ids, message \\ "") do
    # Convert string IDs to integers if needed
    recipient_ids =
      recipient_ids
      |> Enum.map(fn id ->
        case is_binary(id) do
          true -> String.to_integer(id)
          false -> id
        end
      end)

    post =
      Repo.get!(Vibeflow.Posts.Post, post_id)
      |> Repo.preload(:user)

    content = if message && message != "", do: message, else: "Shared a post"

    # Create messages for each recipient
    results =
      Enum.map(recipient_ids, fn recipient_id ->
        case get_or_create_private_conversation(sender_id, recipient_id) do
          {:ok, conversation} ->
            case create_message(%{
              content: content,
              user_id: sender_id,
              conversation_id: conversation.id,
              shared_post_id: post_id
            }) do
              {:ok, message} ->
                # Create notification for the recipient
                Notifications.create_notification(%{
                  user_id: recipient_id,
                  actor_id: sender_id,
                  type: "shared_post",
                  post_id: post_id,
                  conversation_id: conversation.id
                })
                {:ok, message}
              error ->
                error
            end
          error ->
            error
        end
      end)

    # Check if all shares were successful
    case Enum.all?(results, &match?({:ok, _}, &1)) do
      true ->
        {:ok, results}
      false ->
        failed_count = Enum.count(results, &match?({:error, _}, &1))
        {:error, "Failed to share to #{failed_count} recipients"}
    end
  end
end
