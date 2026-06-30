defmodule Vibeflow.Repo.Migrations.AddUuidAndReplyToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :uuid, :uuid, default: fragment("gen_random_uuid()"), null: false
    end
  end
end
