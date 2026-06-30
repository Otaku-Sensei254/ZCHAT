defmodule Vibeflow.Repo.Migrations.AddConversationToNotifications do
  use Ecto.Migration

  def change do
    alter table(:notifications) do
      add :conversation_id, references(:conversations, on_delete: :nilify_all)
    end

    create index(:notifications, [:conversation_id])
  end
end
