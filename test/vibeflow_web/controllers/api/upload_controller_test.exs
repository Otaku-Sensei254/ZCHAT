defmodule VibeflowWeb.Api.UploadControllerTest do
  use VibeflowWeb.ConnCase, async: false

  setup do
    :ok
  end

  describe "POST /api/uploads/init" do
    test "requires authentication", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/uploads/init", %{name: "test.jpg"})
      assert json_response(conn, 401)
    end

    test "registers an upload and returns an upload_id", %{conn: conn} do
      user = Vibeflow.AccountsFixtures.user_fixture()
      conn = log_in_user(conn, user)

      conn =
        post(conn, ~p"/api/uploads/init", %{
          upload_id: "custom-id",
          name: "photo.jpg",
          type: "image/jpeg",
          size: 12345
        })

      assert %{"upload_id" => "custom-id"} = json_response(conn, 200)
      assert %{status: :pending} = Vibeflow.UploadTracker.get("custom-id")
    end

    test "generates an upload_id if not provided", %{conn: conn} do
      user = Vibeflow.AccountsFixtures.user_fixture()
      conn = log_in_user(conn, user)

      conn = post(conn, ~p"/api/uploads/init", %{name: "photo.jpg"})
      assert %{"upload_id" => id} = json_response(conn, 200)
      assert String.length(id) > 0
    end
  end

  describe "PUT /api/uploads/:upload_id/data" do
    test "requires authentication", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "application/json")
        |> put_req_header("content-type", "image/jpeg")
        |> put(~p"/api/uploads/some-id/data", "data")
      assert json_response(conn, 401)
    end

    test "accepts raw binary and marks upload complete", %{conn: conn} do
      user = Vibeflow.AccountsFixtures.user_fixture()
      conn = log_in_user(conn, user)

      post(conn, ~p"/api/uploads/init", %{upload_id: "up-1", name: "test.jpg", type: "image/jpeg", size: 11})

      conn =
        conn
        |> put_req_header("content-type", "image/jpeg")
        |> put(~p"/api/uploads/up-1/data", "hello world")

      assert %{"status" => "ok"} = json_response(conn, 200)

      assert %{status: :complete, path: path} = Vibeflow.UploadTracker.get("up-1")
      assert String.ends_with?(path, ".jpg")
      assert File.exists?(path)
      assert File.read!(path) == "hello world"
    end
  end
end
