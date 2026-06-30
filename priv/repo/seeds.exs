# priv/repo/seeds.exs
alias Vibeflow.Repo
alias Vibeflow.Accounts.{Role, Permission}

IO.puts("🌱 Seeding Roles & Permissions...")

# 1. Define and Create Roles (Safely)
roles_to_create = ["admin", "moderator", "user"]

for role_name <- roles_to_create do
  case Repo.get_by(Role, name: role_name) do
    nil ->
      {:ok, _} = Repo.insert(%Role{name: role_name})
      IO.puts("🔹 Created role: #{role_name}")

    _ ->
      IO.puts("🔹 Role '#{role_name}' already exists. Skipping.")
  end
end

IO.puts("✅ Roles table populated.")

# 2. Define the Permissions Dictionary
permissions_data = [
  %Permission{slug: "post-new", description: "Create new posts"},
  %Permission{slug: "post-edit", description: "Edit existing posts"},
  %Permission{slug: "post-delete", description: "Delete posts"},
  %Permission{slug: "user-ban", description: "Ban users"}
]

# 3. Insert Permissions (Safely)
permission_map =
  Enum.reduce(permissions_data, %{}, fn data, acc ->
    perm =
      case Repo.get_by(Permission, slug: data.slug) do
        nil -> Repo.insert!(data)
        existing -> existing
      end

    Map.put(acc, data.slug, perm)
  end)

IO.puts("✅ Permissions table populated.")

# 4. Helper to Link Roles <-> Permissions
assign_perms = fn role_name, slugs ->
  role = Repo.get_by(Role, name: role_name) |> Repo.preload(:permissions)

  if role do
    perms_to_add = Enum.map(slugs, fn s -> Map.get(permission_map, s) end)

    role
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:permissions, perms_to_add)
    |> Repo.update!()

    IO.puts("🔹 Assigned [#{Enum.join(slugs, ", ")}] to role: #{role_name}")
  else
    IO.puts("⚠️ Role '#{role_name}' not found. Skipping.")
  end
end

# 5. Execute Assignments
assign_perms.("admin", ["post-new", "post-edit", "post-delete", "user-ban"])
assign_perms.("moderator", ["post-edit", "post-delete"])
assign_perms.("user", ["post-new", "post-edit", "post-delete"])

IO.puts("🚀 Seeding Complete!")
# Store items seed
alias Vibeflow.Store.StoreItem
alias Vibeflow.Repo

store_items = [
  %{
    item_name: "Wave Frame (Red)",
    item_slug: "wave-frame-red",
    worth: 500,
    duration: "30d",
    category: "digital_flex"
  },
  %{
    item_name: "Wave Frame (Blue)",
    item_slug: "wave-frame-blue",
    worth: 500,
    duration: "30d",
    category: "digital_flex"
  },
  %{
    item_name: "Profile Glow",
    item_slug: "profile-glow",
    worth: 750,
    duration: "14d",
    category: "digital_flex"
  },
  %{
    item_name: "Boost Badge",
    item_slug: "boost-badge",
    worth: 1200,
    duration: "7d",
    category: "power_ups"
  },
  %{
    item_name: "Post Booster",
    item_slug: "post-booster",
    worth: 150,
    duration: "1d",
    category: "power_ups"
  },
  %{
    item_name: "Message in a Bottle",
    item_slug: "message-bottle",
    worth: 50,
    duration: "1d",
    category: "power_ups"
  },
  %{
    item_name: "dummy item",
    item_slug: "dummy-item",
    worth: 3,
    duration: "1d",
    category: "power_ups"
  },
  %{
    item_name: "Glassmorphism Pro Skin",
    item_slug: "skin_glassmorphism_pro",
    worth: 300,
    duration: "permanent",
    category: "message_skins",
    metadata: %{skin_name: "Glassmorphism Pro"}
  },
  %{
    item_name: "Matrix Rain Skin",
    item_slug: "skin_matrix_rain",
    worth: 400,
    duration: "permanent",
    category: "message_skins",
    metadata: %{skin_name: "Matrix Rain"}
  },
  %{
    item_name: "Holographic Foil Skin",
    item_slug: "skin_holographic_foil",
    worth: 350,
    duration: "permanent",
    category: "message_skins",
    metadata: %{skin_name: "Holographic Foil"}
  },
  %{
    item_name: "Vantablack Skin",
    item_slug: "skin_vantablack",
    worth: 500,
    duration: "permanent",
    category: "message_skins",
    metadata: %{skin_name: "Vantablack"}
  }
]

Enum.each(store_items, fn attrs ->
  case Repo.get_by(StoreItem, item_slug: attrs.item_slug) do
    nil ->
      %StoreItem{}
      |> StoreItem.changeset(attrs)
      |> Repo.insert!()

    existing ->
      existing
      |> StoreItem.changeset(attrs)
      |> Repo.update!()
  end
end)

