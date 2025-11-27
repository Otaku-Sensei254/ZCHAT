# lib/zchat_web/plugs/ensure_admin.ex
defmodule ZchatWeb.Plugs.EnsureAdmin do
  import Plug.Conn
  import Phoenix.Controller


  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns.current_user &&
         Zchat.Accounts.user_has_role?(conn.assigns.current_user, "admin") do
      conn
    else
      conn
      |> put_flash(:error, "Unauthorized access")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
