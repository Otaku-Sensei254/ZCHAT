# priv/repo/migrations/[timestamp]_create_conversations_table.exs
defmodule Vibeflow.Repo.Migrations.CreateConversationsTable do
  use Ecto.Migration

  def change do
    create table(:conversations) do
      add :name, :string
      # "direct" or "group"
      add :type, :string, default: "direct"

      timestamps()
    end
  end
end
