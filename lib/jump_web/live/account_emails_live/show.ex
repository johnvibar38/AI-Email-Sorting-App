defmodule JumpWeb.AccountEmailsLive.Show do
  use JumpWeb, :live_view

  alias Jump.EmailManagement
  alias Jump.Accounts
  alias Jump.Unsubscribe

  on_mount {JumpWeb.UserAuth, :default}

  @impl true
  def mount(%{"id" => account_id}, _session, socket) do
    account = Accounts.get_google_account_by_id(String.to_integer(account_id))

    if account && account.user_id == socket.assigns.current_user.id do
      # Get all categories for this user
      categories = EmailManagement.list_categories(socket.assigns.current_user.id)

      # Get all emails for this account across all categories
      emails = EmailManagement.list_emails_by_account(account.id)

      {:ok,
       socket
       |> assign(:account, account)
       |> assign(:categories, categories)
       |> assign(:emails, emails)
       |> assign(:selected_category_id, nil)
       |> assign(:selected_emails, MapSet.new())
       |> assign(:show_email_modal, false)
       |> assign(:selected_email, nil)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Account not found or unauthorized")
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
  def handle_event("filter_by_category", %{"category_id" => category_id}, socket) do
    category_id =
      if category_id == "all" do
        nil
      else
        String.to_integer(category_id)
      end

    # Get filtered emails
    emails =
      if category_id do
        EmailManagement.list_emails_by_category_and_account(
          category_id,
          socket.assigns.account.id
        )
      else
        EmailManagement.list_emails_by_account(socket.assigns.account.id)
      end

    {:noreply,
     socket
     |> assign(:selected_category_id, category_id)
     |> assign(:emails, emails)
     |> assign(:selected_emails, MapSet.new())}
  end

  @impl true
  def handle_event("bulk_delete", _, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected_emails)

    if selected_ids != [] do
      {:ok, count} = EmailManagement.bulk_delete_emails(selected_ids)

      # Refresh emails
      emails = EmailManagement.list_emails_by_account(socket.assigns.account.id)

      {:noreply,
       socket
       |> assign(:emails, emails)
       |> assign(:selected_emails, MapSet.new())
       |> put_flash(:info, "#{count} email(s) deleted")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("bulk_unsubscribe", _, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected_emails)

    if selected_ids != [] do
      # Get the full email structs for selected IDs
      selected_emails = Enum.filter(socket.assigns.emails, fn email -> email.id in selected_ids end)

      # Move emails back to inbox and schedule unsubscribe jobs
      {jobs_queued, skipped} =
        Enum.reduce(selected_emails, {0, 0}, fn email, {queued, skipped} ->
          # Move email back to Gmail inbox
          Jump.Gmail.move_to_inbox(email.google_account, email.gmail_id)

          # Queue unsubscribe job
          case Unsubscribe.queue_unsubscribe_job(email) do
            {:ok, _} -> {queued + 1, skipped}
            {:error, :no_url} -> {queued, skipped + 1}
            {:error, _} -> {queued, skipped}
          end
        end)

      message =
        cond do
          jobs_queued > 0 && skipped > 0 ->
            "Moved #{length(selected_emails)} email(s) to inbox. Queued #{jobs_queued} unsubscribe job(s). #{skipped} email(s) don't have unsubscribe links."

          jobs_queued > 0 ->
            "Moved #{jobs_queued} email(s) to inbox and queued unsubscribe jobs"

          skipped > 0 ->
            "Moved #{skipped} email(s) to inbox but they don't have unsubscribe links"

          true ->
            "No emails processed"
        end

      {:noreply,
       socket
       |> assign(:selected_emails, MapSet.new())
       |> put_flash(:info, message)}
    else
      {:noreply, socket}
    end
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
            <div class="flex items-center space-x-3">
              <div class="bg-blue-100 rounded-full p-3">
                <svg class="w-8 h-8 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M2.003 5.884L10 9.882l7.997-3.998A2 2 0 0016 4H4a2 2 0 00-1.997 1.884z" />
                  <path d="M18 8.118l-8 4-8-4V14a2 2 0 002 2h12a2 2 0 002-2V8.118z" />
                </svg>
              </div>
              <div>
                <h1 class="text-3xl font-bold text-gray-900"><%= @account.email %></h1>
                <p class="mt-1 text-gray-600">
                  <%= if @selected_category_id do %>
                    Showing emails from selected category
                  <% else %>
                    All emails from this account
                  <% end %>
                </p>
              </div>
            </div>
          </div>

          <!-- Main Content with Sidebar -->
          <div class="flex gap-6">
            <!-- Left Sidebar - Categories -->
            <div class="w-64 flex-shrink-0">
              <div class="bg-white rounded-lg shadow p-4 sticky top-4">
                <h2 class="text-lg font-semibold text-gray-900 mb-4">Categories</h2>
                <nav class="space-y-1">
                  <button
                    phx-click="filter_by_category"
                    phx-value-category_id="all"
                    class={"w-full text-left px-3 py-2 rounded-md text-sm font-medium transition-colors #{if @selected_category_id == nil, do: "bg-blue-100 text-blue-700", else: "text-gray-700 hover:bg-gray-100"}"}
                  >
                    <div class="flex items-center justify-between">
                      <span>All Emails</span>
                      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M2.003 5.884L10 9.882l7.997-3.998A2 2 0 0016 4H4a2 2 0 00-1.997 1.884z" />
                        <path d="M18 8.118l-8 4-8-4V14a2 2 0 002 2h12a2 2 0 002-2V8.118z" />
                      </svg>
                    </div>
                  </button>

                  <%= if @categories == [] do %>
                    <p class="text-sm text-gray-500 px-3 py-2">No categories yet</p>
                  <% else %>
                    <%= for category <- @categories do %>
                      <button
                        phx-click="filter_by_category"
                        phx-value-category_id={category.id}
                        class={"w-full text-left px-3 py-2 rounded-md text-sm font-medium transition-colors #{if @selected_category_id == category.id, do: "bg-green-100 text-green-700", else: "text-gray-700 hover:bg-gray-100"}"}
                      >
                        <div class="flex items-center justify-between">
                          <span class="truncate"><%= category.name %></span>
                          <svg class="w-4 h-4 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                            <path
                              fill-rule="evenodd"
                              d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"
                              clip-rule="evenodd"
                            />
                          </svg>
                        </div>
                      </button>
                    <% end %>
                  <% end %>
                </nav>
              </div>
            </div>

            <!-- Main Content Area -->
            <div class="flex-1">
          <!-- Bulk Actions Bar -->
          <%= if MapSet.size(@selected_emails) > 0 do %>
            <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
              <div class="flex items-center justify-between">
                <div class="flex items-center space-x-4">
                  <span class="text-sm font-medium text-blue-900">
                    <%= MapSet.size(@selected_emails) %> email(s) selected
                  </span>
                  <button phx-click="deselect_all" class="text-sm text-blue-700 hover:text-blue-900">
                    Deselect all
                  </button>
                </div>
                <div class="flex space-x-3">
                  <%= if can_unsubscribe_selected?(@selected_emails, @emails) do %>
                    <button
                      phx-click="bulk_unsubscribe"
                      data-confirm="Are you sure you want to unsubscribe from the selected emails?"
                      class="px-4 py-2 bg-yellow-600 text-white text-sm font-medium rounded hover:bg-yellow-700"
                    >
                      Unsubscribe
                    </button>
                  <% end %>
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
                  Emails will appear here once they're synced from Gmail
                </p>
              </div>
            <% else %>
              <div class="divide-y divide-gray-200">
                <div class="p-4 bg-gray-50 border-b border-gray-200">
                  <div class="flex items-center justify-between">
                    <div class="flex items-center space-x-3">
                      <input
                        type="checkbox"
                        checked={MapSet.size(@selected_emails) == length(@emails)}
                        phx-click={
                          if MapSet.size(@selected_emails) == length(@emails),
                            do: "deselect_all",
                            else: "select_all"
                        }
                        class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                      />
                      <span class="text-sm font-medium text-gray-700">Select All</span>
                    </div>
                    <span class="text-sm text-gray-600">
                      <%= length(@emails) %> <%= if length(@emails) == 1, do: "email", else: "emails" %>
                    </span>
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
                      <div class="flex-1 min-w-0 cursor-pointer" phx-click="show_email" phx-value-id={email.id}>
                        <div class="flex items-center justify-between mb-2">
                          <div class="flex items-center space-x-2">
                            <p class="text-sm font-medium text-gray-900 truncate">
                              <%= email.from_address %>
                            </p>
                            <%= if email.category do %>
                              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">
                                <%= email.category.name %>
                              </span>
                            <% else %>
                              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800">
                                Uncategorized
                              </span>
                            <% end %>
                            <%= case get_unsubscribe_status(email) do %>
                              <% "completed" -> %>
                                <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">
                                  ✓ Unsubscribed
                                </span>
                              <% "processing" -> %>
                                <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800">
                                  ⏳ Processing
                                </span>
                              <% "pending" -> %>
                                <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-yellow-100 text-yellow-800">
                                  ⏳ Pending
                                </span>
                              <% "failed" -> %>
                                <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800">
                                  ✗ Failed
                                </span>
                              <% _ -> %>
                            <% end %>
                          </div>
                          <p class="text-xs text-gray-500 flex-shrink-0 ml-2">
                            <%= format_date(email.received_at) %>
                          </p>
                        </div>
                        <p class="text-sm font-semibold text-gray-800 mb-1 truncate">
                          <%= email.subject %>
                        </p>
                        <%= if email.ai_summary do %>
                          <p class="text-sm text-gray-600 line-clamp-2"><%= email.ai_summary %></p>
                        <% else %>
                          <p class="text-sm text-gray-500 italic">No AI summary yet</p>
                        <% end %>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Email Detail Modal -->
      <%= if @show_email_modal && @selected_email do %>
        <div class="fixed z-10 inset-0 overflow-y-auto" phx-click="close_email_modal">
          <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>
            <span class="hidden sm:inline-block sm:align-middle sm:h-screen">&#8203;</span>
            <div
              class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-3xl sm:w-full"
              phx-click-away="close_email_modal"
            >
              <div class="bg-white px-4 pt-5 pb-4 sm:p-6">
                <div class="flex justify-between items-start mb-4">
                  <h3 class="text-lg leading-6 font-medium text-gray-900">
                    <%= @selected_email.subject %>
                  </h3>
                  <button
                    phx-click="close_email_modal"
                    class="text-gray-400 hover:text-gray-500 focus:outline-none"
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
                <div class="border-t border-gray-200 pt-4">
                  <dl class="space-y-3">
                    <div>
                      <dt class="text-sm font-medium text-gray-500">From</dt>
                      <dd class="mt-1 text-sm text-gray-900"><%= @selected_email.from_address %></dd>
                    </div>
                    <div>
                      <dt class="text-sm font-medium text-gray-500">Date</dt>
                      <dd class="mt-1 text-sm text-gray-900">
                        <%= format_date(@selected_email.received_at) %>
                      </dd>
                    </div>
                    <%= if @selected_email.category do %>
                      <div>
                        <dt class="text-sm font-medium text-gray-500">Category</dt>
                        <dd class="mt-1">
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                            <%= @selected_email.category.name %>
                          </span>
                        </dd>
                      </div>
                    <% end %>
                    <%= if @selected_email.ai_summary do %>
                      <div>
                        <dt class="text-sm font-medium text-gray-500">AI Summary</dt>
                        <dd class="mt-1 text-sm text-gray-900 bg-blue-50 p-3 rounded">
                          <%= @selected_email.ai_summary %>
                        </dd>
                      </div>
                    <% end %>
                    <div>
                      <dt class="text-sm font-medium text-gray-500 mb-2">Original Content</dt>
                      <dd class="mt-1 text-sm text-gray-900 bg-gray-50 p-4 rounded max-h-96 overflow-y-auto">
                        <%= if @selected_email.content do %>
                          <%= raw(format_email_content(@selected_email.content)) %>
                        <% else %>
                          <p class="text-gray-500">No content available</p>
                        <% end %>
                      </dd>
                    </div>
                  </dl>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_date(nil), do: "Unknown"

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  # Format email content - detect if HTML or plain text
  defp format_email_content(nil), do: "<p class='text-gray-500'>No content available</p>"

  defp format_email_content(content) when is_binary(content) do
    # Check if content looks like HTML
    if String.contains?(content, ["<html", "<HTML", "<!DOCTYPE", "<body", "<div", "<p>"]) do
      # It's HTML, return as-is
      content
    else
      # It's plain text, convert newlines to <br> and wrap in <p>
      content
      |> String.trim()
      |> String.replace(~r/\r\n|\r|\n/, "<br>")
      |> then(&"<p style='white-space: pre-wrap; word-wrap: break-word;'>#{&1}</p>")
    end
  end

  # Helper to get unsubscribe status for an email
  defp get_unsubscribe_status(email) do
    case email.unsubscribe_jobs do
      [] ->
        nil

      jobs ->
        # Get the most recent job
        latest_job = Enum.max_by(jobs, & &1.inserted_at)
        latest_job.status
    end
  end

  # Helper to check if any selected emails can be unsubscribed
  defp can_unsubscribe_selected?(selected_email_ids, emails) do
    selected_email_ids
    |> MapSet.to_list()
    |> Enum.any?(fn email_id ->
      email = Enum.find(emails, &(&1.id == email_id))
      email && get_unsubscribe_status(email) != "completed"
    end)
  end
end
