defmodule Jump.Accounts.GoogleAccount do
  use Ecto.Schema
  import Ecto.Changeset

  schema "google_accounts" do
    field :email, :string
    field :access_token, Jump.Encrypted.Binary
    field :refresh_token, Jump.Encrypted.Binary
    field :expires_at, :utc_datetime
    field :last_synced_at, :utc_datetime
    field :history_id, :string

    belongs_to :user, Jump.Accounts.User
    has_many :emails, Jump.EmailManagement.Email

    timestamps()
  end

  @doc false
  def changeset(google_account, attrs) do
    google_account
    |> cast(attrs, [
      :user_id,
      :email,
      :access_token,
      :refresh_token,
      :expires_at,
      :last_synced_at,
      :history_id
    ])
    |> validate_required([:user_id, :email, :access_token, :refresh_token, :expires_at])
    |> unique_constraint(:email)
    |> foreign_key_constraint(:user_id)
  end
end
