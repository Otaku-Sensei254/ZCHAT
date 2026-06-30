defmodule Vibeflow.Waves.Wave do
  use Ecto.Schema
  import Ecto.Changeset

  schema "waves" do
    field :uuid, Ecto.UUID, autogenerate: true
    field :media_url, :string
    field :media_type, :string
    field :caption, :string

    belongs_to :user, Vibeflow.Accounts.User

    belongs_to :music_track, Vibeflow.Music.MusicTrack,
      foreign_key: :music_track_id,
      type: :integer

    field :expires_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(wave, attrs) do
    wave
    |> cast(attrs, [
      :media_url,
      :media_type,
      :caption,
      :music_track_id,
      :expires_at,
      :user_id
    ])
    |> validate_required([:media_url, :user_id])
    |> put_expiration()
  end

  defp put_expiration(changeset) do
    if get_field(changeset, :expires_at) == nil do
      # This generates microseconds, so the schema must be :utc_datetime_usec
      put_change(changeset, :expires_at, DateTime.add(DateTime.utc_now(), 24, :hour))
    else
      changeset
    end
  end
end
