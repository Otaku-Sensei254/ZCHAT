defmodule Vibeflow.Repo.Migrations.AddStreakToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :last_ping_date, :date
      add :current_streak, :integer, default: 0
      add :longest_streak, :integer, default: 0
    end
  end

  def down do
    alter table(:users) do
      remove :last_ping_date
      remove :current_streak
      remove :longest_streak
    end
  end
end
