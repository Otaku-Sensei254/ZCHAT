# lib/zchat/accounts/role.ex
defmodule Vibeflow.Accounts.Role do
  use Ecto.Schema
  import Ecto.Changeset

  @permission_types [
    :manage_users,
    :manage_posts,
    :manage_comments,
    :view_analytics,
    :manage_roles,
    :moderate_content,
    :access_sales_dashboard,
    :manage_conversations
  ]

  def permission_types, do: @permission_types

  schema "roles" do
    field :name, :string

    many_to_many :users, Vibeflow.Accounts.User, join_through: "user_roles"

    many_to_many :permissions, Vibeflow.Accounts.Permission,
      join_through: "role_permissions",
      on_replace: :delete

    timestamps()
  end

  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end

  # Predefined roles with their permissions
  def predefined_roles do
    %{
      "admin" => [
        "manage_users",
        "manage_posts",
        "manage_comments",
        "view_analytics",
        "manage_roles",
        "moderate_content",
        "access_sales_dashboard",
        "manage_conversations"
      ],
      "moderator" => [
        "manage_posts",
        "manage_comments",
        "moderate_content",
        "manage_conversations"
      ],
      "sales_executive" => [
        "access_sales_dashboard",
        "view_analytics"
      ]
    }
  end
end
