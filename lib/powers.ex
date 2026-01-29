defimpl Canada.Can, for: Zchat.Accounts.User do
  alias Zchat.Posts.Post
  alias Zchat.Chat.Conversation
  alias Zchat.Accounts

  # --- SPECIFIC RULES FIRST ---

  # create post
  def can?(user, :create, Post) do
    Accounts.user_has_permission?(user, "post-new")
  end

  # edit post (owner or has post-edit permission)
  def can?(user, :edit, %Post{} = post) do
    post.user_id == user.id or Accounts.user_has_permission?(user, "post-edit")
  end

  # delete post (owner or has post-delete permission)
  def can?(user, :delete, %Post{} = post) do
    post.user_id == user.id or Accounts.user_has_permission?(user, "post-delete")
  end

  # chat permissions
  def can?(user, :read, %Conversation{} = conversation) do
    Zchat.Chat.member_of_conversation?(user.id, conversation.id)
  end

  # --- LAST: ADMIN GLOBAL ALLOW ---
  def can?(%Zchat.Accounts.User{} = user, _action, _resource) do
    Ecto.assoc_loaded?(user.roles) &&
      Enum.any?(user.roles, &(&1.name == "admin"))
  end

  # fallback
  def can?(_, _, _), do: false
end
