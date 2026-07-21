defmodule Vibeflow.Repo.Migrations.AddInviteCodeToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :invite_code, :string
      add :referred_by_id, references(:users, on_delete: :nilify_all)
    end

    create unique_index(:users, [:invite_code])
    create index(:users, [:referred_by_id])

    execute """
    UPDATE users SET invite_code = username WHERE invite_code IS NULL
    """
  end

  def down do
    drop index(:users, [:referred_by_id])
    drop index(:users, [:invite_code])
    alter table(:users) do
      remove :referred_by_id
      remove :invite_code
    end
  end
end
