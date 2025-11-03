defmodule Jump.Repo.Migrations.AddSubscriptionStatusToEmails do
  use Ecto.Migration

  def change do
    alter table(:emails) do
      add :is_subscribed, :boolean, default: true
    end

    # Create an index for efficient filtering
    create index(:emails, [:is_subscribed])
  end
end
