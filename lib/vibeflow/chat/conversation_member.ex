defmodule Vibeflow.Chat.ConversationMember do
  use Ecto.Schema
  import Ecto.Changeset

  schema "conversation_members" do
    belongs_to :conversation, Vibeflow.Chat.Conversation
    belongs_to :user, Vibeflow.Accounts.User

    field :last_read_at, :utc_datetime
    field :message_skin, :string, default: "default"

    timestamps()
  end

  @doc false
  def changeset(conversation_member, attrs) do
    conversation_member
    |> cast(attrs, [:conversation_id, :user_id, :last_read_at, :message_skin])
    |> validate_required([:conversation_id, :user_id])
    |> unique_constraint([:conversation_id, :user_id])
  end
end
