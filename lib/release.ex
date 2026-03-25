defmodule Vibeflow.Release do
  @app :vibeflow

  def migrate do
    # This is the standard Ecto migration code used in Heroku deployments
    IO.puts("Running Ecto migrations...")
    # Load the application so Ecto config is available
    Application.load(@app)

    # Get the repo configuration dynamically
    config = Application.get_env(@app, :repo)
    # Get the name of the repository module (e.g., Vibeflow.Repo)
    repo = Keyword.get(config, :repo, @app)

    # Run the migrations using Ecto.Migrator
    {:ok, _} = Ecto.Migrator.with_repo(repo, fn repo_mod ->
      Ecto.Migrator.run(repo_mod, migrations_path(repo_mod), :up, all: true)
    end)
    IO.puts("Migrations completed successfully.")
  end

  def seed do
    IO.puts("Running Ecto seeds...")
    Application.load(@app)
    path = Path.join(migrations_path(Vibeflow.Repo), "seeds.exs")
    Code.eval_file(path)
    IO.puts("Seeds completed successfully.")
  end

  # Helper function to find the migrations directory
  defp migrations_path(repo) do
    priv_dir = Application.app_dir(repo, "priv")
    Path.join([priv_dir, "repo", "migrations"])
  end
end

