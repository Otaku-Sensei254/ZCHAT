defmodule Zchat.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do

    field :content, :string
    field :read_at, :utc_datetime_usec
    field :media_files, {:array, :map}, default: [] # Or {:array, :json}
    belongs_to :user, Zchat.Accounts.User
    belongs_to :conversation, Zchat.Chat.Conversation
    belongs_to :shared_post, Zchat.Posts.Post
    belongs_to :reply_to, Zchat.Chat.Message

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :conversation_id, :user_id, :read_at, :shared_post_id, :media_files, :reply_to_id], empty_values: [])
    |> update_change(:content, &String.trim/1)
    |> validate_required([:conversation_id, :user_id])
    |> validate_length(:content, max: 5000)
    |> validate_message_payload()

  end

  defp validate_message_payload(changeset) do
    content = get_field(changeset, :content)
    media = get_field(changeset, :media_files) || []
    shared_post_id = get_field(changeset, :shared_post_id)

    has_content = is_binary(content) and content != ""
    has_media = is_list(media) and media != []
    has_shared_post = not is_nil(shared_post_id)

    if has_content or has_media or has_shared_post do
      changeset
    else
      add_error(changeset, :content, "Message cannot be empty")
    end
  end
    defp validate_content_or_media(changeset) do
    content = get_field(changeset, :content)
    media = get_field(changeset, :media_files)

    if (content == nil or content == "") and (media == [] or media == nil) do
      add_error(changeset, :content, "Message cannot be empty")
    else
      changeset
    end
  end
end
