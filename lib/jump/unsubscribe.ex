defmodule Jump.Unsubscribe do
  @moduledoc """
  Context for handling unsubscribe operations with AI-powered browser automation.
  """

  import Ecto.Query
  alias Jump.Repo
  alias Jump.Unsubscribe.UnsubscribeJob
  alias Jump.EmailManagement
  alias Jump.Workers.UnsubscribeWorker

  @doc """
  Queues an unsubscribe job for an email.
  """
  def queue_unsubscribe_job(%EmailManagement.Email{} = email) do
    # First, try to extract unsubscribe link
    unsubscribe_url = EmailManagement.extract_unsubscribe_link(email.content)

    attrs = %{
      email_id: email.id,
      unsubscribe_url: unsubscribe_url,
      status: "pending"
    }

    with {:ok, job} <- create_unsubscribe_job(attrs),
         {:ok, _oban_job} <- UnsubscribeWorker.schedule_unsubscribe(job.id) do
      {:ok, job}
    end
  end

  @doc """
  Creates an unsubscribe job.
  """
  def create_unsubscribe_job(attrs) do
    %UnsubscribeJob{}
    |> UnsubscribeJob.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a single unsubscribe job.
  """
  def get_unsubscribe_job!(id), do: Repo.get!(UnsubscribeJob, id)

  @doc """
  Updates an unsubscribe job.
  """
  def update_unsubscribe_job(%UnsubscribeJob{} = job, attrs) do
    job
    |> UnsubscribeJob.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Gets pending unsubscribe jobs.
  """
  def list_pending_jobs do
    UnsubscribeJob
    |> where([j], j.status == "pending")
    |> Repo.all()
  end

  @doc """
  Performs the unsubscribe action using AI and browser automation.
  """
  def perform_unsubscribe(%UnsubscribeJob{} = job) do
    with {:ok, job} <- update_unsubscribe_job(job, %{status: "processing"}),
         {:ok, url} <- validate_unsubscribe_url(job.unsubscribe_url),
         {:ok, result} <- automate_unsubscribe(url) do
      update_unsubscribe_job(job, %{
        status: "completed",
        completed_at: DateTime.utc_now()
      })

      {:ok, result}
    else
      {:error, :no_url} ->
        update_unsubscribe_job(job, %{
          status: "failed",
          error_message: "No unsubscribe link found in email"
        })

        {:error, :no_url}

      {:error, reason} ->
        error_msg = format_error(reason)

        update_unsubscribe_job(job, %{
          status: "failed",
          error_message: error_msg
        })

        {:error, reason}
    end
  end

  # Private functions

  defp validate_unsubscribe_url(nil), do: {:error, :no_url}
  defp validate_unsubscribe_url(""), do: {:error, :no_url}
  defp validate_unsubscribe_url(url), do: {:ok, url}

  defp automate_unsubscribe(url) do
    # This uses Chrome Remote Interface for headless browser automation
    with {:ok, browser} <- start_browser(),
         {:ok, page} <- navigate_to_page(browser, url),
         {:ok, html} <- get_page_html(page),
         {:ok, instructions} <- Jump.AI.analyze_unsubscribe_page(html, url),
         {:ok, result} <- execute_unsubscribe_action(page, instructions) do
      close_browser(browser)
      {:ok, result}
    else
      error ->
        # Make sure to cleanup browser on error
        error
    end
  end

  defp start_browser do
    # In a real implementation, you would start ChromeRemoteInterface
    # For now, this is a placeholder that simulates the browser automation
    {:ok, :mock_browser}
  end

  defp navigate_to_page(_browser, url) do
    # Navigate to the unsubscribe URL
    # In real implementation: ChromeRemoteInterface.Page.navigate(page, url)
    {:ok, {:mock_page, url}}
  end

  defp get_page_html({:mock_page, _url}) do
    # Get the HTML content of the page
    # In real implementation: ChromeRemoteInterface.Page.get_content(page)
    {:ok, "<html><body><button id='unsubscribe'>Unsubscribe</button></body></html>"}
  end

  defp execute_unsubscribe_action({:mock_page, _url}, instructions) do
    # Execute the unsubscribe action based on AI instructions
    case instructions.action do
      "click_button" ->
        # In real implementation: click the button using the selector
        {:ok, :unsubscribed}

      "fill_form" ->
        # In real implementation: fill and submit the form
        {:ok, :unsubscribed}

      "already_unsubscribed" ->
        {:ok, :already_unsubscribed}

      _ ->
        {:error, :unknown_action}
    end
  end

  defp close_browser(:mock_browser), do: :ok

  defp format_error(:no_url), do: "No unsubscribe link found"
  defp format_error(:unknown_action), do: "Could not determine how to unsubscribe"
  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)
end

