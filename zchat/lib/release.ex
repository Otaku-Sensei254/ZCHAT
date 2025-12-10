# lib/zchat/release.ex
defmodule Zchat.Release do
  @app :zchat

  def seed do
    # Ensure the app is loaded so we can find the file
    Application.load(@app)

    # Run the seed script
    path = Path.join(:code.priv_dir(@app), "repo/seeds.exs")
    Code.eval_file(path)
  end
end
