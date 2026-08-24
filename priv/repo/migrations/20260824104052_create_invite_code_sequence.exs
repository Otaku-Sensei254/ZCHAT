defmodule Vibeflow.Repo.Migrations.CreateInviteCodeSequence do
  use Ecto.Migration

  def up do
    execute "CREATE SEQUENCE IF NOT EXISTS invite_code_seq START 1"
  end

  def down do
    execute "DROP SEQUENCE IF EXISTS invite_code_seq"
  end
end