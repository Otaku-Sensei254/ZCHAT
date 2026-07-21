defmodule Vibeflow.Repo.Migrations.AddSearchIndexes do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"

    execute "CREATE INDEX IF NOT EXISTS users_username_index ON users (username)"
    execute "CREATE INDEX IF NOT EXISTS users_username_trgm_index ON users USING gin (username gin_trgm_ops)"
    execute "CREATE INDEX IF NOT EXISTS users_bio_trgm_index ON users USING gin (bio gin_trgm_ops)"
    execute "CREATE INDEX IF NOT EXISTS posts_title_trgm_index ON posts USING gin (title gin_trgm_ops)"
    execute "CREATE INDEX IF NOT EXISTS posts_content_trgm_index ON posts USING gin (content gin_trgm_ops)"
    execute "CREATE INDEX IF NOT EXISTS posts_status_index ON posts (status)"
  end

  def down do
    execute "DROP EXTENSION IF EXISTS pg_trgm"
    execute "DROP INDEX IF EXISTS users_username_index"
    execute "DROP INDEX IF EXISTS users_username_trgm_index"
    execute "DROP INDEX IF EXISTS users_bio_trgm_index"
    execute "DROP INDEX IF EXISTS posts_title_trgm_index"
    execute "DROP INDEX IF EXISTS posts_content_trgm_index"
    execute "DROP INDEX IF EXISTS posts_status_index"
  end
end
