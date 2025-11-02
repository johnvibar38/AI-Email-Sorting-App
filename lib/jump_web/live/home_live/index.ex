defmodule JumpWeb.HomeLive.Index do
  use JumpWeb, :live_view

  on_mount {JumpWeb.UserAuth, :allow_unauthenticated}

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="max-w-4xl mx-auto text-center">
        <h1 class="text-4xl font-bold text-gray-900 mb-6">Welcome to Jump</h1>
        <p class="text-xl text-gray-600 mb-8">
          AI-powered email sorting and management
        </p>
        <%= if is_nil(@current_user) do %>
          <div>
            <a href={~p"/auth/google"} class="inline-block phx-submit-loading:opacity-75 rounded-lg bg-zinc-900 px-6 py-3 text-sm font-semibold leading-6 text-white active:bg-zinc-700 hover:bg-zinc-700">
              Sign in with Google
            </a>
          </div>
        <% else %>
          <div class="mt-8">
            <a href={~p"/dashboard"} class="inline-block phx-submit-loading:opacity-75 rounded-lg bg-zinc-900 px-6 py-3 text-sm font-semibold leading-6 text-white active:bg-zinc-700 hover:bg-zinc-700">
              Go to Dashboard
            </a>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
