#!/bin/bash

##############################################################################
# Claude Code Headless Integration
##############################################################################
#
# DESCRIPTION:
#   High-performance headless Claude invocation for AI Swarm coordination
#   Provides streaming JSON I/O with OpenTelemetry tracing and error handling
#   Optimized for Engineering Elixir Applications observability patterns
#
# PERFORMANCE:
#   - Streaming JSON responses with timeout handling
#   - OpenTelemetry trace correlation for distributed coordination
#   - Fallback mechanisms for high availability
#   - Performance monitoring with telemetry emission
#
# USAGE:
#   ./claude_code_headless.sh analyze <input_file> <output_file> <prompt>
#   ./claude_code_headless.sh stream <data> <prompt>
#   ./claude_code_headless.sh health_check
#
##############################################################################

set -euo pipefail

# Configuration
CLAUDE_TIMEOUT=${CLAUDE_TIMEOUT:-30}
MAX_RETRIES=${MAX_RETRIES:-2}
TRACE_PREFIX="s2s.claude_headless"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  [CLAUDE-HEADLESS]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}✅ [CLAUDE-HEADLESS]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠️  [CLAUDE-HEADLESS]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}❌ [CLAUDE-HEADLESS]${NC} $*" >&2
}

# Create OpenTelemetry trace context
create_otel_context() {
    local operation="$1"
    echo "$(python3 -c "import secrets; print(secrets.token_hex(16))")"
}

# Emit telemetry for Claude operations
emit_telemetry() {
    local operation="$1"
    local status="$2"
    local duration_ms="$3"
    local trace_id="$4"
    
    local telemetry_data=$(cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "trace_id": "$trace_id",
  "span_id": "$(python3 -c "import secrets; print(secrets.token_hex(8))")",
  "operation_name": "${TRACE_PREFIX}.${operation}",
  "duration_ms": $duration_ms,
  "status": "$status",
  "attributes": {
    "claude.version": "headless_v1.0",
    "system.component": "agent_coordination",
    "observability.pattern": "engineering_elixir_applications"
  }
}
EOF
    )
    
    # Append to telemetry file if coordination directory exists
    if [ -d "$(dirname "$0")" ]; then
        echo "$telemetry_data" >> "$(dirname "$0")/telemetry_spans.jsonl"
    fi
}

# Health check for Claude CLI availability and functionality
claude_health_check() {
    local trace_id=$(create_otel_context "health_check")
    local start_time=$(python3 -c "import time; print(int(time.time() * 1000))")
    
    log_info "Performing Claude CLI health check..."
    
    if ! command -v claude >/dev/null 2>&1; then
        log_error "Claude CLI not found in PATH"
        return 1
    fi
    
    # Test with simple prompt
    local test_response
    if test_response=$(echo '{"test": "health check"}' | timeout 10s claude --input-format json --output-format json --prompt "Return exactly: {\"status\": \"healthy\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" 2>/dev/null); then
        local end_time=$(python3 -c "import time; print(int(time.time() * 1000))")
        local duration=$((end_time - start_time))
        
        # Validate JSON response
        if echo "$test_response" | jq . >/dev/null 2>&1; then
            log_success "Claude CLI health check passed (${duration}ms)"
            emit_telemetry "health_check" "ok" "$duration" "$trace_id"
            return 0
        else
            log_error "Claude CLI returned invalid JSON"
            emit_telemetry "health_check" "invalid_json" "$duration" "$trace_id"
            return 1
        fi
    else
        local end_time=$(python3 -c "import time; print(int(time.time() * 1000))")
        local duration=$((end_time - start_time))
        log_error "Claude CLI health check failed"
        emit_telemetry "health_check" "failed" "$duration" "$trace_id"
        return 1
    fi
}

# Streaming JSON analysis with retry logic and performance monitoring
claude_stream_analyze() {
    local input_data="$1"
    local prompt="$2"
    local trace_id=$(create_otel_context "stream_analyze")
    local start_time=$(python3 -c "import time; print(int(time.time() * 1000))")
    
    log_info "Starting Claude streaming analysis (Trace: $trace_id)"
    
    local attempt=1
    local max_attempts=$((MAX_RETRIES + 1))
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Attempt $attempt/$max_attempts"
        
        local temp_input="/tmp/claude_input_${trace_id}_${attempt}.json"
        local temp_output="/tmp/claude_output_${trace_id}_${attempt}.json"
        
        # Write input data to temp file
        echo "$input_data" > "$temp_input"
        
        # Execute Claude with timeout and error handling
        if timeout "${CLAUDE_TIMEOUT}s" claude \
            --input-format json \
            --output-format json \
            --prompt "$prompt" \
            < "$temp_input" \
            > "$temp_output" 2>/dev/null; then
            
            # Validate output
            if [ -s "$temp_output" ] && jq . "$temp_output" >/dev/null 2>&1; then
                local end_time=$(python3 -c "import time; print(int(time.time() * 1000))")
                local duration=$((end_time - start_time))
                
                log_success "Claude analysis completed successfully (${duration}ms, attempt $attempt)"
                
                # Output the result
                cat "$temp_output"
                
                # Clean up
                rm -f "$temp_input" "$temp_output"
                
                # Emit success telemetry
                emit_telemetry "stream_analyze" "success" "$duration" "$trace_id"
                return 0
            else
                log_warning "Attempt $attempt: Invalid or empty JSON response"
            fi
        else
            log_warning "Attempt $attempt: Claude execution failed or timed out"
        fi
        
        # Clean up failed attempt
        rm -f "$temp_input" "$temp_output"
        
        attempt=$((attempt + 1))
        
        # Exponential backoff for retries
        if [ $attempt -le $max_attempts ]; then
            local delay=$((2 ** (attempt - 1)))
            log_info "Retrying in ${delay}s..."
            sleep "$delay"
        fi
    done
    
    # All attempts failed
    local end_time=$(python3 -c "import time; print(int(time.time() * 1000))")
    local duration=$((end_time - start_time))
    
    log_error "All Claude attempts failed after $max_attempts tries"
    emit_telemetry "stream_analyze" "failed" "$duration" "$trace_id"
    return 1
}

