defmodule JumpWeb.UserAuth do
  use JumpWeb, :controller

  import Plug.Conn
  import Phoenix.Controller

  alias Jump.Accounts

  # Make the remember me cookie valid for 60 days.
  @max_age 60 * 60 * 24 * 60
  @token_max_age @max_age

  def on_mount(:default, _params, session, socket) do
    socket =
      Phoenix.Component.assign_new(socket, :current_user, fn ->
        case session do
          %{"user_token" => user_token} ->
            case Phoenix.Token.verify(socket, "user socket", user_token, max_age: @token_max_age) do
              {:ok, user_id} -> Accounts.get_user(user_id)
              {:error, _} -> nil
            end

          _ ->
            nil
        end
      end)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        Phoenix.LiveView.put_flash(socket, :error, "You must be logged in to access this page")

      {:halt, Phoenix.LiveView.push_navigate(socket, to: ~p"/")}
    end
  end

  def on_mount(:allow_unauthenticated, _params, session, socket) do
    socket =
      Phoenix.Component.assign_new(socket, :current_user, fn ->
        case session do
          %{"user_token" => user_token} ->
            case Phoenix.Token.verify(socket, "user socket", user_token, max_age: @token_max_age) do
              {:ok, user_id} -> Accounts.get_user(user_id)
              {:error, _} -> nil
            end

          _ ->
            nil
        end
      end)

    {:cont, socket}
  end

  def fetch_current_user(conn, _opts) do
    user_token = get_session(conn, :user_token)

    user =
      if user_token do
        case Phoenix.Token.verify(conn, "user socket", user_token, max_age: @token_max_age) do
          {:ok, user_id} -> Accounts.get_user(user_id)
          {:error, _} -> nil
        end
      end

    assign(conn, :current_user, user)
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> Phoenix.Controller.redirect(to: ~p"/")
      |> halt()
    end
  end

  def log_in_user(conn, user) do
    token = Phoenix.Token.sign(conn, "user socket", user.id)

    conn
    |> renew_session()
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{user.id}")
  end

  def log_out_user(conn) do
    conn
    |> renew_session()
    |> delete_session(:user_token)
    |> delete_session(:live_socket_id)
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
