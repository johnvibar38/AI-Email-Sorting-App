defmodule Jump.Workers.UnsubscribeWorker do
  @moduledoc """
  Background worker that processes unsubscribe requests using AI and browser automation.
  """

  use Oban.Worker,
    queue: :unsubscribe,
    max_attempts: 3

  require Logger

  alias Jump.Unsubscribe

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"unsubscribe_job_id" => job_id}}) do
    Logger.info("Processing unsubscribe job #{job_id}")

    job = Unsubscribe.get_unsubscribe_job!(job_id)

    case Unsubscribe.perform_unsubscribe(job) do
      {:ok, _result} ->
        Logger.info("Successfully completed unsubscribe job #{job_id}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to process unsubscribe job #{job_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Schedules an unsubscribe job to be processed.
  """
  def schedule_unsubscribe(unsubscribe_job_id) do
    %{unsubscribe_job_id: unsubscribe_job_id}
    |> new()
    |> Oban.insert()
  end
end
