defmodule Zchat.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do

    field :content, :string
    field :read_at, :utc_datetime_usec
    belongs_to :user, Zchat.Accounts.User
    belongs_to :conversation, Zchat.Chat.Conversation

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
   |> cast(attrs, [:content, :conversation_id, :user_id, :read_at])
    |> validate_required([:content, :conversation_id, :user_id])
    |> validate_length(:content, min: 1, max: 5000)
  end
end
