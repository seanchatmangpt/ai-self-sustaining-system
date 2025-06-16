#!/bin/bash
set -euo pipefail

# =============================================================================
# End-to-End OpenTelemetry Trace ID Propagation Validation
# 
# This script sets up real OpenTelemetry infrastructure and validates that
# trace IDs propagate correctly through government operations end-to-end.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATION_LOG="/tmp/e2e_otel_validation.log"
TRACE_RESULTS_DIR="/tmp/otel_trace_results"

# OpenTelemetry infrastructure endpoints
JAEGER_UI="http://localhost:16686"
JAEGER_API="http://localhost:16686/api"
OTEL_COLLECTOR_ENDPOINT="http://localhost:4317"
OTEL_COLLECTOR_HTTP="http://localhost:4318"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables for trace validation
EXPECTED_TRACE_IDS=()
GOVERNMENT_OPERATION_RESULTS=()
VALIDATION_SUCCESS_COUNT=0
VALIDATION_TOTAL_COUNT=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$VALIDATION_LOG"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$VALIDATION_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$VALIDATION_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$VALIDATION_LOG"
}

log_section() {
    echo -e "\n${PURPLE}=== $1 ===${NC}" | tee -a "$VALIDATION_LOG"
}

log_trace() {
    echo -e "${CYAN}[TRACE]${NC} $1" | tee -a "$VALIDATION_LOG"
}

# Initialize validation environment
init_validation_environment() {
    log_section "Initializing E2E OpenTelemetry Validation Environment"
    
    # Create results directory
    mkdir -p "$TRACE_RESULTS_DIR"
    
    # Initialize validation log
    cat > "$VALIDATION_LOG" << EOF
# End-to-End OpenTelemetry Trace ID Validation Log
# Generated: $(date)
# Purpose: Validate real trace ID propagation through government operations

EOF
    
    log_info "Validation environment initialized"
    log_info "Results directory: $TRACE_RESULTS_DIR"
    log_info "Validation log: $VALIDATION_LOG"
}

