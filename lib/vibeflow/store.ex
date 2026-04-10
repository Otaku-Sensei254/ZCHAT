defmodule Vibeflow.Store do
  @moduledoc false

  import Ecto.Query, only: [from: 2]

  alias Vibeflow.Repo
  alias Vibeflow.Accounts.User
  alias Vibeflow.Store.{Inventory, StoreItem}

  def list_store_items do
    Repo.all(from(s in StoreItem, order_by: [asc: s.category, asc: s.item_name]))
  end

  def get_store_item!(id), do: Repo.get!(StoreItem, id)

  def get_store_item_by_slug(slug) when is_binary(slug) do
    Repo.get_by(StoreItem, item_slug: slug)
  end

    def list_user_inventory(user_id) do
    Repo.all(
      from i in Inventory,
        join: s in StoreItem,
        on: s.id == i.item_slug,
        where: i.user_id == ^user_id,
        select: {s.item_slug, i.metadata}
    )
  end

   def get_user_item(user_id, identifier) when is_binary(identifier) do
    # Try by item name first, then by slug
    Repo.one(
      from i in Inventory,
        join: s in StoreItem,
        on: s.id == i.item_slug,
        where: i.user_id == ^user_id and (i.item_name == ^identifier or s.item_slug == ^identifier),
        limit: 1
    )
   end

  def activate_cosmetic(user_id, cosmetic_type, skin_name) do
    case cosmetic_type do
      "message_skin" ->
        alias Vibeflow.Accounts.User
        alias Vibeflow.Repo

        user = Repo.get!(User, user_id)
        user
        |> User.profile_changeset(%{active_message_skin: skin_name})
        |> Repo.update()

      _ ->
        :ok
    end
  end

  def get_active_cosmetics(user_id) do
    slugs = list_store_items() |> Enum.map(& &1.item_slug)

    items =
      Repo.all(
        from i in Inventory,
          join: s in StoreItem,
          on: s.id == i.item_slug,
          where: i.user_id == ^user_id and s.item_slug in ^slugs,
          select: %{name: s.item_name, slug: s.item_slug, metadata: i.metadata}
      )

    # Extract active message skin from inventory
    message_skin =
      items
      |> Enum.find(fn item ->
        (String.contains?(item.name, "Glassmorphism") or
         String.contains?(item.name, "Matrix") or
         String.contains?(item.name, "Holographic") or
         String.contains?(item.name, "Vantablack")) and not expired_metadata?(item.metadata)
      end)
      |> case do
        %{name: item_name} -> item_name
        nil -> "default"
      end

    %{
      message_skin: message_skin,
      frame: get_active_frame(items),
      glow: get_active_glow(items)
    }
  end

  defp get_active_frame(items) do
    case Enum.find(items, fn item ->
      String.contains?(item.slug, "wave-frame") and not expired_metadata?(item.metadata)
    end) do
      %{slug: "wave-frame-red"} -> "red"
      %{slug: "wave-frame-blue"} -> "blue"
      _ -> nil
    end
  end

  defp get_active_glow(items) do
    Enum.any?(items, fn item ->
      (item.name == "Profile Glow" or item.slug == "profile-glow") and not expired_metadata?(item.metadata)
    end)
  end

  def purchase_item(user_id, store_item_id) do
    store_item = get_store_item!(store_item_id)
    worth = get_item_worth(store_item)
    now = DateTime.utc_now()
    duration_seconds = parse_duration_seconds(store_item.duration)
    expires_at = if duration_seconds, do: DateTime.add(now, duration_seconds, :second), else: nil

    existing =
      Repo.get_by(Inventory, user_id: user_id, item_slug: store_item.id)

    cond do
      existing && not expired?(existing) ->
        {:error, :already_active}

      true ->
        Repo.transaction(fn ->
          charge_user!(user_id, worth)

          maybe_remove_other_frame!(user_id, store_item.item_slug)
          upsert_inventory(user_id, store_item.id, store_item.item_name, existing, expires_at)
        end)
        |> case do
          {:ok, inventory} -> {:ok, inventory}
          {:error, :insufficient_points} -> {:error, :insufficient_points}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def get_item_worth(store_item) do
    case store_item do
      nil -> 0
      %StoreItem{worth: worth} -> parse_worth(worth)
      _ -> 0
    end
  end

  defp upsert_inventory(user_id, store_item_id, store_item_name, existing, expires_at) do
    metadata =
      if expires_at,
        do: %{"expires_at" => DateTime.to_iso8601(expires_at)},
        else: %{}

    changeset =
      if existing do
        Inventory.changeset(existing, %{metadata: metadata})
      else
        Inventory.changeset(%Inventory{}, %{
          user_id: user_id,
          item_slug: store_item_id,
          item_name: store_item_name,
          is_equipped: false,
          metadata: metadata
        })
      end

    Repo.insert_or_update!(changeset)
  end

  defp charge_user!(user_id, worth) do
    {count, _} =
      from(u in User, where: u.id == ^user_id and u.points >= ^worth)
      |> Repo.update_all(inc: [points: -worth])

    if count == 1, do: :ok, else: Repo.rollback(:insufficient_points)
  end

  defp expired?(inventory) do
    case Map.get(inventory.metadata || %{}, "expires_at") do
      nil ->
        false

      iso ->
        case DateTime.from_iso8601(iso) do
          {:ok, dt, _} -> DateTime.compare(DateTime.utc_now(), dt) == :gt
          _ -> false
        end
    end
  end

  defp expired_metadata?(metadata) do
    case Map.get(metadata || %{}, "expires_at") do
      nil ->
        false

      iso ->
        case DateTime.from_iso8601(iso) do
          {:ok, dt, _} -> DateTime.compare(DateTime.utc_now(), dt) == :gt
          _ -> false
        end
    end
  end

  defp maybe_remove_other_frame!(user_id, item_slug) do
    frame_slugs = ["wave-frame-red", "wave-frame-blue"]

    if item_slug in frame_slugs do
      Repo.delete_all(
        from i in Inventory,
          join: s in StoreItem,
          on: s.id == i.item_slug,
          where: i.user_id == ^user_id and s.item_slug in ^frame_slugs and s.item_slug != ^item_slug
      )
    end

    :ok
  end

  defp parse_worth(worth) when is_integer(worth), do: worth

  defp parse_worth(worth) when is_binary(worth) do
    case Integer.parse(worth) do
      {int, _} -> int
      _ -> 0
    end
  end

  defp parse_duration_seconds(nil), do: nil
  defp parse_duration_seconds(""), do: nil

  defp parse_duration_seconds(duration) when is_binary(duration) do
    with [_, value, unit] <- Regex.run(~r/^(\d+)\s*([smhdw])$/i, String.trim(duration)),
         {int, ""} <- Integer.parse(value) do
      case String.downcase(unit) do
        "s" -> int
        "m" -> int * 60
        "h" -> int * 3600
        "d" -> int * 86_400
        "w" -> int * 604_800
        _ -> nil
      end
    else
      _ -> nil
    end
  end
end
