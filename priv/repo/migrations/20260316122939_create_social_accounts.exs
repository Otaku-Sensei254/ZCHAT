defmodule Vibeflow.Repo.Migrations.CreateSocialAccounts do
  use Ecto.Migration

  def change do
    create table(:social_accounts, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:platform, :string, null: false)
      add(:url, :string)
      add(:username, :string)
      add(:user_id, references(:users, on_delete: :delete_all))

      timestamps(type: :utc_datetime)
    end

    create(index(:social_accounts, [:user_id]))
    create(unique_index(:social_accounts, [:user_id, :platform]))
  end
end
