defmodule VibeflowWeb.UI.Store.StoreLive do
  use VibeflowWeb, :live_view
  alias Vibeflow.Store
  alias Vibeflow.Repo
  alias Vibeflow.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    points_balance =
      socket.assigns.current_user
      |> maybe_get_points()

    items = Store.list_store_items()
    grouped_items = Enum.group_by(items, &(&1.category || "other"))

    socket =
      socket
      |> assign(points_balance: points_balance)
      |> assign(points_display: format_points(points_balance))
      |> assign(store_items: items)
      |> assign(grouped_items: grouped_items)

    {:ok, socket}
  end

  @impl true
  def handle_event("purchase_item", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    if user do
      item = Enum.find(socket.assigns.store_items, &(&1.id == id))

      case Store.purchase_item(user.id, id) do
        {:ok, _inv} ->
          points_balance = maybe_get_points(Repo.get!(User, user.id))

          socket =
            socket
            |> assign(points_balance: points_balance)
            |> assign(points_display: format_points(points_balance))

          if item && item.item_slug == "profile-glow" do
            {:noreply, push_navigate(socket, to: ~p"/users/settings?glow=1")}
          else
            {:noreply, put_flash(socket, :info, "Item purchased!")}
          end

        {:error, :already_active} ->
          {:noreply,
           put_flash(socket, :error, "You already own this item. Try again after it expires.")}

        {:error, :insufficient_points} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "Purchase failed. You do not have enough points for this item."
           )}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Purchase failed. Try again.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Please log in to purchase items.")}
    end
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
