defmodule ZchatWeb.Plugs.LoadNavigation do
  import Plug.Conn
  alias ZchatWeb.Navigation

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      nil ->
        conn

      current_user ->
        navigation_items = Navigation.get_user_navigation(current_user)

        assign(conn, :navigation_items, navigation_items)
    end
  end
end
