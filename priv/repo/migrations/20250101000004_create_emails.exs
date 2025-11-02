defmodule Jump.Repo.Migrations.CreateEmails do
  use Ecto.Migration

  def change do
    create table(:emails) do
      add :google_account_id, references(:google_accounts, on_delete: :delete_all), null: false
      add :category_id, references(:categories, on_delete: :nilify_all)
      add :gmail_id, :string, null: false
      add :subject, :string
      add :from_address, :string
      add :received_at, :utc_datetime, null: false
      add :content, :text
      add :ai_summary, :text
      add :archived, :boolean, default: false
      add :deleted, :boolean, default: false

      timestamps()
    end

    create index(:emails, [:google_account_id])
    create index(:emails, [:category_id])
    create unique_index(:emails, [:gmail_id])
    create index(:emails, [:received_at])
  end
end

