# Test script to verify OpenAI integration
# Run this with: mix run test_openai.exs

defmodule OpenAITest do
  @moduledoc """
  Simple script to test OpenAI integration
  """

  def test_connection do
    IO.puts("\n=== Testing OpenAI Connection ===\n")

    # Check if API key is configured
    api_key = Application.get_env(:openai, :api_key)

    if is_nil(api_key) || api_key == "" do
      IO.puts("❌ ERROR: OPENAI_API_KEY is not configured!")
      IO.puts("   Please set it in your environment or config/dev.exs")
      IO.puts("   Example: export OPENAI_API_KEY=\"sk-...\"")
      System.halt(1)
    end

    IO.puts("✓ API key found: #{String.slice(api_key, 0, 10)}...")

    # Test 1: Simple completion
    IO.puts("\n--- Test 1: Simple completion ---")

    case test_simple_completion() do
      {:ok, response} ->
        IO.puts("✓ Success! Response: #{String.slice(response, 0, 100)}...")

      {:error, reason} ->
        IO.puts("❌ Error: #{inspect(reason)}")
    end

    # Test 2: Email categorization
    IO.puts("\n--- Test 2: Email categorization ---")

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
      {:ok, category_id} ->
        category = Enum.find(test_categories, fn c -> c.id == category_id end)
        IO.puts("✓ Email categorized as: #{if category, do: category.name, else: "None"}")

      {:error, reason} ->
        IO.puts("❌ Categorization failed: #{inspect(reason)}")
    end

    # Test 3: Email summarization
    IO.puts("\n--- Test 3: Email summarization ---")

    case Jump.AI.summarize_email(test_email) do
      {:ok, summary} ->
        IO.puts("✓ Summary generated: #{summary}")

      {:error, reason} ->
        IO.puts("❌ Summarization failed: #{inspect(reason)}")
    end

    IO.puts("\n=== All tests complete! ===\n")
  end

  defp test_simple_completion do
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
        {:ok, content}

      {:ok, response} ->
        {:error, "Unexpected response format: #{inspect(response)}"}

      {:error, error} ->
        {:error, error}
    end
  end
end

# Run the test
OpenAITest.test_connection()
