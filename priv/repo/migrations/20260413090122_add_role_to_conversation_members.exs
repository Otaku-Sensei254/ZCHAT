defmodule Vibeflow.Repo.Migrations.AddRoleToConversationMembers do
  use Ecto.Migration

  def change do
    alter table(:conversations) do
      add(:group_bio, :text)
      add(:group_icon, :string)
      #who created the group 'creator_id' to know who started it
      add(:creator_id, references(:users, on_delete: :nilify_all))
    end

    alter table(:conversation_members) do
      # Default is "member", but the creator gets "admin"
      add(:role, :string, default: "member", null: false)
    end
  end
end
