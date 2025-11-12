defmodule Zchat.Repo do
  use Ecto.Repo,
    otp_app: :zchat,
    adapter: Ecto.Adapters.Postgres
end
