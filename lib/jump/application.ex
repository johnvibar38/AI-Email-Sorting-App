defmodule Jump.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto Repo
      Jump.Repo,
      # Start the Vault for encryption
      Jump.Vault,
      # Start the Telemetry supervisor
      JumpWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Jump.PubSub},
      # Start Oban for background jobs
      {Oban, Application.fetch_env!(:jump, Oban)},
      # Start the Endpoint (http/https)
      JumpWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Jump.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    JumpWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

