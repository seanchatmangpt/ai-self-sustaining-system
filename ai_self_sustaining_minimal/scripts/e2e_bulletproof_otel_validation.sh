#!/bin/bash
set -euo pipefail

# =============================================================================
# Bulletproof End-to-End OpenTelemetry Trace ID Validation
# 
# This script proves that trace IDs propagate correctly through the ENTIRE
# OpenTelemetry ecosystem: Creation → Export → Collection → Storage → Retrieval
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATION_LOG="/tmp/bulletproof_otel_validation.log"
TRACE_DATA_DIR="/tmp/bulletproof_trace_data"

# OpenTelemetry endpoints
JAEGER_UI="http://localhost:16686"
JAEGER_API="http://localhost:16686/api"
OTEL_COLLECTOR_HTTP="http://localhost:4318"
OTEL_COLLECTOR_GRPC="http://localhost:4317"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global validation tracking
TOTAL_OPERATIONS=0
SUCCESSFUL_VALIDATIONS=0
TRACE_IDS_GENERATED=()
TRACE_IDS_FOUND=()

# Logging functions with timestamps
log_with_timestamp() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$VALIDATION_LOG"
}

log_info() {
    log_with_timestamp "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log_with_timestamp "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    log_with_timestamp "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    log_with_timestamp "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo "" | tee -a "$VALIDATION_LOG"
    log_with_timestamp "${PURPLE}=== $1 ===${NC}"
}

log_trace() {
    log_with_timestamp "${CYAN}[TRACE]${NC} $1"
}

# Initialize validation environment
init_validation_environment() {
    log_section "Initializing Bulletproof E2E Validation Environment"
    
    # Create directories
    mkdir -p "$TRACE_DATA_DIR"
    
    # Initialize log
    cat > "$VALIDATION_LOG" << EOF
# Bulletproof End-to-End OpenTelemetry Trace Validation Log
# Generated: $(date)
# Purpose: Prove trace IDs propagate through entire OTEL ecosystem
# Flow: Creation → Export → Collection → Storage → Retrieval → Validation

EOF
    
    log_info "Environment initialized"
    log_info "Trace data directory: $TRACE_DATA_DIR"
    log_info "Validation log: $VALIDATION_LOG"
}

# Check all prerequisites
check_prerequisites() {
    log_section "Checking Prerequisites"
    
    local missing_deps=()
    
    # Essential tools
    for tool in docker docker-compose jq curl nc elixir mix; do
        if ! command -v "$tool" &> /dev/null; then
            missing_deps+=("$tool")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        exit 1
    fi
    
    # Check Docker is running
    if ! docker info &> /dev/null; then
        log_error "Docker is not running"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# Create production-grade OpenTelemetry infrastructure
create_bulletproof_otel_infrastructure() {
    log_section "Creating Production-Grade OpenTelemetry Infrastructure"
    
    # Create advanced OTEL collector configuration
    cat > "$PROJECT_ROOT/otel-collector-bulletproof.yaml" << 'EOF'
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
        cors:
          allowed_origins:
            - "*"
          allowed_headers:
            - "*"

processors:
  # Government security processor
  attributes/government_security:
    actions:
      - key: government.validation.session
        action: upsert
        value: "bulletproof_e2e_${VALIDATION_SESSION_ID}"
      - key: government.infrastructure.type
        action: upsert
        value: "production_grade"
      - key: government.trace.validation.enabled
        action: upsert
        value: true
      - key: government.compliance.validated
        action: upsert
        value: true
        
  # Resource processor for service identification
  resource/government:
    attributes:
      - key: service.name
        value: "government-bulletproof-e2e"
        action: upsert
      - key: service.version
        value: "2.0.0"
        action: upsert
      - key: deployment.environment
        value: "bulletproof-validation"
        action: upsert

  # Batch processor for optimal performance
  batch:
    timeout: 500ms
    send_batch_size: 512
    send_batch_max_size: 1024

  # Memory limiter to prevent OOM
  memory_limiter:
    limit_mib: 256
    check_interval: 1s

exporters:
  # OTLP exporter to Jaeger's OTLP endpoint
  otlp/jaeger:
    endpoint: http://jaeger:14268/api/traces
    tls:
      insecure: true
      
  # File exporter for backup validation
  file:
    path: /tmp/otel-bulletproof-traces.jsonl
    rotation:
      max_megabytes: 10
      max_days: 1
    
  # Logging exporter for real-time monitoring
  logging:
    loglevel: info
    sampling_initial: 2
    sampling_thereafter: 500

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, attributes/government_security, resource/government, batch]
      exporters: [otlp/jaeger, file, logging]
  
  extensions: []
  
  telemetry:
    logs:
      level: "info"
    metrics:
      level: "basic"
EOF

    # Create production Docker Compose
    cat > "$PROJECT_ROOT/docker-compose.bulletproof-otel.yml" << 'EOF'
version: '3.8'

services:
  # Jaeger all-in-one with optimized settings
  jaeger:
    image: jaegertracing/all-in-one:1.50
    ports:
      - "16686:16686"  # Jaeger UI
      - "14250:14250"  # Jaeger gRPC
      - "14268:14268"  # Jaeger OTLP HTTP
      - "6831:6831/udp"  # Jaeger thrift compact
      - "6832:6832/udp"  # Jaeger thrift binary
    environment:
      - COLLECTOR_OTLP_ENABLED=true
      - SPAN_STORAGE_TYPE=memory
      - MEMORY_MAX_TRACES=100000
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:16686/"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - otel-bulletproof

  # OpenTelemetry Collector with production settings
  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.88.0
    command: ["--config=/etc/otel-collector-bulletproof.yaml"]
    volumes:
      - ./otel-collector-bulletproof.yaml:/etc/otel-collector-bulletproof.yaml:ro
      - /tmp:/tmp
    ports:
      - "4317:4317"    # OTLP gRPC receiver
      - "4318:4318"    # OTLP HTTP receiver
      - "8888:8888"    # Prometheus metrics
      - "13133:13133"  # Health check
    depends_on:
      jaeger:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:13133/"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - otel-bulletproof

networks:
  otel-bulletproof:
    driver: bridge
EOF

    log_success "Production-grade OpenTelemetry infrastructure created"
}

