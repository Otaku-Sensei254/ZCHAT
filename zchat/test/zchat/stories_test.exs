defmodule Zchat.StoriesTest do
  use Zchat.DataCase

  alias Zchat.Stories

  describe "stories" do
    alias Zchat.Stories.Story

    import Zchat.StoriesFixtures

    @invalid_attrs %{media_url: nil, media_type: nil, caption: nil, music_preview_url: nil, music_title: nil, music_artist: nil, music_cover_url: nil, expires_at: nil}

    test "list_stories/0 returns all stories" do
      story = story_fixture()
      assert Stories.list_stories() == [story]
    end

    test "get_story!/1 returns the story with given id" do
      story = story_fixture()
      assert Stories.get_story!(story.id) == story
    end

    test "create_story/1 with valid data creates a story" do
      valid_attrs = %{media_url: "some media_url", media_type: "some media_type", caption: "some caption", music_preview_url: "some music_preview_url", music_title: "some music_title", music_artist: "some music_artist", music_cover_url: "some music_cover_url", expires_at: ~U[2026-01-13 08:08:00Z]}

      assert {:ok, %Story{} = story} = Stories.create_story(valid_attrs)
      assert story.media_url == "some media_url"
      assert story.media_type == "some media_type"
      assert story.caption == "some caption"
      assert story.music_preview_url == "some music_preview_url"
      assert story.music_title == "some music_title"
      assert story.music_artist == "some music_artist"
      assert story.music_cover_url == "some music_cover_url"
      assert story.expires_at == ~U[2026-01-13 08:08:00Z]
    end

    test "create_story/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Stories.create_story(@invalid_attrs)
    end

    test "update_story/2 with valid data updates the story" do
      story = story_fixture()
      update_attrs = %{media_url: "some updated media_url", media_type: "some updated media_type", caption: "some updated caption", music_preview_url: "some updated music_preview_url", music_title: "some updated music_title", music_artist: "some updated music_artist", music_cover_url: "some updated music_cover_url", expires_at: ~U[2026-01-14 08:08:00Z]}

      assert {:ok, %Story{} = story} = Stories.update_story(story, update_attrs)
      assert story.media_url == "some updated media_url"
      assert story.media_type == "some updated media_type"
      assert story.caption == "some updated caption"
      assert story.music_preview_url == "some updated music_preview_url"
      assert story.music_title == "some updated music_title"
      assert story.music_artist == "some updated music_artist"
      assert story.music_cover_url == "some updated music_cover_url"
      assert story.expires_at == ~U[2026-01-14 08:08:00Z]
    end

    test "update_story/2 with invalid data returns error changeset" do
      story = story_fixture()
      assert {:error, %Ecto.Changeset{}} = Stories.update_story(story, @invalid_attrs)
      assert story == Stories.get_story!(story.id)
    end

    test "delete_story/1 deletes the story" do
      story = story_fixture()
      assert {:ok, %Story{}} = Stories.delete_story(story)
      assert_raise Ecto.NoResultsError, fn -> Stories.get_story!(story.id) end
    end

    test "change_story/1 returns a story changeset" do
      story = story_fixture()
      assert %Ecto.Changeset{} = Stories.change_story(story)
    end
  end
end
