defmodule Zchat.Accounts do
  @moduledoc """
  The Accounts context.
  """


  import Ecto.Query, warn: false
  alias Zchat.Repo
  alias Zchat.Accounts.{User, Role}
  alias Zchat.Accounts.{User, UserToken, UserNotifier, Role}

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  def list_users, do: Repo.all(User)

  #----Get user by username-----

  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: username)
  end
  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
def get_user!(id) do
  Repo.get!(User, id)
  |> Repo.preload(:roles)
end
  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
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

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm_email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
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

  ##update user avatar profile pic

def change_user_profile(%User{} = user, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
  end

  def update_user_profile(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)

    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
    |> Repo.preload(:roles)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &url(~p"/users/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
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

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
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

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/users/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
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


  # ROLE MANAGEMENT HELPERS
  def get_roles, do: Repo.all(Role)

  def get_user_with_roles!(id) do
    Repo.get!(User, id) |> Repo.preload(:roles)
  end
    def get_role_by_name(name), do: Repo.get_by(Role, name: name)


  @doc """
  Checks if a user has a specific role.
  """
  def user_has_role?(%User{roles: roles}, role_name) when is_list(roles) do
    Enum.any?(roles, fn role -> role.name == role_name end)
  end

  def user_has_role?(user, role_name) do
    # Fallback for when roles are not preloaded
    user
    |> Ecto.assoc(:roles)
    |> Repo.all()
    |> Enum.any?(fn role -> role.name == role_name end)
  end

  @doc """
  Checks if a user has a specific permission.
  """
  def user_has_permission?(%User{roles: roles}, permission) when is_list(roles) do
    Enum.any?(roles, fn role -> permission in role.permissions end)
  end

  def user_has_permission?(user, permission) do
    # Fallback for when roles are not preloaded
    user
    |> Ecto.assoc(:roles)
    |> Repo.all()
    |> Enum.any?(fn role -> permission in role.permissions end)
  end

  def update_user_roles(%User{} = user, role_ids) do
    roles = Repo.all(from r in Role, where: r.id in ^role_ids)

    user
    |> Repo.preload(:roles)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:roles, roles)
    |> Repo.update()
end
  def search_users(query)  do
    search_term = "%#{query}%"
    from(u in User,
    where: ilike(u.username, ^search_term) or ilike(u.bio, ^search_term),
    order_by: [asc: u.inserted_at],
    preload: [:roles]
    )
|> Repo.all()
  end

  # Add these role management functions to your Accounts module


@doc """
Assigns a role to a user.
"""
def assign_role_to_user(user_id, role_id) when is_integer(user_id) and is_integer(role_id) do
  %Zchat.Accounts.UserRole{}
  |> Zchat.Accounts.UserRole.changeset(%{user_id: user_id, role_id: role_id})
  |> Repo.insert(
    conflict_target: [:user_id, :role_id],
    on_conflict: :nothing
  )
end

def assign_role_to_user(%User{} = user, %Role{} = role) do
  assign_role_to_user(user.id, role.id)
end

@doc """
Removes a role from a user.
"""
def remove_role_from_user(user_id, role_id) when is_integer(user_id) and is_integer(role_id) do
  from(ur in "user_roles",
    where: ur.user_id == ^user_id and ur.role_id == ^role_id)
  |> Repo.delete_all()
  |> case do
    {1, _} -> {:ok, "Role removed"}
    {0, _} -> {:error, "Role assignment not found"}
  end
end

def remove_role_from_user(%User{} = user, %Role{} = role) do
  remove_role_from_user(user.id, role.id)
end

@doc """
Makes a user an admin by assigning the admin role.
"""
def make_user_admin(user_id) when is_integer(user_id) do
  case get_role_by_name("admin") do
    nil -> {:error, "Admin role not found"}
    admin_role -> assign_role_to_user(user_id, admin_role.id)
  end
end

def make_user_admin(%User{} = user) do
  make_user_admin(user.id)
end

@doc """
Removes admin role from a user.
"""
def remove_admin_role(user_id) when is_integer(user_id) do
  case get_role_by_name("admin") do
    nil -> {:error, "Admin role not found"}
    admin_role -> remove_role_from_user(user_id, admin_role.id)
  end
end

def remove_admin_role(%User{} = user) do
  remove_admin_role(user.id)
end

@doc """
Lists all users with a specific role.
"""
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

@doc """
Lists all admins.
"""
def list_admins do
  list_users_with_role("admin")
end

@doc """
Checks if a user is an admin.
"""
def is_admin?(%User{} = user) do
  user_has_role?(user, "admin")
end

def is_admin?(user_id) when is_integer(user_id) do
  user = get_user!(user_id)
  user_has_role?(user, "admin")
end

def can_manage() do
  
end

end
