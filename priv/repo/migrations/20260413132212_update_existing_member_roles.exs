defmodule Vibeflow.Repo.Migrations.UpdateExistingMemberRoles do
  use Ecto.Migration

  def up do
    # Update existing conversation members to have default role
    execute("UPDATE conversation_members SET role = 'member' WHERE role IS NULL")

    # For group conversations, set the earliest member as admin (creator)
    execute("""
      UPDATE conversation_members
      SET role = 'admin'
      WHERE id IN (
        SELECT DISTINCT ON (conversation_id) cm.id
        FROM conversation_members cm
        JOIN conversations c ON c.id = cm.conversation_id
        WHERE c.type = 'group'
        ORDER BY conversation_id, cm.id ASC
      )
    """)
  end

  def down do
    # No rollback needed as this is just setting default values
  end
end
