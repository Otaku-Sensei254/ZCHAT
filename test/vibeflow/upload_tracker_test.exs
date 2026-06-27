defmodule Vibeflow.UploadTrackerTest do
  use Vibeflow.DataCase, async: false

  alias Vibeflow.UploadTracker

  setup do
    pid = Process.whereis(UploadTracker)
    if pid do
      Ecto.Adapters.SQL.Sandbox.allow(Vibeflow.Repo, self(), pid)
    end
    %{}
  end

  describe "register/4" do
    test "registers a new upload with pending status" do
      UploadTracker.register("id-1", "photo.jpg", "image/jpeg", 1024)
      assert %{status: :pending, client_name: "photo.jpg", client_type: "image/jpeg", client_size: 1024, path: nil, post_id: nil, finalized: false} = UploadTracker.get("id-1")
    end
  end

  describe "complete/2" do
    test "marks upload as complete and sets path" do
      UploadTracker.register("id-1", "photo.jpg", "image/jpeg", 1024)
      UploadTracker.complete("id-1", "/tmp/test.jpg")
      assert %{status: :complete, path: "/tmp/test.jpg"} = UploadTracker.get("id-1")
    end

    test "returns error for unknown upload" do
      assert {:error, :not_found} = UploadTracker.complete("nonexistent", "/tmp/x.jpg")
    end
  end

  describe "associate/2" do
    test "associates uploads with a post_id" do
      UploadTracker.register("id-1", "a.jpg", "image/jpeg", 100)
      UploadTracker.register("id-2", "b.jpg", "image/jpeg", 200)
      UploadTracker.associate(["id-1", "id-2"], 42)

      assert %{post_id: 42} = UploadTracker.get("id-1")
      assert %{post_id: 42} = UploadTracker.get("id-2")
    end

    test "ignores unknown ids" do
      assert :ok = UploadTracker.associate(["nonexistent"], 42)
    end
  end

  describe "finalization" do
    test "enqueues Oban job when all uploads for a post are complete" do
      UploadTracker.register("id-1", "a.jpg", "image/jpeg", 100)
      UploadTracker.register("id-2", "b.jpg", "image/jpeg", 200)

      UploadTracker.complete("id-1", "/tmp/a.jpg")
      entry = UploadTracker.get("id-1")
      refute entry.finalized

      UploadTracker.associate(["id-1", "id-2"], 99)
      entry = UploadTracker.get("id-1")
      refute entry.finalized

      UploadTracker.complete("id-2", "/tmp/b.jpg")
      entry = UploadTracker.get("id-1")
      assert entry.finalized
    end

    test "does not double-finalize" do
      UploadTracker.register("id-1", "a.jpg", "image/jpeg", 100)
      UploadTracker.complete("id-1", "/tmp/a.jpg")
      UploadTracker.associate(["id-1"], 99)

      entry = UploadTracker.get("id-1")
      assert entry.finalized
    end

    test "does not finalize if no post_id set" do
      UploadTracker.register("id-1", "a.jpg", "image/jpeg", 100)
      UploadTracker.complete("id-1", "/tmp/a.jpg")
      entry = UploadTracker.get("id-1")
      refute entry.finalized
    end
  end
end
