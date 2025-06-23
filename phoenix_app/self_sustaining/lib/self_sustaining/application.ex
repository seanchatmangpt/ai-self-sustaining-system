defmodule SelfSustaining.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Initialize OpenTelemetry
    OpentelemetryPhoenix.setup()
    
    children = [
      SelfSustainingWeb.Telemetry,
      SelfSustaining.Repo,
      {DNSCluster, query: Application.get_env(:self_sustaining, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SelfSustaining.PubSub},
      # Start PromEx for metrics collection
      SelfSustaining.PromEx,
      # Start a worker by calling: SelfSustaining.Worker.start_link(arg)
      # {SelfSustaining.Worker, arg},
      # Start to serve requests, typically the last entry
      SelfSustainingWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SelfSustaining.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SelfSustainingWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
