defmodule Vibeflow.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias Vibeflow.Posts.Post

  schema "users" do
    field(:username, :string)
    field(:email, :string)
    field(:avatar_url, :string)
    field(:bio, :string)
    field(:password, :string, virtual: true, redact: true)
    field(:hashed_password, :string, redact: true)
    field(:current_password, :string, virtual: true, redact: true)
    field(:confirmed_at, :naive_datetime)
    field(:is_verified, :boolean, default: false)
    field(:points, :integer, default: 0)
    field(:username_style, :string)
    field(:active_message_skin, :string, default: "default")
    has_many(:posts, Post)
    has_many(:social_accounts, Vibeflow.Socials.SocialAccount)
    has_many(:verification_requests, Vibeflow.Accounts.VerificationRequest)

    has_many(:user_roles, Vibeflow.Accounts.UserRole)
    many_to_many(:roles, Vibeflow.Accounts.Role, join_through: "user_roles", on_replace: :delete)

    many_to_many(:following, Vibeflow.Accounts.User,
      join_through: "follows",
      join_keys: [follower_id: :id, following_id: :id]
    )

    has_many(:reposts, Vibeflow.Posts.Repost)
    has_many(:likes, Vibeflow.Posts.Like)

    timestamps()
  end

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.

    * `:validate_email` - Validates the uniqueness of the email, in case
      you don't want to validate the uniqueness of the email (like when
      using this changeset for validations on a LiveView form before
      submitting the form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:username, :email, :password, :avatar_url])
    |> validate_email(opts)
    |> validate_required([:username])
    # Combined the constraints
    |> unique_constraint(:username, message: "Username already taken")
    # Optional, but good practice
    |> validate_length(:username, min: 2, max: 50)
    |> validate_password(opts)
    |> prepare_changes(fn changeset ->
      if changeset.valid? do
        Phoenix.PubSub.broadcast(Vibeflow.PubSub, "admin:stats", {:user_created, changeset.data})
      end

      changeset
    end)
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 30)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, Vibeflow.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  A changeset for updating public profile information (Avatar, Bio, Username).
  """
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :bio, :avatar_url, :is_verified, :username_style, :active_message_skin])
    |> validate_required([:username])
    |> validate_length(:username, min: 3, max: 20)
    |> validate_length(:bio, max: 160)
    # Ensure username is unique (excluding current user)
    |> unsafe_validate_unique(:username, Vibeflow.Repo)
    |> unique_constraint(:username)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Vibeflow.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    changeset = cast(changeset, %{current_password: password}, [:current_password])

    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  # helper function to check if user is admin
  # ... existing code ...

  @doc """
  Checks if the user is an admin.
  """

  def is_admin?(%Vibeflow.Accounts.User{roles: roles}) when is_list(roles) do
    Enum.any?(roles, fn role -> role.name == "admin" end)
  end

  # Fallback: If roles are not loaded (Ecto.Association.NotLoaded) or user is nil
  def is_admin?(_), do: false

  @doc """
  A changeset for upgrading users to admins (only accessible by system)
  """
  def admin_changeset(user, attrs) do
    user
    |> cast(attrs, [:role])
    |> validate_inclusion(:role, ["user", "admin", "moderator"])
  end

  @doc """
  A user changeset for updating user roles.
  """
  def roles_changeset(user, attrs) do
    user
    # No direct fields to cast, only associations
    |> cast(attrs, [])
    |> cast_assoc(:roles)
  end

  @doc """
  A user changeset for updating user roles without initial attributes.
  """
  def roles_changeset(user) do
    user
    # No direct fields to cast, only associations
    |> cast(%{}, [])

    |> cast_assoc(:roles)
  end
end
