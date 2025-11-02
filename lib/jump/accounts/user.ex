defmodule Jump.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :name, :string
    field :provider, :string
    field :provider_id, :string
    field :avatar_url, :string

    has_many :google_accounts, Jump.Accounts.GoogleAccount
    has_many :categories, Jump.EmailManagement.Category

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :provider, :provider_id, :avatar_url])
    |> validate_required([:email, :provider, :provider_id])
    |> unique_constraint(:email)
    |> unique_constraint([:provider, :provider_id])
  end
end

