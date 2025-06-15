# Restarting Phoenix App with New Ash Phoenix Project

## Overview

This document outlines the process for restarting the AI self-sustaining system Phoenix application using a fresh Ash Framework Phoenix project. This approach will provide a clean foundation while preserving the valuable OpenTelemetry data processing pipeline and system architecture.

## Current System Analysis

### Existing Valuable Components

**✅ Keep These Components:**
- OpenTelemetry data processing pipeline (`lib/self_sustaining/telemetry_pipeline/`)
- Reactor middleware and orchestration (`lib/self_sustaining/reactor_middleware/`)
- Agent coordination system (`.agent_coordination/`)
- N8N integration workflows (`lib/self_sustaining/n8n/`)
- System monitoring and telemetry (`lib/self_sustaining_web/controllers/otlp_controller.ex`)
- Configuration management (`config/`)
- Gherkin feature specifications (`features/`)

**🔄 Modernize These Components:**
- Phoenix application structure (outdated patterns)
- Database migrations and schemas (convert to Ash resources)
- LiveView components (upgrade to latest patterns)
- Authentication and authorization (implement with Ash Authentication)
- API endpoints (convert to Ash JSON API)

**❌ Replace These Components:**
- Manual Ecto schemas → Ash resources
- Custom CRUD operations → Ash actions
- Manual authorization → Ash policies
- Custom API controllers → Ash JSON API

## Migration Strategy

### Phase 1: Create New Ash Phoenix Project

```bash
# Create new Ash Phoenix project
mix phx.new ai_self_sustaining_system_v2 --live --ash
cd ai_self_sustaining_system_v2

# Add required dependencies
mix deps.get
```

### Phase 2: Core Ash Resources Setup

**Define Core Resources:**

1. **Agent Resource** (`lib/ai_self_sustaining_system_v2/coordination/agent.ex`)
```elixir
defmodule AiSelfSustainingSystemV2.Coordination.Agent do
  use Ash.Resource,
    domain: AiSelfSustainingSystemV2.Coordination,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "agents"
    repo AiSelfSustainingSystemV2.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :agent_id, :string, allow_nil?: false
    attribute :status, :atom, constraints: [one_of: [:active, :idle, :error]]
    attribute :capabilities, {:array, :string}
    attribute :last_heartbeat, :utc_datetime_usec
    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :register do
      accept [:agent_id, :capabilities]
      change set_attribute(:status, :active)
      change set_attribute(:last_heartbeat, &DateTime.utc_now/0)
    end
    
    update :heartbeat do
      change set_attribute(:last_heartbeat, &DateTime.utc_now/0)
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end
end
```

2. **Work Item Resource** (`lib/ai_self_sustaining_system_v2/coordination/work_item.ex`)
```elixir
defmodule AiSelfSustainingSystemV2.Coordination.WorkItem do
  use Ash.Resource,
    domain: AiSelfSustainingSystemV2.Coordination,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "work_items"
    repo AiSelfSustainingSystemV2.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :work_item_id, :string, allow_nil?: false
    attribute :work_type, :string, allow_nil?: false
    attribute :description, :string
    attribute :priority, :atom, constraints: [one_of: [:low, :medium, :high, :critical]]
    attribute :status, :atom, constraints: [one_of: [:pending, :claimed, :in_progress, :completed, :failed]]
    attribute :claimed_by, :uuid
    attribute :claimed_at, :utc_datetime_usec
    attribute :completed_at, :utc_datetime_usec
    attribute :payload, :map
    timestamps()
  end

  relationships do
    belongs_to :agent, AiSelfSustainingSystemV2.Coordination.Agent,
      attribute: :claimed_by
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :submit_work do
      accept [:work_type, :description, :priority, :payload]
      change set_attribute(:status, :pending)
      change set_attribute(:work_item_id, &generate_work_id/0)
    end
    
    update :claim_work do
      accept [:claimed_by]
      change set_attribute(:status, :claimed)
      change set_attribute(:claimed_at, &DateTime.utc_now/0)
    end
    
    update :complete_work do
      change set_attribute(:status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  defp generate_work_id do
    "work_#{System.system_time(:nanosecond)}"
  end
end
```

