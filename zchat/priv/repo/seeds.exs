# priv/repo/seeds.exs
alias Zchat.Repo
alias Zchat.Accounts
alias Zchat.Accounts.{User, Role}
alias Zchat.Posts

IO.puts("🌱 Starting Seed Script...")

# 1. CLEANUP (Safely delete old data)
Repo.delete_all(Zchat.Chat.Message)
Repo.delete_all(Zchat.Posts.Like)
Repo.delete_all(Zchat.Posts.Comment)
Repo.delete_all(Zchat.Posts.Post)
Repo.delete_all(User)
Repo.delete_all(Role)

IO.puts("🗑️  Database cleared.")

# 2. SETUP ROLES
role_names = ["admin", "moderator", "sales_executive", "user"]

# Insert roles
Enum.each(role_names, fn name ->
  Repo.insert!(%Role{name: name}, on_conflict: :nothing)
end)

# Fetch them back to ensure we have the IDs (This is safer)
roles = Repo.all(Role)
role_map = Map.new(roles, fn r -> {r.name, r} end)

IO.puts("✅ Roles created.")

# 3. CREATE SUPER ADMIN
admin_email = "admin@zchat.com"
password = "Password1234!"

{:ok, admin} =
  Accounts.register_user(%{
    username: "TheBoss",
    email: admin_email,
    password: password,
    avatar_url: nil
  })

# Assign ADMIN role
Accounts.update_user_roles(admin, [role_map["admin"].id])

IO.puts("👑 Admin created! Login: #{admin_email} / #{password}")

# 4. CREATE DUMMY USERS
users =
  for i <- 1..5 do
    {:ok, user} =
      Accounts.register_user(%{
        username: "User_#{i}",
        email: "user#{i}@test.com",
        password: password,
        avatar_url: nil
      })

    # Assign USER role
    Accounts.update_user_roles(user, [role_map["user"].id])
    user
  end

IO.puts("👥 Created 5 dummy users.")

# 5. CREATE POSTS
all_users = [admin | users]
categories = Zchat.Posts.categories()

for _i <- 1..25 do
  random_user = Enum.random(all_users)
  random_category = Enum.random(categories)

  {:ok, post} =
    Posts.create_post(random_user, %{
      title: "Random Topic #{System.unique_integer([:positive])}",
      content: "This is a seeded post to test the feed. Zchat is growing!",
      category: random_category,
      tags: ["seed", "test", "elixir"]
    })

  # Add random likes
  if :rand.uniform(10) > 3 do
    random_liker = Enum.random(all_users)
    Posts.toggle_like(random_liker.id, "Post", post.id)
  end
end

IO.puts("📝 Created posts with likes.")

# 6. CREATE CONVERSATION
alias Zchat.Chat.Conversation
alias Zchat.Chat.ConversationMember

{:ok, conversation} = Repo.insert(%Conversation{name: "General"})

for user <- all_users do
  Repo.insert(%ConversationMember{user_id: user.id, conversation_id: conversation.id})
end

IO.puts("💬 Created a general conversation and added all users.")

IO.puts("✅ Seeding Complete!")
