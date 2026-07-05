defmodule VibeflowWeb.UserSocket do
  use Phoenix.Socket

  channel "conversation:*", VibeflowWeb.ConversationChannel
  channel "chat_topic", VibeflowWeb.ChatChannelChannel
  channel "relay:*", VibeflowWeb.RelayChannel

  @impl true
  def connect(%{"token" => token} = _params, socket, _connect_info) do
    case Base.url_decode64(token) do
      {:ok, decoded_token} ->
        if user = Vibeflow.Accounts.get_user_by_session_token(decoded_token) do
          {:ok, assign(socket, :current_user, user)}
        else
          :error
        end

      _ ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.current_user.id}"
end
