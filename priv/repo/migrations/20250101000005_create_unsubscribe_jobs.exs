defmodule Jump.Repo.Migrations.CreateUnsubscribeJobs do
  use Ecto.Migration

  def change do
    create table(:unsubscribe_jobs) do
      add :email_id, references(:emails, on_delete: :delete_all), null: false
      add :status, :string, default: "pending", null: false
      add :unsubscribe_url, :string
      add :error_message, :text
      add :completed_at, :utc_datetime

      timestamps()
    end

    create index(:unsubscribe_jobs, [:email_id])
    create index(:unsubscribe_jobs, [:status])
  end
end

