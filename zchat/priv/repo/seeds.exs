# priv/repo/seeds.exs
alias Zchat.Repo
alias Zchat.Accounts
alias Zchat.Posts
alias Zchat.Chat
alias Zchat.Chat.{Conversation, ConversationMember}

IO.puts("🌱 Starting Additive Seed Script...")

# ==============================================
# 1. FETCH EXISTING USERS
# ==============================================
# We need to know who is already in the DB to make them interact
existing_users = Repo.all(Accounts.User)
IO.puts("ℹ️  Found #{length(existing_users)} existing users.")

# ==============================================
# 2. CREATE NEW DUMMY USERS (Additive)
# ==============================================
# We add a random suffix to ensure emails are unique every time you run this
suffix = System.unique_integer([:positive])
password = "Password1234!"

new_user_data = [
  {"Alice_#{suffix}", "alice_#{suffix}@test.com"},
  {"Bob_#{suffix}", "bob_#{suffix}@test.com"},
  {"Charlie_#{suffix}", "charlie_#{suffix}@test.com"},
  {"Diana_#{suffix}", "diana_#{suffix}@test.com"}
]

new_users =
  Enum.map(new_user_data, fn {name, email} ->
    {:ok, user} = Accounts.register_user(%{
      username: name,
      email: email,
      password: password,
      avatar_url: nil
    })
    user
  end)

IO.puts("✅ Added #{length(new_users)} new users.")

# Combine existing users and new users for the content generation
all_users = existing_users ++ new_users

# ==============================================
# 3. CREATE POSTS
# ==============================================
categories = ["Tech", "Fitness", "Food", "Politics", "Nature", "Comedy/ Humor"]
titles = [
  "Just saw something amazing",
  "Does anyone know how to fix this?",
  "My daily routine",
  "Unpopular opinion...",
  "Check out this view!",
  "Coding is life",
  "Why I love Elixir",
  "Pizza vs Burgers",
  "The weather today is crazy",
  "Monday motivation"
]

IO.puts("📝 Creating 30 new posts...")

for _ <- 1..30 do
  random_user = Enum.random(all_users)
  random_category = Enum.random(categories)
  random_title = Enum.random(titles)

  {:ok, post} =
    Posts.create_post(random_user, %{
      title: "#{random_title} ##{System.unique_integer([:positive])}",
      content: "This is a seeded post about #{random_category}. We are testing the random feed logic!",
      category: random_category,
      tags: ["seed", String.downcase(random_category)]
    })

  # Add Random Likes (0 to 4 likes per post)
  likers = all_users |> Enum.shuffle() |> Enum.take(:rand.uniform(5) - 1)

  for liker <- likers do
    try do
      Posts.toggle_like(liker.id, "Post", post.id)
    rescue
      _ -> :ok
    end
  end
end

IO.puts("✅ Posts created.")

# ==============================================
# 4. CREATE CHATS
# ==============================================

IO.puts("💬 Setting up conversations...")

# A. Create ONE "General" Group Chat for this specific seed run
{:ok, group_chat} = Repo.insert(%Conversation{name: "Seed Group #{suffix}", type: "group"})

for user <- all_users do
  Repo.insert!(%ConversationMember{
    user_id: user.id,
    conversation_id: group_chat.id,
    last_read_at: DateTime.utc_now()
  })
end

# B. Create Random 1-on-1 Chats (DMs)
# Create 5 random private conversations between ANY users (new or old)
for _ <- 1..5 do
  [user1, user2] = all_users |> Enum.shuffle() |> Enum.take(2)

  # Use context helper to check if chat exists, or create new
  case Chat.get_or_create_private_conversation(user1.id, user2.id) do
    {:ok, conv} ->
      # Add a starter message
      Chat.create_message(%{
        content: "Hey! This is a seeded message ID: #{System.unique_integer([:positive])}",
        user_id: user1.id,
        conversation_id: conv.id
      })
    _ -> :ok
  end
end

IO.puts("✅ Chats created.")
IO.puts("🚀 SEEDING COMPLETE!")
