defmodule JumpWeb.DashboardLiveTest do
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

    %{user: user}
  end

  describe "Dashboard" do
    test "displays welcome message for logged in user", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "AI Email Manager"
    end

    test "shows connected accounts section", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Connected Accounts"
      assert html =~ "Connect Gmail Account"
    end

    test "shows categories section", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Email Categories"
      assert html =~ "Add Category"
    end

    test "can create a new category", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # Navigate to new category modal
      {:ok, view, _html} = view
      |> element("a", "Add Category")
      |> render_click()
      |> follow_redirect(conn)

      # Fill out form
      view
      |> form("form", category: %{
        name: "Newsletters",
        description: "Marketing emails"
      })
      |> render_submit()

      # Verify category was created
      categories = EmailManagement.list_categories(user.id)
      assert length(categories) == 1
      assert hd(categories).name == "Newsletters"
    end

    test "displays categories with email counts", %{conn: conn, user: user} do
      {:ok, _category} = EmailManagement.create_category(%{
        user_id: user.id,
        name: "Work",
        description: "Work emails"
      })

      conn = log_in_user(conn, user)
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Work"
      assert html =~ "email"
    end
  end

  defp log_in_user(conn, user) do
    token = Phoenix.Token.sign(JumpWeb.Endpoint, "user auth", user.id)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end
end

