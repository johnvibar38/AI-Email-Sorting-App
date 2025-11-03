defmodule Jump.Repo.Migrations.AddSystemCategories do
  use Ecto.Migration

  def up do
    # Add is_system field to categories
    alter table(:categories) do
      add :is_system, :boolean, default: false, null: false
    end

    # Add "Other" category for all existing users
    execute """
    INSERT INTO categories (user_id, name, description, position, is_system, inserted_at, updated_at)
    SELECT 
      id as user_id,
      'Other',
      'Emails that don''t fit into other categories',
      999,
      true,
      NOW(),
      NOW()
    FROM users
    ON CONFLICT DO NOTHING
    """
  end

  def down do
    # Remove "Other" system categories
    execute """
    DELETE FROM categories WHERE name = 'Other' AND is_system = true
    """

    # Remove is_system field
    alter table(:categories) do
      remove :is_system
    end
  end
end
