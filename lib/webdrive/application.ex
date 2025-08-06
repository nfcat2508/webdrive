defmodule Webdrive.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      WebdriveWeb.Telemetry,
      # Start the Ecto repository
      Webdrive.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Webdrive.PubSub},
      # Start Finch
      {Finch, name: Webdrive.Finch},
      # Start the Endpoint (http/https)
      WebdriveWeb.Endpoint
      # Start a worker by calling: Webdrive.Worker.start_link(arg)
      # {Webdrive.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Webdrive.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WebdriveWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
