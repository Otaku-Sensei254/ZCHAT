defmodule VibeflowWeb.Api.V1.UserController do
  use VibeflowWeb, :controller
  import Ecto.Query

  def show(conn, %{"username" => username}) do
    case Vibeflow.Accounts.get_user_by_username(username) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "User not found"})
      user ->
        user = Vibeflow.Repo.preload(user, [:roles, :social_accounts])
        followers = Vibeflow.Accounts.get_user_followers(user.id)
        following = Vibeflow.Accounts.get_user_following(user.id)
        posts =
          Vibeflow.Posts.Post
          |> where([p], p.user_id == ^user.id and p.status == "published" and p.content_type == "standard")
          |> order_by([p], desc: p.inserted_at)
          |> limit(20)
          |> Vibeflow.Repo.all()
          |> Vibeflow.Repo.preload([:user, :likes, :reposts, comments: :user])

        currents =
          Vibeflow.Posts.Post
          |> where([p], p.user_id == ^user.id and p.status == "published" and p.content_type == "current")
          |> order_by([p], desc: p.inserted_at)
          |> limit(20)
          |> Vibeflow.Repo.all()
          |> Vibeflow.Repo.preload([:user, :likes, :reposts, comments: :user])

        is_following = if conn.assigns[:current_user] do
          Enum.any?(followers, fn f -> f.id == conn.assigns[:current_user].id end)
        else
          false
        end

        json(conn, %{
          data: %{
            user: profile_json(user, length(followers), length(following)),
            posts: Enum.map(posts, &post_json/1),
            currents: Enum.map(currents, &post_json/1),
            is_following: is_following
          }
        })
    end
  end

  def search(conn, %{"q" => query}) do
    exclude_id = if conn.assigns[:current_user], do: conn.assigns[:current_user].id
    users = Vibeflow.Accounts.search_users(query, exclude_id)
    json(conn, %{data: %{users: Enum.map(users, &user_json/1)}})
  end

  def follow(conn, %{"username" => username}) do
    current_user = conn.assigns.current_user
    case Vibeflow.Accounts.get_user_by_username(username) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "User not found"})
      target when target.id == current_user.id ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Cannot follow yourself"})
      target ->
        case Vibeflow.Accounts.follow_user(current_user, target) do
          {:ok, _} -> json(conn, %{data: %{following: true}})
          {:error, :already_following} -> json(conn, %{data: %{following: true, already: true}})
          {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Could not follow user"})
        end
    end
  end

  def unfollow(conn, %{"username" => username}) do
    current_user = conn.assigns.current_user
    case Vibeflow.Accounts.get_user_by_username(username) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "User not found"})
      target ->
        case Vibeflow.Socials.delete_follow(current_user.id, target.id) do
          {:ok, _} -> json(conn, %{data: %{following: false}})
          {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Could not unfollow user"})
        end
    end
  end

  def update_profile(conn, %{"user" => user_params}) do
    current_user = conn.assigns.current_user

    if Map.has_key?(user_params, "username_style") and
         user_params["username_style"] != "none" and
         not Vibeflow.Store.has_active_item?(current_user.id, "profile-glow") do
      conn
      |> put_status(:forbidden)
      |> json(%{errors: %{username_style: ["Purchase Profile Glow from the Wave Store to unlock username styles."]}})
    else
      case Vibeflow.Accounts.update_user_profile(current_user, user_params) do
        {:ok, user} ->
          json(conn, %{data: %{user: profile_json(user, 0, 0)}})
        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: format_changeset(changeset)})
      end
    end
  end

  def update_password(conn, %{"current_password" => current, "password" => password, "password_confirmation" => confirmation}) do
    current_user = conn.assigns.current_user
    case Vibeflow.Accounts.update_user_password(current_user, current, %{
      password: password,
      password_confirmation: confirmation
    }) do
      {:ok, _} ->
        json(conn, %{data: %{message: "Password updated"}})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset(changeset)})
    end
  end

  def update_password(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Current password, new password and confirmation required"})
  end

  def saved_posts(conn, _params) do
    current_user = conn.assigns.current_user
    posts = Vibeflow.Posts.list_saved_posts(current_user.id)
    json(conn, %{data: %{posts: Enum.map(posts, &post_json/1)}})
  end

  def ping(conn, _params) do
    current_user = conn.assigns.current_user
    case Vibeflow.Accounts.ping_user(current_user.id) do
      {:ok, _user} ->
        json(conn, %{data: %{pinged: true}})
      {:error, _} ->
        json(conn, %{data: %{pinged: false}})
    end
  end

  def streak(conn, _params) do
    current_user = conn.assigns.current_user
    case Vibeflow.Accounts.get_streak(current_user.id) do
      {:ok, streak_data} ->
        json(conn, %{data: streak_data})
      {:error, _} ->
        json(conn, %{data: %{current_streak: 0, longest_streak: 0}})
    end
  end

  def verification_status(conn, _params) do
    current_user = conn.assigns.current_user
    pending = Vibeflow.Accounts.check_verification_status(current_user)
    latest = Vibeflow.Accounts.get_latest_verification_request(current_user)

    json(conn, %{
      data: %{
        has_pending: pending != nil,
        status: if(latest, do: latest.status, else: nil),
        social_links: if(latest, do: latest.social_links, else: [])
      }
    })
  end

  def social_accounts(conn, _params) do
    current_user = conn.assigns.current_user
    accounts = Vibeflow.Socials.list_social_accounts(current_user.id)
    json(conn, %{
      data: %{
        accounts: Enum.map(accounts, fn a ->
          %{
            id: a.id,
            platform: a.platform,
            url: a.url,
            username: a.username
          }
        end)
      }
    })
  end

  def add_social_account(conn, %{"platform" => platform, "username" => username}) do
    current_user = conn.assigns.current_user
    case Vibeflow.Socials.create_social_account(current_user, %{platform: platform, username: username}) do
      {:ok, account} ->
        json(conn, %{data: %{account: %{id: account.id, platform: account.platform, url: account.url, username: account.username}}})
      {:error, :social_limit_reached} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Max 3 social accounts allowed"})
      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: format_changeset(changeset)})
    end
  end

  def add_social_account(conn, params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Expected platform and username", received: params})
  end

  def delete_social_account(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user
    account = Vibeflow.Socials.get_social_account!(id)
    if account.user_id == current_user.id do
      {:ok, _} = Vibeflow.Socials.delete_social_account(id)
      json(conn, %{data: %{deleted: true}})
    else
      conn |> put_status(:forbidden) |> json(%{error: "Not your account"})
    end
  end

  def submit_verification(conn, _params) do
    current_user = conn.assigns.current_user
    case Vibeflow.Accounts.get_verified(current_user) do
      {:ok, _msg} ->
        json(conn, %{data: %{submitted: true}})
      {:error, :pending} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Verification already pending"})
      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Could not submit verification"})
    end
  end

  def suggestions(conn, _params) do
    current_user = conn.assigns[:current_user]
    users = if current_user do
      Vibeflow.Accounts.suggest_users_for_onboarding(current_user.id)
    else
      []
    end
    json(conn, %{data: %{users: Enum.map(users, &user_json/1)}})
  end

  def batch_follow(conn, %{"usernames" => usernames}) do
    current_user = conn.assigns.current_user
    Vibeflow.Accounts.batch_follow(current_user.id, usernames)
    json(conn, %{data: %{followed: true}})
  end

  def profile_by_code(conn, %{"code" => code}) do
    user =
      Vibeflow.Accounts.get_user_by_invite_code(code) ||
        Vibeflow.Accounts.get_user_by_username(code)

    case user do
      nil -> json(conn, %{data: nil})
      user ->
        user = Vibeflow.Repo.preload(user, :roles)
        json(conn, %{
          data: %{
            user: %{
              id: user.id,
              uuid: user.uuid,
              username: user.username,
              invite_code: user.invite_code,
              avatar_url: user.avatar_url,
              bio: user.bio,
              is_verified: user.is_verified,
              username_style: user.username_style,
              roles: clean_roles(user)
            }
          }
        })
    end
  end

  def creator_hub(conn, %{"username" => username}) do
    case Vibeflow.Accounts.get_user_by_username(username) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "User not found"})
      user ->
        if conn.assigns.current_user.id == user.id do
          stats = Vibeflow.Posts.list_creator_hub_posts(user.id)
          json(conn, %{
            data: %{
              stats: Enum.map(stats, fn s ->
                %{
                  post: post_json(s.post),
                  seed_count: s.seed_count,
                  rippled_count: s.rippled_count,
                  frontier_count: s.frontier_count,
                  likes_count: s.likes_count,
                  comments_count: s.comments_count,
                  ripplers: Enum.map(s.ripplers || [], &user_json/1)
                }
              end)
            }
          })
        else
          conn |> put_status(:forbidden) |> json(%{error: "Not your profile"})
        end
    end
  end

  def followers(conn, %{"username" => username}) do
    case Vibeflow.Accounts.get_user_by_username(username) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "User not found"})
      user ->
        followers = Vibeflow.Accounts.get_user_followers(user.id)
        json(conn, %{data: %{users: Enum.map(followers, &user_json/1)}})
    end
  end

  def following(conn, %{"username" => username}) do
    case Vibeflow.Accounts.get_user_by_username(username) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "User not found"})
      user ->
        following = Vibeflow.Accounts.get_user_following(user.id)
        json(conn, %{data: %{users: Enum.map(following, &user_json/1)}})
    end
  end

  defp profile_json(user, followers_count, following_count) do
    %{
      id: user.id,
      username: user.username,
      email: user.email,
      avatar_url: user.avatar_url,
      bio: user.bio,
      points: user.points || 0,
      is_verified: user.is_verified,
      username_style: user.username_style,
      active_message_skin: user.active_message_skin,
      confirmed_at: user.confirmed_at,
      followers_count: followers_count,
      following_count: following_count,
      inserted_at: user.inserted_at,
      roles: clean_roles(user),
      social_accounts: clean_social_accounts(user)
    }
  end

  defp clean_social_accounts(user) do
    case Map.get(user, :social_accounts) do
      nil -> []
      %Ecto.Association.NotLoaded{} -> []
      accounts ->
        Enum.map(accounts, fn a ->
          %{id: a.id, platform: a.platform, url: a.url, username: a.username}
        end)
    end
  end

  defp clean_roles(user) do
    case Map.get(user, :roles) do
      nil -> []
      %Ecto.Association.NotLoaded{} -> []
      roles -> Enum.map(roles, & %{name: &1.name, id: &1.id})
    end
  end

  defp user_json(%Ecto.Association.NotLoaded{}), do: nil

  defp user_json(user) do
    %{
      id: user.id,
      username: user.username,
      avatar_url: user.avatar_url,
      bio: user.bio,
      is_verified: user.is_verified,
      username_style: user.username_style
    }
  end

  defp post_json(post) do
    %{
      id: post.id,
      uuid: post.uuid,
      title: post.title,
      content: post.content,
      media_files: clean_media_files(post.media_files),
      tags: post.tags || [],
      category: post.category,
      view_count: Map.get(post, :view_count, 0),
      likes_count: Map.get(post, :likes_count, 0),
      comments_count: Map.get(post, :comments_count, 0),
      user: user_json(post.user),
      inserted_at: post.inserted_at
    }
  end

  defp format_changeset(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", format_error_value(value))
      end)
    end)
  end

  defp format_error_value(value) when is_list(value), do: Enum.join(value, ", ")
  defp format_error_value(value), do: to_string(value)

  defp clean_media_files(nil), do: []
  defp clean_media_files(files) do
    Enum.filter(files, fn f ->
      url = f["url"] || f[:url] || ""
      url != "" && !String.contains?(url, "cloudinary.com")
    end)
  end
end
