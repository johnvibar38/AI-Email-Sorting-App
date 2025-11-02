defmodule Jump.Workers.EmailSyncWorkerTest do
  use Jump.DataCase
  use Oban.Testing, repo: Jump.Repo

  alias Jump.Workers.EmailSyncWorker
  alias Jump.Accounts

  describe "perform/1" do
    setup do
      {:ok, user} = Accounts.create_user(%{
        email: "test@example.com",
        name: "Test User",
        provider: "google",
        provider_id: "12345"
      })

      {:ok, account} = Accounts.create_or_update_google_account(
        user.id,
        "test@gmail.com",
        %{
          access_token: "token",
          refresh_token: "refresh",
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        }
      )

      %{user: user, account: account}
    end

    test "schedule_sync/1 enqueues a job", %{account: account} do
      assert {:ok, _job} = EmailSyncWorker.schedule_sync(account.id)
    end

    test "schedule_all_syncs/0 enqueues a job" do
      assert {:ok, _job} = EmailSyncWorker.schedule_all_syncs()
    end
  end
end

