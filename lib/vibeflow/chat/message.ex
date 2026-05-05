defmodule Vibeflow.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "messages" do
    field :uuid, Ecto.UUID, autogenerate: true
    field :content, :string
    field :read_at, :naive_datetime
    field :media_files, {:array, :map}, default: []
    field :is_bottle, :boolean, default: false
    field :is_found, :boolean, default: false
    field :bottle_origin_id, :id
    field :sender_id, :id
    belongs_to :conversation, Vibeflow.Chat.Conversation
    belongs_to :user, Vibeflow.Accounts.User
    belongs_to :shared_post, Vibeflow.Posts.Post, foreign_key: :shared_post_id
    belongs_to :shared_wave, Vibeflow.Waves.Wave, foreign_key: :shared_wave_id
    belongs_to :reply_to, Vibeflow.Chat.Message, foreign_key: :reply_to_id

    has_many :replies, Vibeflow.Chat.Message, foreign_key: :reply_to_id

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(
      attrs,
      [
        :content,
        :conversation_id,
        :user_id,
        :sender_id,
        :is_bottle,
        :is_found,
        :bottle_origin_id,
        :read_at,
        :shared_post_id,
        :shared_wave_id,
        :media_files,
        :reply_to_id
      ],
      empty_values: []
    )
    |> update_change(:content, &String.trim/1)
    |> validate_required([:conversation_id])
    |> validate_length(:content, max: 5000)
    |> validate_message_payload()
    |> validate_bottle_messages()
  end

  defp validate_message_payload(changeset) do
    content = get_field(changeset, :content)
    media = get_field(changeset, :media_files) || []
    shared_post_id = get_field(changeset, :shared_post_id)
    shared_wave_id = get_field(changeset, :shared_wave_id)

    has_content = is_binary(content) and content != ""
    has_media = is_list(media) and media != []
    has_shared_post = not is_nil(shared_post_id)
    has_shared_wave = not is_nil(shared_wave_id)

    if has_content or has_media or has_shared_post or has_shared_wave do
      changeset
    else
      add_error(changeset, :content, "Message cannot be empty")
    end
  end

  #validate bottle messages - bottles are anonymous (no user_id), sender stored in sender_id
  defp validate_bottle_messages(changeset) do
    is_bottle = get_field(changeset, :is_bottle)

    if is_bottle do
      # For bottle messages: no user_id (anonymous), but require sender_id and bottle_origin_id
      changeset
      |> validate_required([:bottle_origin_id, :sender_id])
    else
      # For regular messages, enforce the standard validation rules
      changeset
      |> validate_required([:user_id, :conversation_id])
    end
  end

  defp validate_message_payload(changeset, required_fields) do
    if Enum.all?(required_fields, fn field -> not is_nil(get_field(changeset, field)) end) do
      changeset
    else
      add_error(changeset, :content, "Missing required fields for message type")
    end
  end

end
