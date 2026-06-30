# priv/repo/migrations/[timestamp]_create_conversation_members_table.exs
defmodule Vibeflow.Repo.Migrations.CreateConversationMembersTable do
  use Ecto.Migration

  def change do
    create table(:conversation_members) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:conversation_members, [:user_id])
    create index(:conversation_members, [:conversation_id])
    create unique_index(:conversation_members, [:user_id, :conversation_id])
  end
end
