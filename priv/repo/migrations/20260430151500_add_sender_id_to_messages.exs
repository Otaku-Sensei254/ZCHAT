defmodule Vibeflow.Repo.Migrations.AddSenderIdToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :sender_id, references(:users, on_delete: :nilify_all)
    end

    create index(:messages, [:sender_id])
  end
end
