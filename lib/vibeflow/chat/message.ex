defmodule Vibeflow.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "messages" do
    field :uuid, Ecto.UUID, autogenerate: true
    field :content, :string
    field :read_at, :naive_datetime
    field :media_files, {:array, :map}, default: []

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
        :read_at,
        :shared_post_id,
        :shared_wave_id,
        :media_files,
        :reply_to_id
      ],
      empty_values: []
    )
    |> update_change(:content, &String.trim/1)
    |> validate_required([:conversation_id, :user_id])
    |> validate_length(:content, max: 5000)
    |> validate_message_payload()
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
end
