defmodule SelfSustaining do
  @moduledoc """
  Main application module for the AI Self-Sustaining System.

  Provides the main application supervision tree with enhanced observability
  through PromEx integration, OpenTelemetry tracing, and agent coordination.

  ## Architecture

  The application follows a layered architecture:
  - **Web Layer**: Phoenix controllers and LiveViews with real-time capabilities
  - **Business Logic**: Ash domains and resources for AI coordination
  - **Workflow Layer**: Reactor-based workflows for AI operations
  - **Storage Layer**: PostgreSQL with Ecto for persistent data
  - **Observability**: OpenTelemetry + PromEx for comprehensive monitoring

  ## Supervision Tree

  The application starts the following supervisors:
  - `SelfSustaining.Repo` - Database connection pool
  - `SelfSustainingWeb.Endpoint` - Phoenix web server
  - `SelfSustaining.PromEx` - Prometheus metrics collection
  - `{Oban, Application.fetch_env!(:self_sustaining, Oban)}` - Background jobs
  - Various telemetry and monitoring processes

  ## Telemetry Integration

  All application components emit telemetry events that are captured by:
  - OpenTelemetry for distributed tracing
  - PromEx for Prometheus metrics
  - Agent coordination system for business intelligence

  ## Usage

  This module is automatically started by the Phoenix application framework.
  Individual components can be accessed via their respective modules.

      # Access coordination metrics
      SelfSustaining.PromEx.coordination_efficiency()

      # Record business metrics
      SelfSustaining.PromEx.record_coordination_metric(:work_completed, %{
        agent_id: "agent_123",
        work_type: "observability",
        business_value: 85
      })
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Database connection
      SelfSustaining.Repo,

      # Background job processing
      {Oban, Application.fetch_env!(:self_sustaining, Oban)},

      # Prometheus metrics (PromEx)
      SelfSustaining.PromEx,

      # Web endpoint
      SelfSustainingWeb.Endpoint,

      # Telemetry supervisor for observability
      SelfSustaining.TelemetrySupervisor
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
