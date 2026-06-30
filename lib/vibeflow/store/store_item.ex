defmodule Vibeflow.Store.StoreItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "store_items" do
    field :item_name, :string
    field :item_slug, :string
    field :worth, :integer
    field :duration, :string
    field :category, :string
  end

  def changeset(store_item, attrs) do
    store_item
    |> cast(attrs, [:item_name, :item_slug, :worth, :duration, :category])
    |> validate_required([:item_name, :item_slug, :worth, :category])
  end
end
