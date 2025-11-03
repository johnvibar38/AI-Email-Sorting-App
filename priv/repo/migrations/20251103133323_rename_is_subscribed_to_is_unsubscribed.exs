defmodule Jump.Repo.Migrations.RenameIsSubscribedToIsUnsubscribed do
  use Ecto.Migration

  def change do
    # Rename the column and invert the boolean values
    # is_subscribed: true -> is_unsubscribed: false
    # is_subscribed: false -> is_unsubscribed: true

    # Add the new column with inverted default
    alter table(:emails) do
      add :is_unsubscribed, :boolean, default: false
    end

    # Copy the inverted values from the old column
    execute "UPDATE emails SET is_unsubscribed = NOT COALESCE(is_subscribed, true)"

    # Remove the old column
    alter table(:emails) do
      remove :is_subscribed
    end

    # Create index on the new column
    create index(:emails, [:is_unsubscribed])
  end
end
