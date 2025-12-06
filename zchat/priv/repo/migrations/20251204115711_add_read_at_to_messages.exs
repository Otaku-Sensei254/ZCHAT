defmodule Zchat.Repo.Migrations.AddReadAtToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :read_at, :utc_datetime
    end
  end
end
