defmodule Vibeflow.Store.Inventory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :id

  schema "inventory" do
    field :item_slug, :binary_id
    field :is_equipped, :boolean, default: false
    field :metadata, :map, default: %{}

    belongs_to :user, Vibeflow.Accounts.User

    timestamps()
  end

  def changeset(inventory, attrs) do
    inventory
    |> cast(attrs, [:user_id, :item_slug, :is_equipped, :metadata])
    |> validate_required([:user_id, :item_slug])
  end
end
