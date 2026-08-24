defmodule Vibeflow.Drifts.Drifts do
  import Ecto.Changeset

  use Ecto.Schema
  alias Vibeflow.Repo

  schema "drifts" do
    field(:uuid, Ecto.UUID, autogenerate: true)
    field(:note, :string)
    field(:song_name, :string)
    field(:reactions, {:array, :map}, default: [])
    belongs_to(:user, Vibeflow.Accounts.User)
  end
end
