defmodule Jump.Repo.Migrations.IncreaseStringFieldSizes do
  use Ecto.Migration

  def change do
    # Increase avatar_url size to text (unlimited)
    alter table(:users) do
      modify :avatar_url, :text
    end

    # Increase history_id size to text
    alter table(:google_accounts) do
      modify :history_id, :text
    end
  end
end

