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
