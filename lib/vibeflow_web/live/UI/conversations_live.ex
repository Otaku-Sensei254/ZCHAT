defmodule VibeflowWeb.UI.ConversationsLive do
  use VibeflowWeb, :live_view

  alias Vibeflow.Chat

  # 1. MOUNT
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    conversations = Chat.list_user_conversations(user)
    {:ok, assign(socket, :conversations, conversations)}
  end
end
