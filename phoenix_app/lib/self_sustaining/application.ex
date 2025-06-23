defmodule SelfSustaining.Application do
  @moduledoc """
  The SelfSustaining Application module for AI Self-Sustaining System.

  This application supervisor manages the comprehensive Phoenix application with:
  - Enhanced PromEx integration for coordination performance monitoring
  - OpenTelemetry distributed tracing
  - Reactor workflow orchestration
  - Agent coordination telemetry
  - Business intelligence metrics collection
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Core infrastructure
      SelfSustaining.Repo,
      {Phoenix.PubSub, name: SelfSustaining.PubSub},

      # Telemetry and monitoring
      SelfSustainingWeb.Telemetry,

      # PromEx comprehensive monitoring for coordination performance visibility 
      SelfSustaining.PromExMinimal,

      # Skip Ash Registry for now - will be added when Ash resources are properly configured

      # Background job processing - disabled temporarily until properly configured
      # {Oban, Application.fetch_env!(:self_sustaining, Oban)},

      # Web endpoint
      SelfSustainingWeb.Endpoint,

      # Additional services
      {SelfSustaining.AutonomousHealthMonitor, []},
      {SelfSustaining.AutonomousTraceOptimizer, []}
    ]

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
