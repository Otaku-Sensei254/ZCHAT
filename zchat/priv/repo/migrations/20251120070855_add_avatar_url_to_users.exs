defmodule Zchat.Repo.Migrations.AddAvatarUrlToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :avatar_url, :string
    end

    create index(:users, [:avatar_url])
  end
end
