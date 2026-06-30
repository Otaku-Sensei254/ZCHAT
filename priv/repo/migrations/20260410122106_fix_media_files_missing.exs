defmodule Vibeflow.Repo.Migrations.FixMediaFilesMissing do
  use Ecto.Migration

  def change do
    # Check if column exists before adding it
    execute "ALTER TABLE messages ADD COLUMN IF NOT EXISTS media_files jsonb DEFAULT '[]'::jsonb",
            ""
  end
end
