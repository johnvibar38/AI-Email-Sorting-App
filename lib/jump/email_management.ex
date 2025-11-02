defmodule Jump.EmailManagement do
  @moduledoc """
  The EmailManagement context for categories and emails.
  """

  import Ecto.Query, warn: false
  alias Jump.Repo
  alias Jump.EmailManagement.{Category, Email}
  alias Jump.AI
  alias Jump.Accounts.GoogleAccount

  # Category functions

  @doc """
  Returns the list of categories for a user.
  """
  def list_categories(user_id) do
    Category
    |> where([c], c.user_id == ^user_id)
    |> order_by([c], asc: c.position, asc: c.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the list of categories with email counts.
  """
  def list_categories_with_counts(user_id) do
    Category
    |> where([c], c.user_id == ^user_id)
    |> join(:left, [c], e in Email, on: e.category_id == c.id and e.deleted == false)
    |> group_by([c], c.id)
    |> select([c, e], %{
      category: c,
      email_count: count(e.id)
    })
    |> order_by([c], asc: c.position, asc: c.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single category.
  """
  def get_category!(id), do: Repo.get!(Category, id)

  @doc """
  Gets a category by id and user_id.
  """
  def get_user_category(id, user_id) do
    Category
    |> where([c], c.id == ^id and c.user_id == ^user_id)
    |> Repo.one()
  end

  @doc """
  Creates a category.
  """
  def create_category(attrs \\ %{}) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a category.
  """
  def update_category(%Category{} = category, attrs) do
    category
    |> Category.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a category.
  """
  def delete_category(%Category{} = category) do
    Repo.delete(category)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking category changes.
  """
  def change_category(%Category{} = category, attrs \\ %{}) do
    Category.changeset(category, attrs)
  end

  @doc """
  Creates default categories for a new user.
  """
  def create_default_categories(user_id) do
    default_categories = [
      %{
        name: "Newsletters",
        description: "Marketing emails, updates, and promotional content",
        position: 1
      },
      %{
        name: "Work",
        description: "Job-related emails, client communications, team updates",
        position: 2
      },
      %{
        name: "Personal",
        description: "Family, friends, personal correspondence",
        position: 3
      },
      %{
        name: "Receipts",
        description: "Purchase confirmations, invoices, shipping notifications",
        position: 4
      },
      %{
        name: "Social Media",
        description: "Notifications from Facebook, Twitter, LinkedIn",
        position: 5
      }
    ]

    results =
      Enum.map(default_categories, fn category_attrs ->
        attrs = Map.put(category_attrs, :user_id, user_id)
        create_category(attrs)
      end)

    # Return success if at least one category was created
    successful =
      Enum.filter(results, fn
        {:ok, _} -> true
        _ -> false
      end)

    if length(successful) > 0 do
      {:ok, successful}
    else
      {:error, :failed_to_create_categories}
    end
  end

  # Email functions

  @doc """
  Returns the list of emails for a category.
  """
  def list_emails_by_category(category_id) do
    Email
    |> where([e], e.category_id == ^category_id and e.deleted == false)
    |> order_by([e], desc: e.received_at)
    |> preload(:google_account)
    |> Repo.all()
  end

  @doc """
  Returns the list of emails for a category and specific Google account.
  """
  def list_emails_by_category_and_account(category_id, google_account_id) do
    Email
    |> where(
      [e],
      e.category_id == ^category_id and e.google_account_id == ^google_account_id and
        e.deleted == false
    )
    |> order_by([e], desc: e.received_at)
    |> preload(:google_account)
    |> Repo.all()
  end

  @doc """
  Returns emails grouped by Google account for a category.
  """
  def list_emails_by_category_grouped_by_account(category_id, user_id) do
    Email
    |> join(:inner, [e], g in GoogleAccount, on: e.google_account_id == g.id)
    |> where(
      [e, g],
      e.category_id == ^category_id and g.user_id == ^user_id and e.deleted == false
    )
    |> order_by([e], asc: e.google_account_id, desc: e.received_at)
    |> preload(:google_account)
    |> Repo.all()
    |> Enum.group_by(& &1.google_account)
  end

  @doc """
  Returns all emails for a specific Google account.
  """
  def list_emails_by_account(google_account_id) do
    Email
    |> where([e], e.google_account_id == ^google_account_id and e.deleted == false)
    |> order_by([e], desc: e.received_at)
    |> preload([:google_account, :category])
    |> Repo.all()
  end

  @doc """
  Returns the list of uncategorized emails for a user.
  """
  def list_uncategorized_emails(user_id) do
    Email
    |> join(:inner, [e], g in GoogleAccount, on: e.google_account_id == g.id)
    |> where([e, g], g.user_id == ^user_id and is_nil(e.category_id) and e.deleted == false)
    |> order_by([e], desc: e.received_at)
    |> Repo.all()
  end

  @doc """
  Gets a single email.
  """
  def get_email!(id), do: Repo.get!(Email, id)

  @doc """
  Gets an email with preloaded associations.
  """
  def get_email_with_assoc(id) do
    Email
    |> preload([:category, :google_account])
    |> Repo.get(id)
  end

  @doc """
  Imports an email from Gmail and categorizes it with AI.
  """
  def import_email(google_account_id, gmail_data, categories) do
    with {:ok, category_id} <- AI.categorize_email(gmail_data, categories),
         {:ok, summary} <- AI.summarize_email(gmail_data) do
      attrs = %{
        google_account_id: google_account_id,
        category_id: category_id,
        gmail_id: gmail_data.id,
        subject: gmail_data.subject,
        from_address: extract_email_address(gmail_data.from),
        received_at: gmail_data.date,
        content: gmail_data.body,
        ai_summary: summary
      }

      %Email{}
      |> Email.changeset(attrs)
      |> Repo.insert(on_conflict: :nothing)
    end
  end

  @doc """
  Bulk deletes emails (soft delete).
  """
  def bulk_delete_emails(email_ids) when is_list(email_ids) do
    {count, _} =
      Email
      |> where([e], e.id in ^email_ids)
      |> Repo.update_all(set: [deleted: true, updated_at: DateTime.utc_now()])

    {:ok, count}
  end

  @doc """
  Deletes an email (soft delete).
  """
  def delete_email(%Email{} = email) do
    email
    |> Email.changeset(%{deleted: true})
    |> Repo.update()
  end

  @doc """
  Extracts unsubscribe link from email content.
  """
  def extract_unsubscribe_link(email_content) do
    # Look for common unsubscribe link patterns
    patterns = [
      ~r/https?:\/\/[^\s<>"]+unsubscribe[^\s<>"]*/i,
      ~r/https?:\/\/[^\s<>"]+optout[^\s<>"]*/i,
      ~r/https?:\/\/[^\s<>"]+opt-out[^\s<>"]*/i,
      ~r/<https?:\/\/[^\s<>"]+unsubscribe[^\s<>"]*>/i
    ]

    Enum.find_value(patterns, fn pattern ->
      case Regex.run(pattern, email_content) do
        [url | _] ->
          # Clean up URL (remove < > if present)
          String.replace(url, ~r/[<>]/, "")

        nil ->
          nil
      end
    end)
  end

  @doc """
  Marks an email as archived.
  """
  def mark_email_archived(%Email{} = email) do
    email
    |> Email.changeset(%{archived: true})
    |> Repo.update()
  end

  @doc """
  Updates an email's category.
  """
  def update_email_category(%Email{} = email, category_id) do
    email
    |> Email.changeset(%{category_id: category_id})
    |> Repo.update()
  end

  # Private functions

  defp extract_email_address(from_string) when is_binary(from_string) do
    # Extract email from "Name <email@domain.com>" format
    case Regex.run(~r/<([^>]+)>/, from_string) do
      [_, email] -> email
      nil -> from_string
    end
  end

  defp extract_email_address(_), do: nil
end
