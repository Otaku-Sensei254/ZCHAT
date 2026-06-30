defmodule VibeflowWeb.ChatChannelChannelTest do
  use VibeflowWeb.ChannelCase
  import Phoenix.Socket

  setup do
    # Create a dummy user using your new fixture
    user = Vibeflow.AccountsFixtures.user_fixture()

    {:ok, _, socket} =
      VibeflowWeb.UserSocket
      |> socket("user_id", %{some: :assign})
      |> assign(:current_user, user)
      |> subscribe_and_join(VibeflowWeb.ChatChannelChannel, "chat_topic")

    %{socket: socket}
  end

  test "ping replies with status ok", %{socket: socket} do
    ref = push(socket, "ping", %{"hello" => "there"})
    assert_reply(ref, :ok, %{"hello" => "there"})
  end

  test "shout broadcasts to chat_channel:lobby", %{socket: socket} do
    push(socket, "shout", %{"content" => "all"})
    assert_broadcast("new_public_message", %{content: "all"})
  end

  test "broadcasts are pushed to the client", %{socket: socket} do
    broadcast_from!(socket, "broadcast", %{"some" => "data"})
    assert_push("broadcast", %{"some" => "data"})
  end
end
