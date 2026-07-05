defmodule VibeflowWeb.Api.V1.UserController do
  use VibeflowWeb, :controller

  def show(conn, %{"username" => username}) do
    case Vibeflow.Accounts.get_user_by_username(username) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "User not found"})
      user ->
        followers = Vibeflow.Accounts.get_user_followers(user.id)
        following = Vibeflow.Accounts.get_user_following(user.id)
        posts = Vibeflow.Posts.list_posts(user_id: user.id, per_page: 20)
        is_following = if conn.assigns[:current_user] do
          Enum.any?(followers, fn f -> f.id == conn.assigns[:current_user].id end)
        else
          false
        end

        json(conn, %{
          data: %{
            user: profile_json(user, length(followers), length(following)),
            posts: Enum.map(posts, &post_json/1),
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
    case Vibeflow.Accounts.update_user_profile(current_user, user_params) do
      {:ok, user} ->
        json(conn, %{data: %{user: profile_json(user, 0, 0)}})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset(changeset)})
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

  def creator_hub(conn, %{"username" => username}) do
    case Vibeflow.Accounts.get_user_by_username(username) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "User not found"})
      user ->
        if conn.assigns.current_user.id == user.id do
          stats = Vibeflow.Posts.list_creator_hub_posts(user.id)
          json(conn, %{data: %{stats: stats}})
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
      followers_count: followers_count,
      following_count: following_count,
      inserted_at: user.inserted_at
    }
  end

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
      !String.contains?(url, "cloudinary.com")
    end)
  end
end
