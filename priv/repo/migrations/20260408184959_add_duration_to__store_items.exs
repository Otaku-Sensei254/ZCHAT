defmodule Vibeflow.Repo.Migrations.AddDurationToStoreItems do
  use Ecto.Migration

  def change do
    alter table(:store_items) do
      add :duration, :string
    end
  end
end
