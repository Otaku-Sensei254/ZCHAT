# priv/repo/migrations/[timestamp]_make_user_roles_timestamps_nullable.exs
defmodule Zchat.Repo.Migrations.MakeUserRolesTimestampsNullable do
  use Ecto.Migration

  def change do
    alter table(:user_roles) do
      modify :inserted_at, :naive_datetime, null: true
      modify :updated_at, :naive_datetime, null: true
    end
  end
end
