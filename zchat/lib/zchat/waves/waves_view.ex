defmodule Zchat.Waves.WaveView do
  use Ecto.Schema
  import Ecto.Changeset

  schema "wave_views" do
    belongs_to :user, Zchat.Accounts.User
    belongs_to :wave, Zchat.Waves.Wave
    timestamps(updated_at: false)
  end

  def changeset(view, attrs) do
    view
    |> cast(attrs, [:user_id, :wave_id])
    |> validate_required([:user_id, :wave_id])
    |> unique_constraint([:user_id, :wave_id])
  end
end
