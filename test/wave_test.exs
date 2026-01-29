defmodule Vibeflow.WavesTest do
  # 1. Use DataCase. This gives you access to the Repo and the Sandbox.
  use Vibeflow.DataCase

  alias Vibeflow.Waves
  alias Vibeflow.Socials
  alias Vibeflow.Socials.Follow

  # This allows us to use `user_fixture()` to quickly make fake users
  import Vibeflow.AccountsFixtures

  describe "list_active_waves/1" do
    test "returns waves from people I follow, but ignores strangers" do
      # --- ARRANGE ---
      # 1. Create 3 users
      me = user_fixture()
      friend = user_fixture()
      stranger = user_fixture()

      # 2. Make 'me' follow 'friend' (but NOT the stranger)
      Socials.create_follow(%{follower_id: me.id, following_id: friend.id})

      # 3. Create a wave for the friend (should see this)
      {:ok, _friend_wave} = Waves.create_wave(%{
        user_id: friend.id,
        media_url: "friend.mp4",
        media_type: "video",
        expires_at: DateTime.add(DateTime.utc_now(), 3600) # Expires in 1 hour
      })

      # 4. Create a wave for the stranger (should NOT see this)
      {:ok, _stranger_wave} = Waves.create_wave(%{
        user_id: stranger.id,
        media_url: "stranger.mp4",
        media_type: "video",
        expires_at: DateTime.add(DateTime.utc_now(), 3600)
      })

      # --- ACT ---
      # Call the function we are testing
      results = Waves.list_active_waves(me.id)

      # --- ASSERT ---
      # 1. We expect exactly 1 group of waves (the friend's)
      assert length(results) == 1

      # 2. Grab that first group
      [first_group] = results

      # 3. Verify it belongs to the friend
      assert first_group.user.id == friend.id

      # 4. Verify we are NOT seeing the stranger's data
      assert first_group.user.id != stranger.id
    end
  end
end
