defmodule VibeflowWeb.UI.Store.StoreLive do
  use VibeflowWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    points_balance =
      socket.assigns.current_user
      |> maybe_get_points()

    socket =
      socket
      |> assign(points_balance: points_balance)
      |> assign(points_display: format_points(points_balance))

    {:ok, socket}
  end

  defp maybe_get_points(nil), do: 0
  defp maybe_get_points(%{points: points}) when is_integer(points), do: points
  defp maybe_get_points(_), do: 0

  defp format_points(points) when is_integer(points) do
    points
    |> Integer.to_string()
    |> String.replace(~r/(?<=\d)(?=(?:\d{3})+$)/, ",")
  end
  defp format_points(_), do: "0"
end
