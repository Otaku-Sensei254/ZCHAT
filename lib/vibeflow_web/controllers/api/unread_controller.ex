defmodule VibeflowWeb.Api.UnreadController do
  use VibeflowWeb, :controller

  alias Vibeflow.Accounts
  alias Vibeflow.Chat

  # GET /api/unread_chats_count
  # Accepts either:
  # - query param `user_token` (Base.url_encode64'd or raw token)
  # - Authorization: Bearer <token>
  def show(conn, params) do
    token =
      case get_req_header(conn, "authorization") do
        [auth | _] ->
          case String.split(auth, " ") do
            ["Bearer", t] -> t
            _ -> nil
          end
        _ -> nil
      end || Map.get(params, "user_token")

    with token when not is_nil(token) <- token,
         raw_token <- decode_token_if_needed(token),
         user when not is_nil(user) <- Accounts.get_user_by_session_token(raw_token) do
      count = Chat.count_unread_conversations(user.id)
      json(conn, %{unread_chats_count: count})
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "unauthorized"})
    end
  end

  defp decode_token_if_needed(token) do
    case Base.url_decode64(token) do
      {:ok, decoded} -> decoded
      :error -> token
    end
  end
end
