# priv/repo/seeds.exs
alias Zchat.Repo
alias Zchat.Accounts.{Role, Permission}

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
