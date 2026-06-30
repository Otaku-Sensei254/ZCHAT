defmodule VibeflowWeb.Chat.ChatSettingsRouterLive do
  use VibeflowWeb, :live_view

  alias Vibeflow.Chat

  def mount(%{"uuid" => conversation_uuid}, _session, socket) do
    conversation = Chat.get_conversation_by_uuid!(conversation_uuid)

    # Route to appropriate settings page based on conversation type
    if conversation.type == "group" do
      # Redirect to group settings
      {:ok, push_navigate(socket, to: ~p"/chat/#{conversation.uuid}/group-settings")}
    else
      # Redirect to individual chat settings
      {:ok, push_navigate(socket, to: ~p"/chat/#{conversation.uuid}/individual-settings")}
    end
  end
end
