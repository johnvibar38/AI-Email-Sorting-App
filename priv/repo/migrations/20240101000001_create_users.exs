defmodule Jump.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :name, :string
      add :provider, :string, null: false
      add :provider_id, :string, null: false
      add :avatar_url, :string

      timestamps()
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:provider, :provider_id])
  end
end

