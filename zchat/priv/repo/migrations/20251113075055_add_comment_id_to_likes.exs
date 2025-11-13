defmodule Zchat.Repo.Migrations.AddCommentIdToLikes do
  use Ecto.Migration

 def change do
  alter table(:likes) do
    add :comment_id, references(:comments, on_delete: :delete_all)
  end
end
end
