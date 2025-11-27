# priv/repo/migrations/[timestamp]_create_conversations_table.exs
defmodule Zchat.Repo.Migrations.CreateConversationsTable do
  use Ecto.Migration

  def change do
    create table(:conversations) do
      add :name, :string
      add :type, :string, default: "direct" # "direct" or "group"

      timestamps()
    end
  end
end
