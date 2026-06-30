defmodule Vibeflow.Repo.Migrations.AddLastReadAtToConversationMembers do
  use Ecto.Migration

  def change do
    alter table(:conversation_members) do
      add :last_read_at, :utc_datetime
    end
  end
end
