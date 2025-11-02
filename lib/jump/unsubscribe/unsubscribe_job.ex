defmodule Jump.Unsubscribe.UnsubscribeJob do
  use Ecto.Schema
  import Ecto.Changeset

  schema "unsubscribe_jobs" do
    field :status, :string, default: "pending"
    field :unsubscribe_url, :string
    field :error_message, :string
    field :completed_at, :utc_datetime

    belongs_to :email, Jump.EmailManagement.Email

    timestamps()
  end

  @doc false
  def changeset(unsubscribe_job, attrs) do
    unsubscribe_job
    |> cast(attrs, [:email_id, :status, :unsubscribe_url, :error_message, :completed_at])
    |> validate_required([:email_id, :status])
    |> validate_inclusion(:status, ["pending", "processing", "completed", "failed"])
    |> foreign_key_constraint(:email_id)
  end
end