3. **Telemetry Event Resource** (`lib/ai_self_sustaining_system_v2/telemetry/telemetry_event.ex`)
```elixir
defmodule AiSelfSustainingSystemV2.Telemetry.TelemetryEvent do
  use Ash.Resource,
    domain: AiSelfSustainingSystemV2.Telemetry,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "telemetry_events"
    repo AiSelfSustainingSystemV2.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :event_name, {:array, :atom}, allow_nil?: false
    attribute :measurements, :map
    attribute :metadata, :map
    attribute :trace_id, :string
    attribute :span_id, :string
    attribute :source, :string
    attribute :processed_at, :utc_datetime_usec
    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :record_event do
      accept [:event_name, :measurements, :metadata, :trace_id, :span_id, :source]
      change set_attribute(:processed_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end
end
```

### Phase 3: Migrate Existing Components

**Step 1: Copy Telemetry Pipeline**
```bash
# Copy entire telemetry pipeline
cp -r ../phoenix_app/lib/self_sustaining/telemetry_pipeline lib/ai_self_sustaining_system_v2/telemetry_pipeline

# Update module names
find lib/ai_self_sustaining_system_v2/telemetry_pipeline -name "*.ex" -exec sed -i '' 's/SelfSustaining/AiSelfSustainingSystemV2/g' {} \;
```

**Step 2: Copy Reactor Components**
```bash
# Copy reactor middleware and steps
cp -r ../phoenix_app/lib/self_sustaining/reactor_middleware lib/ai_self_sustaining_system_v2/reactor_middleware
cp -r ../phoenix_app/lib/self_sustaining/reactor_steps lib/ai_self_sustaining_system_v2/reactor_steps

# Update module names
find lib/ai_self_sustaining_system_v2/reactor_middleware -name "*.ex" -exec sed -i '' 's/SelfSustaining/AiSelfSustainingSystemV2/g' {} \;
find lib/ai_self_sustaining_system_v2/reactor_steps -name "*.ex" -exec sed -i '' 's/SelfSustaining/AiSelfSustainingSystemV2/g' {} \;
```

**Step 3: Copy N8N Integration**
```bash
# Copy N8N components
cp -r ../phoenix_app/lib/self_sustaining/n8n lib/ai_self_sustaining_system_v2/n8n

# Update module names
find lib/ai_self_sustaining_system_v2/n8n -name "*.ex" -exec sed -i '' 's/SelfSustaining/AiSelfSustainingSystemV2/g' {} \;
```

### Phase 4: Update Configuration

**Update Application Configuration** (`config/config.exs`):
```elixir
import Config

# Ash Framework configuration
config :ai_self_sustaining_system_v2,
  ash_domains: [
    AiSelfSustainingSystemV2.Coordination,
    AiSelfSustainingSystemV2.Telemetry,
    AiSelfSustainingSystemV2.Workflows
  ]

# Database configuration with Ash
config :ai_self_sustaining_system_v2, AiSelfSustainingSystemV2.Repo,
  username: System.get_env("DATABASE_USERNAME", "postgres"),
  password: System.get_env("DATABASE_PASSWORD", "postgres"),
  hostname: System.get_env("DATABASE_HOST", "localhost"),
  database: System.get_env("DATABASE_NAME", "ai_self_sustaining_v2_dev"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: String.to_integer(System.get_env("DATABASE_POOL_SIZE", "10"))

# OpenTelemetry Pipeline configuration (preserved)
config :ai_self_sustaining_system_v2, :otlp_pipeline,
  max_concurrent_pipelines: String.to_integer(System.get_env("OTLP_MAX_CONCURRENT_PIPELINES", "5")),
  trace_sampling_rate: String.to_float(System.get_env("OTLP_TRACE_SAMPLING_RATE", "0.1")),
  jaeger_endpoint: System.get_env("JAEGER_ENDPOINT", "http://localhost:14268/api/traces"),
  prometheus_endpoint: System.get_env("PROMETHEUS_ENDPOINT", "http://localhost:9090/api/v1/write"),
  elasticsearch_endpoint: System.get_env("ELASTICSEARCH_ENDPOINT", "http://localhost:9200")

# Agent coordination configuration (preserved)
config :ai_self_sustaining_system_v2, :agent_coordination,
  heartbeat_interval_ms: String.to_integer(System.get_env("AGENT_HEARTBEAT_INTERVAL", "30000")),
  work_claim_timeout_ms: String.to_integer(System.get_env("WORK_CLAIM_TIMEOUT", "300000")),
  max_concurrent_work_items: String.to_integer(System.get_env("MAX_CONCURRENT_WORK", "10"))

# N8N integration configuration (preserved)  
config :ai_self_sustaining_system_v2, :n8n,
  api_url: System.get_env("N8N_API_URL", "http://localhost:5678/api/v1"),
  api_key: System.get_env("N8N_API_KEY"),
  webhook_url: System.get_env("N8N_WEBHOOK_URL", "http://localhost:4000/api/webhooks/n8n")

import_config "#{config_env()}.exs"
```

