defmodule Vibeflow.Repo.Migrations.AddContentTypeToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :content_type, :string, default: "standard", null: false
    end

    create index(:posts, [:content_type])
  end
end
