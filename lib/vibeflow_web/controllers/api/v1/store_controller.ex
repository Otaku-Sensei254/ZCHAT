defmodule VibeflowWeb.Api.V1.StoreController do
  use VibeflowWeb, :controller

  alias Vibeflow.Store
  alias Vibeflow.Accounts
  alias Vibeflow.Repo

  def index(conn, _params) do
    items = Store.list_store_items()
    user = conn.assigns.current_user
    points = if user, do: user.points || 0, else: 0

    json(conn, %{
      data: %{
        items: Enum.map(items, &item_json/1),
        points_balance: points
      }
    })
  end

  def purchase(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    if user do
      case Store.purchase_item(user.id, id) do
        {:ok, _inv} ->
          updated_user = Repo.get!(Vibeflow.Accounts.User, user.id)
          points_balance = updated_user.points || 0

          json(conn, %{
            data: %{
              success: true,
              points_balance: points_balance,
              message: "Item purchased successfully!"
            }
          })

        {:error, :already_active} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "You already own this item. Try again after it expires."})

        {:error, :insufficient_points} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "You do not have enough points for this item."})

        {:error, _} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Purchase failed. Try again."})
      end
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Please log in to purchase items."})
    end
  end

  defp item_json(item) do
    %{
      id: item.id,
      item_name: item.item_name,
      item_slug: item.item_slug,
      worth: item.worth,
      duration: item.duration,
      category: item.category
    }
  end
end
