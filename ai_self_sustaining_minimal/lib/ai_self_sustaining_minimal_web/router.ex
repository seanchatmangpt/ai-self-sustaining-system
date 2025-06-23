defmodule AiSelfSustainingMinimalWeb.Router do
  @moduledoc """
  Phoenix router for the minimal AI self-sustaining system.
  
  Provides a simplified routing structure focused on core coordination and telemetry
  functionality. This minimal version excludes complex features and focuses on
  the essential 20% of functionality that provides 80% of the value.
  
  ## Route Organization
  
  ### Browser Routes (`/`)
  - **Homepage**: Basic system status and navigation (`/`)
  - **Dashboard**: Minimal LiveView monitoring interface (`/dashboard`)
  
  ### OpenTelemetry Pipeline API (`/api/otlp`)
  Critical telemetry ingestion endpoints for distributed tracing:
  - **Traces**: `/api/otlp/v1/traces` - OpenTelemetry trace data ingestion
  - **Metrics**: `/api/otlp/v1/metrics` - Performance metrics collection
  - **Logs**: `/api/otlp/v1/logs` - System log aggregation
  - **Health**: `/api/otlp/health` - Pipeline health monitoring
  
  ### Agent Coordination API (`/api/coordination`)
  Core agent coordination functionality:
  - **Agent Management**: Registration, heartbeat, listing
  - **Work Management**: Submit, claim, start, complete work items
  
  ## Performance Characteristics
  
  This minimal router excludes features that contribute to information loss:
  - No complex Phoenix dashboard (reduces overhead)
  - Simplified API surface (reduces failure points)
  - Direct OTLP integration (preserves telemetry fidelity)
  
  ## Design Philosophy
  
  Follows 80/20 principle: maintains essential coordination and telemetry
  functionality while eliminating complexity theater that contributes to
  the measured 77.5% information loss in the full system.
  """
  
  use AiSelfSustainingMinimalWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AiSelfSustainingMinimalWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", AiSelfSustainingMinimalWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/dashboard", DashboardLive
  end

  # API endpoints
  scope "/api", AiSelfSustainingMinimalWeb do
    pipe_through :api

    # OpenTelemetry Data Pipeline API (preserve critical endpoints)
    scope "/otlp" do
      post "/v1/traces", OtlpController, :ingest_traces
      post "/v1/metrics", OtlpController, :ingest_metrics
      post "/v1/logs", OtlpController, :ingest_logs
      post "/v1/data", OtlpController, :ingest_otlp
      
      get "/pipeline/status", OtlpController, :pipeline_status
      get "/pipeline/statistics", OtlpController, :pipeline_statistics
      get "/health", OtlpController, :health_check
    end

    # Agent coordination API
    scope "/coordination" do
      post "/agents/register", CoordinationController, :register_agent
      put "/agents/:agent_id/heartbeat", CoordinationController, :heartbeat
      get "/agents", CoordinationController, :list_agents
      
      post "/work", CoordinationController, :submit_work
      put "/work/:work_id/claim", CoordinationController, :claim_work
      put "/work/:work_id/start", CoordinationController, :start_work
      put "/work/:work_id/complete", CoordinationController, :complete_work
      get "/work", CoordinationController, :list_work
    end
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:ai_self_sustaining_minimal, :dev_routes) do

    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
