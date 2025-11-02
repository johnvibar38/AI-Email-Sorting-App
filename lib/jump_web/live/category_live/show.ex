defmodule JumpWeb.CategoryLive.Show do
  use JumpWeb, :live_view

  alias Jump.EmailManagement
  alias Jump.Unsubscribe
  alias Jump.Accounts

  on_mount {JumpWeb.UserAuth, :default}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    category = EmailManagement.get_user_category(id, socket.assigns.current_user.id)

    if category do
      # Get all Google accounts for the user
      google_accounts = Accounts.list_google_accounts(socket.assigns.current_user.id)

      # Get emails grouped by account
      emails_by_account =
        EmailManagement.list_emails_by_category_grouped_by_account(
          category.id,
          socket.assigns.current_user.id
        )

      # Default to first account's emails (or all if no accounts)
      {selected_account_id, initial_emails} =
        case google_accounts do
          [first_account | _] ->
            # Show first account's emails by default
            emails =
              EmailManagement.list_emails_by_category_and_account(
                category.id,
                first_account.id
              )

            {first_account.id, emails}

          [] ->
            # No accounts, show empty
            {nil, []}
        end

      {:ok,
       socket
       |> assign(:category, category)
       |> assign(:google_accounts, google_accounts)
       |> assign(:emails_by_account, emails_by_account)
       |> assign(:emails, initial_emails)
       |> assign(:selected_account_id, selected_account_id)
       |> assign(:selected_emails, MapSet.new())
       |> assign(:show_email_modal, false)
       |> assign(:selected_email, nil)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Category not found")
       |> push_navigate(to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("toggle_email", %{"id" => email_id}, socket) do
    email_id = String.to_integer(email_id)
    selected = socket.assigns.selected_emails

    new_selected =
      if MapSet.member?(selected, email_id) do
        MapSet.delete(selected, email_id)
      else
        MapSet.put(selected, email_id)
      end

    {:noreply, assign(socket, :selected_emails, new_selected)}
  end

  @impl true
  def handle_event("select_all", _, socket) do
    all_email_ids = Enum.map(socket.assigns.emails, & &1.id) |> MapSet.new()
    {:noreply, assign(socket, :selected_emails, all_email_ids)}
  end

  @impl true
  def handle_event("deselect_all", _, socket) do
    {:noreply, assign(socket, :selected_emails, MapSet.new())}
  end

  @impl true
  def handle_event("filter_by_account", %{"account_id" => account_id}, socket) do
    account_id = String.to_integer(account_id)

    # Filter emails by specific account
    filtered_emails =
      EmailManagement.list_emails_by_category_and_account(
        socket.assigns.category.id,
        account_id
      )

    {:noreply,
     socket
     |> assign(:selected_account_id, account_id)
     |> assign(:emails, filtered_emails)
     |> assign(:selected_emails, MapSet.new())}
  end

  @impl true
  def handle_event("bulk_delete", _, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected_emails)

    {:ok, count} = EmailManagement.bulk_delete_emails(selected_ids)
    emails = EmailManagement.list_emails_by_category(socket.assigns.category.id)

    {:noreply,
     socket
     |> assign(:emails, emails)
     |> assign(:selected_emails, MapSet.new())
     |> put_flash(:info, "Successfully deleted #{count} email(s)")}
  end

  @impl true
  def handle_event("bulk_unsubscribe", _, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected_emails)
    selected_emails = Enum.filter(socket.assigns.emails, &(&1.id in selected_ids))

    # Queue unsubscribe jobs for each selected email
    jobs_queued =
      Enum.reduce(selected_emails, 0, fn email, acc ->
        case Unsubscribe.queue_unsubscribe_job(email) do
          {:ok, _} -> acc + 1
          {:error, _} -> acc
        end
      end)

    {:noreply,
     socket
     |> assign(:selected_emails, MapSet.new())
     |> put_flash(:info, "Queued #{jobs_queued} unsubscribe job(s)")}
  end

  @impl true
  def handle_event("show_email", %{"id" => email_id}, socket) do
    email = EmailManagement.get_email_with_assoc(String.to_integer(email_id))

    {:noreply,
     socket
     |> assign(:selected_email, email)
     |> assign(:show_email_modal, true)}
  end

  @impl true
  def handle_event("close_email_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_email_modal, false)
     |> assign(:selected_email, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="container mx-auto px-4 py-8">
        <div class="max-w-7xl mx-auto">
          <!-- Header -->
          <div class="mb-6">
            <.link navigate={~p"/dashboard"} class="text-blue-600 hover:text-blue-800 mb-4 inline-block">
              ← Back to Dashboard
            </.link>
            <div class="flex items-center justify-between">
              <div>
                <h1 class="text-3xl font-bold text-gray-900"><%= @category.name %></h1>
                <p class="mt-2 text-gray-600"><%= @category.description || "No description" %></p>
              </div>
              
              <!-- Account Filter -->
              <%= if length(@google_accounts) > 0 do %>
                <div class="w-64">
                  <label for="account-filter" class="block text-sm font-medium text-gray-700 mb-2">
                    <%= if length(@google_accounts) > 1, do: "Switch Account", else: "Gmail Account" %>
                  </label>
                  <select
                    id="account-filter"
                    phx-change="filter_by_account"
                    name="account_id"
                    class="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
                  >
                    <%= for account <- @google_accounts do %>
                      <option value={account.id} selected={@selected_account_id == account.id}>
                        <%= account.email %>
                      </option>
                    <% end %>
                  </select>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Bulk Actions Bar -->
          <%= if MapSet.size(@selected_emails) > 0 do %>
            <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
              <div class="flex items-center justify-between">
                <div class="flex items-center space-x-4">
                  <span class="text-sm font-medium text-blue-900">
                    <%= MapSet.size(@selected_emails) %> email(s) selected
                  </span>
                  <button
                    phx-click="deselect_all"
                    class="text-sm text-blue-700 hover:text-blue-900"
                  >
                    Deselect all
                  </button>
                </div>
                <div class="flex space-x-3">
                  <button
                    phx-click="bulk_unsubscribe"
                    data-confirm="Are you sure you want to unsubscribe from the selected emails?"
                    class="px-4 py-2 bg-yellow-600 text-white text-sm font-medium rounded hover:bg-yellow-700"
                  >
                    Unsubscribe
                  </button>
                  <button
                    phx-click="bulk_delete"
                    data-confirm="Are you sure you want to delete the selected emails?"
                    class="px-4 py-2 bg-red-600 text-white text-sm font-medium rounded hover:bg-red-700"
                  >
                    Delete
                  </button>
                </div>
              </div>
            </div>
          <% end %>

          <!-- Email List -->
          <div class="bg-white rounded-lg shadow">
            <%= if @emails == [] do %>
              <div class="p-12 text-center">
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
                    d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"
                  />
                </svg>
                <h3 class="mt-2 text-sm font-medium text-gray-900">No emails yet</h3>
                <p class="mt-1 text-sm text-gray-500">
                  Emails will appear here once they're categorized
                </p>
              </div>
            <% else %>
              <div class="divide-y divide-gray-200">
                <div class="p-4 bg-gray-50 border-b border-gray-200">
                  <div class="flex items-center space-x-3">
                    <input
                      type="checkbox"
                      checked={MapSet.size(@selected_emails) == length(@emails)}
                      phx-click={if MapSet.size(@selected_emails) == length(@emails), do: "deselect_all", else: "select_all"}
                      class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                    />
                    <span class="text-sm font-medium text-gray-700">Select All</span>
                  </div>
                </div>

                <%= for email <- @emails do %>
                  <div class="p-4 hover:bg-gray-50 transition-colors">
                    <div class="flex items-start space-x-4">
                      <div class="flex-shrink-0 pt-1">
                        <input
                          type="checkbox"
                          checked={MapSet.member?(@selected_emails, email.id)}
                          phx-click="toggle_email"
                          phx-value-id={email.id}
                          class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                        />
                      </div>
                      <div
                        class="flex-1 min-w-0 cursor-pointer"
                        phx-click="show_email"
                        phx-value-id={email.id}
                      >
                        <div class="flex items-center justify-between mb-2">
                          <div class="flex items-center space-x-2">
                            <p class="text-sm font-medium text-gray-900 truncate">
                              <%= email.from_address %>
                            </p>
                            <%= if email.google_account do %>
                              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                                <%= email.google_account.email %>
                              </span>
                            <% end %>
                          </div>
                          <p class="text-xs text-gray-500 flex-shrink-0 ml-2">
                            <%= format_date(email.received_at) %>
                          </p>
                        </div>
                        <p class="text-sm font-semibold text-gray-800 mb-1 truncate">
                          <%= email.subject || "(No Subject)" %>
                        </p>
                        <p class="text-sm text-gray-600 line-clamp-2">
                          <%= email.ai_summary || "No summary available" %>
                        </p>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Email Detail Modal -->
      <%= if @show_email_modal && @selected_email do %>
        <div
          class="fixed z-10 inset-0 overflow-y-auto"
          phx-click="close_email_modal"
          phx-window-keydown="close_email_modal"
          phx-key="escape"
        >
          <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>
            <span class="hidden sm:inline-block sm:align-middle sm:h-screen">&#8203;</span>
            <div
              class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-3xl sm:w-full"
              phx-click-away="close_email_modal"
            >
              <div class="bg-white px-6 py-5">
                <div class="flex justify-between items-start mb-4">
                  <h3 class="text-xl font-semibold text-gray-900">
                    <%= @selected_email.subject || "(No Subject)" %>
                  </h3>
                  <button
                    phx-click="close_email_modal"
                    class="text-gray-400 hover:text-gray-500"
                  >
                    <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M6 18L18 6M6 6l12 12"
                      />
                    </svg>
                  </button>
                </div>
                <div class="mb-4 space-y-2">
                  <p class="text-sm text-gray-700">
                    <span class="font-medium">From:</span>
                    <%= @selected_email.from_address %>
                  </p>
                  <p class="text-sm text-gray-700">
                    <span class="font-medium">Date:</span>
                    <%= format_full_date(@selected_email.received_at) %>
                  </p>
                  <div class="bg-blue-50 p-3 rounded">
                    <p class="text-sm font-medium text-blue-900 mb-1">AI Summary:</p>
                    <p class="text-sm text-blue-800">
                      <%= @selected_email.ai_summary || "No summary available" %>
                    </p>
                  </div>
                </div>
                <div class="border-t border-gray-200 pt-4">
                  <p class="text-sm font-medium text-gray-900 mb-2">Email Content:</p>
                  <div class="prose prose-sm max-w-none overflow-auto max-h-96 text-gray-700">
                    <%= raw(format_email_content(@selected_email.content)) %>
                  </div>
                </div>
              </div>
              <div class="bg-gray-50 px-6 py-4">
                <button
                  phx-click="close_email_modal"
                  class="w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 sm:text-sm"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  defp format_full_date(datetime) do
    Calendar.strftime(datetime, "%A, %B %d, %Y at %I:%M %p")
  end

  defp format_email_content(nil), do: "<p class='text-gray-500'>No content available</p>"

  defp format_email_content(content) do
    # Basic HTML sanitization and formatting
    content
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> String.replace("\n", "<br>")
  end
end
