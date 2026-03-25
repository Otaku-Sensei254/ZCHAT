# lib/zchat_web/navigation.ex
defmodule VibeflowWeb.Navigation do
  @moduledoc """
  Centralized navigation configuration for role-based menu items.
  """

  @doc """
  Returns all possible navigation items with their role requirements.
  """
  def get_nav_items do
    [
      # Dashboard - visible to all authenticated users
      %{
        path: "/admin/dashboard",
        label: "Dashboard",
        icon: "home",
        roles: ["admin"],
        section: nil
      },

      # Admin only section
      %{
        section: "User Management",
        roles: ["admin"]
      },
      %{
        path: "/admin/users",
        label: "All Users",
        icon: "users",
        roles: ["admin"],
        section: "User Management"
      },
      %{
        path: "/admin/roles",
        label: "Roles & Permissions",
        icon: "shield",
        roles: ["admin"],
        section: "User Management"
      },
      %{
        path: "/admin/verification-requests",
        label: "Verification Requests",
        icon: "shield",
        roles: ["admin"],
        section: "User Management"
      },

      # Moderator section
      %{
        path: "/moderator/dashboard",
        label: "Dashboard",
        icon: "home",
        roles: ["moderator"],
        section: nil
      },

      %{
        section: "Moderation",
        roles: ["moderator"]
      },
      %{
        path: "/moderator/reports",
        label: "Reports",
        icon: "eye",
        roles: ["moderator"],
        section: "Moderation"
      },
      %{
        path: "/moderator/verification-requests",
        label: "Verification Requests",
        icon: "shield",
        roles: ["moderator"],
        section: "Moderation"
      },

      # Sales Executive section
      %{
        path: "/sales-executive/dashboard",
        label: "Dashboard",
        icon: "home",
        roles: ["sales_executive"],
        section: nil
      },

      %{
        section: "Sales",
        roles: ["sales_executive"]
      },
      %{
        path: "/sales-executive/ads-request",
        label: "Ad Requests",
        icon: "briefcase",
        roles: ["sales_executive"],
        section: "Sales"
      },

      # Content section - visible to all
      %{
        section: "Content",
        roles: ["admin", "moderator", "sales_executive"]
      },
      %{
        path: "/feed",
        label: "View Live Feed",
        icon: "eye",
        roles: ["admin", "moderator", "sales_executive"],
        section: "Content"
      }
    ]
  end

  @doc """
  Filters navigation items based on user's roles.
  Returns only the items the user has access to.
  """
  def filter_by_user_roles(nav_items, user_roles) when is_list(user_roles) do
    # Extract role names from the user's roles
    user_role_names = Enum.map(user_roles, fn
      %{name: name} -> name
      role when is_binary(role) -> role
    end)

    # Filter items where user has at least one matching role
    Enum.filter(nav_items, fn item ->
      required_roles = Map.get(item, :roles, [])
      has_access?(user_role_names, required_roles)
    end)
  end

  def filter_by_user_roles(_nav_items, _user_roles), do: []

  @doc """
  Checks if user has access based on their roles.
  User needs at least ONE of the required roles.
  """
  defp has_access?(user_role_names, required_roles) do
    Enum.any?(required_roles, fn required_role ->
      required_role in user_role_names
    end)
  end

  @doc """
  Groups filtered navigation items by section for rendering.
  """
  def group_by_section(nav_items) do
    nav_items
    |> Enum.reduce([], fn item, acc ->
      cond do
        # It's a section header
        Map.has_key?(item, :section) and not Map.has_key?(item, :path) ->
          acc ++ [{:section_header, item.section}]

        # It's a nav link
        Map.has_key?(item, :path) ->
          acc ++ [{:nav_link, item}]

        true ->
          acc
      end
    end)
  end

  @doc """
  Helper to get user-specific navigation in one call.
  """
  def get_user_navigation(user) do
    get_nav_items()
    |> filter_by_user_roles(user.roles)
    |> group_by_section()
  end
end