# File-based analysis with input/output file management
claude_file_analyze() {
    local input_file="$1"
    local output_file="$2"
    local prompt="$3"
    local trace_id=$(create_otel_context "file_analyze")
    
    log_info "Starting Claude file analysis (Trace: $trace_id)"
    
    if [ ! -f "$input_file" ]; then
        log_error "Input file does not exist: $input_file"
        return 1
    fi
    
    # Read input data
    local input_data
    if ! input_data=$(cat "$input_file"); then
        log_error "Failed to read input file: $input_file"
        return 1
    fi
    
    # Perform streaming analysis
    local result
    if result=$(claude_stream_analyze "$input_data" "$prompt"); then
        # Write result to output file
        echo "$result" > "$output_file"
        log_success "Analysis result written to: $output_file"
        return 0
    else
        log_error "Analysis failed"
        return 1
    fi
}

# Engineering Elixir Applications inspired fallback analysis
engineering_fallback() {
    local trace_id=$(create_otel_context "engineering_fallback")
    local start_time=$(python3 -c "import time; print(int(time.time() * 1000))")
    
    log_warning "Using Engineering Elixir Applications fallback analysis"
    
    local fallback_analysis=$(cat <<'EOF'
{
  "analysis_type": "engineering_elixir_fallback",
  "source": "Engineering Elixir Applications patterns",
  "recommendations": [
    {
      "work_type": "observability_infrastructure",
      "priority_score": 95,
      "reasoning": "Critical: Need comprehensive monitoring for coordination performance with Promex + Grafana",
      "recommended_action": "implement_promex_grafana",
      "observability_focus": "custom_metrics_collection"
    },
    {
      "work_type": "distributed_tracing",
      "priority_score": 90,
      "reasoning": "Essential: Trace correlation across agent coordination boundaries with OpenTelemetry",
      "recommended_action": "enhance_opentelemetry",
      "observability_focus": "trace_propagation"
    },
    {
      "work_type": "performance_monitoring",
      "priority_score": 85,
      "reasoning": "Important: Real-time visibility into system performance with live dashboards",
      "recommended_action": "build_live_dashboards",
      "observability_focus": "live_metrics_dashboard"
    }
  ],
  "optimization_opportunities": [
    {
      "type": "promex_integration",
      "description": "Add custom Promex metrics for agent coordination performance tracking",
      "impact_score": 0.85,
      "observability_metrics": ["coordination_latency", "agent_utilization", "work_queue_depth"]
    },
    {
      "type": "grafana_dashboards", 
      "description": "Engineering Elixir Applications: Real-time coordination monitoring dashboards",
      "impact_score": 0.80,
      "observability_metrics": ["system_health", "coordination_velocity", "error_patterns"]
    },
    {
      "type": "trace_correlation",
      "description": "OpenTelemetry correlation between coordination events and system performance",
      "impact_score": 0.75,
      "observability_metrics": ["trace_completion_rates", "span_duration", "error_correlation"]
    }
  ],
  "performance_insights": {
    "coordination_efficiency": "needs_observability_baseline",
    "trace_correlation_points": ["work_claim", "progress_update", "completion"],
    "metric_collection_gaps": ["agent_response_time", "coordination_throughput", "error_patterns"]
  },
  "confidence": 0.70,
  "claude_available": false,
  "fallback_reason": "engineering_elixir_applications_patterns",
  "metadata": {
    "fallback_version": "v3.0_headless",
    "pattern_source": "Engineering Elixir Applications book",
    "implementation_priority": "high"
  }
}
EOF
    )
    
    local end_time=$(python3 -c "import time; print(int(time.time() * 1000))")
    local duration=$((end_time - start_time))
    
    emit_telemetry "engineering_fallback" "success" "$duration" "$trace_id"
    echo "$fallback_analysis"
}

# Main command dispatcher
main() {
    local command="${1:-help}"
    
    case "$command" in
        "health"|"health_check")
            claude_health_check
            ;;
        "stream")
            local input_data="$2"
            local prompt="$3"
            if claude_stream_analyze "$input_data" "$prompt"; then
                return 0
            else
                log_warning "Streaming analysis failed, using Engineering fallback"
                engineering_fallback
                return 0
            fi
            ;;
        "analyze"|"file")
            local input_file="$2"
            local output_file="$3"
            local prompt="$4"
            claude_file_analyze "$input_file" "$output_file" "$prompt"
            ;;
        "fallback")
            engineering_fallback
            ;;
        "help"|*)
            cat <<EOF
Claude Code Headless Integration v1.0

USAGE:
    $0 health                                    - Check Claude CLI health
    $0 stream "<json_data>" "<prompt>"          - Stream analysis with JSON I/O
    $0 analyze <input_file> <output_file> "<prompt>" - File-based analysis
    $0 fallback                                 - Engineering Elixir fallback

EXAMPLES:
    $0 health
    $0 stream '{"data": "test"}' "Analyze this data"
    $0 analyze input.json output.json "Provide recommendations"

FEATURES:
    ✅ Streaming JSON I/O with timeout handling
    ✅ OpenTelemetry trace correlation
    ✅ Engineering Elixir Applications fallback patterns
    ✅ Retry logic with exponential backoff
    ✅ Performance monitoring and telemetry
EOF
            ;;
    esac
}

# Execute main function with all arguments
main "$@"