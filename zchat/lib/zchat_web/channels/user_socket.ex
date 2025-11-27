defmodule ZchatWeb.UserSocket do
  use Phoenix.Socket

  channel "conversation:*", ZchatWeb.ConversationChannel
  channel "chat_topic", ZchatWeb.ChatChannelChannel

  @impl true
  def connect(%{"token" => token} = _params, socket, _connect_info) do
    IO.inspect(token, label: "UserSocket connect token")
    case Base.url_decode64(token) do

      {:ok, decoded_token} ->
        if user = Zchat.Accounts.get_user_by_session_token(decoded_token) do
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
