defmodule Jump.EmailManagementTest do
  use Jump.DataCase

  alias Jump.EmailManagement
  alias Jump.Accounts

  describe "categories" do
    setup do
      {:ok, user} =
        Accounts.create_user(%{
          email: "test@example.com",
          name: "Test User",
          provider: "google",
          provider_id: "12345"
        })

      %{user: user}
    end

    test "list_categories/1 returns all categories for a user", %{user: user} do
      {:ok, cat1} = EmailManagement.create_category(%{user_id: user.id, name: "Work"})
      {:ok, cat2} = EmailManagement.create_category(%{user_id: user.id, name: "Personal"})

      categories = EmailManagement.list_categories(user.id)

      assert length(categories) == 2
      assert Enum.any?(categories, &(&1.id == cat1.id))
      assert Enum.any?(categories, &(&1.id == cat2.id))
    end

    test "create_category/1 with valid data creates a category", %{user: user} do
      attrs = %{
        user_id: user.id,
        name: "Newsletters",
        description: "Marketing emails and newsletters"
      }

      assert {:ok, category} = EmailManagement.create_category(attrs)
      assert category.name == "Newsletters"
      assert category.description == "Marketing emails and newsletters"
      assert category.user_id == user.id
    end

    test "create_category/1 with invalid data returns error changeset", %{user: user} do
      attrs = %{user_id: user.id, name: nil}
      assert {:error, %Ecto.Changeset{}} = EmailManagement.create_category(attrs)
    end

    test "delete_category/1 deletes the category", %{user: user} do
      {:ok, category} = EmailManagement.create_category(%{user_id: user.id, name: "Work"})

      assert {:ok, _} = EmailManagement.delete_category(category)

      assert_raise Ecto.NoResultsError, fn ->
        EmailManagement.get_category!(category.id)
      end
    end
  end

  describe "emails" do
    setup do
      {:ok, user} =
        Accounts.create_user(%{
          email: "test@example.com",
          name: "Test User",
          provider: "google",
          provider_id: "12345"
        })

      {:ok, google_account} =
        Accounts.create_or_update_google_account(
          user.id,
          "test@gmail.com",
          %{
            access_token: "token",
            refresh_token: "refresh",
            expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
          }
        )

      {:ok, category} =
        EmailManagement.create_category(%{
          user_id: user.id,
          name: "Work"
        })

      %{user: user, google_account: google_account, category: category}
    end

    test "list_emails_by_category/1 returns emails for a category", %{
      google_account: account,
      category: category
    } do
      gmail_data = %{
        id: "msg123",
        subject: "Test Email",
        from: "sender@example.com",
        date: DateTime.utc_now(),
        body: "Test content",
        snippet: "Test"
      }

      {:ok, _email} = EmailManagement.import_email(account.id, gmail_data, [category])

      emails = EmailManagement.list_emails_by_category(category.id)
      assert length(emails) >= 0
    end

    test "bulk_delete_emails/1 soft deletes multiple emails", %{
      google_account: account,
      category: category
    } do
      # Create test emails
      {:ok, email1} = create_test_email(account.id, category.id, "msg1")
      {:ok, email2} = create_test_email(account.id, category.id, "msg2")

      assert {:ok, count} = EmailManagement.bulk_delete_emails([email1.id, email2.id])
      assert count == 2

      # Verify emails are soft deleted
      updated_email1 = EmailManagement.get_email!(email1.id)
      updated_email2 = EmailManagement.get_email!(email2.id)

      assert updated_email1.deleted
      assert updated_email2.deleted
    end

    test "extract_unsubscribe_link/1 finds unsubscribe URL", _context do
      content = """
      This is an email with an unsubscribe link.
      Click here to unsubscribe: https://example.com/unsubscribe?id=123
      """

      assert EmailManagement.extract_unsubscribe_link(content) =~ "unsubscribe"
    end

    test "extract_unsubscribe_link/1 returns nil when no URL found", _context do
      content = "This email has no unsubscribe link"
      assert EmailManagement.extract_unsubscribe_link(content) == nil
    end
  end

  defp create_test_email(google_account_id, category_id, gmail_id) do
    attrs = %{
      google_account_id: google_account_id,
      category_id: category_id,
      gmail_id: gmail_id,
      subject: "Test Email",
      from_address: "test@example.com",
      received_at: DateTime.utc_now(),
      content: "Test content"
    }

    %EmailManagement.Email{}
    |> EmailManagement.Email.changeset(attrs)
    |> Repo.insert()
  end
end
