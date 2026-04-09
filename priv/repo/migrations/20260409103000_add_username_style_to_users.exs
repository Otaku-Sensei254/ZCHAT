defmodule Vibeflow.Repo.Migrations.AddUsernameStyleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :username_style, :string
    end
  end
end