### Phase 5: Create Ash JSON API

**API Setup** (`lib/ai_self_sustaining_system_v2_web/router.ex`):
```elixir
defmodule AiSelfSustainingSystemV2Web.Router do
  use AiSelfSustainingSystemV2Web, :router
  use AshJsonApi.Router,
    domains: [
      AiSelfSustainingSystemV2.Coordination,
      AiSelfSustainingSystemV2.Telemetry
    ],
    open_api: "/open_api"

  pipeline :api do
    plug :accepts, ["json"]
    plug AshJsonApi.Plug
  end

  scope "/api/json" do
    pipe_through :api
    ash_json_api_routes()
  end

  # Preserve OTLP endpoints
  scope "/api/otlp" do
    pipe_through :api
    
    post "/v1/traces", OtlpController, :ingest_traces
    post "/v1/metrics", OtlpController, :ingest_metrics
    post "/v1/logs", OtlpController, :ingest_logs
    get "/pipeline/status", OtlpController, :pipeline_status
    get "/health", OtlpController, :health_check
  end

  # Agent coordination API
  scope "/api/coordination" do
    pipe_through :api
    
    post "/agents/register", CoordinationController, :register_agent
    put "/agents/:agent_id/heartbeat", CoordinationController, :heartbeat
    post "/work_items", CoordinationController, :submit_work
    put "/work_items/:work_id/claim", CoordinationController, :claim_work
    put "/work_items/:work_id/complete", CoordinationController, :complete_work
  end
end
```

### Phase 6: LiveView Integration

**Dashboard LiveView** (`lib/ai_self_sustaining_system_v2_web/live/dashboard_live.ex`):
```elixir
defmodule AiSelfSustainingSystemV2Web.DashboardLive do
  use AiSelfSustainingSystemV2Web, :live_view
  use AshPhoenix.LiveView

  alias AiSelfSustainingSystemV2.Coordination

  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(5000, self(), :update_metrics)
    end

    socket =
      socket
      |> assign(:agents, list_agents())
      |> assign(:work_items, list_work_items())
      |> assign(:telemetry_stats, get_telemetry_stats())

    {:ok, socket}
  end

  def handle_info(:update_metrics, socket) do
    socket =
      socket
      |> assign(:agents, list_agents())
      |> assign(:work_items, list_work_items())
      |> assign(:telemetry_stats, get_telemetry_stats())

    {:noreply, socket}
  end

  defp list_agents do
    Coordination.Agent
    |> Ash.Query.for_read(:read)
    |> Coordination.read!()
  end

  defp list_work_items do
    Coordination.WorkItem
    |> Ash.Query.for_read(:read)
    |> Ash.Query.limit(50)
    |> Coordination.read!()
  end

  defp get_telemetry_stats do
    # Implementation using Ash queries
    %{
      active_agents: length(list_agents()),
      pending_work: count_work_by_status(:pending),
      completed_work: count_work_by_status(:completed)
    }
  end
end
```

### Phase 7: Migration Scripts

