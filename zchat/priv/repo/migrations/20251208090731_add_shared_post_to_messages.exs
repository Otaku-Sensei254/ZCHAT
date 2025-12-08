defmodule Zchat.Repo.Migrations.AddSharedPostToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      # Reference the posts table. Nullable (because normal messages don't have posts)
      add :shared_post_id, references(:posts, on_delete: :nilify_all)
    end

    create index(:messages, [:shared_post_id])
  end
end
