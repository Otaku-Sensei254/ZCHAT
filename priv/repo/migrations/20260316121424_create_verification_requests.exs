defmodule Vibeflow.Repo.Migrations.CreateVerificationRequests do
  use Ecto.Migration

  def change do
    create table(:verification_requests) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      # "pending", "approved", "rejected"
      add :status, :string, default: "pending"
      add :social_links, {:array, :string}, default: []
      add :admin_notes, :string

      timestamps()
    end

    # A user should only have one pending request at a time
    create unique_index(:verification_requests, [:user_id],
             where: "status = 'pending'",
             name: :one_pending_request_per_user
           )
  end
end