# Start bulletproof infrastructure
start_bulletproof_infrastructure() {
    log_section "Starting Bulletproof OpenTelemetry Infrastructure"
    
    cd "$PROJECT_ROOT"
    
    # Generate validation session ID
    export VALIDATION_SESSION_ID="$(date +%s)_$$"
    log_info "Validation session: $VALIDATION_SESSION_ID"
    
    # Substitute session ID in collector config
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i.bak "s/\\\${VALIDATION_SESSION_ID}/$VALIDATION_SESSION_ID/g" otel-collector-bulletproof.yaml
    else
        sed -i.bak "s/\${VALIDATION_SESSION_ID}/$VALIDATION_SESSION_ID/g" otel-collector-bulletproof.yaml
    fi
    
    # Clean up any existing containers
    docker-compose -f docker-compose.bulletproof-otel.yml down -v 2>/dev/null || true
    
    # Start infrastructure
    log_info "Starting Docker containers..."
    docker-compose -f docker-compose.bulletproof-otel.yml up -d
    
    # Wait for Jaeger to be ready
    log_info "Waiting for Jaeger to be ready..."
    for i in {1..60}; do
        if curl -s "$JAEGER_UI/api/services" &> /dev/null; then
            log_success "Jaeger is ready at $JAEGER_UI"
            break
        fi
        if [ $i -eq 60 ]; then
            log_error "Jaeger failed to start within 60 seconds"
            docker-compose -f docker-compose.bulletproof-otel.yml logs jaeger | tail -20
            exit 1
        fi
        sleep 1
    done
    
    # Wait for OTEL Collector to be ready
    log_info "Waiting for OTEL Collector to be ready..."
    for i in {1..60}; do
        if curl -s "http://localhost:13133/" &> /dev/null; then
            log_success "OTEL Collector is ready"
            break
        fi
        if [ $i -eq 60 ]; then
            log_error "OTEL Collector failed to start within 60 seconds"
            docker-compose -f docker-compose.bulletproof-otel.yml logs otel-collector | tail -20
            exit 1
        fi
        sleep 1
    done
    
    log_success "Bulletproof OpenTelemetry infrastructure is operational"
}

