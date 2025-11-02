defmodule JumpWeb.CategoryLiveTest do
  use JumpWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Jump.Accounts
  alias Jump.EmailManagement

  setup do
    {:ok, user} = Accounts.create_user(%{
      email: "test@example.com",
      name: "Test User",
      provider: "google",
      provider_id: "12345"
    })

    {:ok, category} = EmailManagement.create_category(%{
      user_id: user.id,
      name: "Work",
      description: "Work emails"
    })

    %{user: user, category: category}
  end

  describe "Category Show" do
    test "displays category name and description", %{conn: conn, user: user, category: category} do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/categories/#{category.id}")

      assert html =~ category.name
      assert html =~ category.description
    end

    test "shows empty state when no emails", %{conn: conn, user: user, category: category} do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/categories/#{category.id}")

      assert html =~ "No emails yet"
    end

    test "displays back to dashboard link", %{conn: conn, user: user, category: category} do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/categories/#{category.id}")

      assert html =~ "Back to Dashboard"
    end

    test "redirects when category not found", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      
      # Should redirect to dashboard immediately
      assert {:error, {:live_redirect, %{to: "/dashboard"}}} = 
        live(conn, ~p"/categories/999999")
    end
  end

  defp log_in_user(conn, user) do
    token = Phoenix.Token.sign(JumpWeb.Endpoint, "user socket", user.id)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end
end

