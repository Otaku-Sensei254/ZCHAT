defmodule Zchat.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications) do
      add :type, :string, null: false # "like", "comment", "repost"
      add :read_at, :naive_datetime

      # Who RECEIVES the notification
      add :user_id, references(:users, on_delete: :delete_all), null: false
      # Who CAUSED the notification
      add :actor_id, references(:users, on_delete: :delete_all), null: false

      # Link to the post (optional, as some notifs might not be post-related)
      add :post_id, references(:posts, on_delete: :delete_all)

      timestamps()
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:user_id, :read_at])
  end
end