IO.puts("✅ Store items seeded.")

# Seed posts
alias Vibeflow.Accounts.User
alias Vibeflow.Posts.Post
alias Vibeflow.Posts.Like
alias Vibeflow.Posts.Comment

IO.puts("📝 Seeding posts...")

# Create a test user for seeding posts
test_user = %User{
  username: "demo_user",
  email: "demo@example.com",
  hashed_password: Bcrypt.hash_pwd_salt("password123"),
  points: 5000,
  username_style: "neon-green",
  active_message_skin: "default",
  is_verified: true
}

test_user =
  case Repo.get_by(User, email: "demo@example.com") do
    nil ->
      user = Repo.insert!(test_user)
      IO.puts("🔹 Created demo user: #{user.username}")
      user

    existing ->
      IO.puts("🔹 Demo user already exists: #{existing.username}")
      existing
  end

# Seed posts
posts_to_seed = [
  %{
    title: "Welcome to VibeFlow!",
    content:
      "Welcome to VibeFlow! 🌊 This is your first wave. Share your thoughts, connect with friends, and express yourself freely.",
    user_id: test_user.id,
    category: "Tech",
    media_files: [],
    inserted_at: DateTime.utc_now(),
    updated_at: DateTime.utc_now()
  },
  %{
    title: "Creative Flow",
    content:
      "Just dropped my first track! 🎵 Feeling the creative flow today. Music production mode: ON. Who else is creating something amazing?",
    user_id: test_user.id,
    category: "Music",
    media_files: [],
    inserted_at: DateTime.add(DateTime.utc_now(), -7200, :second),
    updated_at: DateTime.add(DateTime.utc_now(), -7200, :second)
  },
  %{
    title: "Sunset Vibes",
    content:
      "The sunset vibes are hitting different today 🌅 Sometimes the best conversations happen when we're not trying to have them. Just being present is enough.",
    user_id: test_user.id,
    category: "Nature",
    media_files: [],
    inserted_at: DateTime.add(DateTime.utc_now(), -14400, :second),
    updated_at: DateTime.add(DateTime.utc_now(), -14400, :second)
  },
  %{
    title: "Weekend Energy",
    content:
      "Anyone else feeling the weekend energy? ⚡ Time to recharge, reset, and come back stronger. What's your weekend ritual?",
    user_id: test_user.id,
    category: "Fitness",
    media_files: [],
    inserted_at: DateTime.add(DateTime.utc_now(), -21600, :second),
    updated_at: DateTime.add(DateTime.utc_now(), -21600, :second)
  },
  %{
    title: "Revolutionary Stillness",
    content:
      "Deep thought: In a world of endless scrolling, the most revolutionary act is to be still. 🧘",
    user_id: test_user.id,
    category: "Science",
    media_files: [],
    inserted_at: DateTime.add(DateTime.utc_now(), -28800, :second),
    updated_at: DateTime.add(DateTime.utc_now(), -28800, :second)
  },
  %{
    title: "Neighborhood Coffee Shop",
    content:
      "Just discovered this amazing coffee shop in my neighborhood ☕ Perfect spot for morning coding sessions and afternoon vibes.",
    user_id: test_user.id,
    category: "Food",
    media_files: [],
    inserted_at: DateTime.add(DateTime.utc_now(), -43200, :second),
    updated_at: DateTime.add(DateTime.utc_now(), -43200, :second)
  },
  %{
    title: "UI/UX Journey",
    content: "The UI/UX journey continues... Every pixel matters, every interaction counts. 💻✨",
    user_id: test_user.id,
    category: "Tech",
    media_files: [],
    inserted_at: DateTime.add(DateTime.utc_now(), -64800, :second),
    updated_at: DateTime.add(DateTime.utc_now(), -64800, :second)
  },
  %{
    title: "Vibe Attracts Tribe",
    content: "Remember: Your vibe attracts your tribe. Don't chase trends, set them. 🌟",
    user_id: test_user.id,
    category: "Fashion",
    media_files: [],
    inserted_at: DateTime.add(DateTime.utc_now(), -86400, :second),
    updated_at: DateTime.add(DateTime.utc_now(), -86400, :second)
  }
]

Enum.each(posts_to_seed, fn post_attrs ->
  %Post{}
  |> Post.changeset(post_attrs)
  |> Repo.insert!()
end)

IO.puts("✅ Posts seeded successfully!")

# Add some likes to posts
all_posts = Repo.all(Post)

Enum.take_random(all_posts, 5)
|> Enum.each(fn post ->
  %Like{
    user_id: test_user.id,
    likeable_type: "Post",
    likeable_id: post.id,
    inserted_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
    updated_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
  }
  |> Repo.insert!()
end)

IO.puts("❤️ Added likes to posts!")

IO.puts("🚀 Seeding Complete!")
