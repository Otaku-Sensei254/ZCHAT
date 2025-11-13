defmodule Zchat.Repo.Migrations.AddCategoryToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :category, :string
    end
  end
end
