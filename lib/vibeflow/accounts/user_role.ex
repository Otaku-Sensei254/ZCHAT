# lib/zchat/accounts/user_role.ex
defmodule Vibeflow.Accounts.UserRole do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_roles" do
    belongs_to :user, Vibeflow.Accounts.User
    belongs_to :role, Vibeflow.Accounts.Role

    timestamps()
  end

  def changeset(user_role, attrs) do
    user_role
    |> cast(attrs, [:user_id, :role_id])
    |> validate_required([:user_id, :role_id])
    |> unique_constraint([:user_id, :role_id])
  end
end
