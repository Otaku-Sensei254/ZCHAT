defmodule VibeflowWeb.Api.V1.AuthController do
  use VibeflowWeb, :controller

  def register(conn, %{"user" => user_params}) do
    case Vibeflow.Accounts.register_user(user_params) do
      {:ok, user} ->
        token = Vibeflow.Accounts.generate_user_session_token(user)
        conn
        |> put_status(:created)
        |> json(%{data: %{token: Base.url_encode64(token), user: user_json(user)}})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset(changeset)})
    end
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Vibeflow.Accounts.get_user_by_email_and_password(email, password) do
      %{} = user ->
        token = Vibeflow.Accounts.generate_user_session_token(user)
        conn
        |> put_status(:ok)
        |> json(%{data: %{token: Base.url_encode64(token), user: user_json(user)}})

      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid email or password"})
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Email and password required"})
  end

  def me(conn, _params) do
    user = Vibeflow.Repo.preload(conn.assigns.current_user, :roles)
    json(conn, %{data: %{user: user_json(user)}})
  end

  def logout(conn, _params) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> encoded] ->
        token = case Base.url_decode64(encoded) do
          {:ok, t} -> t
          :error -> encoded
        end
        Vibeflow.Accounts.delete_user_session_token(token)
        json(conn, %{data: %{message: "Logged out"}})
      _ ->
        json(conn, %{data: %{message: "Logged out"}})
    end
  end

  def forgot_password(conn, %{"email" => email}) do
    user = Vibeflow.Accounts.get_user_by_email(email)
    if user do
      Vibeflow.Accounts.deliver_user_reset_password_instructions(
        user,
        fn token -> "http://localhost:3000/reset-password/#{token}" end
      )
    end
    json(conn, %{data: %{message: "If your email exists, you will receive reset instructions"}})
  end

  def forgot_password(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Email required"})
  end

  def reset_password(conn, %{"token" => token, "password" => password, "password_confirmation" => confirmation}) do
    user = Vibeflow.Accounts.get_user_by_reset_password_token(token)
    if user do
      case Vibeflow.Accounts.reset_user_password(user, %{password: password, password_confirmation: confirmation}) do
        {:ok, _} ->
          json(conn, %{data: %{message: "Password reset successfully"}})
        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: format_changeset(changeset)})
      end
    else
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{error: "Invalid or expired token"})
    end
  end

  def reset_password(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Token, password and confirmation required"})
  end

  def confirm_email(conn, %{"token" => token}) do
    case Vibeflow.Accounts.confirm_user(token) do
      {:ok, _user} ->
        json(conn, %{data: %{message: "Email confirmed successfully"}})
      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid or expired token"})
    end
  end

  def resend_confirmation(conn, %{"email" => email}) do
    user = Vibeflow.Accounts.get_user_by_email(email)
    if user do
      Vibeflow.Accounts.deliver_user_confirmation_instructions(
        user,
        fn token -> "http://localhost:3000/confirm-email/#{token}" end
      )
    end
    json(conn, %{data: %{message: "If your email exists, you will receive confirmation instructions"}})
  end

  def resend_confirmation(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Email required"})
  end

  defp user_json(user) do
    %{
      id: user.id,
      username: user.username,
      email: user.email,
      avatar_url: user.avatar_url,
      bio: user.bio,
      points: user.points || 0,
      is_verified: user.is_verified,
      username_style: user.username_style,
      active_message_skin: user.active_message_skin,
      confirmed_at: user.confirmed_at,
      inserted_at: user.inserted_at,
      roles: clean_roles(user)
    }
  end

  defp clean_roles(user) do
    case Map.get(user, :roles) do
      nil -> []
      roles -> Enum.map(roles, & %{name: &1.name})
    end
  end

  defp format_changeset(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", format_error_value(value))
      end)
    end)
  end

  defp format_error_value(value) when is_list(value), do: Enum.join(value, ", ")
  defp format_error_value(value), do: to_string(value)
end
