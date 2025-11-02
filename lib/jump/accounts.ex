defmodule Jump.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Jump.Repo
  alias Jump.Accounts.User
  alias Jump.Accounts.GoogleAccount

  @doc """
  Gets a single user.
  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets a single user or raises if not found.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets or creates a user from OAuth information.
  """
  def get_or_create_user_from_oauth(oauth_info) do
    case Repo.get_by(User, provider: oauth_info.provider, provider_id: oauth_info.provider_id) do
      nil ->
        # New user - create user and default categories
        case %User{}
             |> User.changeset(oauth_info)
             |> Repo.insert() do
          {:ok, user} ->
            # Create default categories for new user
            Jump.EmailManagement.create_default_categories(user.id)
            {:ok, user}

          error ->
            error
        end

      user ->
        # Existing user - just update info
        user
        |> User.changeset(oauth_info)
        |> Repo.update()
    end
  end

  @doc """
  Creates a user.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  # Google Account functions

  @doc """
  Gets a google account by email.
  """
  def get_google_account_by_email(email) do
    Repo.get_by(GoogleAccount, email: email)
  end

  @doc """
  Gets a google account by ID.
  """
  def get_google_account_by_id(id) do
    Repo.get(GoogleAccount, id)
  end

  @doc """
  Lists all google accounts for a user.
  """
  def list_google_accounts(user_id) do
    GoogleAccount
    |> where([g], g.user_id == ^user_id)
    |> Repo.all()
  end

  @doc """
  Creates or updates a google account with OAuth tokens.
  """
  def create_or_update_google_account(user_id, email, tokens) do
    # Check if THIS USER already has THIS email connected
    case Repo.get_by(GoogleAccount, user_id: user_id, email: email) do
      nil ->
        # New account for this user
        %GoogleAccount{}
        |> GoogleAccount.changeset(%{
          user_id: user_id,
          email: email,
          access_token: tokens.access_token,
          refresh_token: tokens.refresh_token,
          expires_at: tokens.expires_at
        })
        |> Repo.insert()

      account ->
        # Update existing account tokens
        account
        |> GoogleAccount.changeset(%{
          access_token: tokens.access_token,
          refresh_token: tokens.refresh_token,
          expires_at: tokens.expires_at
        })
        |> Repo.update()
    end
  end

  @doc """
  Updates a google account's sync information.
  """
  def update_google_account_sync(%GoogleAccount{} = account, attrs) do
    account
    |> GoogleAccount.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a google account.
  """
  def delete_google_account(%GoogleAccount{} = account) do
    Repo.delete(account)
  end
end
