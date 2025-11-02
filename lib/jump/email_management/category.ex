defmodule Jump.EmailManagement.Category do
  use Ecto.Schema
  import Ecto.Changeset

  schema "categories" do
    field :name, :string
    field :description, :string
    field :position, :integer, default: 0

    belongs_to :user, Jump.Accounts.User
    has_many :emails, Jump.EmailManagement.Email

    timestamps()
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:user_id, :name, :description, :position])
    |> validate_required([:user_id, :name])
    |> validate_length(:name, min: 1, max: 100)
    |> unique_constraint([:user_id, :name])
    |> foreign_key_constraint(:user_id)
  end
end

