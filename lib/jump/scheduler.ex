defmodule Jump.Scheduler do
  @moduledoc """
  Scheduler for recurring background jobs.
  This would typically be triggered by a cron job or external scheduler in production.
  """

  alias Jump.Workers.{EmailSyncWorker, TokenRefreshWorker}

  @doc """
  Schedules all recurring jobs. Call this from a cron job or scheduler.
  """
  def schedule_all do
    # Schedule email sync for all accounts
    EmailSyncWorker.schedule_all_syncs()

    # Schedule token refresh check
    TokenRefreshWorker.schedule_refresh()

    :ok
  end
end
