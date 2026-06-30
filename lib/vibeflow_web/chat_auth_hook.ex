defmodule VibeflowWeb.ChatAuthHook do
  import Phoenix.LiveView
  import Phoenix.Component
  alias Vibeflow.Chat
  use VibeflowWeb, :verified_routes

  def on_mount(:require_member, %{"uuid" => conversation_uuid}, _session, socket) do
    user = socket.assigns.current_user

    case Chat.get_conversation(conversation_uuid) do
      nil ->
        {:halt, redirect(socket, to: ~p"/chat")}

      conversation ->
        if Chat.member_of_conversation?(user, conversation.id) do
          {:cont, socket}
        else
          socket =
            socket
            |> put_flash(:error, "You don't have permission to access this chat.")
            |> redirect(to: ~p"/chat")

          {:halt, socket}
        end
    end
  end

  def on_mount(:require_member, _params, _session, socket), do: {:cont, socket}
end