# Check prerequisites
check_prerequisites() {
    log_section "Checking Prerequisites"
    
    local missing_deps=()
    
    # Check essential tools
    for tool in docker docker-compose jq curl mix elixir bc nc; do
        if ! command -v "$tool" &> /dev/null; then
            missing_deps+=("$tool")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Please install missing dependencies and try again"
        exit 1
    fi
    
    # Check Docker is running
    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# Create Docker Compose configuration for OpenTelemetry infrastructure
create_otel_infrastructure() {
    log_section "Creating OpenTelemetry Infrastructure"
    
    # Create OTEL collector configuration
    cat > "$PROJECT_ROOT/otel-collector-config.yaml" << 'EOF'
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  # Government-specific processors
  attributes/government:
    actions:
      - key: government.deployment.environment
        action: upsert
        value: "e2e-validation"
      - key: government.validation.session
        action: upsert
        value: "${E2E_SESSION_ID}"
      - key: government.trace.validation
        action: upsert
        value: true
        
  resource/government:
    attributes:
      - key: service.name
        value: "government-claude-code-e2e"
        action: upsert
      - key: service.version
        value: "1.0.0"
        action: upsert

  # Batch processor for performance
  batch:
    timeout: 1s
    send_batch_size: 1024

exporters:
  # Jaeger exporter for visualization
  jaeger:
    endpoint: jaeger:14250
    tls:
      insecure: true
      
  # File exporter for validation
  file:
    path: /tmp/otel-traces.jsonl
    
  # Logging for debugging
  logging:
    loglevel: info

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [attributes/government, resource/government, batch]
      exporters: [jaeger, file, logging]
EOF

    # Create Docker Compose configuration
    cat > "$PROJECT_ROOT/docker-compose.e2e-otel.yml" << 'EOF'
version: '3.8'

services:
  # Jaeger all-in-one
  jaeger:
    image: jaegertracing/all-in-one:1.50
    ports:
      - "16686:16686"  # Jaeger UI
      - "14250:14250"  # Jaeger gRPC
    environment:
      - COLLECTOR_OTLP_ENABLED=true
    networks:
      - otel-network

  # OpenTelemetry Collector
  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.88.0
    command: ["--config=/etc/otel-collector-config.yaml"]
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml
      - /tmp:/tmp
    ports:
      - "4317:4317"    # OTLP gRPC receiver
      - "4318:4318"    # OTLP HTTP receiver
      - "8888:8888"    # Metrics endpoint
    depends_on:
      - jaeger
    networks:
      - otel-network

networks:
  otel-network:
    driver: bridge
EOF

    log_success "OpenTelemetry infrastructure configuration created"
}

# Start OpenTelemetry infrastructure
start_otel_infrastructure() {
    log_section "Starting OpenTelemetry Infrastructure"
    
    cd "$PROJECT_ROOT"
    
    # Generate unique session ID for this validation run
    export E2E_SESSION_ID="e2e_$(date +%s)"
    
    # Substitute session ID in collector config
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i.bak "s/\\\${E2E_SESSION_ID}/$E2E_SESSION_ID/g" otel-collector-config.yaml
    else
        sed -i.bak "s/\${E2E_SESSION_ID}/$E2E_SESSION_ID/g" otel-collector-config.yaml
    fi
    
    # Start infrastructure
    log_info "Starting Docker containers..."
    docker-compose -f docker-compose.e2e-otel.yml up -d
    
    # Wait for services to be ready
    log_info "Waiting for services to be ready..."
    
    # Wait for Jaeger
    for i in {1..30}; do
        if curl -s "$JAEGER_UI/api/services" &> /dev/null; then
            log_success "Jaeger UI is ready at $JAEGER_UI"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Jaeger failed to start within 30 seconds"
            exit 1
        fi
        sleep 1
    done
    
    # Wait for OTEL Collector
    for i in {1..60}; do
        # Check if collector is responding to health checks
        if curl -s "$OTEL_COLLECTOR_HTTP/v1/traces" -X POST -H "Content-Type: application/json" -d '{"traces":[]}' &> /dev/null; then
            log_success "OTEL Collector is ready at $OTEL_COLLECTOR_ENDPOINT"
            break
        fi
        # Alternative check - just see if the port is open
        if nc -z localhost 4317 &> /dev/null; then
            log_success "OTEL Collector is ready at $OTEL_COLLECTOR_ENDPOINT"
            break
        fi
        if [ $i -eq 60 ]; then
            log_error "OTEL Collector failed to start within 60 seconds"
            log_info "Checking OTEL Collector logs..."
            docker-compose -f docker-compose.e2e-otel.yml logs otel-collector | tail -20
            exit 1
        fi
        if [ $((i % 10)) -eq 0 ]; then
            log_info "Still waiting for OTEL Collector... (${i}s)"
        fi
        sleep 1
    done
    
    log_success "OpenTelemetry infrastructure is ready"
}

# Create instrumented government CLI with real OpenTelemetry
create_instrumented_government_cli() {
    log_section "Creating Instrumented Government CLI"
    
    cat > "$PROJECT_ROOT/lib/ai_self_sustaining_minimal/government/e2e_trace_cli.ex" << 'EOF'
defmodule AiSelfSustainingMinimal.Government.E2ETraceCli do
  @moduledoc """
  End-to-end OpenTelemetry instrumented government CLI for trace validation.
  
  This module creates real OpenTelemetry spans and validates trace ID propagation
  through government operations.
  """
  
  require OpenTelemetry.Tracer, as: Tracer
  require Logger
  
  @trace_validation_service "government-claude-code-e2e"
  
  def execute_government_operation(operation_type, opts \\ []) do
    # Start the root span for government operation using proper API
    span_name = "government.operation.#{operation_type}"
    
    ctx = :otel_ctx.new()
    span_ctx = :otel_tracer.start_span(ctx, span_name, %{})
    trace_id = get_trace_id_from_span_ctx(span_ctx)
    
    # Set as current span context
    :otel_ctx.attach(ctx)
    
    Logger.info("🔍 E2E Government Operation Started", trace_id: trace_id, operation: operation_type)
    
    try do
      # Set government-specific attributes
      :otel_span.set_attributes(span_ctx, [
        {"government.operation.type", operation_type},
        {"government.security.clearance", opts[:security_clearance] || "unclassified"},
        {"government.data.classification", opts[:data_classification] || "unclassified"},
        {"government.environment", opts[:environment] || "e2e-test"},
        {"government.compliance.frameworks", "fisma,fedramp,soc2,stig"},
        {"government.audit.required", true},
        {"government.trace.validation", true}
      ])
      
      :otel_span.add_event(span_ctx, "government.operation.started", %{
        "operation_type" => operation_type,
        "trace_id" => trace_id
      })
      
      try do
        # Execute security validation
        security_result = execute_security_validation(opts)
        
        case security_result do
          {:granted, context} ->
            Logger.info("🔐 Security Authorized", trace_id: trace_id, context: context)
            
            # Execute compliance validation
            compliance_result = execute_compliance_validation(operation_type)
            
            if compliance_result == :passed do
              Logger.info("✅ Compliance Validated", trace_id: trace_id)
              
              # Execute operation phases based on type
              if opts[:dry_run] do
                result = execute_plan_phase(operation_type, opts)
                Logger.info("📋 Plan Phase Completed", trace_id: trace_id, result: result)
              else
                plan_result = execute_plan_phase(operation_type, opts)
                apply_result = execute_apply_phase(operation_type, opts)
                audit_result = execute_audit_phase(operation_type, opts)
                
                Logger.info("🚀 Full Operation Completed", 
                  trace_id: trace_id, 
                  plan: plan_result, 
                  apply: apply_result, 
                  audit: audit_result
                )
              end
              
              Tracer.add_event("government.operation.completed", %{
                "result" => "success",
                "trace_id" => trace_id
              })
              
              {:success, trace_id}
            else
              Logger.warning("❌ Compliance Failed", trace_id: trace_id)
              Tracer.add_event("government.operation.failed", %{
                "reason" => "compliance_failure",
                "trace_id" => trace_id
              })
              
              {:error, trace_id, "compliance_failure"}
            end
            
          {:denied, reason} ->
            Logger.warning("🚫 Security Denied", trace_id: trace_id, reason: reason)
            Tracer.add_event("government.operation.failed", %{
              "reason" => "security_denied: #{reason}",
              "trace_id" => trace_id
            })
            
            {:error, trace_id, "security_denied"}
        end
      rescue
        error ->
          Logger.error("💥 Operation Failed", trace_id: trace_id, error: inspect(error))
          Tracer.add_event("government.operation.error", %{
            "error" => inspect(error),
            "trace_id" => trace_id
          })
          
          {:error, trace_id, "operation_error"}
      end
    end
  end
  
  defp execute_security_validation(opts) do
    Tracer.with_span "government.security.validation" do
      trace_id = get_current_trace_id()
      
      Tracer.set_attributes([
        {"security.clearance.provided", opts[:security_clearance] || "unclassified"},
        {"security.classification.required", opts[:data_classification] || "unclassified"}
      ])
      
      clearance_level = get_security_level(opts[:security_clearance] || "unclassified")
      required_level = get_security_level(opts[:data_classification] || "unclassified")
      
      if clearance_level >= required_level do
        Tracer.add_event("security.authorization.granted", %{
          "clearance" => opts[:security_clearance],
          "classification" => opts[:data_classification],
          "trace_id" => trace_id
        })
        
        {:granted, %{clearance: opts[:security_clearance], classification: opts[:data_classification]}}
      else
        Tracer.add_event("security.authorization.denied", %{
          "clearance" => opts[:security_clearance],
          "classification" => opts[:data_classification],
          "reason" => "insufficient_clearance",
          "trace_id" => trace_id
        })
        
        {:denied, "insufficient_clearance"}
      end
    end
  end
  
  defp execute_compliance_validation(operation_type) do
    Tracer.with_span "government.compliance.validation" do
      trace_id = get_current_trace_id()
      
      frameworks = ["fisma", "fedramp", "soc2", "stig"]
      
      Tracer.set_attributes([
        {"compliance.frameworks", Enum.join(frameworks, ",")},
        {"compliance.operation_type", operation_type}
      ])
      
      # Validate each framework in child spans
      framework_results = Enum.map(frameworks, fn framework ->
        Tracer.with_span "government.compliance.framework.#{framework}" do
          Tracer.set_attributes([
            {"compliance.framework", framework},
            {"compliance.operation_type", operation_type}
          ])
          
          # Simulate framework validation
          result = if :rand.uniform() > 0.1, do: :passed, else: :failed
          
          Tracer.add_event("compliance.framework.validated", %{
            "framework" => framework,
            "result" => Atom.to_string(result),
            "trace_id" => trace_id
          })
          
          result
        end
      end)
      
      overall_result = if Enum.all?(framework_results, &(&1 == :passed)), do: :passed, else: :failed
      
      Tracer.add_event("compliance.all_frameworks.validated", %{
        "result" => Atom.to_string(overall_result),
        "frameworks_passed" => Enum.count(framework_results, &(&1 == :passed)),
        "frameworks_total" => length(framework_results),
        "trace_id" => trace_id
      })
      
      overall_result
    end
  end
  
  defp execute_plan_phase(operation_type, opts) do
    Tracer.with_span "government.plan.phase" do
      trace_id = get_current_trace_id()
      
      Tracer.set_attributes([
        {"plan.operation_type", operation_type},
        {"plan.environment", opts[:environment] || "e2e-test"}
      ])
      
      # Simulate plan calculations
      Process.sleep(50)
      
      Tracer.add_event("plan.calculations.completed", %{
        "operation_type" => operation_type,
        "trace_id" => trace_id
      })
      
      :plan_completed
    end
  end
  
  defp execute_apply_phase(operation_type, _opts) do
    Tracer.with_span "government.apply.phase" do
      trace_id = get_current_trace_id()
      
      Tracer.set_attributes([
        {"apply.operation_type", operation_type}
      ])
      
      # Create rollback snapshot
      Tracer.with_span "government.rollback.snapshot" do
        Tracer.add_event("rollback.snapshot.created", %{
          "snapshot_id" => "snap_#{System.system_time(:millisecond)}",
          "trace_id" => trace_id
        })
      end
      
      # Apply changes
      Tracer.with_span "government.changes.application" do
        Process.sleep(100)
        
        Tracer.add_event("changes.applied.successfully", %{
          "operation_type" => operation_type,
          "trace_id" => trace_id
        })
      end
      
      Tracer.add_event("apply.phase.completed", %{
        "operation_type" => operation_type,
        "trace_id" => trace_id
      })
      
      :apply_completed
    end
  end
  
  defp execute_audit_phase(operation_type, _opts) do
    Tracer.with_span "government.audit.finalization" do
      trace_id = get_current_trace_id()
      
      Tracer.set_attributes([
        {"audit.operation_type", operation_type}
      ])
      
      # Generate audit trail
      Process.sleep(25)
      
      Tracer.add_event("audit.trail.finalized", %{
        "operation_type" => operation_type,
        "audit_id" => "audit_#{System.system_time(:millisecond)}",
        "trace_id" => trace_id
      })
      
      :audit_completed
    end
  end
  
  defp get_current_trace_id() do
    case :otel_tracer.current_span_ctx() do
      :undefined -> 
        "no_trace"
      span_ctx ->
        span_ctx
        |> :otel_span.trace_id()
        |> Integer.to_string(16)
        |> String.downcase()
        |> String.pad_leading(32, "0")
    end
  end
  
  defp get_security_level(clearance) do
    case clearance do
      "unclassified" -> 1
      "cui" -> 2
      "confidential" -> 3
      "secret" -> 4
      "top-secret" -> 5
      _ -> 1
    end
  end
end
EOF

    log_success "Instrumented government CLI created"
}

# Set up OpenTelemetry environment for Elixir
setup_otel_environment() {
    log_section "Setting Up OpenTelemetry Environment"
    
    # Set OpenTelemetry environment variables
    export OTEL_SERVICE_NAME="government-claude-code-e2e"
    export OTEL_SERVICE_VERSION="1.0.0"
    export OTEL_EXPORTER_OTLP_ENDPOINT="$OTEL_COLLECTOR_ENDPOINT"
    export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="$OTEL_COLLECTOR_ENDPOINT"
    export OTEL_RESOURCE_ATTRIBUTES="service.name=government-claude-code-e2e,deployment.environment=e2e-validation"
    export OTEL_SDK_DISABLED="false"
    
    log_info "OpenTelemetry environment configured:"
    log_info "  Service: $OTEL_SERVICE_NAME"
    log_info "  Endpoint: $OTEL_EXPORTER_OTLP_ENDPOINT"
    log_info "  Resource: $OTEL_RESOURCE_ATTRIBUTES"
}

# Execute government operations with real telemetry
execute_government_operations() {
    log_section "Executing Government Operations with Real Telemetry"
    
    cd "$PROJECT_ROOT"
    
    # Create test script for government operations
    cat > test_e2e_government_ops.exs << 'EOF'
# E2E Government Operations Test with Real OpenTelemetry

# Load OpenTelemetry dependencies
Mix.install([
  {:opentelemetry, "~> 1.3"},
  {:opentelemetry_api, "~> 1.2"},
  {:opentelemetry_exporter, "~> 1.6"},
  {:opentelemetry_semantic_conventions, "~> 0.2"},
  {:jason, "~> 1.4"}
])

# Configure OpenTelemetry with console/file output for validation
import OpenTelemetry.Tracer

# Start OpenTelemetry API
{:ok, _} = Application.ensure_all_started(:opentelemetry_api)

# Configure a simple tracer that logs to console for validation
:opentelemetry.set_default_tracer({:otel_tracer_default, []})

# Load our instrumented CLI
Code.compile_file("lib/ai_self_sustaining_minimal/government/e2e_trace_cli.ex")

alias AiSelfSustainingMinimal.Government.E2ETraceCli

IO.puts("🚀 Starting E2E Government Operations with Real OpenTelemetry")
IO.puts("=" |> String.duplicate(70))

# Test 1: Successful security patch operation
IO.puts("\n📋 Test 1: Successful Security Patch Operation")
{result1, trace_id1} = E2ETraceCli.execute_government_operation("security_patch", [
  security_clearance: "secret",
  data_classification: "confidential",
  environment: "e2e-validation"
])

IO.puts("Result: #{result1}")
IO.puts("Trace ID: #{trace_id1}")

# Wait for telemetry to be sent
Process.sleep(1000)

# Test 2: Unauthorized infrastructure update
IO.puts("\n❌ Test 2: Unauthorized Infrastructure Update") 
{result2, trace_id2} = E2ETraceCli.execute_government_operation("infrastructure_update", [
  security_clearance: "unclassified",
  data_classification: "secret",
  environment: "production"
])

IO.puts("Result: #{result2}")
IO.puts("Trace ID: #{trace_id2}")

# Wait for telemetry to be sent
Process.sleep(1000)

# Test 3: Plan-only compliance audit
IO.puts("\n📝 Test 3: Plan-Only Compliance Audit")
{result3, trace_id3} = E2ETraceCli.execute_government_operation("compliance_audit", [
  security_clearance: "top-secret",
  data_classification: "confidential",
  environment: "e2e-validation",
  dry_run: true
])

IO.puts("Result: #{result3}")
IO.puts("Trace ID: #{trace_id3}")

# Wait for telemetry to be sent
Process.sleep(2000)

# Write trace IDs to file for validation
trace_results = %{
  test_1: %{result: result1, trace_id: trace_id1, operation: "security_patch"},
  test_2: %{result: result2, trace_id: trace_id2, operation: "infrastructure_update"},
  test_3: %{result: result3, trace_id: trace_id3, operation: "compliance_audit"}
}

File.write!("/tmp/otel_trace_results/e2e_test_results.json", Jason.encode!(trace_results, pretty: true))

IO.puts("\n✅ E2E Government Operations completed")
IO.puts("📊 Trace IDs generated and sent to OpenTelemetry infrastructure")
IO.puts("🔍 Ready for trace validation...")
EOF

    log_info "Executing government operations..."
    elixir test_e2e_government_ops.exs
    
    # Cleanup test script
    rm test_e2e_government_ops.exs
    
    log_success "Government operations executed with real telemetry"
}

# Validate trace ID propagation through Jaeger API
validate_trace_propagation() {
    log_section "Validating Trace ID Propagation"
    
    # Wait for traces to be processed
    log_info "Waiting for traces to be processed by Jaeger..."
    sleep 5
    
    # Read test results
    if [ -f "$TRACE_RESULTS_DIR/e2e_test_results.json" ]; then
        log_info "Reading test results..."
        
        # Extract trace IDs from results
        local trace_ids=($(jq -r '.[] | .trace_id' "$TRACE_RESULTS_DIR/e2e_test_results.json"))
        
        for trace_id in "${trace_ids[@]}"; do
            if [ "$trace_id" != "no_trace" ] && [ "$trace_id" != "null" ]; then
                validate_single_trace "$trace_id"
            else
                log_warning "Skipping invalid trace ID: $trace_id"
            fi
        done
    else
        log_error "Test results file not found"
        return 1
    fi
    
    # Generate validation summary
    generate_validation_summary
}

# Validate a single trace ID through Jaeger API
validate_single_trace() {
    local trace_id="$1"
    log_info "Validating trace ID: $trace_id"
    
    VALIDATION_TOTAL_COUNT=$((VALIDATION_TOTAL_COUNT + 1))
    
    # Query Jaeger API for the trace
    local jaeger_response
    if jaeger_response=$(curl -s "$JAEGER_API/traces/$trace_id"); then
        
        # Check if trace was found
        if echo "$jaeger_response" | jq -e '.data[0]' > /dev/null 2>&1; then
            local trace_data
            trace_data=$(echo "$jaeger_response" | jq '.data[0]')
            
            # Extract spans from trace
            local spans
            spans=$(echo "$trace_data" | jq '.spans')
            local span_count
            span_count=$(echo "$spans" | jq 'length')
            
            log_trace "Found trace with $span_count spans"
            
            # Validate trace ID consistency across all spans
            local trace_ids_in_spans
            trace_ids_in_spans=$(echo "$spans" | jq -r '.[].traceID' | sort | uniq)
            local unique_trace_ids
            unique_trace_ids=$(echo "$trace_ids_in_spans" | wc -l)
            
            if [ "$unique_trace_ids" -eq 1 ]; then
                log_success "✅ Trace ID consistent across all $span_count spans"
                
                # Validate government-specific spans
                local government_spans
                government_spans=$(echo "$spans" | jq '[.[] | select(.operationName | startswith("government."))]')
                local government_span_count
                government_span_count=$(echo "$government_spans" | jq 'length')
                
                log_trace "Found $government_span_count government spans"
                
                # Validate span hierarchy
                local root_spans
                root_spans=$(echo "$spans" | jq '[.[] | select(.references | length == 0)]')
                local root_span_count
                root_span_count=$(echo "$root_spans" | jq 'length')
                
                if [ "$root_span_count" -eq 1 ]; then
                    log_success "✅ Valid span hierarchy (1 root span)"
                    
                    # Save detailed trace validation
                    echo "$trace_data" > "$TRACE_RESULTS_DIR/trace_${trace_id}_validation.json"
                    
                    VALIDATION_SUCCESS_COUNT=$((VALIDATION_SUCCESS_COUNT + 1))
                    
                    # Log span details
                    log_trace "Span breakdown:"
                    echo "$spans" | jq -r '.[] | "  • \(.operationName) (duration: \(.duration/1000)ms)"' | head -10 | while read -r line; do
                        log_trace "$line"
                    done
                    
                else
                    log_warning "⚠️ Invalid span hierarchy: $root_span_count root spans (expected 1)"
                fi
                
            else
                log_error "❌ Trace ID inconsistency: $unique_trace_ids different trace IDs found"
                log_trace "Trace IDs found: $trace_ids_in_spans"
            fi
            
        else
            log_error "❌ Trace not found in Jaeger: $trace_id"
        fi
        
    else
        log_error "❌ Failed to query Jaeger API for trace: $trace_id"
    fi
}

# Generate comprehensive validation summary
generate_validation_summary() {
    log_section "E2E Trace Validation Summary"
    
    local success_rate=0
    if [ "$VALIDATION_TOTAL_COUNT" -gt 0 ]; then
        success_rate=$(echo "scale=1; $VALIDATION_SUCCESS_COUNT * 100 / $VALIDATION_TOTAL_COUNT" | bc -l)
    fi
    
    log_info "Total Traces Validated: $VALIDATION_TOTAL_COUNT"
    log_info "Successful Validations: $VALIDATION_SUCCESS_COUNT"
    log_info "Success Rate: ${success_rate}%"
    
    if [ "$VALIDATION_SUCCESS_COUNT" -eq "$VALIDATION_TOTAL_COUNT" ] && [ "$VALIDATION_TOTAL_COUNT" -gt 0 ]; then
        log_success "🏆 ALL TRACE ID PROPAGATION VALIDATIONS PASSED!"
        log_success "✅ End-to-end OpenTelemetry trace validation successful"
        log_success "🔍 Trace IDs properly propagated through all government operations"
        
        # Generate final report
        cat > "$TRACE_RESULTS_DIR/e2e_validation_report.md" << EOF
# End-to-End OpenTelemetry Trace Validation Report

## Executive Summary
✅ **VALIDATION SUCCESSFUL** - All trace IDs properly propagated through government operations

## Metrics
- **Total Traces**: $VALIDATION_TOTAL_COUNT
- **Successful Validations**: $VALIDATION_SUCCESS_COUNT  
- **Success Rate**: ${success_rate}%
- **Infrastructure**: Jaeger + OTEL Collector
- **Service**: government-claude-code-e2e

## Validation Criteria
✅ Trace ID consistency across all spans
✅ Government operation spans created
✅ Valid span hierarchy (single root)
✅ Real OpenTelemetry infrastructure
✅ End-to-end trace propagation

## Access Points
- **Jaeger UI**: $JAEGER_UI
- **OTEL Collector**: $OTEL_COLLECTOR_ENDPOINT
- **Trace Results**: $TRACE_RESULTS_DIR

## Status: 🏆 E2E VALIDATION SUCCESSFUL
Generated: $(date)
EOF
        
        log_success "📋 Comprehensive validation report generated"
        
    else
        log_error "❌ E2E Trace validation failed"
        log_error "🔧 Check individual trace results for details"
    fi
}

# Cleanup function
cleanup() {
    log_section "Cleaning Up"
    
    cd "$PROJECT_ROOT"
    
    # Stop Docker containers
    log_info "Stopping OpenTelemetry infrastructure..."
    docker-compose -f docker-compose.e2e-otel.yml down -v || true
    
    # Restore collector config
    if [ -f "otel-collector-config.yaml.bak" ]; then
        mv otel-collector-config.yaml.bak otel-collector-config.yaml
    fi
    
    log_info "Cleanup completed"
}

# Trap cleanup on exit
trap cleanup EXIT

# Main execution flow
main() {
    log_section "End-to-End OpenTelemetry Trace ID Validation"
    log_info "Starting comprehensive E2E validation with real OpenTelemetry infrastructure"
    
    init_validation_environment
    check_prerequisites
    create_otel_infrastructure
    start_otel_infrastructure
    create_instrumented_government_cli
    setup_otel_environment
    execute_government_operations
    validate_trace_propagation
    
    log_section "E2E Validation Complete"
    log_info "🔍 Check results at: $TRACE_RESULTS_DIR"
    log_info "🌐 View traces at: $JAEGER_UI"
    log_info "📋 Validation log: $VALIDATION_LOG"
}

# Execute main function
main "$@"