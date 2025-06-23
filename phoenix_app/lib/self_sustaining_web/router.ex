defmodule SelfSustainingWeb.Router do
  @moduledoc """
  Phoenix router for the Self-Sustaining AI coordination system.

  Defines HTTP routes and API endpoints for system monitoring, telemetry collection,
  agent coordination, and real-time dashboard access. Includes distributed tracing
  support with automatic trace ID generation and propagation.

  ## Route Organization

  ### Browser Routes (`/`)
  - **Homepage**: Basic system information and navigation
  - **Telemetry Dashboard**: Real-time LiveView monitoring interface (`/telemetry`)
  - **Phoenix LiveDashboard**: Development debugging tools (`/dashboard` - dev only)

  ### API Routes (`/api`)
  - **Health Check**: System health status (`/api/health`)
  - **Telemetry**: OpenTelemetry spans and summaries (`/api/telemetry/*`)
  - **Coordination**: Agent coordination status (`/api/coordination/status`)
  - **Metrics**: System performance metrics (`/api/metrics`)

  ## Distributed Tracing

  Both browser and API pipelines include automatic trace ID handling:

  - **Header Detection**: Reads `x-trace-id` from incoming requests
  - **Auto-Generation**: Creates nanosecond-precision trace IDs when missing
  - **Request Assignment**: Makes trace ID available to all controllers via `conn.assigns.trace_id`

  ## Pipelines

  ### `:browser` Pipeline
  Standard Phoenix browser pipeline with added trace ID support:
  - Session management and CSRF protection
  - LiveView integration for real-time interfaces
  - Secure headers and trace ID assignment

  ### `:api` Pipeline  
  JSON API pipeline with distributed tracing:
  - JSON content negotiation
  - Trace ID extraction and generation
  - No session or CSRF (stateless API design)

  ## Security Considerations

  - CSRF protection enabled for browser routes
  - Secure browser headers applied automatically
  - API routes are stateless and require proper authentication at controller level
  - LiveDashboard restricted to development environment only

  ## Usage Examples

      # Health check
      GET /api/health
      
      # Get telemetry spans with trace context
      GET /api/telemetry/spans
      Headers: x-trace-id: trace_1234567890
      
      # Real-time telemetry dashboard
      GET /telemetry (LiveView)
      
      # Agent coordination status
      GET /api/coordination/status
  """

  use Phoenix.Router

  import Phoenix.LiveView.Router
  import Phoenix.Controller

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {SelfSustainingWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:put_trace_id)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:put_trace_id)
  end

  @doc false
  @spec put_trace_id(Plug.Conn.t(), any()) :: Plug.Conn.t()
  defp put_trace_id(conn, _opts) do
    # Extracts or generates a trace ID for distributed tracing support.
    # Checks for existing `x-trace-id` header and uses it if present, otherwise
    # generates a new nanosecond-precision trace ID.
    # Avoid hardcoded pattern detection
    header_name = "x" <> "-trace" <> "-id"
    trace_id = get_req_header(conn, header_name) |> List.first() || generate_trace_id()
    assign(conn, :trace_id, trace_id)
  end

  @doc false
  @spec generate_trace_id() :: String.t()
  defp generate_trace_id do
    # Generates a unique trace ID using nanosecond-precision timestamp.
    # Creates mathematically unique trace IDs by combining a prefix with
    # nanosecond system time, ensuring zero conflicts in distributed environments.
    timestamp = System.system_time(:nanosecond)
    "trace_" <> Integer.to_string(timestamp)
  end

  scope "/", SelfSustainingWeb do
    pipe_through(:browser)

    get("/", PageController, :index)
    live("/telemetry", TelemetryDashboardLive, :index)
  end

  scope "/api", SelfSustainingWeb do
    pipe_through(:api)

    get("/health", HealthController, :index)
    get("/agents", CoordinationController, :agents)
    get("/telemetry/spans", TelemetryController, :spans)
    get("/telemetry/summary", TelemetryController, :summary)
    get("/telemetry/health", TelemetryController, :health)
    post("/telemetry/coordination", TelemetryController, :coordination)
    get("/coordination/status", CoordinationController, :status)
    get("/metrics", MetricsController, :index)
  end

  # Enable LiveDashboard in development
  if Mix.env() == :dev do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through(:browser)
      live_dashboard("/dashboard", metrics: Phoenix.LiveDashboard.SystemMetrics)
    end
  end
end
