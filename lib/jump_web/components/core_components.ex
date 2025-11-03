defmodule JumpWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  The components in this module use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn how to
  customize the generated components in this module.
  """

  use Phoenix.Component

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-click={JS.push("lv:clear-flash", value: %{key: :info})} flash={@flash} />
  """
  attr :id, :string, default: "flash-group", doc: "the id of flash container"
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :title, :string, default: nil
  slot :inner_block, doc: "the optional inner block that renders the flash title"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} phx-hook="Flash" class="bg-zinc-900 p-3">
      <div :if={@title} class="mb-2 text-sm font-semibold text-zinc-400">
        <%= @title %>
      </div>
      <div :for={{kind, msg} <- @flash} id={"flash-#{kind}"} class={[
        "alert",
        "alert-#{kind}",
        "rounded-lg p-3 shadow-sm"
      ]}>
        <div class="flex items-center gap-2">
          <span><%= msg %></span>
        </div>
      </div>
      <div :if={@inner_block} class="mt-2">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr :type, :string, default: "button"
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "phx-submit-loading:opacity-75 rounded-lg bg-zinc-900 px-3 py-2 text-sm font-semibold leading-6 text-white active:bg-zinc-700 hover:bg-zinc-700",
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders an input with label and error messages.

  A `%Phoenix.HTML.Form{}` and field name may be passed to the input
  to build input names and error messages, or all the attributes and
  errors may be passed explicitly.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
               range radio search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField, doc: "a form field struct retrieved from the form"
  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global,
    include: ~w(accept autocomplete cols disabled form list max maxlength min minlength
                                   pattern placeholder readonly required rows size step)

  slot :inner_block

  def input(assigns) do
    assigns =
      assigns
      |> assign_new(:field, fn
        %{field: %Phoenix.HTML.FormField{} = field} -> field
        _ -> nil
      end)
      |> assign_new(:errors, fn
        %{field: %Phoenix.HTML.FormField{} = field} ->
          translate_errors(field.errors)

        %{errors: errors} ->
          errors

        _ ->
          []
      end)
      |> assign_new(:id, fn
        %{field: %Phoenix.HTML.FormField{} = field} -> field.id
        %{id: id} -> id
        _ -> nil
      end)
      |> assign_new(:name, fn
        %{field: %Phoenix.HTML.FormField{} = field} -> field.name
        %{name: name} -> name
        _ -> nil
      end)
      |> assign_new(:value, fn
        %{field: %Phoenix.HTML.FormField{} = field} -> field.value
        %{value: value} -> value
        _ -> nil
      end)

    ~H"""
    <div phx-feedback-for={@name}>
      <.label :if={@label} for={@id}><%= @label %></.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        checked={@checked}
        class={[
          "mt-2 block w-full rounded-lg border-zinc-300 bg-white px-3 py-2 text-base text-zinc-800",
          "focus:border-zinc-400 focus:ring-zinc-400 focus:outline-none focus:ring-2 focus:ring-offset-2",
          @errors != [] && "border-red-500"
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-medium leading-6 text-zinc-900">
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-3 flex gap-3 text-sm leading-6 text-red-600 phx-no-feedback:hidden">
      <svg
        class="mt-0.5 h-5 w-5 flex-none fill-red-500"
        viewBox="0 0 20 20"
        aria-hidden="true"
      >
        <circle cx="10" cy="10" r="10" fill="currentColor" />
        <path
          fill-rule="evenodd"
          d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z"
          clip-rule="evenodd"
        />
      </svg>
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  defp translate_errors(errors) do
    for {msg, opts} <- errors do
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end
  end
end
