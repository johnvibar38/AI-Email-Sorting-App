defmodule Jump.EmailManagement.Email do
  use Ecto.Schema
  import Ecto.Changeset

  schema "emails" do
    field :gmail_id, :string
    field :subject, :string
    field :from_address, :string
    field :received_at, :utc_datetime
    field :content, :string
    field :ai_summary, :string
    field :archived, :boolean, default: false
    field :deleted, :boolean, default: false

    belongs_to :google_account, Jump.Accounts.GoogleAccount
    belongs_to :category, Jump.EmailManagement.Category
    has_many :unsubscribe_jobs, Jump.Unsubscribe.UnsubscribeJob

    timestamps()
  end

  @doc false
  def changeset(email, attrs) do
    email
    |> cast(attrs, [
      :google_account_id,
      :category_id,
      :gmail_id,
      :subject,
      :from_address,
      :received_at,
      :content,
      :ai_summary,
      :archived,
      :deleted
    ])
    |> validate_required([:google_account_id, :gmail_id, :received_at])
    |> unique_constraint(:gmail_id)
    |> foreign_key_constraint(:google_account_id)
    |> foreign_key_constraint(:category_id)
  end
end
