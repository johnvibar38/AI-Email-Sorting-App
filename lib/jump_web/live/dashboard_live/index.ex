defmodule JumpWeb.DashboardLive.Index do
  use JumpWeb, :live_view

  alias Jump.Accounts
  alias Jump.EmailManagement
  alias Jump.Workers.EmailSyncWorker

  on_mount {JumpWeb.UserAuth, :default}

  @impl true
  def mount(_params, _session, socket) do
    google_accounts =
      if connected?(socket) do
        Accounts.list_google_accounts(socket.assigns.current_user.id)
      else
        []
      end

    categories =
      if connected?(socket) do
        EmailManagement.list_categories_with_counts(socket.assigns.current_user.id)
      else
        []
      end

    {:ok,
     socket
     |> assign(:google_accounts, google_accounts)
     |> assign(:categories, categories)
     |> assign(:show_category_modal, false)
     |> assign(:form, to_form(%{}))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Email Manager Dashboard")
  end

  defp apply_action(socket, :new_category, _params) do
    socket
    |> assign(:page_title, "New Category")
    |> assign(:show_category_modal, true)
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, push_patch(socket, to: ~p"/dashboard")}
  end

  @impl true
  def handle_event("create_category", %{"category" => category_params}, socket) do
    category_params = Map.put(category_params, "user_id", socket.assigns.current_user.id)

    case EmailManagement.create_category(category_params) do
      {:ok, _category} ->
        categories = EmailManagement.list_categories_with_counts(socket.assigns.current_user.id)

        {:noreply,
         socket
         |> assign(:categories, categories)
         |> put_flash(:info, "Category created successfully")
         |> push_patch(to: ~p"/dashboard")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("delete_category", %{"id" => id}, socket) do
    category = EmailManagement.get_user_category(id, socket.assigns.current_user.id)

    case category do
      nil ->
        {:noreply, put_flash(socket, :error, "Category not found")}

      category ->
        case EmailManagement.delete_category(category) do
          {:ok, _} ->
            categories =
              EmailManagement.list_categories_with_counts(socket.assigns.current_user.id)

            {:noreply,
             socket
             |> assign(:categories, categories)
             |> put_flash(:info, "Category deleted successfully")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete category")}
        end
    end
  end

  @impl true
  def handle_event("sync_account", %{"id" => account_id}, socket) do
    case EmailSyncWorker.schedule_sync(String.to_integer(account_id)) do
      {:ok, _job} ->
        {:noreply, put_flash(socket, :info, "Email sync started")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to start sync")}
    end
  end

  @impl true
  def handle_event("delete_account", %{"id" => account_id}, socket) do
    case Accounts.get_google_account_by_email(account_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Account not found")}

      account ->
        if account.user_id == socket.assigns.current_user.id do
          case Accounts.delete_google_account(account) do
            {:ok, _} ->
              google_accounts = Accounts.list_google_accounts(socket.assigns.current_user.id)

              {:noreply,
               socket
               |> assign(:google_accounts, google_accounts)
               |> put_flash(:info, "Account disconnected successfully")}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Failed to disconnect account")}
          end
        else
          {:noreply, put_flash(socket, :error, "Unauthorized")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="container mx-auto px-4 py-8">
        <div class="max-w-7xl mx-auto">
          <div class="mb-8">
            <h1 class="text-4xl font-bold text-gray-900">AI Email Manager</h1>
            <p class="mt-2 text-gray-600">Automatically organize and summarize your emails</p>
          </div>

          <!-- Google Accounts Section -->
          <div class="mb-10">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-2xl font-semibold text-gray-800">Connected Gmail Accounts</h2>
              <a
                href={~p"/auth/google/add"}
                class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors"
              >
                <svg
                  class="w-5 h-5 mr-2"
                  fill="currentColor"
                  viewBox="0 0 24 24"
                  xmlns="http://www.w3.org/2000/svg"
                >
                  <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm5 11h-4v4h-2v-4H7v-2h4V7h2v4h4v2z" />
                </svg>
                <%= if @google_accounts == [] do %>
                  Connect Gmail Account
                <% else %>
                  Add Another Account
                <% end %>
              </a>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <%= if @google_accounts == [] do %>
                <div class="col-span-full bg-white rounded-lg shadow p-8 text-center">
                  <svg
                    class="mx-auto h-12 w-12 text-gray-400"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                    />
                  </svg>
                  <h3 class="mt-2 text-sm font-medium text-gray-900">No Gmail accounts connected</h3>
                  <p class="mt-1 text-sm text-gray-500">
                    Click "Connect Gmail Account" above to get started
                  </p>
                </div>
              <% else %>
                <%= for account <- @google_accounts do %>
                  <div class="bg-white rounded-lg shadow hover:shadow-lg transition-shadow">
                    <.link
                      navigate={~p"/accounts/#{account.id}/emails"}
                      class="block p-6"
                    >
                      <div class="flex items-center justify-between mb-4">
                        <div class="flex items-center">
                          <div class="bg-blue-100 rounded-full p-2">
                            <svg
                              class="w-6 h-6 text-blue-600"
                              fill="currentColor"
                              viewBox="0 0 20 20"
                            >
                              <path d="M2.003 5.884L10 9.882l7.997-3.998A2 2 0 0016 4H4a2 2 0 00-1.997 1.884z" />
                              <path d="M18 8.118l-8 4-8-4V14a2 2 0 002 2h12a2 2 0 002-2V8.118z" />
                            </svg>
                          </div>
                          <div class="ml-3">
                            <p class="text-sm font-medium text-gray-900 hover:text-blue-600">
                              <%= account.email %>
                            </p>
                            <p class="text-xs text-gray-500">
                              Last synced: <%= format_timestamp(account.last_synced_at) %>
                            </p>
                          </div>
                        </div>
                        <svg
                          class="w-5 h-5 text-gray-400"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M9 5l7 7-7 7"
                          />
                        </svg>
                      </div>
                    </.link>
                    <div class="px-6 pb-6 flex space-x-2 border-t border-gray-100 pt-4">
                      <button
                        phx-click="sync_account"
                        phx-value-id={account.id}
                        class="flex-1 px-3 py-2 text-sm bg-blue-50 text-blue-700 rounded hover:bg-blue-100"
                        onclick="event.stopPropagation();"
                      >
                        Sync Now
                      </button>
                      <button
                        phx-click="delete_account"
                        phx-value-id={account.email}
                        data-confirm="Are you sure you want to disconnect this account?"
                        class="px-3 py-2 text-sm bg-red-50 text-red-700 rounded hover:bg-red-100"
                        onclick="event.stopPropagation();"
                      >
                        Disconnect
                      </button>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>

          <!-- Categories Section -->
          <div class="mb-10">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-2xl font-semibold text-gray-800">Email Categories</h2>
              <.link
                patch={~p"/dashboard/new_category"}
                class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
              >
                <svg
                  class="w-5 h-5 mr-2"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 4v16m8-8H4"
                  />
                </svg>
                Add Category
              </.link>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <%= if @categories == [] do %>
                <div class="col-span-full bg-white rounded-lg shadow p-8 text-center">
                  <svg
                    class="mx-auto h-12 w-12 text-gray-400"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"
                    />
                  </svg>
                  <h3 class="mt-2 text-sm font-medium text-gray-900">No categories yet</h3>
                  <p class="mt-1 text-sm text-gray-500">
                    Create categories to organize your emails automatically
                  </p>
                </div>
              <% else %>
                <%= for %{category: category, email_count: count} <- @categories do %>
                  <.link
                    navigate={~p"/categories/#{category.id}"}
                    class="block bg-white rounded-lg shadow hover:shadow-lg transition-shadow p-6"
                  >
                    <div class="flex justify-between items-start mb-2">
                      <h3 class="text-lg font-semibold text-gray-900"><%= category.name %></h3>
                      <button
                        phx-click="delete_category"
                        phx-value-id={category.id}
                        data-confirm="Are you sure you want to delete this category?"
                        class="text-gray-400 hover:text-red-600"
                        onclick="event.preventDefault(); event.stopPropagation();"
                      >
                        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                          <path
                            fill-rule="evenodd"
                            d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z"
                            clip-rule="evenodd"
                          />
                        </svg>
                      </button>
                    </div>
                    <p class="text-sm text-gray-600 mb-4 line-clamp-2">
                      <%= category.description || "No description" %>
                    </p>
                    <div class="flex items-center justify-between">
                      <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800">
                        <%= count %> <%= if count == 1, do: "email", else: "emails" %>
                      </span>
                      <svg
                        class="w-5 h-5 text-gray-400"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M9 5l7 7-7 7"
                        />
                      </svg>
                    </div>
                  </.link>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <!-- Category Modal -->
      <%= if @show_category_modal do %>
        <div
          class="fixed z-10 inset-0 overflow-y-auto"
          phx-click="close_modal"
          phx-window-keydown="close_modal"
          phx-key="escape"
        >
          <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>
            <span class="hidden sm:inline-block sm:align-middle sm:h-screen">&#8203;</span>
            <div
              class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full"
              phx-click-away="close_modal"
            >
              <.form for={@form} phx-submit="create_category" class="bg-white px-4 pt-5 pb-4 sm:p-6">
                <div>
                  <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
                    Create New Category
                  </h3>
                  <div class="space-y-4">
                    <div>
                      <label for="category_name" class="block text-sm font-medium text-gray-700">
                        Category Name
                      </label>
                      <input
                        type="text"
                        name="category[name]"
                        id="category_name"
                        required
                        class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                        placeholder="e.g., Newsletters, Receipts, Social"
                      />
                    </div>
                    <div>
                      <label
                        for="category_description"
                        class="block text-sm font-medium text-gray-700"
                      >
                        Description
                      </label>
                      <textarea
                        name="category[description]"
                        id="category_description"
                        rows="3"
                        class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                        placeholder="Describe what emails should go in this category..."
                      ></textarea>
                      <p class="mt-2 text-sm text-gray-500">
                        AI will use this description to categorize your emails automatically
                      </p>
                    </div>
                  </div>
                </div>
                <div class="mt-5 sm:mt-6 sm:grid sm:grid-cols-2 sm:gap-3 sm:grid-flow-row-dense">
                  <button
                    type="submit"
                    class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-green-600 text-base font-medium text-white hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 sm:col-start-2 sm:text-sm"
                  >
                    Create Category
                  </button>
                  <button
                    type="button"
                    phx-click="close_modal"
                    class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 sm:mt-0 sm:col-start-1 sm:text-sm"
                  >
                    Cancel
                  </button>
                </div>
              </.form>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_timestamp(nil), do: "Never"

  defp format_timestamp(timestamp) do
    case DateTime.compare(timestamp, DateTime.add(DateTime.utc_now(), -86400, :second)) do
      :gt ->
        # Less than 24 hours ago
        diff = DateTime.diff(DateTime.utc_now(), timestamp, :second)

        cond do
          diff < 60 -> "Just now"
          diff < 3600 -> "#{div(diff, 60)} min ago"
          true -> "#{div(diff, 3600)} hours ago"
        end

      _ ->
        # More than 24 hours ago
        Calendar.strftime(timestamp, "%b %d, %Y")
    end
  end
end
