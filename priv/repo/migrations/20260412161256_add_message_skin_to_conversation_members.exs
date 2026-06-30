defmodule Vibeflow.Repo.Migrations.AddMessageSkinToConversationMembers do
  use Ecto.Migration

  def change do
    alter table(:conversation_members) do
      add :message_skin, :string, default: "default"
    end
  end
end