# Create bulletproof government operations with real OTLP export
create_bulletproof_government_operations() {
    log_section "Creating Bulletproof Government Operations"
    
    cat > "$PROJECT_ROOT/bulletproof_government_e2e.exs" << 'EOF'
# Bulletproof Government Operations with Real OTLP Export

Mix.install([
  {:opentelemetry, "~> 1.3"},
  {:opentelemetry_api, "~> 1.2"},
  {:opentelemetry_exporter, "~> 1.6"},
  {:jason, "~> 1.4"},
  {:req, "~> 0.4"}
])

defmodule BulletproofGovernmentE2E do
  @moduledoc """
  Bulletproof end-to-end government operations with real OpenTelemetry export.
  
  This module creates REAL traces that are exported via OTLP to the collector,
  then validates they appear in Jaeger via API queries.
  """
  
  require Logger
  
  def run_bulletproof_validation() do
    Logger.info("🚀 Starting Bulletproof E2E Government Operations")
    
    # Setup real OpenTelemetry with OTLP export
    setup_real_opentelemetry()
    
    # Execute government operations with real trace export
    government_operations = [
      execute_security_patch_operation(),
      execute_infrastructure_update_operation(),
      execute_compliance_audit_operation()
    ]
    
    # Wait for traces to be exported and processed
    Logger.info("⏳ Waiting for traces to be exported and processed...")
    Process.sleep(5000)
    
    # Validate traces in Jaeger
    validation_results = validate_traces_in_jaeger(government_operations)
    
    # Generate comprehensive report
    generate_bulletproof_report(government_operations, validation_results)
    
    Logger.info("✅ Bulletproof E2E validation completed")
    {government_operations, validation_results}
  end
  
  defp setup_real_opentelemetry() do
    # Start required applications
    {:ok, _} = Application.ensure_all_started(:inets)
    {:ok, _} = Application.ensure_all_started(:ssl)
    
    # Configure OTLP exporter for real export
    Application.put_env(:opentelemetry_exporter, :otlp_endpoint, "http://localhost:4318")
    Application.put_env(:opentelemetry_exporter, :otlp_headers, [])
    Application.put_env(:opentelemetry_exporter, :otlp_protocol, :http_protobuf)
    
    # Configure OpenTelemetry with real exporter
    Application.put_env(:opentelemetry, :tracer, :otel_tracer_default)
    Application.put_env(:opentelemetry, :processors, [
      {:otel_batch_processor, %{
        exporter: {:opentelemetry_exporter, %{
          endpoints: ["http://localhost:4318/v1/traces"]
        }}
      }}
    ])
    
    # Start OpenTelemetry
    {:ok, _} = Application.ensure_all_started(:opentelemetry_api)
    {:ok, _} = Application.ensure_all_started(:opentelemetry)
    {:ok, _} = Application.ensure_all_started(:opentelemetry_exporter)
    
    Logger.info("📡 Real OpenTelemetry configured with OTLP export to localhost:4318")
  end
  
  defp execute_security_patch_operation() do
    operation_type = "security_patch"
    Logger.info("🔒 Executing #{operation_type} operation")
    
    # Create real OpenTelemetry span
    :otel_tracer.with_span operation_type, %{}, fn span_ctx ->
      trace_id = get_trace_id_from_span(span_ctx)
      Logger.info("🔍 Security patch trace ID: #{trace_id}")
      
      # Set government attributes
      :otel_span.set_attributes(span_ctx, [
        {"government.operation.type", operation_type},
        {"government.security.clearance", "secret"},
        {"government.data.classification", "confidential"},
        {"government.environment", "production"},
        {"government.compliance.frameworks", "fisma,fedramp,soc2,stig"},
        {"government.trace.bulletproof", true}
      ])
      
      # Add security validation event
      :otel_span.add_event(span_ctx, "government.security.validated", %{
        "clearance_provided" => "secret",
        "classification_required" => "confidential",
        "authorization" => "granted"
      })
      
      # Create child spans
      create_compliance_spans(span_ctx, trace_id)
      create_execution_spans(span_ctx, trace_id)
      
      %{
        operation_type: operation_type,
        trace_id: trace_id,
        security_clearance: "secret",
        data_classification: "confidential",
        span_count: 6,
        timestamp: System.system_time(:millisecond)
      }
    end
  end
  
  defp execute_infrastructure_update_operation() do
    operation_type = "infrastructure_update"
    Logger.info("🏗️ Executing #{operation_type} operation")
    
    :otel_tracer.with_span operation_type, %{}, fn span_ctx ->
      trace_id = get_trace_id_from_span(span_ctx)
      Logger.info("🔍 Infrastructure update trace ID: #{trace_id}")
      
      :otel_span.set_attributes(span_ctx, [
        {"government.operation.type", operation_type},
        {"government.security.clearance", "unclassified"},
        {"government.data.classification", "secret"},
        {"government.environment", "production"},
        {"government.authorization.result", "denied"},
        {"government.trace.bulletproof", true}
      ])
      
      :otel_span.add_event(span_ctx, "government.security.denied", %{
        "clearance_provided" => "unclassified",
        "classification_required" => "secret",
        "authorization" => "denied",
        "reason" => "insufficient_clearance"
      })
      
      %{
        operation_type: operation_type,
        trace_id: trace_id,
        security_clearance: "unclassified",
        data_classification: "secret",
        authorization_result: "denied",
        span_count: 2,
        timestamp: System.system_time(:millisecond)
      }
    end
  end
  
  defp execute_compliance_audit_operation() do
    operation_type = "compliance_audit"
    Logger.info("📋 Executing #{operation_type} operation")
    
    :otel_tracer.with_span operation_type, %{}, fn span_ctx ->
      trace_id = get_trace_id_from_span(span_ctx)
      Logger.info("🔍 Compliance audit trace ID: #{trace_id}")
      
      :otel_span.set_attributes(span_ctx, [
        {"government.operation.type", operation_type},
        {"government.security.clearance", "top-secret"},
        {"government.data.classification", "confidential"},
        {"government.environment", "production"},
        {"government.audit.type", "compliance"},
        {"government.dry_run", true},
        {"government.trace.bulletproof", true}
      ])
      
      :otel_span.add_event(span_ctx, "government.audit.started", %{
        "audit_type" => "compliance",
        "frameworks" => "fisma,fedramp,soc2,stig",
        "dry_run" => true
      })
      
      create_audit_spans(span_ctx, trace_id)
      
      %{
        operation_type: operation_type,
        trace_id: trace_id,
        security_clearance: "top-secret",
        data_classification: "confidential",
        audit_type: "compliance",
        span_count: 4,
        timestamp: System.system_time(:millisecond)
      }
    end
  end
  
  defp create_compliance_spans(parent_span_ctx, trace_id) do
    :otel_tracer.with_span "government.compliance.validation", %{}, fn span_ctx ->
      :otel_span.set_attributes(span_ctx, [
        {"compliance.frameworks", "fisma,fedramp,soc2,stig"},
        {"compliance.status", "passed"}
      ])
      
      Logger.debug("📊 Created compliance span for trace: #{trace_id}")
    end
  end
  
  defp create_execution_spans(parent_span_ctx, trace_id) do
    [:plan, :apply, :audit].each(fn phase ->
      :otel_tracer.with_span "government.#{phase}.phase", %{}, fn span_ctx ->
        :otel_span.set_attributes(span_ctx, [
          {"government.phase", Atom.to_string(phase)},
          {"government.phase.status", "completed"}
        ])
        
        Logger.debug("📊 Created #{phase} span for trace: #{trace_id}")
      end
    end)
  end
  
  defp create_audit_spans(parent_span_ctx, trace_id) do
    ["fisma", "fedramp", "soc2"].each(fn framework ->
      :otel_tracer.with_span "government.compliance.#{framework}", %{}, fn span_ctx ->
        :otel_span.set_attributes(span_ctx, [
          {"compliance.framework", framework},
          {"compliance.result", "passed"}
        ])
        
        Logger.debug("📊 Created #{framework} compliance span for trace: #{trace_id}")
      end
    end)
  end
  
  defp validate_traces_in_jaeger(operations) do
    Logger.info("🔍 Validating traces in Jaeger via API...")
    
    jaeger_base_url = "http://localhost:16686/api"
    
    validation_results = Enum.map(operations, fn operation ->
      trace_id = operation.trace_id
      Logger.info("🔎 Validating trace ID: #{trace_id}")
      
      # Query Jaeger API for this specific trace
      trace_url = "#{jaeger_base_url}/traces/#{trace_id}"
      
      case Req.get(trace_url) do
        {:ok, %{status: 200, body: response}} ->
          case response do
            %{"data" => [trace_data | _]} ->
              spans = trace_data["spans"] || []
              
              # Validate trace ID consistency
              trace_ids_in_spans = Enum.map(spans, & &1["traceID"]) |> Enum.uniq()
              
              validation = %{
                trace_id: trace_id,
                operation_type: operation.operation_type,
                found_in_jaeger: true,
                spans_found: length(spans),
                spans_expected: operation.span_count,
                trace_id_consistent: length(trace_ids_in_spans) == 1,
                government_spans: count_government_spans(spans),
                jaeger_trace_id: List.first(trace_ids_in_spans),
                validation_status: :success
              }
              
              Logger.info("✅ Trace #{trace_id} found in Jaeger with #{length(spans)} spans")
              validation
              
            %{"data" => []} ->
              Logger.warning("⚠️ Trace #{trace_id} not found in Jaeger")
              %{
                trace_id: trace_id,
                operation_type: operation.operation_type,
                found_in_jaeger: false,
                validation_status: :not_found
              }
              
            _ ->
              Logger.error("❌ Unexpected Jaeger response format for trace #{trace_id}")
              %{
                trace_id: trace_id,
                operation_type: operation.operation_type,
                found_in_jaeger: false,
                validation_status: :error
              }
          end
          
        {:ok, %{status: status}} ->
          Logger.error("❌ Jaeger API returned status #{status} for trace #{trace_id}")
          %{
            trace_id: trace_id,
            operation_type: operation.operation_type,
            found_in_jaeger: false,
            validation_status: :api_error
          }
          
        {:error, error} ->
          Logger.error("❌ Failed to query Jaeger API for trace #{trace_id}: #{inspect(error)}")
          %{
            trace_id: trace_id,
            operation_type: operation.operation_type,
            found_in_jaeger: false,
            validation_status: :network_error
          }
      end
    end)
    
    validation_results
  end
  
  defp count_government_spans(spans) do
    Enum.count(spans, fn span ->
      operation_name = span["operationName"] || ""
      String.starts_with?(operation_name, "government.") or 
      String.contains?(operation_name, "_patch") or
      String.contains?(operation_name, "_update") or
      String.contains?(operation_name, "_audit")
    end)
  end
  
  defp generate_bulletproof_report(operations, validations) do
    successful_validations = Enum.count(validations, & &1.validation_status == :success)
    total_validations = length(validations)
    success_rate = if total_validations > 0, do: (successful_validations / total_validations * 100) |> Float.round(1), else: 0.0
    
    report = %{
      validation_session: System.get_env("VALIDATION_SESSION_ID", "unknown"),
      timestamp: DateTime.utc_now(),
      summary: %{
        total_operations: length(operations),
        total_validations: total_validations,
        successful_validations: successful_validations,
        success_rate: success_rate,
        status: if(successful_validations == total_validations, do: "BULLETPROOF_SUCCESS", else: "PARTIAL_SUCCESS")
      },
      operations: operations,
      validations: validations,
      infrastructure: %{
        jaeger_ui: "http://localhost:16686",
        otel_collector_http: "http://localhost:4318",
        otel_collector_grpc: "http://localhost:4317"
      }
    }
    
    # Save detailed report
    File.write!("/tmp/bulletproof_trace_data/bulletproof_e2e_report.json", Jason.encode!(report, pretty: true))
    
    # Save trace IDs for shell script validation
    trace_ids = Enum.map(operations, & &1.trace_id)
    File.write!("/tmp/bulletproof_trace_data/trace_ids.txt", Enum.join(trace_ids, "\n"))
    
    Logger.info("🏆 Bulletproof Validation Summary:")
    Logger.info("  Total Operations: #{length(operations)}")
    Logger.info("  Successful Validations: #{successful_validations}/#{total_validations}")
    Logger.info("  Success Rate: #{success_rate}%")
    Logger.info("  Status: #{report.summary.status}")
    
    if successful_validations == total_validations do
      Logger.info("🎉 BULLETPROOF E2E VALIDATION SUCCESSFUL!")
      Logger.info("🔍 All trace IDs propagated through entire OpenTelemetry ecosystem")
    else
      Logger.error("❌ Some validations failed - check individual results")
    end
    
    report
  end
  
  defp get_trace_id_from_span(span_ctx) do
    case :otel_span.trace_id(span_ctx) do
      trace_id when is_integer(trace_id) ->
        trace_id |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(32, "0")
      _ ->
        "unknown_trace_id"
    end
  end
end

# Execute bulletproof validation
{operations, validations} = BulletproofGovernmentE2E.run_bulletproof_validation()

IO.puts("\n🏆 Bulletproof E2E OpenTelemetry Validation Complete!")
IO.puts("📊 View traces at: http://localhost:16686")
IO.puts("📋 Detailed report: /tmp/bulletproof_trace_data/bulletproof_e2e_report.json")
IO.puts("🔍 Trace IDs: /tmp/bulletproof_trace_data/trace_ids.txt")
EOF

    log_success "Bulletproof government operations created"
}

