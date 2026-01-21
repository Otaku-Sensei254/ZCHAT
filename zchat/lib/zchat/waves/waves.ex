defmodule Zchat.Waves.Wave do
  use Ecto.Schema
  import Ecto.Changeset

  schema "waves" do
    field :media_url, :string
    field :media_type, :string
    field :caption, :string

    # Music Fields
    field :music_track_id, :string
    field :music_preview_url, :string
    field :music_title, :string
    field :music_artist, :string
    field :music_cover_url, :string


    
    field :expires_at, :utc_datetime_usec

    belongs_to :user, Zchat.Accounts.User

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
      :music_preview_url,
      :music_title,
      :music_artist,
      :music_cover_url,
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
