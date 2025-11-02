defmodule JumpWeb.TestController do
  use JumpWeb, :controller

  @moduledoc """
  Controller for testing OpenAI integration.
  Only available in dev mode.
  """

  def test_openai(conn, _params) do
    if Mix.env() != :dev do
      conn
      |> put_status(404)
      |> text("Not available in production")
    else
      results = run_tests()

      html_response = """
      <!DOCTYPE html>
      <html>
      <head>
        <title>OpenAI Test Results</title>
        <style>
          body { font-family: monospace; padding: 20px; background: #1a1a1a; color: #e0e0e0; }
          .success { color: #4ade80; }
          .error { color: #f87171; }
          .test { margin: 20px 0; padding: 15px; border: 1px solid #404040; border-radius: 5px; }
          .test h3 { margin-top: 0; color: #60a5fa; }
          pre { background: #2d2d2d; padding: 10px; border-radius: 3px; overflow-x: auto; }
        </style>
      </head>
      <body>
        <h1>🔍 OpenAI Integration Test Results</h1>
        <p><strong>Time:</strong> #{DateTime.utc_now()}</p>

        <div class="test">
          <h3>✓ Test 1: API Configuration</h3>
          <pre>#{results.config}</pre>
        </div>

        <div class="test">
          <h3>✓ Test 2: Simple Completion</h3>
          <pre>#{results.completion}</pre>
        </div>

        <div class="test">
          <h3>✓ Test 3: Email Categorization</h3>
          <pre>#{results.categorization}</pre>
        </div>

        <div class="test">
          <h3>✓ Test 4: Email Summarization</h3>
          <pre>#{results.summarization}</pre>
        </div>

        <p><a href="/dashboard" style="color: #60a5fa;">← Back to Dashboard</a></p>
      </body>
      </html>
      """

      conn
      |> put_resp_content_type("text/html")
      |> send_resp(200, html_response)
    end
  end

  defp run_tests do
    %{
      config: test_config(),
      completion: test_completion(),
      categorization: test_categorization(),
      summarization: test_summarization()
    }
  end

  defp test_config do
    api_key = Application.get_env(:openai, :api_key)

    if is_nil(api_key) || api_key == "" do
      "<span class='error'>❌ ERROR: OPENAI_API_KEY is not configured!</span>"
    else
      "<span class='success'>✓ API key found: #{String.slice(api_key, 0, 15)}...</span>"
    end
  end

  defp test_completion do
    messages = [
      %{role: "user", content: "Say 'Hello from OpenAI!' if you can read this."}
    ]

    case OpenAI.chat_completion(
           model: "gpt-4o-mini",
           messages: messages,
           temperature: 0.7,
           max_tokens: 50
         ) do
      {:ok, %{choices: [%{"message" => %{"content" => content}} | _]}} ->
        "<span class='success'>✓ Success!</span>\nResponse: #{content}"

      {:ok, response} ->
        "<span class='error'>❌ Unexpected response format</span>\n#{inspect(response, pretty: true)}"

      {:error, error} ->
        "<span class='error'>❌ Error</span>\n#{inspect(error, pretty: true)}"
    end
  end

  defp test_categorization do
    test_email = %{
      subject: "Weekly Newsletter - Tech Updates",
      from: "newsletter@example.com",
      body: "Here are this week's top tech stories..."
    }

    test_categories = [
      %{id: 1, name: "Newsletters", description: "Marketing emails and newsletters"},
      %{id: 2, name: "Work", description: "Work-related emails"},
      %{id: 3, name: "Personal", description: "Personal correspondence"}
    ]

    case Jump.AI.categorize_email(test_email, test_categories) do
      {:ok, nil} ->
        "<span class='success'>✓ Success (no category match)</span>"

      {:ok, category_id} ->
        category = Enum.find(test_categories, fn c -> c.id == category_id end)
        "<span class='success'>✓ Success!</span>\nCategorized as: #{if category, do: category.name, else: "Unknown"} (ID: #{category_id})"

      _ ->
        "<span class='error'>❌ Unexpected response</span>"
    end
  end

  defp test_summarization do
    test_email = %{
      subject: "Weekly Newsletter - Tech Updates",
      from: "newsletter@example.com",
      body: "Here are this week's top tech stories and innovations from the past week..."
    }

    case Jump.AI.summarize_email(test_email) do
      {:ok, summary} ->
        "<span class='success'>✓ Success!</span>\nSummary: #{summary}"

      _ ->
        "<span class='error'>❌ Unexpected response</span>"
    end
  end
end

