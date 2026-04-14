defmodule Vibeflow.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Vibeflow.Repo
  alias Vibeflow.Accounts.{User, UserToken, UserNotifier, Role, Permission, VerificationRequest}
  alias Vibeflow.Infrastructure.UploadCloudinary
  ## Database getters

  def get_user_by_email(email) when is_binary(email) do
    with user when not is_nil(user) <- Repo.get_by(User, email: email) do
      Repo.preload(user, roles: :permissions)
    end
  end

  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  def list_users, do: Repo.all(User)

  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: username)
  end

  def get_user!(id) do
    Repo.get!(User, id)
    |> Repo.preload(roles: :permissions)
  end

  ## User registration

  def register_user(attrs) do
    # UPDATED: Handle avatar upload before changeset
    attrs = handle_image_upload(attrs, "avatar_url")

    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, [context]))
  end

  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Profile

  def change_user_profile(%User{} = user, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
  end

  def update_user_profile(%User{} = user, attrs) do
    # UPDATED: Handle avatar upload before changeset
    attrs = handle_image_upload(attrs, "avatar_url")

    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  # user request verifications
  def get_verified(%User{} = user, attrs \\ %{}) do
    cond do
      Repo.exists?(
        from(v in VerificationRequest, where: v.user_id == ^user.id and v.status == "approved")
      ) ->
        {:ok, "User is verified"}

      Repo.exists?(
        from(v in VerificationRequest, where: v.user_id == ^user.id and v.status == "pending")
      ) ->
        {:error, :pending}

      true ->
        create_verification_request(user, attrs)
    end
  end

  defp create_verification_request(user, attrs) do
    user = Repo.preload(user, :social_accounts)
    # check if they have social accounts
    fetch_socials = Enum.map(user.social_accounts, & &1.url)

    attrs =
      attrs
      |> Map.put("user_id", user.id)
      |> Map.put("social_links", fetch_socials)

    case %VerificationRequest{}
         |> VerificationRequest.changeset(attrs)
         |> Repo.insert() do
      {:ok, _request} ->
        # Notify admins
        notify_admins_of_verification_request(user)
        {:ok, "Verification request submitted"}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp notify_admins_of_verification_request(user) do
    admins = list_admins()
    moderators = list_moderators()

    (admins ++ moderators)
    |> Enum.uniq_by(& &1.id)
    |> Enum.each(fn admin ->
      Vibeflow.Notifications.create_notification(%{
        type: "verification_request",
        user_id: admin.id,
        actor_id: user.id
      })
    end)
  end

  def list_moderators do
    list_role_users("moderator")
  end

  defp list_role_users(role_name) do
    role = Repo.get_by(Role, name: role_name)

    if role do
      from(u in User,
        join: ur in "user_roles",
        on: u.id == ur.user_id,
        where: ur.role_id == ^role.id
      )
      |> Repo.all()
    else
      []
    end
  end

  # for admin and moderator to view all verification requests
  def list_verification_requests do
    VerificationRequest
    |> order_by(desc: :inserted_at)
    |> preload(:user)
    |> Repo.all()
  end

  # check for pending requests
  def list_pending_verification_requests do
    VerificationRequest
    |> where([v], v.status == "pending")
    |> order_by(asc: :inserted_at)
    |> preload(:user)
    |> Repo.all()
  end

  def get_verification_request!(id) do
    VerificationRequest
    |> Repo.get!(id)
    |> Repo.preload(:user)
  end

  # check request status
  def check_verification_status(%User{} = user) do
    Repo.get_by(VerificationRequest, user_id: user.id, status: "pending")
  end

  def get_latest_verification_request(%User{} = user) do
    from(vr in VerificationRequest,
      where: vr.user_id == ^user.id,
      order_by: [desc: vr.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  def get_latest_verification_request(_), do: nil

  # admin approves or rejects a verification request
  def approve_verification_request(%VerificationRequest{} = request, admin_id) do
    Repo.transaction(fn ->
      {:ok, updated_request} =
        request
        |> VerificationRequest.changeset(%{"status" => "approved"})
        |> Repo.update()

      {:ok, _user} =
        request.user
        |> User.profile_changeset(%{"is_verified" => true})
        |> Repo.update()

      # Notify user
      Vibeflow.Notifications.create_notification(%{
        type: "verification_approved",
        user_id: request.user_id,
        actor_id: admin_id
      })

      updated_request
    end)
  end

  def reject_verification_request(%VerificationRequest{} = request, admin_id, admin_notes \\ nil) do
    {:ok, updated_request} =
      request
      |> VerificationRequest.changeset(%{"status" => "rejected", "admin_notes" => admin_notes})
      |> Repo.update()

    # Notify user
    Vibeflow.Notifications.create_notification(%{
      type: "verification_rejected",
      user_id: request.user_id,
      actor_id: admin_id
    })

    {:ok, updated_request}
  end

  # defp create
  ## Session

  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)

    Repo.one(query)
    |> Repo.preload(roles: :permissions)
  end

  def delete_user_session_token(token) do
    Repo.delete_all(from(t in Vibeflow.Accounts.UserToken, where: t.token == ^token))
    :ok
  end

  ## Confirmation & Reset Password

  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, ["confirm"]))
  end

  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  # =================================================================
  # ROLE & PERMISSION MANAGEMENT
  # =================================================================

  def get_roles, do: Repo.all(Role) |> Repo.preload(:permissions) |> Repo.preload(:permissions)

  def get_user_with_roles!(id) do
    Repo.get!(User, id) |> Repo.preload(:roles)
  end

  def get_role_by_name(name), do: Repo.get_by(Role, name: name) |> Repo.preload(:permissions)

  def user_has_role?(%User{} = user, role_name) do
    user = Repo.preload(user, :roles)
    Enum.any?(user.roles, fn role -> role.name == role_name end)
  end

  def user_has_role?(user_id, role_name) when is_integer(user_id) do
    user = get_user!(user_id)
    user_has_role?(user, role_name)
  end

  # Get user's followers
  def get_user_followers(user_id) do
    from(u in User,
      join: f in "follows",
      on: f.follower_id == u.id,
      where: f.following_id == ^user_id,
      select: u
    )
    |> Repo.all()
  end

  # Get user's following
  def get_user_following(user_id) do
    from(u in User,
      join: f in "follows",
      on: f.following_id == u.id,
      where: f.follower_id == ^user_id,
      select: u
    )
    |> Repo.all()
  end

  def has_permission?(%User{} = user, permission_slug) do
    user = Repo.preload(user, roles: :permissions)

    Enum.any?(user.roles, fn role ->
      Enum.any?(role.permissions, fn p -> p.slug == permission_slug end)
    end)
  end

  def user_has_permission?(user, perm), do: has_permission?(user, perm)

  def update_user_roles(%User{} = user, role_ids) do
    roles = Repo.all(from(r in Role, where: r.id in ^role_ids))

    user
    |> Repo.preload(:roles)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:roles, roles)
    |> Repo.update()
  end

  def update_user_message_skin(user_id, skin) do
    from(u in User, where: u.id == ^user_id)
    |> Repo.update_all([set: [active_message_skin: skin]], returning: true)
    |> case do
      {1, [user]} -> {:ok, user}
      {1, [nil]} -> {:ok, %{id: user_id, active_message_skin: skin}} # Handle nil case
      {0, []} -> {:error, :not_found}
      {count, _} -> {:error, {:unexpected_count, count}}
    end
  end

  def list_permissions do
    Repo.all(Permission)
  end

  def create_role(attrs, permission_ids \\ []) do
    permissions =
      from(p in Permission, where: p.id in ^permission_ids)
      |> Repo.all()

    %Vibeflow.Accounts.Role{}
    |> Role.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:permissions, permissions)
    |> Repo.insert()
  end

  def search_users(query), do: search_users(query, nil)

  def search_users(query, exclude_user_id) do
    search_term = "%#{query}%"

    query = from(u in User,
      where: ilike(u.username, ^search_term) or ilike(u.bio, ^search_term),
      order_by: [asc: u.inserted_at],
      preload: [:roles]
    )

    # Exclude current user if exclude_user_id is provided
    query = if exclude_user_id do
      from(u in query, where: u.id != ^exclude_user_id)
    else
      query
    end

    Repo.all(query)
  end

  # --- ASSIGNMENT HELPERS ---

  def assign_role_to_user(user_id, role_id) when is_integer(user_id) and is_integer(role_id) do
    %User{}
    |> struct(id: user_id)
    |> Repo.preload(:roles)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:roles, [Repo.get!(Role, role_id)])
    |> Repo.update()
  end

  def assign_role_to_user(%User{} = user, %Vibeflow.Accounts.Role{} = role) do
    assign_role_to_user(user.id, role.id)
  end

  def remove_role_from_user(user_id, role_id) when is_integer(user_id) and is_integer(role_id) do
    from(ur in "user_roles",
      where: ur.user_id == ^user_id and ur.role_id == ^role_id
    )
    |> Repo.delete_all()
    |> case do
      {1, _} -> {:ok, "Role removed"}
      {0, _} -> {:error, "Role assignment not found"}
    end
  end

  def remove_role_from_user(%User{} = user, %Vibeflow.Accounts.Role{} = role) do
    remove_role_from_user(user.id, role.id)
  end

  def remove_admin_role(user_id) when is_integer(user_id) do
    case get_role_by_name("admin") do
      nil -> {:error, "Admin role not found"}
      admin_role -> remove_role_from_user(user_id, admin_role.id)
    end
  end

  def remove_admin_role(%User{} = user) do
    remove_admin_role(user.id)
  end

  def list_users_with_role(role_name) do
    case get_role_by_name(role_name) do
      nil ->
        []

      role ->
        from(u in User,
          join: ur in "user_roles",
          on: ur.user_id == u.id,
          where: ur.role_id == ^role.id,
          preload: [:roles]
        )
        |> Repo.all()
    end
  end

  def list_admins do
    list_users_with_role("admin")
  end

  def is_admin?(%User{} = user) do
    user_has_role?(user, "admin")
  end

  def is_admin?(user_id) when is_integer(user_id) do
    user = get_user!(user_id)
    user_has_role?(user, "admin")
  end

  # =================================================================
  # CLOUDINARY HELPER
  # =================================================================

  defp handle_image_upload(attrs, field_name) do
    # Get the value from attrs (supports string keys "avatar_url" or atom keys :avatar_url)
    value = attrs[field_name] || attrs[String.to_atom(field_name)]

    case value do
      # 1. If it's a Plug.Upload struct (from a standard form submission)
      %Plug.Upload{path: path} ->
        upload_to_cloudinary(path, attrs, field_name)

      # 2. If it's just a file path string (sometimes from LiveView temp files)
      path when is_binary(path) and byte_size(path) < 255 ->
        # Simple check to see if it looks like a local file path
        if File.exists?(path) do
          IO.puts("-> File exists on disk. Attempting upload...")
          upload_to_cloudinary(path, attrs, field_name)
        else
          attrs
        end

      _ ->
        attrs
    end
  end

  defp upload_to_cloudinary(path, attrs, field_name) do
    # FIX: We removed 'opts' because your uploader doesn't support it.
    # We simply pass the path.
    case Vibeflow.Infrastructure.UploadCloudinary.upload_file(path) do
      {:ok, result} ->
        IO.puts("-> SUCCESS: Cloudinary returned URL: #{result.url}")
        Map.put(attrs, field_name, result.url)

      {:error, reason} ->
        IO.inspect(reason, label: "-> FAILURE: Cloudinary Error")
        # If it fails, remove the temp path so we don't save a broken link
        Map.delete(attrs, field_name)
    end
  end

  # get friends
  def list_friends(%User{} = user) do
    user
    |> Repo.preload(:following)
    |> Map.get(:following)
  end

  def follow_user(user_a, user_b) do
    user_a
    |> Repo.preload(:following)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:following, [user_b | user_a.following])
    |> Repo.update()
  end

  # Adding mentions to posts and comments
  def mention_user_in_post(user_id, post_id) do
    # This is a placeholder function. You would implement the logic to create a mention record in the database.
    # For example, you might have a PostMention schema that tracks which users are mentioned in which posts.
    # You would create a new PostMention record here linking the user_id and post_id.
    {:ok, :mentioned}
  end

  # --- POINTS MANAGEMENT ---

  def grant_points(_user_id, 0), do: {:ok, :no_change}

  def grant_points(user_id, amount) when is_integer(user_id) and is_integer(amount) do
    from(u in User, where: u.id == ^user_id)
    |> Repo.update_all(inc: [points: amount])
    |> case do
      {1, _} ->
        # Broadcast for real-time UI updates
        Phoenix.PubSub.broadcast(
          Vibeflow.PubSub,
          "notifications:#{user_id}",
          {:points_awarded, %{user_id: user_id, amount: amount}}
        )

        {:ok, :awarded}

      _ ->
        {:error, :user_not_found}
    end
  end

  def grant_points(_, _), do: {:error, :invalid_input}
end
