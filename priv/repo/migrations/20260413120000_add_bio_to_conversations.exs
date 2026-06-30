defmodule Vibeflow.Repo.Migrations.AddBioToConversations do
  use Ecto.Migration

  def change do
    alter table(:conversations) do
      add :bio, :text
    end
  end
end
