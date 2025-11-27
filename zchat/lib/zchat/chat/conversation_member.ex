defmodule Zchat.Chat.ConversationMember do
  use Ecto.Schema
  import Ecto.Changeset

  alias Zchat.Accounts.User
  alias Zchat.Chat.Conversation

  schema "conversation_members" do
    belongs_to :conversation, Zchat.Chat.Conversation
    belongs_to :user, Zchat.Accounts.User

    field :last_read_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(conversation_member, attrs) do
    conversation_member
    |> cast(attrs, [:conversation_id, :user_id, :last_read_at])
    |> validate_required([:conversation_id, :user_id])
    |> unique_constraint([:conversation_id, :user_id])
  end
end
