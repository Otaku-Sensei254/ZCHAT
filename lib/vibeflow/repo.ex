defmodule Vibeflow.Repo do
  use Ecto.Repo,
    otp_app: :vibeflow,
    adapter: Ecto.Adapters.Postgres
end
