defmodule Jump.Repo.Migrations.AllowMultipleGoogleAccountsPerUser do
  use Ecto.Migration

  def change do
    # Drop the old unique constraint on email
    drop unique_index(:google_accounts, [:email])
    
    # Add a composite unique constraint on (user_id, email)
    # This allows the same email across different users, but prevents
    # the same user from adding the same Gmail account twice
    create unique_index(:google_accounts, [:user_id, :email])
  end
end

