# In your existing 20251125140525_create_messages_table.exs
defmodule Vibeflow.Repo.Migrations.CreateMessagesTable do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :content, :text, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      # Remove the conversation_id foreign key for now, add it later
      add :conversation_id, :integer, null: false

      timestamps()
    end

    create index(:messages, [:user_id])
    create index(:messages, [:conversation_id])
    create index(:messages, [:inserted_at])
  end
end
