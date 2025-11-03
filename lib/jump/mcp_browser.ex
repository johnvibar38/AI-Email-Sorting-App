defmodule Jump.MCPBrowser do
  @moduledoc """
  Browser automation wrapper using ChromeRemoteInterface.
  Provides a clean interface for headless browser automation.
  """

  require Logger
  alias ChromeRemoteInterface.{Session, PageSession}

  @doc """
  Start a new browser session and navigate to a URL.
  Returns {:ok, page_session} or {:error, reason}
  """
  def navigate(url) do
    with {:ok, server} <- start_chrome_server(),
         {:ok, page} <- ChromeRemoteInterface.Session.new_page(server),
         :ok <- PageSession.navigate(page, url),
         :ok <- PageSession.await_page_load(page) do
      {:ok, %{server: server, page: page}}
    else
      error ->
        Logger.error("Browser navigation failed: #{inspect(error)}")
        {:error, :navigation_failed}
    end
  end

  @doc """
  Get the HTML content/snapshot of the current page.
  """
  def snapshot(%{page: page}) do
    case PageSession.evaluate(page, "document.documentElement.outerHTML") do
      {:ok, %{"result" => %{"value" => html}}} ->
        {:ok, html}

      error ->
        Logger.error("Browser snapshot failed: #{inspect(error)}")
        {:error, :snapshot_failed}
    end
  end

  def snapshot(_), do: {:error, :invalid_session}

  @doc """
  Click an element on the page using a CSS selector.
  """
  def click(%{element: _element, ref: selector}, %{page: page} = session) do
    js_code = """
    document.querySelector('#{escape_quotes(selector)}').click();
    """

    case PageSession.evaluate(page, js_code) do
      {:ok, _} ->
        {:ok, session}

      error ->
        Logger.error("Browser click failed: #{inspect(error)}")
        {:error, :click_failed}
    end
  end

  def click(_, _), do: {:error, :invalid_params}

  @doc """
  Fill a form on the page.
  """
  def fill_form(%{fields: fields}, %{page: page} = session) do
    results =
      Enum.map(fields, fn field ->
        fill_field(page, field)
      end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      {:ok, session}
    else
      {:error, :fill_form_failed}
    end
  end

  def fill_form(_, _), do: {:error, :invalid_params}

  @doc """
  Type text into an element.
  """
  def type(%{ref: selector, text: text}, %{page: page} = session) do
    js_code = """
    var el = document.querySelector('#{escape_quotes(selector)}');
    if (el) {
      el.value = '#{escape_quotes(text)}';
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    }
    """

    case PageSession.evaluate(page, js_code) do
      {:ok, _} ->
        {:ok, session}

      error ->
        Logger.error("Browser type failed: #{inspect(error)}")
        {:error, :type_failed}
    end
  end

  def type(_, _), do: {:error, :invalid_params}

  @doc """
  Close the browser session.
  """
  def close(%{server: server, page: page}) do
    try do
      PageSession.close(page)
      Session.stop(server)
      :ok
    rescue
      _ -> :ok
    end
  end

  def close(_), do: :ok

  # Private functions

  defp start_chrome_server do
    ChromeRemoteInterface.Session.start_link(
      headless: true,
      no_sandbox: true
    )
  end

  defp fill_field(page, %{ref: selector, value: value, type: type}) do
    js_code =
      case type do
        "checkbox" ->
          """
          var el = document.querySelector('#{escape_quotes(selector)}');
          if (el) { el.checked = #{value}; }
          """

        "radio" ->
          """
          var el = document.querySelector('#{escape_quotes(selector)}');
          if (el) { el.checked = true; }
          """

        _ ->
          """
          var el = document.querySelector('#{escape_quotes(selector)}');
          if (el) {
            el.value = '#{escape_quotes(to_string(value))}';
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
          }
          """
      end

    PageSession.evaluate(page, js_code)
  end

  defp escape_quotes(str) when is_binary(str) do
    str
    |> String.replace("'", "\\'")
    |> String.replace("\"", "\\\"")
  end

  defp escape_quotes(other), do: to_string(other)
end
