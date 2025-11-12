defmodule Zchat.Repo.Migrations.AddUsernameToUsers do
  use Ecto.Migration

  def change do
    # First add the column as nullable
    alter table(:users) do
      add :username, :string
    end

    # Create the index
    create unique_index(:users, [:username])

    # Then update existing records with a default username
    execute "UPDATE users SET username = 'user_' || id WHERE username IS NULL"

    # Finally, alter the column to be non-nullable
    alter table(:users) do
      modify :username, :string, null: false
    end
  end
end