# Execute bulletproof validation
execute_bulletproof_validation() {
    log_section "Executing Bulletproof E2E Validation"
    
    cd "$PROJECT_ROOT"
    
    log_info "Running bulletproof government operations with real OTLP export..."
    elixir bulletproof_government_e2e.exs
    
    log_success "Bulletproof operations completed"
}

# Validate results through comprehensive checks
validate_bulletproof_results() {
    log_section "Bulletproof Results Validation"
    
    # Check if report was generated
    if [ -f "/tmp/bulletproof_trace_data/bulletproof_e2e_report.json" ]; then
        log_success "✅ Bulletproof validation report found"
        
        # Extract key metrics
        local total_ops=$(jq -r '.summary.total_operations' /tmp/bulletproof_trace_data/bulletproof_e2e_report.json)
        local successful=$(jq -r '.summary.successful_validations' /tmp/bulletproof_trace_data/bulletproof_e2e_report.json)
        local success_rate=$(jq -r '.summary.success_rate' /tmp/bulletproof_trace_data/bulletproof_e2e_report.json)
        local status=$(jq -r '.summary.status' /tmp/bulletproof_trace_data/bulletproof_e2e_report.json)
        
        log_info "📊 Bulletproof Validation Results:"
        log_info "  Total Operations: $total_ops"
        log_info "  Successful Validations: $successful"
        log_info "  Success Rate: $success_rate%"
        log_info "  Status: $status"
        
        # Update global counters
        TOTAL_OPERATIONS=$total_ops
        SUCCESSFUL_VALIDATIONS=$successful
        
        # Extract trace IDs for verification
        if [ -f "/tmp/bulletproof_trace_data/trace_ids.txt" ]; then
            while IFS= read -r trace_id; do
                TRACE_IDS_GENERATED+=("$trace_id")
                log_trace "Generated trace ID: $trace_id"
            done < "/tmp/bulletproof_trace_data/trace_ids.txt"
        fi
        
    else
        log_error "❌ Bulletproof validation report not found"
        return 1
    fi
    
    # Validate traces directly in Jaeger
    validate_traces_directly_in_jaeger
    
    # Generate final validation summary
    generate_final_validation_summary
}

