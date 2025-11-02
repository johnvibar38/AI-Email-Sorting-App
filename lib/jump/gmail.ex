defmodule Jump.Gmail do
  @moduledoc """
  Context for interacting with Gmail API.
  """

  alias Jump.Gmail.Client
  alias Jump.Accounts.GoogleAccount
  alias Jump.Accounts

  @doc """
  Fetches new emails since last sync for a Google account.
  - On first sync (last_synced_at is nil): fetches emails from last 7 days
  - On subsequent syncs: fetches emails since last_synced_at
  Returns {:ok, emails_list} or {:error, reason}
  """
  def fetch_new_emails(%GoogleAccount{} = account) do
    since = get_sync_start_time(account)
    
    with {:ok, access_token} <- ensure_valid_token(account),
         {:ok, messages} <- Client.list_messages(access_token, since: since, max_results: 50),
         {:ok, emails} <- Client.fetch_message_details(access_token, messages) do
      {:ok, emails}
    end
  end

  # Get the start time for fetching emails
  defp get_sync_start_time(%GoogleAccount{last_synced_at: nil}) do
    # First sync: only get emails from last 7 days to avoid overwhelming the system
    DateTime.add(DateTime.utc_now(), -7, :day)
  end

  defp get_sync_start_time(%GoogleAccount{last_synced_at: last_synced}) do
    # Subsequent syncs: get emails since last sync, minus 1 minute buffer
    DateTime.add(last_synced, -60, :second)
  end

  @doc """
  Archives an email in Gmail (removes from inbox).
  """
  def archive_email(%GoogleAccount{} = account, gmail_id) do
    with {:ok, access_token} <- ensure_valid_token(account),
         {:ok, _response} <- Client.archive_message(access_token, gmail_id) do
      {:ok, :archived}
    end
  end

  @doc """
  Refreshes the access token if expired or about to expire.
  """
  def refresh_token(%GoogleAccount{} = account) do
    if token_expired?(account) do
      case Client.refresh_access_token(account.refresh_token) do
        {:ok, new_tokens} ->
          Accounts.update_google_account_sync(account, %{
            access_token: new_tokens.access_token,
            expires_at: new_tokens.expires_at
          })

        error ->
          error
      end
    else
      {:ok, account}
    end
  end

  @doc """
  Ensures the account has a valid access token, refreshing if necessary.
  """
  def ensure_valid_token(%GoogleAccount{} = account) do
    case refresh_token(account) do
      {:ok, updated_account} ->
        {:ok, updated_account.access_token}

      error ->
        error
    end
  end

  defp token_expired?(%GoogleAccount{expires_at: expires_at}) do
    # Consider token expired if it expires in less than 5 minutes
    DateTime.compare(expires_at, DateTime.add(DateTime.utc_now(), 300, :second)) == :lt
  end
end

