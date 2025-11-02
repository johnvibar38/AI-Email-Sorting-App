defmodule Jump.Workers.EmailSyncWorker do
  @moduledoc """
  Background worker that syncs emails from Gmail accounts.
  Runs every 5 minutes to fetch new emails.
  """

  use Oban.Worker,
    queue: :emails,
    max_attempts: 3

  require Logger

  alias Jump.Accounts
  alias Jump.Gmail
  alias Jump.EmailManagement
  alias Jump.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"google_account_id" => account_id}}) do
    Logger.info("Starting email sync for account #{account_id}")

    with {:ok, account} <- fetch_account(account_id),
         {:ok, user_id} <- {:ok, account.user_id},
         categories <- EmailManagement.list_categories(user_id) do
      
      # Log sync info
      sync_type = if account.last_synced_at, do: "incremental", else: "initial"
      Logger.info("Running #{sync_type} sync for account #{account_id}")
      
      case Gmail.fetch_new_emails(account) do
        {:ok, emails} ->
          process_emails(account, emails, categories)
          
          # Update last synced timestamp
          Accounts.update_google_account_sync(account, %{
            last_synced_at: DateTime.utc_now()
          })

          Logger.info("Successfully synced #{length(emails)} emails for account #{account_id}")
          :ok
          
        {:error, reason} ->
          Logger.error("Failed to fetch emails for account #{account_id}: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, reason} ->
        Logger.error("Failed to sync emails for account #{account_id}: #{inspect(reason)}")
        {:error, reason}

      error ->
        Logger.error("Unexpected error syncing emails: #{inspect(error)}")
        {:error, :sync_failed}
    end
  end

  # Sync all accounts
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{}}) do
    Logger.info("Starting email sync for all accounts")

    google_accounts =
      Accounts.GoogleAccount
      |> Repo.all()

    results =
      Enum.map(google_accounts, fn account ->
        %{google_account_id: account.id}
        |> new()
        |> Oban.insert()
      end)

    success_count = Enum.count(results, fn {:ok, _} -> true; _ -> false end)
    Logger.info("Queued #{success_count} email sync jobs")

    :ok
  end

  @doc """
  Schedules email sync for a specific account.
  """
  def schedule_sync(google_account_id) do
    %{google_account_id: google_account_id}
    |> new()
    |> Oban.insert()
  end

  @doc """
  Schedules recurring email sync for all accounts.
  This should be called by a cron-like scheduler.
  """
  def schedule_all_syncs do
    new(%{})
    |> Oban.insert()
  end

  # Private functions

  defp fetch_account(account_id) do
    case Repo.get(Accounts.GoogleAccount, account_id) do
      nil -> {:error, :account_not_found}
      account -> {:ok, account}
    end
  end

  defp process_emails(_account, [], _categories), do: :ok

  defp process_emails(account, emails, categories) do
    Enum.each(emails, fn email_data ->
      case EmailManagement.import_email(account.id, email_data, categories) do
        {:ok, _email} ->
          # Archive the email in Gmail
          Gmail.archive_email(account, email_data.id)

        {:error, reason} ->
          Logger.error("Failed to import email #{email_data.id}: #{inspect(reason)}")
      end
    end)

    :ok
  end
end

