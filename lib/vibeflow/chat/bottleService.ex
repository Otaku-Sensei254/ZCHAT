defmodule Vibeflow.Chat.BottleService do
  import Ecto.Query, warn: false

  alias Vibeflow.Accounts.User
  alias Vibeflow.Chat
  alias Vibeflow.Chat.{Conversation, ConversationMember, Message}
  alias Vibeflow.Repo
  alias Vibeflow.Store
  alias VibeflowWeb.Presence

  @bottle_item_slug "message-bottle"
  @bottle_cooldown_seconds 86_400  # 24 hours
  @encouraging_terms ~w(
    hope
    healing
    brave
    calm
    peace
    smile
    kind
    kindness
    comfort
    comforting
    gentle
    joy
    warm
    support
    supported
    strength
    stronger
    proud
    believe
    breathing
    breathe
    rest
    softer
    okay
    safe
    loved
    worthy
    light
    better
    steady
    tomorrow
    encouragement
    care
    caring
    friend
    beautiful
    wonderful
  )
  @blocked_terms ~w(
    stupid
    idiot
    ugly
    loser
    worthless
    hate
    kill
    die
    dumb
    trash
    shutup
    bastard
    bitch
    fuck
    shit
    asshole
    moron
    disgusting
    pathetic
    psycho
    useless
    whore
    slut
  )

  def can_throw_bottle?(user_id) do
    case Store.has_active_item?(user_id, @bottle_item_slug) do
      false -> {:error, :bottle_access_required}
      true ->
        # Check if user has thrown a bottle in the last 24 hours
        last_bottle = get_last_bottle_sent_by(user_id)

        case last_bottle do
          nil -> :ok
          %Message{inserted_at: timestamp} ->
            seconds_since = DateTime.diff(DateTime.utc_now(), DateTime.from_naive!(timestamp, "Etc/UTC"))
            if seconds_since >= @bottle_cooldown_seconds do
              :ok
            else
              hours_remaining = ceil((@bottle_cooldown_seconds - seconds_since) / 3600)
              {:error, {:bottle_cooldown, hours_remaining}}
            end
        end
    end
  end

  def throw_bottle(message_params, %User{} = user) do
    throw_bottle(message_params, user.id)
  end

  def throw_bottle(message_params, user_id) when is_integer(user_id) do
    with :ok <- can_throw_bottle?(user_id),
         :ok <- validate_bottle_content(message_params),
         recipient when not is_nil(recipient) <- random_online_recipient_for(user_id) do
      Repo.transaction(fn ->
        {:ok, conversation} =
          %Conversation{}
          |> Conversation.changeset(%{type: "bottle", name: "Message in a Bottle"})
          |> Repo.insert()

        insert_member!(conversation.id, user_id)
        insert_member!(conversation.id, recipient.id)

        attrs =
          Map.merge(message_params, %{
            "is_bottle" => true,
            "is_found" => false,
            "user_id" => user_id,
            "sender_id" => user_id,
            "conversation_id" => conversation.id,
            "bottle_origin_id" => user_id
          })

        case Chat.create_message(attrs) do
          {:ok, message} ->
            %{conversation: conversation, message: message, recipient: recipient}

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)
      |> case do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> {:error, reason}
      end
    else
      nil ->
        {:error, :no_recipient_available}

      {:error, _} = error ->
        error
    end
  end

  def wash_up_bottle_to_randomo(receiver_id) when is_integer(receiver_id) do
    require Logger
    Logger.info("wash_up_bottle_to_randomo called for receiver_id=#{receiver_id}")

    query =
      from m in Message,
        join: cm in ConversationMember,
        on: cm.conversation_id == m.conversation_id,
        where:
          m.is_bottle == true and m.is_found == false and cm.user_id == ^receiver_id and
            m.bottle_origin_id != ^receiver_id,
        order_by: [asc: m.inserted_at],
        limit: 1

    case Repo.one(query) do
      nil ->
        Logger.warning("No bottle found for receiver_id=#{receiver_id}")
        {:error, :no_bottles_found_in_ocean}

      message ->
        Logger.info("Found bottle message id=#{message.id} for receiver_id=#{receiver_id}, updating is_found to true")
        # Load the conversation to get its UUID for the broadcast topic
        conversation = Repo.get!(Conversation, message.conversation_id)

        result =
          message
          |> Ecto.Changeset.change(is_found: true)
          |> Repo.update()

        Logger.info("Repo.update result: #{inspect(result)}")

        # Broadcast to conversation that bottle was found (using UUID)
        VibeflowWeb.Endpoint.broadcast(
          "conversation:#{conversation.uuid}",
          "bottle_found",
          %{message_id: message.id}
        )

        result
    end
  end

  def get_bottle_messages do
    query =
      from m in Message,
        where: m.is_bottle == true and m.is_found == false,
        order_by: [desc: m.inserted_at]

    Repo.all(query)
  end

  def get_bottle_messages_for_user(user_id) do
    query =
      from m in Message,
        where: m.is_bottle == true and m.is_found == true and m.bottle_origin_id == ^user_id,
        order_by: [desc: m.inserted_at]

    Repo.all(query)
  end

  def find_unfound_bottle_in_conversation(conversation_id, receiver_id) do
    query =
      from m in Message,
        where:
          m.is_bottle == true and m.is_found == false and
            m.conversation_id == ^conversation_id and
            m.bottle_origin_id != ^receiver_id,
        order_by: [asc: m.inserted_at],
        limit: 1

    case Repo.one(query) do
      nil -> {:error, :no_unfound_bottle}
      message -> {:ok, message}
    end
  end

  def reveal_bottle_sender(message_id) do
    message = Repo.get!(Message, message_id)

    result =
      message
      |> Ecto.Changeset.change(is_found: true)
      |> Repo.update()

    # Broadcast to conversation that bottle was found
    conversation = Repo.get!(Conversation, message.conversation_id)

    VibeflowWeb.Endpoint.broadcast(
      "conversation:#{conversation.uuid}",
      "bottle_found",
      %{message_id: message.id}
    )

    result
  end

  defp get_last_bottle_sent_by(user_id) do
    from(m in Message,
      where: m.is_bottle == true and m.bottle_origin_id == ^user_id,
      order_by: [desc: m.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  defp random_online_recipient_for(sender_id) do
    # Get list of currently online users from Presence
    online_users = Presence.list("users:online")

    # Extract user IDs from presence data, excluding the sender
    online_user_ids =
      online_users
      |> Map.keys()
      |> Enum.map(&String.to_integer/1)
      |> Enum.reject(&(&1 == sender_id))

    case online_user_ids do
      [] -> nil
      ids ->
        # Pick a random user from online users
        random_id = Enum.random(ids)
        Repo.get(User, random_id)
    end
  end

  defp insert_member!(conversation_id, user_id) do
    %ConversationMember{}
    |> ConversationMember.changeset(%{
      conversation_id: conversation_id,
      user_id: user_id
    })
    |> Repo.insert!()
  end

  defp ensure_bottle_access(user_id) do
    if Store.has_active_item?(user_id, @bottle_item_slug) do
      :ok
    else
      {:error, :bottle_access_required}
    end
  end

  defp validate_bottle_content(message_params) do
    content =
      message_params
      |> Map.get("content", "")
      |> to_string()
      |> String.trim()

    media_files = Map.get(message_params, "media_files", [])
    normalized = normalize_text(content)

    cond do
      content == "" && media_files == [] ->
        {:error, :empty_bottle_message}

      content == "" && media_files != [] ->
        :ok

      contains_blocked_term?(normalized) ->
        {:error, :unsafe_bottle_message}

      true ->
        :ok
    end
  end

  defp contains_blocked_term?(normalized) do
    Enum.any?(@blocked_terms, &String.contains?(normalized, &1))
  end

  defp contains_encouraging_signal?(normalized) do
    Enum.any?(@encouraging_terms, &String.contains?(normalized, &1))
  end

  defp normalize_text(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/u, " ")
    |> String.replace(~r/\s+/, " ")
  end

  # ===========================================================================
  # 24HR AUTO-DELETE FOR BOTTLE CONVERSATIONS
  # ===========================================================================

  def delete_expired_bottle_conversations do
    require Logger

    # Find bottle conversations older than 24 hours
    cutoff_time = DateTime.add(DateTime.utc_now(), -86400, :second)

    expired_conversations =
      from(c in Conversation,
        where: c.type == "bottle" and c.inserted_at < ^cutoff_time,
        select: c.id
      )
      |> Repo.all()

    count = length(expired_conversations)

    if count > 0 do
      Logger.info("Deleting #{count} expired bottle conversations (older than 24h)")

      # Delete messages first (due to foreign key constraints)
      from(m in Message, where: m.conversation_id in ^expired_conversations)
      |> Repo.delete_all()

      # Delete conversation members
      from(cm in ConversationMember, where: cm.conversation_id in ^expired_conversations)
      |> Repo.delete_all()

      # Delete conversations
      from(c in Conversation, where: c.id in ^expired_conversations)
      |> Repo.delete_all()

      {:ok, count}
    else
      {:ok, 0}
    end
  end
end
