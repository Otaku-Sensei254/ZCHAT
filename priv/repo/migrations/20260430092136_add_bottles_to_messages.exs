defmodule Vibeflow.Repo.Migrations.AddBottlesToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add(:is_bottle, :boolean, default: false)
      add(:is_found, :boolean, default: false)
      add(:bottle_origin_id, references(:users, on_delete: :nilify_all))

      modify(:conversation_id, :bigint, null: true)
      modify(:user_id, :bigint, null: true)
    end
  end
end
