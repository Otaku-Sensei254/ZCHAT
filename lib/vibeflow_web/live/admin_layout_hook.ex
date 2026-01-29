defmodule VibeflowWeb.AdminLayoutHook do
  import Phoenix.Component
  import Phoenix.LiveView
  alias VibeflowWeb.Navigation

  def on_mount(:default, _params, _session, socket) do
    # Set the layout
    socket = attach_hook(socket, :set_layout, :handle_params, fn _params, url, socket ->
      {:cont,
       socket
       |> assign(:current_path, URI.parse(url).path)
       |> assign_new(:navigation_items, fn ->
         Navigation.get_user_navigation(socket.assigns.current_user)
       end)}
    end)

    {:cont, socket}
  end
end
