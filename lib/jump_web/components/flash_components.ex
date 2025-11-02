defmodule JumpWeb.FlashComponents do
  @moduledoc """
  Flash message components for displaying notifications.
  """
  use Phoenix.Component

  @doc """
  Renders flash messages with icons and proper styling.
  """
  attr :flash, :map, required: true
  attr :kind, :atom, required: true

  def flash_message(assigns) do
    ~H"""
    <%= if live_flash(@flash, @kind) do %>
      <div class={"fixed top-4 right-4 z-50 max-w-sm w-full shadow-lg rounded-lg pointer-events-auto #{flash_class(@kind)}"}>
        <div class="p-4">
          <div class="flex items-start">
            <div class="flex-shrink-0">
              <%= flash_icon(@kind) %>
            </div>
            <div class="ml-3 w-0 flex-1 pt-0.5">
              <p class="text-sm font-medium text-gray-900">
                <%= live_flash(@flash, @kind) %>
              </p>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp flash_class(:info), do: "bg-blue-50 border border-blue-200"
  defp flash_class(:error), do: "bg-red-50 border border-red-200"
  defp flash_class(_), do: "bg-gray-50 border border-gray-200"

  defp flash_icon(:info) do
    assigns = %{}

    ~H"""
    <svg
      class="h-6 w-6 text-blue-400"
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
    """
  end

  defp flash_icon(:error) do
    assigns = %{}

    ~H"""
    <svg
      class="h-6 w-6 text-red-400"
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
    """
  end
end

