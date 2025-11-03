defmodule Jump.Repo.Migrations.IncreaseUnsubscribeUrlLength do
  use Ecto.Migration

  def change do
    alter table(:unsubscribe_jobs) do
      modify :unsubscribe_url, :text
    end
  end
end
