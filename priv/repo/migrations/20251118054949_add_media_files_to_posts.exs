defmodule Zchat.Repo.Migrations.AddMediaFilesToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :media_files, {:array, :map}, default: []
    end
  end
end
