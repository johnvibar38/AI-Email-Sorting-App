defmodule JumpWeb.Router do
  use JumpWeb, :router

  import JumpWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {JumpWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # OAuth routes
  scope "/auth", JumpWeb do
    pipe_through :browser

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
    delete "/logout", AuthController, :delete
  end

  # Add additional Gmail account (user must be logged in)
  scope "/auth", JumpWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/google/add", AuthController, :add_account_request
    get "/google/add/callback", AuthController, :add_account_callback
  end

  # Public routes
  scope "/", JumpWeb do
    pipe_through :browser

    live "/", HomeLive.Index, :index
  end

  # Protected routes
  scope "/", JumpWeb do
    pipe_through [:browser, :require_authenticated_user]

    live "/dashboard", DashboardLive.Index, :index
    live "/dashboard/new_category", DashboardLive.Index, :new_category
    live "/categories/:id", CategoryLive.Show, :show
    live "/accounts/:id/emails", AccountEmailsLive.Show, :show
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:jump, :dev_routes, false) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: JumpWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
      get "/test-openai", JumpWeb.TestController, :test_openai
    end
  end
end
