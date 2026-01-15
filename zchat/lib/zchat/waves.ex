defmodule Zchat.Waves do
  @moduledoc """
  The Waves context.
  """

  import Ecto.Query, warn: false
  alias Zchat.Repo

  alias Zchat.Waves.Wave

  @doc """
  Returns the list of waves.

  ## Examples

      iex> list_waves()
      [%Wave{}, ...]

  """
  def list_waves do
    Repo.all(Wave)
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
  def get_wave!(id), do: Repo.get!(Wave, id)

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
    |> case do
      {:ok, wave}->
      wave = Repo.preload(wave, :user)
      #Notifications.notify_followers_of_new_wave(wave)
      {:ok, wave}

      {:error, changeset} ->
        {:error, changeset}
    end
  end


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
