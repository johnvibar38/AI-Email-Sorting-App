defmodule JumpWeb.AccountEmailsLive.Show do
  use JumpWeb, :live_view

  alias Jump.EmailManagement
  alias Jump.Accounts

  on_mount {JumpWeb.UserAuth, :default}

  @impl true
  def mount(%{"id" => account_id}, _session, socket) do
    account = Accounts.get_google_account_by_id(String.to_integer(account_id))

    if account && account.user_id == socket.assigns.current_user.id do
      # Get categories with email counts for this specific account
      categories = EmailManagement.list_categories_with_counts_for_account(socket.assigns.current_user.id, account.id)

      # Get all emails for this account across all categories (filter by inbox status - subscribed only)
      emails = EmailManagement.list_emails_by_account(account.id)
               |> Enum.filter(& !&1.is_unsubscribed)

      {:ok,
       socket
       |> assign(:account, account)
       |> assign(:categories, categories)
       |> assign(:emails, emails)
       |> assign(:selected_category_id, nil)
       |> assign(:active_tab, :all)
       |> assign(:selected_emails, MapSet.new())
       |> assign(:show_email_modal, false)
       |> assign(:selected_email, nil)
       |> assign(:show_confirm_modal, false)
       |> assign(:confirm_action, nil)
       |> assign(:confirm_message, "")}
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
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    active_tab = String.to_existing_atom(tab)

    # Get filtered emails based on category and tab
    emails =
      get_filtered_emails(
        socket.assigns.account.id,
        socket.assigns.selected_category_id,
        active_tab
      )

    {:noreply,
     socket
     |> assign(:active_tab, active_tab)
     |> assign(:emails, emails)
     |> assign(:selected_emails, MapSet.new())}
  end

  @impl true
  def handle_event("filter_by_category", %{"category_id" => category_id}, socket) do
    category_id =
      if category_id == "all" do
        nil
      else
        String.to_integer(category_id)
      end

    # Get filtered emails based on category and active tab
    emails =
      get_filtered_emails(socket.assigns.account.id, category_id, socket.assigns.active_tab)

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

    # Refresh categories with updated counts
    categories = EmailManagement.list_categories_with_counts_for_account(socket.assigns.current_user.id, socket.assigns.account.id)

    # Refresh emails with current filters
    emails =
      get_filtered_emails(
        socket.assigns.account.id,
        socket.assigns.selected_category_id,
        socket.assigns.active_tab
      )

    {:noreply,
     socket
     |> assign(:categories, categories)
     |> assign(:emails, emails)
     |> assign(:selected_emails, MapSet.new())
     |> put_flash(:info, "#{count} email(s) deleted")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("unsubscribe_email", %{"id" => email_id}, socket) do
    email_id = String.to_integer(email_id)
    perform_unsubscribe_email(email_id, socket)
  end

  @impl true
  def handle_event("delete_email", %{"id" => email_id}, socket) do
    email_id = String.to_integer(email_id)
    email = EmailManagement.get_email!(email_id)

    if email.google_account_id == socket.assigns.account.id do
      case EmailManagement.delete_email(email) do
        {:ok, _deleted_email} ->
          # Refresh categories with updated counts
          categories = EmailManagement.list_categories_with_counts_for_account(socket.assigns.current_user.id, socket.assigns.account.id)

          # Refresh emails with current filters
          emails = get_filtered_emails(
            socket.assigns.account.id,
            socket.assigns.selected_category_id,
            socket.assigns.active_tab
          )

          {:noreply,
           socket
           |> assign(:categories, categories)
           |> assign(:emails, emails)
           |> assign(:selected_emails, MapSet.delete(socket.assigns.selected_emails, email_id))
           |> put_flash(:info, "Email deleted successfully")}

        {:error, _reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to delete email")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("bulk_unsubscribe", _, socket) do
    perform_bulk_unsubscribe(socket)
  end

  # Helper to perform bulk unsubscribe action
  defp perform_bulk_unsubscribe(socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected_emails)

    if selected_ids != [] do
      # Get the full email structs for selected IDs
      selected_emails =
        Enum.filter(socket.assigns.emails, fn email -> email.id in selected_ids end)

      # Move emails back to inbox and mark as unsubscribed
      Enum.each(selected_emails, fn email ->
        # Mark email as unsubscribed
        {:ok, _updated_email} = EmailManagement.update_email(email, %{is_unsubscribed: true})

        # Move email back to Gmail inbox
        Jump.Gmail.move_to_inbox(email.google_account, email.gmail_id)
      end)

      # Refresh categories with updated counts
      categories = EmailManagement.list_categories_with_counts_for_account(socket.assigns.current_user.id, socket.assigns.account.id)

      # Refresh emails with current filters
      emails =
        get_filtered_emails(
          socket.assigns.account.id,
          socket.assigns.selected_category_id,
          socket.assigns.active_tab
        )

      {:noreply,
       socket
       |> assign(:categories, categories)
       |> assign(:emails, emails)
       |> assign(:selected_emails, MapSet.new())
       |> put_flash(:info, "Successfully unsubscribed from #{length(selected_emails)} email(s)")}
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
  def handle_event("show_confirm_modal", %{"action" => action, "message" => message} = params, socket) do
    {:noreply,
     socket
     |> assign(:show_confirm_modal, true)
     |> assign(:confirm_action, action)
     |> assign(:confirm_message, message)
     |> assign(:confirm_params, Map.drop(params, ["action", "message"]))}
  end

  @impl true
  def handle_event("confirm_action", _, socket) do
    # Execute the stored action
    case socket.assigns.confirm_action do
      "unsubscribe_email" ->
        email_id = String.to_integer(socket.assigns.confirm_params["id"])
        perform_unsubscribe_email(email_id, socket
          |> assign(:show_confirm_modal, false)
          |> assign(:confirm_action, nil)
          |> assign(:confirm_message, "")
          |> assign(:confirm_params, %{}))

      "bulk_unsubscribe" ->
        perform_bulk_unsubscribe(socket
          |> assign(:show_confirm_modal, false)
          |> assign(:confirm_action, nil)
          |> assign(:confirm_message, "")
          |> assign(:confirm_params, %{}))

      _ ->
        {:noreply,
         socket
         |> assign(:show_confirm_modal, false)
         |> assign(:confirm_action, nil)
         |> assign(:confirm_message, "")
         |> assign(:confirm_params, %{})}
    end
  end

  @impl true
  def handle_event("cancel_confirm", _, socket) do
    {:noreply,
     socket
     |> assign(:show_confirm_modal, false)
     |> assign(:confirm_action, nil)
     |> assign(:confirm_message, "")
     |> assign(:confirm_params, %{})}
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
                    <%= for category_with_count <- @categories do %>
                      <% category = category_with_count.category %>
                      <% email_count = category_with_count.email_count %>
                      <button
                        phx-click="filter_by_category"
                        phx-value-category_id={category.id}
                        class={"w-full text-left px-3 py-2 rounded-md text-sm font-medium transition-colors #{if @selected_category_id == category.id, do: "bg-green-100 text-green-700", else: "text-gray-700 hover:bg-gray-100"}"}
                      >
                        <div class="flex items-center justify-between">
                          <div class="flex items-center space-x-2">
                            <span class="truncate"><%= category.name %></span>
                            <span class="inline-flex items-center px-1.5 py-0.5 rounded-full text-xs font-medium bg-gray-200 text-gray-800">
                              <%= email_count %>
                            </span>
                          </div>
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
          <!-- Tab Navigation -->
          <div class="mb-6">
            <div class="border-b border-gray-200">
              <nav class="-mb-px flex space-x-8" aria-label="Tabs">
                <button
                  phx-click="switch_tab"
                  phx-value-tab="all"
                  class={[
                    "whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm",
                    if(@active_tab == :all,
                      do: "border-blue-500 text-blue-600",
                      else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                    )
                  ]}
                >
                  <div class="flex items-center space-x-2">
                    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                      <path d="M2.003 5.884L10 9.882l7.997-3.998A2 2 0 0016 4H4a2 2 0 00-1.997 1.884z" />
                      <path d="M18 8.118l-8 4-8-4V14a2 2 0 002 2h12a2 2 0 002-2V8.118z" />
                    </svg>
                    <span>Inbox</span>
                  </div>
                </button>

                <button
                  phx-click="switch_tab"
                  phx-value-tab="unsubscribed"
                  class={[
                    "whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm",
                    if(@active_tab == :unsubscribed,
                      do: "border-green-500 text-green-600",
                      else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                    )
                  ]}
                >
                  <div class="flex items-center space-x-2">
                    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                    </svg>
                    <span>Unsubscribed</span>
                  </div>
                </button>
              </nav>
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
                  <button phx-click="deselect_all" class="text-sm text-blue-700 hover:text-blue-900">
                    Deselect all
                  </button>
                </div>
                <div class="flex space-x-3">
                  <%= if @active_tab == :all && can_unsubscribe_selected?(@selected_emails, @emails) do %>
                    <button
                      phx-click="show_confirm_modal"
                      phx-value-action="bulk_unsubscribe"
                      phx-value-message="Are you sure you want to unsubscribe from the selected emails?"
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
                            <!-- Individual Action Buttons -->
                            <div class="flex items-center space-x-1 ml-auto mr-4">
                              <%= if can_unsubscribe_email?(email) do %>
                                <button
                                  phx-click="show_confirm_modal"
                                  phx-value-action="unsubscribe_email"
                                  phx-value-message="Are you sure you want to unsubscribe from this email?"
                                  phx-value-id={email.id}
                                  class="inline-flex items-center px-2 py-1 text-xs font-medium text-yellow-700 bg-yellow-100 hover:bg-yellow-200 rounded transition-colors"
                                  title="Unsubscribe from this sender"
                                >
                                  <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                                  </svg>
                                  Unsubscribe
                                </button>
                              <% end %>
                              <button
                                phx-click="delete_email"
                                phx-value-id={email.id}
                                data-confirm="Are you sure you want to delete this email?"
                                class="inline-flex items-center px-2 py-1 text-xs font-medium text-red-700 bg-red-100 hover:bg-red-200 rounded transition-colors"
                                title="Delete this email"
                              >
                                <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                                  <path fill-rule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd" />
                                </svg>
                                Delete
                              </button>
                            </div>
                            <%= if email.category do %>
                              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">
                                <%= email.category.name %>
                              </span>
                            <% else %>
                              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800">
                                Uncategorized
                              </span>
                            <% end %>
                            <%= if email.is_unsubscribed do %>
                              <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800">
                                ✓ Unsubscribed
                              </span>
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

      <!-- Confirmation Modal -->
      <%= if @show_confirm_modal do %>
        <div class="fixed z-10 inset-0 overflow-y-auto" phx-click="cancel_confirm">
          <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>
            <span class="hidden sm:inline-block sm:align-middle sm:h-screen">&#8203;</span>
            <div
              class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full"
              phx-click-away="cancel_confirm"
            >
              <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                <div class="sm:flex sm:items-start">
                  <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-yellow-100 sm:mx-0 sm:h-10 sm:w-10">
                    <svg class="h-6 w-6 text-yellow-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z" />
                    </svg>
                  </div>
                  <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left">
                    <h3 class="text-lg leading-6 font-medium text-gray-900">
                      Confirm Action
                    </h3>
                    <div class="mt-2">
                      <p class="text-sm text-gray-500">
                        <%= @confirm_message %>
                      </p>
                    </div>
                  </div>
                </div>
              </div>
              <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
                <button
                  phx-click="confirm_action"
                  type="button"
                  class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-yellow-600 text-base font-medium text-white hover:bg-yellow-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-yellow-500 sm:ml-3 sm:w-auto sm:text-sm"
                >
                  Confirm
                </button>
                <button
                  phx-click="cancel_confirm"
                  type="button"
                  class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm"
                >
                  Cancel
                </button>
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

  # Helper to check if an individual email can be unsubscribed
  defp can_unsubscribe_email?(email) do
    !email.is_unsubscribed
  end

  # Helper to check if any selected emails can be unsubscribed
  defp can_unsubscribe_selected?(selected_email_ids, emails) do
    selected_email_ids
    |> MapSet.to_list()
    |> Enum.any?(fn email_id ->
      email = Enum.find(emails, &(&1.id == email_id))
      email && !email.is_unsubscribed
    end)
  end

  # Helper to perform unsubscribe action for a single email
  defp perform_unsubscribe_email(email_id, socket) do
    email = EmailManagement.get_email_with_assoc(email_id)

    if email && email.google_account_id == socket.assigns.account.id do
      # Move email back to Gmail inbox first
      Jump.Gmail.move_to_inbox(socket.assigns.account, email.gmail_id)

      # Mark as unsubscribed immediately
      {:ok, _updated_email} = EmailManagement.update_email(email, %{is_unsubscribed: true})

      # Refresh categories with updated counts
      categories = EmailManagement.list_categories_with_counts_for_account(socket.assigns.current_user.id, socket.assigns.account.id)

      # Refresh emails with current filters
      emails = get_filtered_emails(
        socket.assigns.account.id,
        socket.assigns.selected_category_id,
        socket.assigns.active_tab
      )

      {:noreply,
       socket
       |> assign(:categories, categories)
       |> assign(:emails, emails)
       |> put_flash(:info, "Successfully unsubscribed from #{email.from_address}")}
    else
      {:noreply, socket}
    end
  end

  # Helper to get filtered emails based on account, category, and tab
  defp get_filtered_emails(account_id, category_id, active_tab) do
    # First get emails by account and category
    emails =
      if category_id do
        EmailManagement.list_emails_by_category_and_account(category_id, account_id)
      else
        EmailManagement.list_emails_by_account(account_id)
      end

    # Then filter by tab
    case active_tab do
      :all ->
        # Show only subscribed emails in "All Emails" tab
        Enum.filter(emails, fn email ->
          !email.is_unsubscribed
        end)

      :unsubscribed ->
        # Show only unsubscribed emails in "Unsubscribed" tab
        Enum.filter(emails, fn email ->
          email.is_unsubscribed
        end)

      _ ->
        emails
    end
  end
end
