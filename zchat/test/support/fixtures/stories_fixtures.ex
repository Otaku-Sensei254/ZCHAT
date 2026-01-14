defmodule Zchat.StoriesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Zchat.Stories` context.
  """

  @doc """
  Generate a story.
  """
  def story_fixture(attrs \\ %{}) do
    {:ok, story} =
      attrs
      |> Enum.into(%{
        caption: "some caption",
        expires_at: ~U[2026-01-13 08:08:00Z],
        media_type: "some media_type",
        media_url: "some media_url",
        music_artist: "some music_artist",
        music_cover_url: "some music_cover_url",
        music_preview_url: "some music_preview_url",
        music_title: "some music_title"
      })
      |> Zchat.Stories.create_story()

    story
  end
end
