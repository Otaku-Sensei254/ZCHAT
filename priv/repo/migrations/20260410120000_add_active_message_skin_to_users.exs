defmodule Vibeflow.Repo.Migrations.AddActiveMessageSkinToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :active_message_skin, :string, default: "default"
    end
  end
end