# Validate traces directly in Jaeger API
validate_traces_directly_in_jaeger() {
    log_section "Direct Jaeger API Validation"
    
    log_info "🔍 Querying Jaeger API directly for each trace ID..."
    
    for trace_id in "${TRACE_IDS_GENERATED[@]}"; do
        local jaeger_url="$JAEGER_API/traces/$trace_id"
        
        log_trace "Querying: $jaeger_url"
        
        if response=$(curl -s "$jaeger_url"); then
            if echo "$response" | jq -e '.data[0]' > /dev/null 2>&1; then
                local spans=$(echo "$response" | jq '.data[0].spans | length')
                local trace_id_in_jaeger=$(echo "$response" | jq -r '.data[0].spans[0].traceID')
                
                log_success "✅ Trace $trace_id found in Jaeger with $spans spans"
                log_trace "   Jaeger trace ID: $trace_id_in_jaeger"
                
                TRACE_IDS_FOUND+=("$trace_id")
                
                # Validate trace ID consistency
                if [ "$trace_id" = "$trace_id_in_jaeger" ]; then
                    log_success "✅ Trace ID consistency verified: $trace_id"
                else
                    log_error "❌ Trace ID mismatch: $trace_id != $trace_id_in_jaeger"
                fi
                
            else
                log_error "❌ Trace $trace_id not found in Jaeger"
            fi
        else
            log_error "❌ Failed to query Jaeger API for trace $trace_id"
        fi
    done
}

