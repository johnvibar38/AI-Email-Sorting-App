defmodule JumpWeb.AuthController do
  use JumpWeb, :controller

  require Logger

  alias Jump.Accounts
  alias JumpWeb.UserAuth

  plug Ueberauth

  def request(conn, _params) do
    # Debug: Check if OAuth credentials are loaded
    client_id = Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_id]

    client_secret =
      Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_secret]

    Logger.info("=== OAuth Debug ===")

    Logger.info(
      "Client ID present: #{if client_id, do: "YES (#{String.slice(client_id || "", 0, 20)}...)", else: "NO"}"
    )

    Logger.info("Client Secret present: #{if client_secret, do: "YES", else: "NO"}")
    Logger.info("==================")

    # Ueberauth will handle the request
    conn
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: ~p"/")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    with {:ok, user} <- create_or_update_user(auth),
         {:ok, _google_account} <- create_or_update_google_account(user, auth) do
      conn
      |> UserAuth.log_in_user(user)
      |> put_flash(:info, "Successfully authenticated.")
      |> redirect(to: ~p"/dashboard")
    else
      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to create or update user.")
        |> redirect(to: ~p"/")
    end
  end

  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user()
    |> put_flash(:info, "Logged out successfully.")
    |> redirect(to: ~p"/")
  end

  @doc """
  Request to add an additional Gmail account (user already logged in).
  """
  def add_account_request(conn, _params) do
    Logger.info("========================================")
    Logger.info("ADD ACCOUNT REQUEST STARTED")
    Logger.info("User ID: #{conn.assigns.current_user.id}")
    Logger.info("Building OAuth URL...")
    Logger.info("========================================")

    # Redirect to Google OAuth with prompt=consent to force account selection
    oauth_url = build_add_account_url(conn)

    Logger.info("========================================")
    Logger.info("REDIRECTING TO GOOGLE OAUTH")
    Logger.info("OAuth URL: #{oauth_url}")
    Logger.info("========================================")

    redirect(conn, external: oauth_url)
  end

  @doc """
  Callback for adding an additional Gmail account.
  Manually handles OAuth code exchange since we're not using Ueberauth for this route.
  """
  def add_account_callback(conn, %{"code" => code} = _params) do
    user = conn.assigns.current_user

    Logger.info("========================================")
    Logger.info("ADD ACCOUNT CALLBACK RECEIVED")
    Logger.info("User: #{user.id}, Code present: #{!!code}")
    Logger.info("========================================")

    case exchange_code_for_tokens(conn, code) do
      {:ok, token_response} ->
        case fetch_user_info(token_response["access_token"]) do
          {:ok, user_info} ->
            tokens = %{
              access_token: token_response["access_token"],
              refresh_token: token_response["refresh_token"] || "",
              expires_at:
                DateTime.add(DateTime.utc_now(), token_response["expires_in"] || 3600, :second)
            }

            case Accounts.create_or_update_google_account(user.id, user_info["email"], tokens) do
              {:ok, _google_account} ->
                conn
                |> put_flash(:info, "Gmail account '#{user_info["email"]}' added successfully!")
                |> redirect(to: ~p"/dashboard")

              {:error, changeset} ->
                error_msg = format_changeset_errors(changeset)
                Logger.error("Failed to save account: #{error_msg}")

                conn
                |> put_flash(:error, "Failed to add Gmail account: #{error_msg}")
                |> redirect(to: ~p"/dashboard")
            end

          {:error, reason} ->
            Logger.error("Failed to fetch user info: #{inspect(reason)}")

            conn
            |> put_flash(:error, "Failed to fetch account information from Google.")
            |> redirect(to: ~p"/dashboard")
        end

      {:error, reason} ->
        Logger.error("Failed to exchange code: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Failed to authenticate with Google.")
        |> redirect(to: ~p"/dashboard")
    end
  end

  def add_account_callback(conn, _params) do
    # No code parameter - something went wrong
    Logger.error("Add account callback - No code parameter")

    conn
    |> put_flash(:error, "Failed to authenticate with Google.")
    |> redirect(to: ~p"/dashboard")
  end

  defp create_or_update_user(%Ueberauth.Auth{} = auth) do
    oauth_info = %{
      email: auth.info.email,
      name: auth.info.name,
      provider: to_string(auth.provider),
      provider_id: auth.uid,
      avatar_url: auth.info.image
    }

    Accounts.get_or_create_user_from_oauth(oauth_info)
  end

  defp create_or_update_google_account(user, %Ueberauth.Auth{} = auth) do
    # Extract tokens from OAuth response
    credentials = auth.credentials

    # Calculate expiry time
    expires_at =
      case credentials.expires_at do
        nil ->
          # If expires_at is not provided, calculate from expires_in
          DateTime.add(DateTime.utc_now(), credentials.expires || 3600, :second)

        timestamp when is_integer(timestamp) ->
          DateTime.from_unix!(timestamp)

        %DateTime{} = dt ->
          dt
      end

    tokens = %{
      access_token: credentials.token,
      refresh_token: credentials.refresh_token || "",
      expires_at: expires_at
    }

    Accounts.create_or_update_google_account(user.id, auth.info.email, tokens)
  end

  # NOTE: This function is kept for reference but currently unused
  # defp create_google_account_for_user(user, %Ueberauth.Auth{} = auth) do
  #   # Just create/update the Google account, don't touch the user
  #   credentials = auth.credentials
  #
  #   expires_at =
  #     case credentials.expires_at do
  #       nil -> DateTime.add(DateTime.utc_now(), credentials.expires || 3600, :second)
  #       timestamp when is_integer(timestamp) -> DateTime.from_unix!(timestamp)
  #       %DateTime{} = dt -> dt
  #     end
  #
  #   tokens = %{
  #     access_token: credentials.token,
  #     refresh_token: credentials.refresh_token || "",
  #     expires_at: expires_at
  #   }
  #
  #   Accounts.create_or_update_google_account(user.id, auth.info.email, tokens)
  # end

  defp build_add_account_url(conn) do
    Logger.info(">>> build_add_account_url called")

    client_id = Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_id]
    Logger.info(">>> Client ID present: #{!!client_id}")

    # Build the redirect URI using Phoenix's URL helpers to respect force_ssl and proxy headers
    redirect_uri = build_redirect_uri(conn, "/auth/google/add/callback")
    # redirect_uri = "https://ai-email-sorting-app-jatm.onrender.com/auth/google/add/callback"

    Logger.info("========================================")
    Logger.info("OAUTH REDIRECT URI GENERATED")
    Logger.info("redirect_uri: #{redirect_uri}")
    Logger.info("========================================")

    scopes = [
      "email",
      "profile",
      "https://www.googleapis.com/auth/gmail.readonly",
      "https://www.googleapis.com/auth/gmail.modify"
    ]

    query =
      URI.encode_query(%{
        client_id: client_id,
        redirect_uri: redirect_uri,
        response_type: "code",
        scope: Enum.join(scopes, " "),
        access_type: "offline",
        # Force account selection
        prompt: "consent select_account"
      })

    "https://accounts.google.com/o/oauth2/v2/auth?#{query}"
  end

  defp format_changeset_errors(%Ecto.Changeset{errors: errors}) do
    errors
    |> Enum.map(fn {field, {msg, _}} -> "#{field} #{msg}" end)
    |> Enum.join(", ")
  end

  defp format_changeset_errors(_), do: "Unknown error"

  defp exchange_code_for_tokens(conn, code) do
    client_id = Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_id]

    client_secret =
      Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_secret]

    # Build the redirect URI using Phoenix's URL helpers to respect force_ssl and proxy headers
    redirect_uri = build_redirect_uri(conn, "/auth/google/add/callback")

    Logger.info("========================================")
    Logger.info("TOKEN EXCHANGE - Using redirect_uri:")
    Logger.info("#{redirect_uri}")
    Logger.info("========================================")

    body =
      URI.encode_query(%{
        code: code,
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: redirect_uri,
        grant_type: "authorization_code"
      })

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case HTTPoison.post("https://oauth2.googleapis.com/token", body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        Jason.decode(response_body)

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("Token exchange failed with status #{status_code}: #{body}")
        {:error, :token_exchange_failed}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP error during token exchange: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_user_info(access_token) do
    headers = [{"Authorization", "Bearer #{access_token}"}]

    case HTTPoison.get("https://www.googleapis.com/oauth2/v2/userinfo", headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode(body)

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("User info fetch failed with status #{status_code}: #{body}")
        {:error, :user_info_fetch_failed}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP error fetching user info: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Builds a redirect URI that respects the endpoint's URL configuration.
  # In production, this will use HTTPS. In development, it uses HTTP.
  defp build_redirect_uri(_conn, path) do
    # Hardcoded redirect URI generation based on environment
    # Production: Always HTTPS
    # Development/Test: Always HTTP

    env = Application.get_env(:jump, :env, :dev)

    # Get host from endpoint config
    endpoint_config = Application.get_env(:jump, JumpWeb.Endpoint)
    url_config = Keyword.get(endpoint_config, :url, [])
    host = Keyword.get(url_config, :host, "localhost")

    # Hardcode scheme and port based on environment
    {scheme, port_string} =
      case env do
        :prod ->
          # Production: Always HTTPS, no port in URL (standard 443)
          {"https", ""}

        _ ->
          # Development/Test: Always HTTP with port 4000
          {"http", ":4000"}
      end

    redirect_uri = "#{scheme}://#{host}#{port_string}#{path}"

    Logger.info("========================================")
    Logger.info("REDIRECT URI GENERATED")
    Logger.info("Environment: #{inspect(env)}")
    Logger.info("Scheme: #{scheme} (hardcoded)")
    Logger.info("Host: #{host}")
    Logger.info("Path: #{path}")
    Logger.info("Final URI: #{redirect_uri}")
    Logger.info("========================================")

    redirect_uri
  end
end
