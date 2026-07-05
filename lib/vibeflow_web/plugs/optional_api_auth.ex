defmodule VibeflowWeb.Plugs.OptionalApiAuth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> encoded] <- get_req_header(conn, "authorization"),
         {:ok, token} <- Base.url_decode64(encoded),
         user when not is_nil(user) <- Vibeflow.Accounts.get_user_by_session_token(token) do
      assign(conn, :current_user, user)
    else
      _ -> conn
    end
  end
end
