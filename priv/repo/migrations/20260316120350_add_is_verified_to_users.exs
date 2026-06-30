defmodule Vibeflow.Repo.Migrations.AddIsVerifiedToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_verified, :boolean, default: false, null: false
    end
  end
end
