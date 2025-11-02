defmodule Jump.Workers.TokenRefreshWorker do
  @moduledoc """
  Background worker that refreshes expiring OAuth tokens.
  Runs daily to check and refresh tokens that will expire soon.
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 3

  require Logger

  import Ecto.Query
  alias Jump.Accounts
  alias Jump.Gmail
  alias Jump.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Starting token refresh check")

    # Find accounts with tokens expiring in the next 24 hours
    expiring_soon = DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second)

    accounts =
      Accounts.GoogleAccount
      |> where([a], a.expires_at < ^expiring_soon)
      |> Repo.all()

    Logger.info("Found #{length(accounts)} accounts with expiring tokens")

    results =
      Enum.map(accounts, fn account ->
        refresh_account_token(account)
      end)

    success_count = Enum.count(results, &match?({:ok, _}, &1))
    failure_count = Enum.count(results, &match?({:error, _}, &1))

    Logger.info("Token refresh complete: #{success_count} succeeded, #{failure_count} failed")

    :ok
  end

  @doc """
  Schedules the token refresh worker to run.
  """
  def schedule_refresh do
    new(%{})
    |> Oban.insert()
  end

  # Private functions

  defp refresh_account_token(account) do
    case Gmail.refresh_token(account) do
      {:ok, _updated_account} ->
        Logger.info("Successfully refreshed token for account #{account.id}")
        {:ok, :refreshed}

      {:error, reason} ->
        Logger.error("Failed to refresh token for account #{account.id}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