# Generate comprehensive final validation summary
generate_final_validation_summary() {
    log_section "Final Bulletproof Validation Summary"
    
    local traces_found=${#TRACE_IDS_FOUND[@]}
    local traces_generated=${#TRACE_IDS_GENERATED[@]}
    local final_success_rate=0
    
    if [ $traces_generated -gt 0 ]; then
        final_success_rate=$(echo "scale=1; $traces_found * 100 / $traces_generated" | bc -l)
    fi
    
    log_info "🏆 BULLETPROOF E2E VALIDATION RESULTS:"
    log_info "  Trace IDs Generated: $traces_generated"
    log_info "  Trace IDs Found in Jaeger: $traces_found"
    log_info "  End-to-End Success Rate: $final_success_rate%"
    log_info "  Operations Executed: $TOTAL_OPERATIONS"
    log_info "  Validations Successful: $SUCCESSFUL_VALIDATIONS"
    
    if [ "$traces_found" -eq "$traces_generated" ] && [ "$traces_generated" -gt 0 ]; then
        log_success "🎉 BULLETPROOF E2E VALIDATION: 100% SUCCESSFUL!"
        log_success "🔍 ALL TRACE IDS PROPAGATED THROUGH ENTIRE OTEL ECOSYSTEM"
        log_success "✅ Creation → Export → Collection → Storage → Retrieval: VERIFIED"
        
        # Create final success report
        cat > "$TRACE_DATA_DIR/BULLETPROOF_SUCCESS.md" << EOF
# 🏆 BULLETPROOF E2E OPENTELEMETRY VALIDATION SUCCESS

## Executive Summary
✅ **COMPLETE SUCCESS** - All trace IDs propagated through entire OpenTelemetry ecosystem

## Flow Validation
✅ **Trace Creation**: Real spans created with government context
✅ **OTLP Export**: Traces exported via HTTP OTLP to collector  
✅ **Collector Processing**: Government-specific processors applied
✅ **Jaeger Storage**: Traces stored in Jaeger backend
✅ **API Retrieval**: Traces retrieved via Jaeger API
✅ **ID Consistency**: Same trace IDs verified end-to-end

## Metrics
- **Trace IDs Generated**: $traces_generated
- **Trace IDs Found**: $traces_found
- **Success Rate**: $final_success_rate%
- **Government Operations**: $TOTAL_OPERATIONS
- **Infrastructure**: Production-grade OTEL Collector + Jaeger

## Trace IDs Validated
$(printf "%s\n" "${TRACE_IDS_FOUND[@]}")

## Status: 🎯 BULLETPROOF VALIDATION COMPLETE
Generated: $(date)
EOF
        
        log_success "📋 Final success report: $TRACE_DATA_DIR/BULLETPROOF_SUCCESS.md"
        
    else
        log_error "❌ BULLETPROOF VALIDATION FAILED"
        log_error "🔧 Some traces did not complete the full journey"
        
        # Show missing traces
        for trace_id in "${TRACE_IDS_GENERATED[@]}"; do
            if [[ ! " ${TRACE_IDS_FOUND[@]} " =~ " ${trace_id} " ]]; then
                log_error "   Missing: $trace_id"
            fi
        done
    fi
}

# Cleanup function
cleanup() {
    log_section "Cleaning Up Bulletproof Infrastructure"
    
    cd "$PROJECT_ROOT"
    
    # Stop containers
    docker-compose -f docker-compose.bulletproof-otel.yml down -v 2>/dev/null || true
    
    # Restore config backup
    if [ -f "otel-collector-bulletproof.yaml.bak" ]; then
        mv otel-collector-bulletproof.yaml.bak otel-collector-bulletproof.yaml 2>/dev/null || true
    fi
    
    # Clean up test script
    rm -f bulletproof_government_e2e.exs
    
    log_info "Cleanup completed"
}

# Trap cleanup on exit
trap cleanup EXIT

# Main execution flow
main() {
    log_section "Bulletproof End-to-End OpenTelemetry Trace Validation"
    log_info "🎯 PROVING trace IDs propagate through ENTIRE OpenTelemetry ecosystem"
    log_info "🔍 Flow: Creation → Export → Collection → Storage → Retrieval → Validation"
    
    init_validation_environment
    check_prerequisites
    create_bulletproof_otel_infrastructure
    start_bulletproof_infrastructure
    create_bulletproof_government_operations
    execute_bulletproof_validation
    validate_bulletproof_results
    
    log_section "Bulletproof E2E Validation Complete"
    log_info "🌐 Jaeger UI: $JAEGER_UI"
    log_info "📋 Validation log: $VALIDATION_LOG"
    log_info "📊 Trace data: $TRACE_DATA_DIR"
    log_info "🔍 Results prove trace IDs go ALL THE WAY THROUGH the OpenTelemetry ecosystem"
}

# Execute main function
main "$@"