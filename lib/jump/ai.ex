defmodule Jump.AI do
  @moduledoc """
  Context for AI-powered email operations using OpenAI.
  """

  require Logger

  @doc """
  Categorizes an email based on available categories using OpenAI.
  Returns {:ok, category_id} or {:error, reason}
  """
  def categorize_email(email_content, categories) when is_list(categories) do
    if Enum.empty?(categories) do
      {:ok, nil}
    else
      prompt = build_categorization_prompt(email_content, categories)

      case call_openai(prompt, temperature: 0.3) do
        {:ok, response} ->
          parse_category_response(response, categories)

        error ->
          Logger.error("Failed to categorize email: #{inspect(error)}")
          {:ok, nil}
      end
    end
  end

  @doc """
  Generates an AI summary of an email.
  Returns {:ok, summary} or {:error, reason}
  """
  def summarize_email(email_content) do
    prompt = build_summarization_prompt(email_content)

    case call_openai(prompt, temperature: 0.5, max_tokens: 150) do
      {:ok, summary} ->
        {:ok, String.trim(summary)}

      error ->
        Logger.error("Failed to summarize email: #{inspect(error)}")
        {:ok, "Summary unavailable"}
    end
  end

  @doc """
  Analyzes webpage content to determine how to unsubscribe.
  Returns instructions for the unsubscribe agent.
  """
  def analyze_unsubscribe_page(html_content, url) do
    prompt = build_unsubscribe_analysis_prompt(html_content, url)

    case call_openai(prompt, temperature: 0.2, max_tokens: 500) do
      {:ok, instructions} ->
        {:ok, parse_unsubscribe_instructions(instructions)}

      error ->
        Logger.error("Failed to analyze unsubscribe page: #{inspect(error)}")
        {:error, :analysis_failed}
    end
  end

  # Private functions

  defp build_categorization_prompt(email_content, categories) do
    category_list =
      categories
      |> Enum.map(fn cat ->
        "- #{cat.name}: #{cat.description || "No description"}"
      end)
      |> Enum.join("\n")

    """
    You are an email categorization assistant. Given an email and a list of categories, 
    determine which category best fits the email.

    Categories:
    #{category_list}

    Email subject: #{email_content.subject || "No subject"}
    From: #{email_content.from || "Unknown"}
    Body preview: #{String.slice(email_content.body || email_content.snippet || "", 0, 500)}

    Respond with ONLY the category name that best matches this email. 
    If none match well, respond with "NONE".
    """
  end

  defp build_summarization_prompt(email_content) do
    """
    Summarize this email in 1-2 concise sentences. Focus on the key action items or main points.

    Subject: #{email_content.subject || "No subject"}
    From: #{email_content.from || "Unknown"}
    Body: #{String.slice(email_content.body || email_content.snippet || "", 0, 2000)}

    Summary:
    """
  end

  defp build_unsubscribe_analysis_prompt(html_content, url) do
    # Truncate HTML to reasonable length
    truncated_html = String.slice(html_content, 0, 5000)

    """
    You are analyzing an unsubscribe page to determine how to unsubscribe.

    URL: #{url}

    HTML Content:
    #{truncated_html}

    Respond in JSON format with these fields:
    - action: "click_button", "fill_form", "already_unsubscribed", or "unknown"
    - selector: CSS selector for the button/form element to interact with
    - form_data: If action is "fill_form", provide key-value pairs for form fields
    - instructions: Human-readable instructions

    Example response:
    {
      "action": "click_button",
      "selector": "#unsubscribe-button",
      "instructions": "Click the unsubscribe button"
    }
    """
  end

  defp call_openai(prompt, opts) do
    temperature = Keyword.get(opts, :temperature, 0.7)
    max_tokens = Keyword.get(opts, :max_tokens, 300)

    messages = [
      %{role: "user", content: prompt}
    ]

    case OpenAI.chat_completion(
           model: "gpt-4o-mini",
           messages: messages,
           temperature: temperature,
           max_tokens: max_tokens
         ) do
      {:ok, %{choices: [%{"message" => %{"content" => content}} | _]}} ->
        {:ok, content}

      {:ok, response} ->
        Logger.error("Unexpected OpenAI response format: #{inspect(response)}")
        {:error, :unexpected_response}

      {:error, error} ->
        Logger.error("OpenAI API error: #{inspect(error)}")
        {:error, error}
    end
  end

  defp parse_category_response(response, categories) do
    category_name = String.trim(response)

    if category_name == "NONE" do
      {:ok, nil}
    else
      case Enum.find(categories, fn cat ->
             String.downcase(cat.name) == String.downcase(category_name)
           end) do
        nil ->
          # Try partial matching if exact match fails
          case Enum.find(categories, fn cat ->
                 String.contains?(String.downcase(response), String.downcase(cat.name))
               end) do
            nil -> {:ok, nil}
            category -> {:ok, category.id}
          end

        category ->
          {:ok, category.id}
      end
    end
  end

  defp parse_unsubscribe_instructions(instructions_json) do
    case Jason.decode(instructions_json) do
      {:ok, parsed} ->
        %{
          action: Map.get(parsed, "action", "unknown"),
          selector: Map.get(parsed, "selector"),
          form_data: Map.get(parsed, "form_data", %{}),
          instructions: Map.get(parsed, "instructions", "")
        }

      {:error, _} ->
        # If not valid JSON, return as raw instructions
        %{
          action: "unknown",
          selector: nil,
          form_data: %{},
          instructions: instructions_json
        }
    end
  end
end
