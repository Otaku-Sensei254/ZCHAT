defmodule VibeflowWeb.ChatAuthHook do
  import Phoenix.LiveView
  import Phoenix.Component
  alias Vibeflow.Chat
  use VibeflowWeb, :verified_routes

  def on_mount(:require_member, %{"id" => conversation_id}, _session, socket) do
    user = socket.assigns.current_user
    IO.inspect(user, label: "User info is this")

    # now we check if the user logged in belongs to the chat
    # the user_id and conversation_id should match in the DB
    if Chat.member_of_conversation?(user, conversation_id) do
      {:cont, socket}
    else
      socket =
        socket
        |> put_flash(:error, "Invalid entry")
        |> redirect(to: ~p"/feed")

      {:halt, socket}
    end
  end

  def on_mount(:require_member, _params, _session, socket), do: {:cont, socket}
end
