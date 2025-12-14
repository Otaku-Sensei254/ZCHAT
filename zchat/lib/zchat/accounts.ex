defmodule Zchat.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Zchat.Repo
  alias Zchat.Accounts.{User, UserToken, UserNotifier, Role, Permission}

  ## Database getters

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
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
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
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

  def get_roles, do: Repo.all(Role)

  def get_user_with_roles!(id) do
    Repo.get!(User, id) |> Repo.preload(:roles)
  end

  def get_role_by_name(name), do: Repo.get_by(Role, name: name)

  def user_has_role?(%User{} = user, role_name) do
    user = Repo.preload(user, :roles)
    Enum.any?(user.roles, fn role -> role.name == role_name end)
  end

  def user_has_role?(user_id, role_name) when is_integer(user_id) do
    user = get_user!(user_id)
    user_has_role?(user, role_name)
  end

  def has_permission?(%User{} = user, permission_slug) do
    user = Repo.preload(user, [roles: :permissions])
    Enum.any?(user.roles, fn role ->
      Enum.any?(role.permissions, fn p -> p.slug == permission_slug end)
    end)
  end

  def user_has_permission?(user, perm), do: has_permission?(user, perm)

  def update_user_roles(%User{} = user, role_ids) do
    roles = Repo.all(from r in Role, where: r.id in ^role_ids)

    user
    |> Repo.preload(:roles)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:roles, roles)
    |> Repo.update()
  end

  def list_permissions do
    Repo.all(Permission)
  end

  def create_role(attrs, permission_ids \\ []) do
    permissions = (from p in Permission , where: p.id in ^permission_ids)
    |> Repo.all()

    %Zchat.Accounts.Role{}
    |> Role.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:permissions, permissions)
    |> Repo.insert()
  end

  def search_users(query) do
    search_term = "%#{query}%"
    from(u in User,
      where: ilike(u.username, ^search_term) or ilike(u.bio, ^search_term),
      order_by: [asc: u.inserted_at],
      preload: [:roles]
    )
    |> Repo.all()
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

  def assign_role_to_user(%User{} = user, %Zchat.Accounts.Role{} = role) do
    assign_role_to_user(user.id, role.id)
  end

  def remove_role_from_user(user_id, role_id) when is_integer(user_id) and is_integer(role_id) do
    from(ur in "user_roles",
      where: ur.user_id == ^user_id and ur.role_id == ^role_id)
    |> Repo.delete_all()
    |> case do
      {1, _} -> {:ok, "Role removed"}
      {0, _} -> {:error, "Role assignment not found"}
    end
  end

  def remove_role_from_user(%User{} = user, %Zchat.Accounts.Role{} = role) do
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
      nil -> []
      role ->
        from(u in User,
          join: ur in "user_roles", on: ur.user_id == u.id,
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
           upload_to_cloudinary(path, attrs, field_name)
        else
           attrs
        end

      _ ->
        attrs
    end
  end

 defp upload_to_cloudinary(path, attrs, field_name) do
    opts = [resource_type: :auto]

    case Zchat.Infrastructure.UploadCloudinary.upload_file(path, opts) do
      {:ok, result} ->
        Map.put(attrs, field_name, result.secure_url)
      {:error, reason} ->
        IO.inspect(reason, label: "CLOUDINARY UPLOAD ERROR")
        attrs
    end
  end
end
