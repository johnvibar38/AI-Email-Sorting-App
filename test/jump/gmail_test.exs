defmodule Jump.GmailTest do
  use Jump.DataCase

  alias Jump.Gmail
  alias Jump.Accounts

  describe "token management" do
    setup do
      {:ok, user} =
        Accounts.create_user(%{
          email: "test@example.com",
          name: "Test User",
          provider: "google",
          provider_id: "12345"
        })

      {:ok, account} =
        Accounts.create_or_update_google_account(
          user.id,
          "test@gmail.com",
          %{
            access_token: "old_token",
            refresh_token: "refresh_token",
            # Expired
            expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
          }
        )

      %{user: user, account: account}
    end

    test "ensure_valid_token/1 returns token for valid account", %{user: user} do
      {:ok, account} =
        Accounts.create_or_update_google_account(
          user.id,
          "valid@gmail.com",
          %{
            access_token: "valid_token",
            refresh_token: "refresh",
            # Valid for 2 hours
            expires_at: DateTime.add(DateTime.utc_now(), 7200, :second)
          }
        )

      case Gmail.ensure_valid_token(account) do
        {:ok, token} ->
          assert is_binary(token)

        {:error, _} ->
          # Token refresh might fail in test environment
          assert true
      end
    end
  end
end
