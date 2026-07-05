defmodule VibeflowWeb.Api.V1.AdminController do
  use VibeflowWeb, :controller

  alias Vibeflow.Accounts
  alias Vibeflow.Posts
  alias Vibeflow.Repo

  def stats(conn, _params) do
    stats = Posts.get_system_stats()
    categories = Posts.count_posts_by_category()
    tags = Posts.count_top_tags()

    json(conn, %{
      data: %{
        stats: %{
          total_users: stats.total_users,
          total_posts: stats.total_posts,
          total_comments: stats.total_comments
        },
        categories: Enum.map(categories, fn {cat, count} -> %{category: cat, count: count} end),
        tags: Enum.map(tags, fn {tag, count} -> %{tag: tag, count: count} end)
      }
    })
  end

  def users(conn, params) do
    opts = []
    opts = if params["search"], do: Keyword.put(opts, :search, params["search"]), else: opts
    opts = if params["sort_by"], do: Keyword.put(opts, :sort_by, params["sort_by"]), else: opts

    users =
      Accounts.list_users(opts)
      |> Repo.preload(:roles)

    json(conn, %{
      data: %{
        users: Enum.map(users, &admin_user_json/1)
      }
    })
  end

  def update_user_roles(conn, %{"id" => id}) do
    user = Accounts.get_user!(String.to_integer(id))
    role_ids = (conn.params["role_ids"] || []) |> Enum.map(&String.to_integer/1)

    case Accounts.update_user_roles(user, role_ids) do
      {:ok, updated_user} ->
        updated_user = Repo.preload(updated_user, :roles)
        json(conn, %{data: %{user: admin_user_json(updated_user)}})

      {:error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Could not update roles"})
    end
  end

  def remove_role(conn, %{"user_id" => user_id, "role_id" => role_id}) do
    case Accounts.remove_role_from_user(
           String.to_integer(user_id),
           String.to_integer(role_id)
         ) do
      {:ok, _} ->
        json(conn, %{data: %{success: true}})

      {:error, msg} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: msg})
    end
  end

  def toggle_role(conn, %{"user_id" => user_id, "role_id" => role_id}) do
    user = Accounts.get_user!(String.to_integer(user_id)) |> Repo.preload(:roles)
    target_role_id = String.to_integer(role_id)
    current_role_ids = Enum.map(user.roles, & &1.id)

    new_role_ids =
      if target_role_id in current_role_ids do
        List.delete(current_role_ids, target_role_id)
      else
        [target_role_id | current_role_ids]
      end

    case Accounts.update_user_roles(user, new_role_ids) do
      {:ok, updated_user} ->
        updated_user = Repo.preload(updated_user, :roles)
        json(conn, %{data: %{user: admin_user_json(updated_user)}})

      {:error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Could not toggle role"})
    end
  end

  def verifications(conn, params) do
    filter = params["filter"] || "pending"

    requests =
      if filter == "pending" do
        Accounts.list_pending_verification_requests()
      else
        Accounts.list_verification_requests()
      end

    json(conn, %{
      data: %{
        requests: Enum.map(requests, &verification_json/1)
      }
    })
  end

  def approve_verification(conn, %{"id" => id}) do
    request = Accounts.get_verification_request!(String.to_integer(id))
    admin_id = conn.assigns.current_user.id

    case Accounts.approve_verification_request(request, admin_id) do
      {:ok, _} ->
        json(conn, %{data: %{success: true}})

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Could not approve"})
    end
  end

  def reject_verification(conn, %{"id" => id}) do
    request = Accounts.get_verification_request!(String.to_integer(id))
    admin_id = conn.assigns.current_user.id
    admin_notes = conn.params["admin_notes"]

    case Accounts.reject_verification_request(request, admin_id, admin_notes) do
      {:ok, _} ->
        json(conn, %{data: %{success: true}})

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Could not reject"})
    end
  end

  def roles(conn, _params) do
    all_roles = Accounts.get_roles()

    json(conn, %{
      data: %{
        roles: Enum.map(all_roles, &role_json/1)
      }
    })
  end

  def create_role(conn, params) do
    permission_ids = params["permission_ids"] || []

    case Accounts.create_role(params, permission_ids) do
      {:ok, role} ->
        role = Repo.preload(role, :permissions)
        json(conn, %{data: %{role: role_json(role)}})

      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Could not create role"})
    end
  end

  def permissions(conn, _params) do
    all_permissions = Accounts.list_permissions()

    json(conn, %{
      data: %{
        permissions:
          Enum.map(all_permissions, fn p -> %{id: p.id, name: p.name, slug: p.slug} end)
      }
    })
  end

  def verification_count(conn, _params) do
    pending = Accounts.list_pending_verification_requests() |> length()
    json(conn, %{data: %{pending_count: pending}})
  end

  defp admin_user_json(user) do
    %{
      id: user.id,
      username: user.username,
      email: user.email,
      avatar_url: user.avatar_url,
      bio: user.bio,
      points: user.points || 0,
      is_verified: user.is_verified,
      inserted_at: user.inserted_at,
      roles:
        Enum.map(user.roles || [], fn r -> %{id: r.id, name: r.name} end)
    }
  end

  defp verification_json(request) do
    %{
      id: request.id,
      status: request.status,
      social_links: request.social_links || [],
      admin_notes: request.admin_notes,
      user: %{
        id: request.user.id,
        username: request.user.username,
        avatar_url: request.user.avatar_url,
        is_verified: request.user.is_verified
      },
      inserted_at: request.inserted_at
    }
  end

  defp role_json(role) do
    %{
      id: role.id,
      name: role.name,
      permissions:
        Enum.map(role.permissions || [], fn p -> %{id: p.id, name: p.name, slug: p.slug} end)
    }
  end
end
