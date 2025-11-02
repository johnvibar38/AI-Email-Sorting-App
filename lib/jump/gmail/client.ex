defmodule Jump.Gmail.Client do
  @moduledoc """
  HTTP client for Gmail API interactions.
  """

  require Logger

  @gmail_api_base "https://gmail.googleapis.com/gmail/v1"
  @oauth_token_url "https://oauth2.googleapis.com/token"

  @doc """
  Lists messages from Gmail inbox.
  Options:
    - since: DateTime to fetch messages after
    - max_results: maximum number of messages to fetch (default 50)
  """
  def list_messages(access_token, opts \\ []) do
    max_results = Keyword.get(opts, :max_results, 50)

    query = build_query(opts)

    params = %{
      q: query,
      maxResults: max_results
    }

    case http_get("#{@gmail_api_base}/users/me/messages", access_token, params) do
      {:ok, %{"messages" => messages}} ->
        {:ok, messages}

      {:ok, %{}} ->
        {:ok, []}

      error ->
        error
    end
  end

  # Build Gmail search query
  defp build_query(opts) do
    base_query = "in:inbox is:unread"

    case Keyword.get(opts, :since) do
      nil ->
        base_query

      %DateTime{} = dt ->
        # Gmail uses YYYY/MM/DD format for after: query
        date_str = Calendar.strftime(dt, "%Y/%m/%d")
        "#{base_query} after:#{date_str}"

      _ ->
        base_query
    end
  end

  @doc """
  Fetches full details for a list of messages.
  """
  def fetch_message_details(access_token, messages) when is_list(messages) do
    emails =
      messages
      |> Enum.map(fn %{"id" => id} ->
        case get_message(access_token, id) do
          {:ok, email} -> email
          {:error, _} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, emails}
  end

  @doc """
  Gets a single message with full details.
  """
  def get_message(access_token, message_id) do
    case http_get("#{@gmail_api_base}/users/me/messages/#{message_id}", access_token, %{
           format: "full"
         }) do
      {:ok, message} ->
        {:ok, parse_message(message)}

      error ->
        error
    end
  end

  @doc """
  Archives a message (removes INBOX label).
  """
  def archive_message(access_token, message_id) do
    body = Jason.encode!(%{removeLabelIds: ["INBOX"]})

    case http_post(
           "#{@gmail_api_base}/users/me/messages/#{message_id}/modify",
           access_token,
           body
         ) do
      {:ok, _response} -> {:ok, :archived}
      error -> error
    end
  end

  @doc """
  Refreshes an access token using a refresh token.
  """
  def refresh_access_token(refresh_token) do
    client_id = Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_id]

    client_secret =
      Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_secret]

    body =
      URI.encode_query(%{
        client_id: client_id,
        client_secret: client_secret,
        refresh_token: refresh_token,
        grant_type: "refresh_token"
      })

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post(@oauth_token_url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, %{"access_token" => access_token, "expires_in" => expires_in}} ->
            expires_at = DateTime.add(DateTime.utc_now(), expires_in, :second)
            {:ok, %{access_token: access_token, expires_at: expires_at}}

          error ->
            Logger.error("Failed to decode token response: #{inspect(error)}")
            {:error, :decode_error}
        end

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("Token refresh failed with status #{status_code}: #{body}")
        {:error, :refresh_failed}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP error refreshing token: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private helpers

  defp http_get(url, access_token, params) do
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Accept", "application/json"}
    ]

    url_with_params = if params == %{}, do: url, else: "#{url}?#{URI.encode_query(params)}"

    case HTTPoison.get(url_with_params, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode(body)

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("Gmail API request failed with status #{status_code}: #{body}")
        {:error, :api_error}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp http_post(url, access_token, body) do
    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}}
      when status_code in 200..299 ->
        Jason.decode(response_body)

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("Gmail API POST failed with status #{status_code}: #{body}")
        {:error, :api_error}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_message(message) do
    headers = get_headers(message)

    %{
      id: message["id"],
      thread_id: message["threadId"],
      subject: get_header(headers, "Subject"),
      from: get_header(headers, "From"),
      to: get_header(headers, "To"),
      date: parse_date(get_header(headers, "Date")),
      snippet: message["snippet"],
      body: extract_body(message),
      internal_date: message["internalDate"]
    }
  end

  defp get_headers(%{"payload" => %{"headers" => headers}}), do: headers
  defp get_headers(_), do: []

  defp get_header(headers, name) do
    case Enum.find(headers, fn h -> h["name"] == name end) do
      %{"value" => value} -> value
      _ -> nil
    end
  end

  defp parse_date(nil), do: DateTime.utc_now()

  defp parse_date(date_string) do
    # Simple date parsing - in production you'd want more robust parsing
    case DateTime.from_iso8601(date_string) do
      {:ok, datetime, _} -> datetime
      _ -> DateTime.utc_now()
    end
  end

  defp extract_body(%{"payload" => payload}) do
    cond do
      # Single part message
      Map.has_key?(payload, "body") && payload["body"]["data"] ->
        decode_body(payload["body"]["data"])

      # Multipart message
      Map.has_key?(payload, "parts") ->
        extract_text_from_parts(payload["parts"])

      true ->
        ""
    end
  end

  defp extract_body(_), do: ""

  defp extract_text_from_parts(parts) when is_list(parts) do
    parts
    |> Enum.find_value(fn part ->
      cond do
        part["mimeType"] == "text/plain" && part["body"]["data"] ->
          decode_body(part["body"]["data"])

        part["mimeType"] == "text/html" && part["body"]["data"] ->
          decode_body(part["body"]["data"])

        Map.has_key?(part, "parts") ->
          extract_text_from_parts(part["parts"])

        true ->
          nil
      end
    end) || ""
  end

  defp extract_text_from_parts(_), do: ""

  defp decode_body(data) do
    data
    |> String.replace("-", "+")
    |> String.replace("_", "/")
    |> Base.decode64!(padding: false)
  rescue
    _ -> ""
  end
end
