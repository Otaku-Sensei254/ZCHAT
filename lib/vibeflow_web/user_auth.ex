defmodule VibeflowWeb.UserAuth do
  use VibeflowWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Vibeflow.Accounts

  # Make the remember me cookie valid for 60 days
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_zchat_web_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  ## -----------------------------
  ## User login / logout
  ## -----------------------------

  @doc """
  Logs the user in.
  """
  def log_in_user(conn, user, params \\ %{}) do
    token = Accounts.generate_user_session_token(user)
    user_return_to = get_session(conn, :user_return_to)

    conn
    |> renew_session()
    |> put_token_in_session(token)
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: user_return_to || signed_in_path(conn))
  end

  defp maybe_write_remember_me_cookie(conn, token, _params) do
    encoded_token = Base.url_encode64(token)
    put_resp_cookie(conn, @remember_me_cookie, encoded_token, @remember_me_options)
  end

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.
  """
  def log_out_user(conn) do
    user_token = get_session(conn, :user_token)
    raw_token = user_token && Base.url_decode64!(user_token)
    IO.inspect({:raw_token_in_logout, raw_token}, label: "Trace")
    raw_token && Accounts.delete_user_session_token(raw_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      VibeflowWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: ~p"/")
  end

  ## -----------------------------
  ## Fetch current user
  ## -----------------------------

  @doc """
  Authenticates the user by looking into the session and remember me token.
  """
  def fetch_current_user(conn, _opts) do
    {user_token, conn} = ensure_user_token(conn)
    user = user_token && Accounts.get_user_by_session_token(user_token)

    conn
    |> assign(:current_user, user)
    |> assign(:user_token, user_token && Base.url_encode64(user_token))
  end

  defp ensure_user_token(conn) do
    if encoded_token = get_session(conn, :user_token) do
      case Base.url_decode64(encoded_token) do
        {:ok, token} -> {token, conn}
        :error -> {nil, conn}
      end
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if encoded_token = conn.cookies[@remember_me_cookie] do
        case Base.url_decode64(encoded_token) do
          {:ok, token} -> {token, put_token_in_session(conn, token)}
          :error -> {nil, conn}
        end
      else
        {nil, conn}
      end
    end
  end

  ## -----------------------------
  ## LiveView on_mount callbacks
  ## -----------------------------

  def on_mount(:default, _params, session, socket),
    do: {:cont, mount_current_user(socket, session)}

  def on_mount(:mount_current_user, _params, session, socket),
    do: {:cont, mount_current_user(socket, session)}

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/users/log_in")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  @doc """
  Public wrapper for LiveViews to mount current_user.
  """
  def mount_current_user(socket, session) do
    mount_current_user_private(socket, session)
  end

  # Private function that does the real work
  defp mount_current_user_private(socket, session) do
    encoded_token = session["user_token"]

    socket
    |> Phoenix.Component.assign_new(:current_user, fn ->
      if encoded_token do
        case Base.url_decode64(encoded_token) do
          {:ok, token} -> Accounts.get_user_by_session_token(token)
          :error -> nil
        end
      else
        nil
      end
    end)
    |> Phoenix.Component.assign_new(:user_token, fn ->
      encoded_token
    end)
  end

  ## -----------------------------
  ## Route plugs
  ## -----------------------------

  @doc """
  Redirects if user is already authenticated.
  """
  def redirect_if_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Ensures the user is authenticated.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      if json_request?(conn) do
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "You must log in to access this page."})
        |> halt()
      else
        conn
        |> put_flash(:error, "You must log in to access this page.")
        |> maybe_store_return_to()
        |> redirect(to: ~p"/users/log_in")
        |> halt()
      end
    end
  end

  defp json_request?(conn) do
    conn
    |> get_req_header("accept")
    |> Enum.any?(&String.contains?(&1, "json"))
  end

  ## -----------------------------
  ## Helpers
  ## -----------------------------

  defp put_token_in_session(conn, token) do
    encoded_token = Base.url_encode64(token)

    conn
    |> put_session(:user_token, encoded_token)
    |> put_session(:live_socket_id, "users_sessions:#{encoded_token}")
  end

  defp maybe_store_return_to(%{method: "GET"} = conn),
    do: put_session(conn, :user_return_to, current_path(conn))

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: ~p"/feed"
end
