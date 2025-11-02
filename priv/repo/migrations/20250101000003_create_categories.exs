defmodule Jump.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text
      add :position, :integer, default: 0

      timestamps()
    end

    create index(:categories, [:user_id])
    create unique_index(:categories, [:user_id, :name])
  end
end

