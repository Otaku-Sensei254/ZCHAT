defmodule Vibeflow.Chat.BottleService do
  import Ecto.Query, warn: false

  alias Vibeflow.Accounts.User
  alias Vibeflow.Chat
  alias Vibeflow.Chat.{Conversation, ConversationMember, Message}
  alias Vibeflow.Repo
  alias Vibeflow.Store

  @bottle_item_slug "message-bottle"
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

  def throw_bottle(message_params, %User{} = user) do
    throw_bottle(message_params, user.id)
  end

  def throw_bottle(message_params, user_id) when is_integer(user_id) do
    with :ok <- ensure_bottle_access(user_id),
         :ok <- validate_bottle_content(message_params),
         recipient when not is_nil(recipient) <- random_recipient_for(user_id) do
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
        {:error, :no_bottles_found_in_ocean}

      message ->
        message
        |> Ecto.Changeset.change(is_found: true)
        |> Repo.update()
    end
  end

  def get_bottle_messages do
    query =
      from m in Message,
        where: m.is_bottle == true and m.is_found == true,
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

  defp random_recipient_for(sender_id) do
    from(u in User,
      where: u.id != ^sender_id,
      order_by: fragment("RANDOM()"),
      limit: 1
    )
    |> Repo.one()
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
end
