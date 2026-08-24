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
    has_many(:interactions, Vibeflow.Drifts.DriftInteraction, foreign_key: :drift_id)

    timestamps()
  end

  @doc false
  def changeset(drift, attrs) do
    drift
    |> cast(attrs, [:note, :song_name, :user_id])
    |> validate_required([:note, :user_id])
    |> validate_length(:note, min: 1, max: 500)
    |> validate_length(:song_name, max: 200)
  end
end