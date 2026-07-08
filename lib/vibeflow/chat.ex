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

  def get_conversation(id_or_uuid) do
    case Ecto.UUID.cast(id_or_uuid) do
      {:ok, uuid} ->
        get_conversation_by_uuid(uuid)

      :error ->
        Conversation
        |> Repo.get(id_or_uuid)
        |> Repo.preload(conversation_members: :user)
    end
  rescue
    _ -> nil
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

  # get convo member active chat text skinny

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
      from(c in Conversation,
        where: c.type == "direct",
        join: cm in ConversationMember,
        on: cm.conversation_id == c.id,
        where: cm.user_id in [^u1, ^u2],
        group_by: c.id,
        having: count(cm.user_id) == 2,
        select: c.id
      )

    case Repo.one(query) do
      nil -> nil
      id -> Repo.get(Conversation, id)
    end
  end

  # lets create group chats now..BOOYAAH
  def create_group_chats(creator, attrs, invited_users_ids) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:conversation, Conversation.changeset(%Conversation{}, attrs))
    |> Ecto.Multi.insert(:creator_member, fn %{conversation: conv} ->
      ConversationMember.changeset(%ConversationMember{}, %{
        conversation_id: conv.id,
        user_id: creator.id,
        role: "admin"
      })
    end)
    |> Ecto.Multi.merge(fn %{conversation: conv} ->
      invited_users_ids
      |> Enum.reduce(Ecto.Multi.new(), fn user_id, multi ->
       Ecto.Multi.insert(
          multi,
          "member_#{user_id}",
          ConversationMember.changeset(%ConversationMember{}, %{
            user_id: user_id,
            conversation_id: conv.id,
            role: "member"
          })
        )
      end)
    end)
    |> Repo.transaction()
  end

  #fetch all group chats
  def list_group_conversations do
    from(c in Conversation,
      where: c.type == "group",
      preload: [conversation_members: :user],
      order_by: [desc: c.updated_at]
    )
    |> Repo.all()
  end

  #list all group members
  def list_conversation_members(conversation_id) do
    from(cm in ConversationMember,
      where: cm.conversation_id == ^conversation_id,
      preload: [:user]
    )
    |> Repo.all()
  end
