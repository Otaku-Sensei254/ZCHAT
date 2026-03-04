defmodule Vibeflow.Waves do
  @moduledoc """
  The Waves context.
  """

  import Ecto.Query, warn: false
  alias Vibeflow.Repo
  alias Vibeflow.Socials.Follow
  alias Vibeflow.Waves.Wave
  import Ecto.Query
  alias Vibeflow.Waves.WaveView # <--- Added Alias

  @doc """
  Returns the list of waves.

  ## Examples

      iex> list_waves()
      [%Wave{}, ...]

  """
  def list_waves(current_user_id) do
    # get the people the user has followed and show their waves
    following_ids =
      from(f in Follow,
        where: f.follower_id == ^current_user_id,
        select: f.following_id
      )

    Wave
    |> where([w], w.user_id in subquery(following_ids) or w.user_id == ^current_user_id)
    |> order_by([w, f], desc: w.inserted_at)
    |> Repo.all()
    |> Repo.preload(:user)
  end

  def list_active_waves(current_user_id) do
    # get the people the user has followed and show their waves
    following_ids =
      from(f in Follow,
        where: f.follower_id == ^current_user_id,
        select: f.following_id
      )

    waves =
      Wave
      |> where([w], w.user_id in subquery(following_ids) or w.user_id == ^current_user_id)
      |> where([w], w.expires_at > ^DateTime.utc_now())
      |> order_by([w], desc: w.inserted_at)
      |> Repo.all()
      |> Repo.preload(:user)

    # those you've already seen
    seen_wave_ids =
      from(sw in WaveView,
        where: sw.user_id == ^current_user_id,
        select: sw.wave_id
      )
      |> Repo.all()
      |> MapSet.new()

    waves
    |> Enum.group_by(fn wave -> wave.user end)
    |> Enum.map(fn {user, user_waves} ->
      has_unseen =
        Enum.any?(user_waves, fn wave ->
          not MapSet.member?(seen_wave_ids, wave.id)
        end)

      %{user: user, waves: user_waves, has_unseen: has_unseen}
    end)
    |> Enum.partition(fn map -> map.user.id == current_user_id end)
    |> (fn {current_user_waves, other_waves} ->
      current_user_waves ++ Enum.sort_by(other_waves, fn map -> map.has_unseen end, :desc)
    end).()
  end

  def list_user_waves(user_id) do
    Wave
    |> where(user_id: ^user_id)
    |> where([w], w.expires_at > ^DateTime.utc_now())
    |> Repo.all()
    |> Repo.preload([:user, :music_track])
  end

  # mark a wave as seen
  def mark_wave_as_seen(user_id, wave_id) do
    %WaveView{}
    |> WaveView.changeset(%{user_id: user_id, wave_id: wave_id})
    # Ignore if already seen
    |> Repo.insert(on_conflict: :nothing)
  end

  @doc """
  Gets a single wave.

  Raises `Ecto.NoResultsError` if the Wave does not exist.

  ## Examples

      iex> get_wave!(123)
      %Wave{}

      iex> get_wave!(456)
      ** (Ecto.NoResultsError)

  """
  def get_wave!(id_or_uuid) do
    case Ecto.UUID.cast(id_or_uuid) do
      {:ok, uuid} -> Repo.get_by!(Wave, uuid: uuid)
      :error -> Repo.get!(Wave, id_or_uuid)
    end
  end

  def get_wave_by_uuid!(uuid) do
    Repo.get_by!(Wave, uuid: uuid)
  end

  def get_wave_by_uuid(uuid) do
    Repo.get_by(Wave, uuid: uuid)
  end

  @doc """
  Creates a wave.

  ## Examples

      iex> create_wave(%{field: value})
      {:ok, %Wave{}}

      iex> create_wave(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_wave(attrs \\ %{}) do
    %Wave{}
    |> Wave.changeset(attrs)
    |> Repo.insert()
    |> broadcast_wave()
  end

  defp broadcast_wave({:ok, wave}) do
    wave = Repo.preload(wave, :user)
    {:ok, wave}
  end

  defp broadcast_wave({:error, changeset}), do: {:error, changeset}

  @doc """
  Updates a wave.

  ## Examples

      iex> update_wave(wave, %{field: new_value})
      {:ok, %Wave{}}

      iex> update_wave(wave, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_wave(%Wave{} = wave, attrs) do
    wave
    |> Wave.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a wave.

  ## Examples

      iex> delete_wave(wave)
      {:ok, %Wave{}}

      iex> delete_wave(wave)
      {:error, %Ecto.Changeset{}}

  """
  def delete_wave(%Wave{} = wave) do
    Repo.delete(wave)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking wave changes.

  ## Examples

      iex> change_wave(wave)
      %Ecto.Changeset{data: %Wave{}}

  """
  def change_wave(%Wave{} = wave, attrs \\ %{}) do
    Wave.changeset(wave, attrs)
  end
end
