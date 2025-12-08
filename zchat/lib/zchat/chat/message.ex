defmodule Zchat.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do

    field :content, :string
    field :read_at, :utc_datetime_usec
    belongs_to :user, Zchat.Accounts.User
    belongs_to :conversation, Zchat.Chat.Conversation
    belongs_to :shared_post, Zchat.Posts.Post
    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
   |> cast(attrs, [:content, :conversation_id, :user_id, :read_at, :shared_post_id])
    |> validate_required([:content, :conversation_id, :user_id])
    |> validate_length(:content, min: 1, max: 5000)
    |> validate_content_or_post()
  end
  defp validate_content_or_post(changeset) do
    if get_field(changeset, :content) || get_field(changeset, :shared_post_id) do
      changeset
    else
      add_error(changeset, :content, "can't be blank unless sharing a post")
    end
  end
end