#get user group chats
def get_my_group_chats(user_id, conversation) do
  from(c in Conversation,
    where: c.type == "group",
    join: cm in assoc(c, :conversation_members),
    where: cm.user_id == ^user_id,
    preload: [conversation_members: :user],
    order_by: [desc: c.updated_at]
  )
  |> Repo.all()
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
      preload: [:user, shared_post: :user, shared_wave: :user, reply_to: :user]
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
        # Return preloaded message for API consumption
        preloaded =
          message
          |> Repo.preload([:user, shared_post: :user, shared_wave: :user, reply_to: :user])
          |> Map.put(:conversation_uuid, convo.uuid)

        {:ok, preloaded}

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

  def update_message(%Message{} = message, attrs) do
    message
    |> Message.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_msg} ->
        preloaded_msg = Repo.preload(updated_msg, [:user, shared_post: :user, shared_wave: :user, reply_to: :user])
        notify_message_updated(preloaded_msg)
        {:ok, preloaded_msg}

      error ->
        error
    end
  end

  defp notify_message_updated(message) do
    convo = get_conversation!(message.conversation_id)

    Phoenix.PubSub.broadcast(
      Vibeflow.PubSub,
      "conversation:#{convo.uuid}",
      {:message_updated, message}
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
    convo = Repo.get!(Conversation, conversation_id)

    preloaded_message =
      Repo.get(Message, message.id)
      |> Repo.preload([:user, shared_post: :user, shared_wave: :user, reply_to: :user])
      |> Map.put(:conversation_uuid, convo.uuid)

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
    message = Repo.preload(message, [:user, shared_post: :user, shared_wave: :user, reply_to: :user])

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
  def share_posts_to_friend(sender_id, friend_id, post_id_or_uuid) do
    {:ok, conversation} = get_or_create_private_conversation(sender_id, friend_id)
    # now get the post (supports id or uuid)
    post = Vibeflow.Posts.get_post!(post_id_or_uuid)

    content = ""

    {:ok, message} =
      create_message(%{
        content: content,
        user_id: sender_id,
        conversation_id: conversation.id,
        shared_post_id: post.id
      })

    Notifications.create_notification(%{
      user_id: friend_id,
      actor_id: sender_id,
      type: "shared_post",
      post_id: post.id,
      conversation_id: conversation.id
    })

    {:ok, message}
  end

  # Share post to multiple friends with optional message
  def share_post_to_friends(sender_id, post_id_or_uuid, recipient_ids, message \\ "") do
    # Convert string IDs to integers if needed
    recipient_ids =
      recipient_ids
      |> Enum.map(fn id ->
        case is_binary(id) do
          true -> String.to_integer(id)
          false -> id
        end
      end)

    post = Vibeflow.Posts.get_post!(post_id_or_uuid)

    content = message || ""

    # Create messages for each recipient
    results =
      Enum.map(recipient_ids, fn recipient_id ->
        case get_or_create_private_conversation(sender_id, recipient_id) do
          {:ok, conversation} ->
            case create_message(%{
                   content: content,
                   user_id: sender_id,
                   conversation_id: conversation.id,
                   shared_post_id: post.id
                 }) do
              {:ok, message} ->
                # Create notification for the recipient
                Notifications.create_notification(%{
                  user_id: recipient_id,
                  actor_id: sender_id,
                  type: "shared_post",
                  post_id: post.id,
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

  # Add user to conversation
  def add_user_to_conversation(conversation_id, user_id) do
    # Check if user is already a member
    existing =
      from(cm in ConversationMember,
        where: cm.conversation_id == ^conversation_id and cm.user_id == ^user_id
      )
      |> Repo.one()

    if existing do
      {:ok, existing}
    else
      %ConversationMember{}
      |> ConversationMember.changeset(%{
          conversation_id: conversation_id,
          user_id: user_id,
          role: "member"
        })
      |> Repo.insert()
    end
  end

  # Find or create direct conversation
  def find_or_create_direct_conversation(current_user_id, target_user_id) do
    # Check if conversation already exists between these two users
    case find_direct_conversation(current_user_id, target_user_id) do
      nil ->
        # Create new direct conversation
        create_direct_conversation(current_user_id, target_user_id)

      conversation ->
        {:ok, conversation}
    end
  end

  # Find direct conversation between two users
  defp find_direct_conversation(user1_id, user2_id) do
    from(c in Conversation,
      where: c.type == "direct",
      # Check that user1 is a member
      join: cm1 in ConversationMember,
      on: cm1.conversation_id == c.id and cm1.user_id == ^user1_id,
      # Check that user2 is also a member
      join: cm2 in ConversationMember,
      on: cm2.conversation_id == c.id and cm2.user_id == ^user2_id
    )
    |> Repo.one()
  end

  # Create direct conversation
  defp create_direct_conversation(user1_id, user2_id) do
    %Conversation{}
    |> Conversation.changeset(%{
        type: "direct",
        name: "Direct Chat"
      })
    |> Repo.insert()
    |> case do
      {:ok, conversation} ->
        Ecto.Multi.new()
        |> Ecto.Multi.insert(:member1, ConversationMember.changeset(%ConversationMember{}, %{
            conversation_id: conversation.id,
            user_id: user1_id,
            role: "admin"
          }))
        |> Ecto.Multi.insert(:member2, ConversationMember.changeset(%ConversationMember{}, %{
            conversation_id: conversation.id,
            user_id: user2_id,
            role: "admin"
          }))
        |> Repo.transaction()
        |> case do
          {:ok, _} ->
            {:ok, conversation}
          {:error, _changeset} ->
            {:error, :member_insert_failed}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # Update conversation
  def update_conversation(conversation, attrs) do
    conversation
    |> Conversation.changeset(attrs)
    |> Repo.update()
  end

  # Remove user from conversation
  def remove_user_from_conversation(conversation_id, user_id) do
    from(cm in ConversationMember,
      where: cm.conversation_id == ^conversation_id and cm.user_id == ^user_id)
    |> Repo.delete_all()

    {:ok, get_conversation!(conversation_id)}
  end

  # Create group conversation (alias for existing function)
  def create_group_conversation(creator_id, group_name, member_ids) do
    create_group_chats(
      %Vibeflow.Accounts.User{id: creator_id},
      %{
        type: "group",
        name: group_name
      },
      member_ids
    )
  end
end
