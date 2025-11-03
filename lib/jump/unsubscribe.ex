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
  Returns {:error, :no_url} if no unsubscribe link is found.
  """
  def queue_unsubscribe_job(%EmailManagement.Email{} = email) do
    # First, try to extract unsubscribe link
    unsubscribe_url = EmailManagement.extract_unsubscribe_link(email.content)

    case unsubscribe_url do
      nil ->
        # No unsubscribe link found, don't create a job
        {:error, :no_url}

      "" ->
        # Empty URL, don't create a job
        {:error, :no_url}

      url ->
        # Valid URL found, create and queue the job
        attrs = %{
          email_id: email.id,
          unsubscribe_url: url,
          status: "pending"
        }

        with {:ok, job} <- create_unsubscribe_job(attrs),
             {:ok, _oban_job} <- UnsubscribeWorker.schedule_unsubscribe(job.id) do
          {:ok, job}
        end
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
    # Use ChromeRemoteInterface for real browser automation
    require Logger

    case Jump.MCPBrowser.navigate(url) do
      {:ok, session} ->
        result =
          with {:ok, snapshot} <- Jump.MCPBrowser.snapshot(session),
               {:ok, instructions} <- Jump.AI.analyze_unsubscribe_page(snapshot, url),
               {:ok, _} <- execute_unsubscribe_action(instructions, session) do
            Logger.info("Successfully automated unsubscribe for URL: #{url}")
            {:ok, :unsubscribed}
          else
            {:error, reason} = error ->
              Logger.error("Failed to automate unsubscribe for #{url}: #{inspect(reason)}")
              error

            error ->
              Logger.error("Unexpected error during unsubscribe automation: #{inspect(error)}")
              {:error, :automation_failed}
          end

        # Always cleanup browser session
        Jump.MCPBrowser.close(session)
        result

      {:error, reason} = error ->
        Logger.error("Failed to navigate to #{url}: #{inspect(reason)}")
        error
    end
  end

  defp execute_unsubscribe_action(%{action: action, selector: selector} = instructions, session) do
    require Logger
    Logger.info("Executing unsubscribe action: #{action}")

    case action do
      "click_button" ->
        click_unsubscribe_button(selector, instructions, session)

      "fill_form" ->
        fill_and_submit_form(instructions, session)

      "already_unsubscribed" ->
        Logger.info("Page indicates already unsubscribed")
        {:ok, :already_unsubscribed}

      _ ->
        Logger.warning("Unknown action type: #{action}")
        {:error, :unknown_action}
    end
  end

  defp execute_unsubscribe_action(_instructions, _session) do
    {:error, :invalid_instructions}
  end

  defp click_unsubscribe_button(selector, instructions, session) do
    require Logger

    element_description = Map.get(instructions, :instructions, "unsubscribe button")

    case Jump.MCPBrowser.click(%{element: element_description, ref: selector}, session) do
      {:ok, _} ->
        # Wait for any confirmation/success message
        Process.sleep(2000)
        Logger.info("Successfully clicked unsubscribe button")
        {:ok, :unsubscribed}

      {:error, _} = error ->
        Logger.error("Failed to click button: #{inspect(error)}")
        error
    end
  end

  defp fill_and_submit_form(instructions, session) do
    require Logger

    form_data = Map.get(instructions, :form_data, %{})

    # Convert form_data to the format expected by fill_form
    fields =
      Enum.map(form_data, fn {field_name, value} ->
        %{
          name: field_name,
          ref: "##{field_name}",
          type: "textbox",
          value: value
        }
      end)

    case Jump.MCPBrowser.fill_form(%{fields: fields}, session) do
      {:ok, session} ->
        # Try to find and click submit button
        case find_and_click_submit(session) do
          {:ok, _} ->
            Process.sleep(2000)
            Logger.info("Successfully filled and submitted form")
            {:ok, :unsubscribed}

          error ->
            Logger.error("Failed to submit form: #{inspect(error)}")
            error
        end

      {:error, _} = error ->
        Logger.error("Failed to fill form: #{inspect(error)}")
        error
    end
  end

  defp find_and_click_submit(session) do
    # Try common submit button selectors
    submit_selectors = [
      "button[type='submit']",
      "input[type='submit']",
      "button",
      "input[type='button']"
    ]

    Enum.reduce_while(submit_selectors, {:error, :no_submit_found}, fn selector, _acc ->
      case Jump.MCPBrowser.click(%{element: "submit button", ref: selector}, session) do
        {:ok, _} -> {:halt, {:ok, :submitted}}
        _ -> {:cont, {:error, :no_submit_found}}
      end
    end)
  end

  defp format_error(:no_url), do: "No unsubscribe link found"
  defp format_error(:unknown_action), do: "Could not determine how to unsubscribe"
  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)
end
