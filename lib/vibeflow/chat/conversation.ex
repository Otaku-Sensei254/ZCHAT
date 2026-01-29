defmodule Vibeflow.Chat.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "conversations" do
    field :name, :string
    field :type, :string, default: "direct" # Matches your DB 'type' column

    field :unread_count, :integer, virtual: true, default: 0
    
    has_many :messages, Vibeflow.Chat.Message
    has_many :conversation_members, Vibeflow.Chat.ConversationMember
    has_many :members, through: [:conversation_members, :user]

    timestamps()
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:name, :type])
    |> validate_length(:name, max: 100)
  end
end
