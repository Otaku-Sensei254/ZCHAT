defmodule Vibeflow.Drifts.DriftInteraction do
  import Ecto.Changeset

  use Ecto.Schema
  alias Vibeflow.Repo

  @valid_types ~w[reaction reply view share]

  schema "drift_interactions" do
    field(:type, :string)
    field(:payload, :map, default: %{})
    belongs_to(:drift, Vibeflow.Drifts.Drifts)
    belongs_to(:actor, Vibeflow.Accounts.User, foreign_key: :actor_id)

    timestamps()
  end

  @doc false
  def changeset(interaction, attrs) do
    interaction
    |> cast(attrs, [:drift_id, :actor_id, :type, :payload])
    |> validate_required([:drift_id, :actor_id, :type])
    |> validate_inclusion(:type, @valid_types, message: "must be one of: #{Enum.join(@valid_types, ", ")}")
  end
end