**Database Migration Script** (`priv/repo/migrations/001_initial_ash_setup.exs`):
```elixir
defmodule AiSelfSustainingSystemV2.Repo.Migrations.InitialAshSetup do
  use Ecto.Migration

  def up do
    # Create agents table
    create table(:agents, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :agent_id, :string, null: false
      add :status, :string, null: false
      add :capabilities, {:array, :string}, default: []
      add :last_heartbeat, :utc_datetime_usec
      
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:agents, [:agent_id])

    # Create work_items table
    create table(:work_items, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :work_item_id, :string, null: false
      add :work_type, :string, null: false
      add :description, :text
      add :priority, :string, null: false
      add :status, :string, null: false
      add :claimed_by, references(:agents, type: :uuid, on_delete: :nilify_all)
      add :claimed_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :payload, :map, default: %{}
      
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:work_items, [:work_item_id])
    create index(:work_items, [:status])
    create index(:work_items, [:work_type])
    create index(:work_items, [:priority])

    # Create telemetry_events table
    create table(:telemetry_events, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :event_name, {:array, :string}, null: false
      add :measurements, :map, default: %{}
      add :metadata, :map, default: %{}
      add :trace_id, :string
      add :span_id, :string
      add :source, :string
      add :processed_at, :utc_datetime_usec
      
      timestamps(type: :utc_datetime_usec)
    end

    create index(:telemetry_events, [:trace_id])
    create index(:telemetry_events, [:source])
    create index(:telemetry_events, [:processed_at])
  end

  def down do
    drop table(:telemetry_events)
    drop table(:work_items)
    drop table(:agents)
  end
end
```

## Execution Plan

### Prerequisites
- [ ] Backup current system and database
- [ ] Install latest Elixir, Phoenix, and Ash Framework
- [ ] Prepare migration environment

### Implementation Steps

1. **Week 1: Foundation Setup**
   - [ ] Create new Ash Phoenix project
   - [ ] Define core Ash resources
   - [ ] Set up database migrations
   - [ ] Test basic CRUD operations

2. **Week 2: Component Migration**
   - [ ] Migrate telemetry pipeline
   - [ ] Migrate reactor components  
   - [ ] Migrate N8N integration
   - [ ] Update module references

3. **Week 3: API Integration**
   - [ ] Implement Ash JSON API endpoints
   - [ ] Create coordination controllers
   - [ ] Test API functionality
   - [ ] Set up authentication

4. **Week 4: LiveView & Testing**
   - [ ] Implement dashboard LiveView
   - [ ] Create monitoring interfaces
   - [ ] Comprehensive testing
   - [ ] Performance validation

5. **Week 5: Deployment**
   - [ ] Production configuration
   - [ ] Database migration
   - [ ] System cutover
   - [ ] Monitoring setup

## Benefits of Migration

### Technical Benefits
- **Modern Architecture**: Latest Ash Framework patterns
- **Declarative Resources**: Simplified CRUD operations
- **Built-in Authorization**: Ash policies for security
- **JSON API Standard**: Consistent API design
- **Type Safety**: Better compile-time guarantees

### Operational Benefits
- **Reduced Complexity**: Less boilerplate code
- **Better Testing**: Ash provides excellent testing tools
- **Documentation**: Auto-generated API documentation
- **Scalability**: Better handling of complex business logic

### Preserved Features
- **OpenTelemetry Pipeline**: Complete pipeline preservation
- **Agent Coordination**: Enhanced with Ash resources
- **N8N Integration**: Maintained functionality
- **Monitoring**: Improved with structured data

## Risk Mitigation

### Rollback Strategy
- Keep current system running during migration
- Parallel deployment approach
- Feature flags for gradual transition
- Database backup and restore procedures

### Testing Strategy
- Unit tests for all Ash resources
- Integration tests for API endpoints
- End-to-end tests for critical workflows
- Performance benchmarking

### Monitoring Strategy
- Health checks for all services
- Error tracking and alerting
- Performance monitoring
- Business metric tracking

## Conclusion

This migration to a new Ash Phoenix project will modernize the AI self-sustaining system while preserving all valuable components, particularly the comprehensive OpenTelemetry data processing pipeline. The result will be a more maintainable, scalable, and feature-rich system built on modern Elixir/Phoenix patterns.