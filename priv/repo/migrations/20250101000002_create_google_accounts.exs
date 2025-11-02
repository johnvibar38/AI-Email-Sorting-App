defmodule Jump.Repo.Migrations.CreateGoogleAccounts do
  use Ecto.Migration

  def change do
    create table(:google_accounts) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :email, :string, null: false
      add :access_token, :binary, null: false
      add :refresh_token, :binary, null: false
      add :expires_at, :utc_datetime, null: false
      add :last_synced_at, :utc_datetime
      add :history_id, :string

      timestamps()
    end

    create index(:google_accounts, [:user_id])
    create unique_index(:google_accounts, [:email])
  end
end

