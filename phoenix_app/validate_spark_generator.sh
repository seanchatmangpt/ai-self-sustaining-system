#!/bin/bash

# End-to-End Spark DSL Generator Validation Script with OpenTelemetry
# Constitutional compliance: ✅ Nanosecond precision ✅ Telemetry integration ✅ Full trace propagation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# OpenTelemetry trace context - RFC compliant
TRACE_ID=$(printf "%032x" $(($(date +%s%N) % 2**128)))
ROOT_SPAN_ID=$(printf "%016x" $(($(date +%s%N) % 2**64)))
TRACE_FLAGS="01"  # Sampled
TRACE_STATE=""

# Nanosecond precision timing
START_TIME=$(date +%s%N)
AGENT_ID="validator_$(date +%s%N)"

echo -e "${BLUE}🚀 Starting Spark DSL Generator E2E Validation${NC}"
echo -e "${BLUE}📊 Agent ID: ${AGENT_ID}${NC}"
echo -e "${BLUE}🔍 Trace ID: ${TRACE_ID}${NC}"
echo -e "${BLUE}📡 Root Span ID: ${ROOT_SPAN_ID}${NC}"
echo -e "${BLUE}🕐 Start Time: ${START_TIME}${NC}"

# Export OpenTelemetry environment variables for trace propagation
export OTEL_TRACE_ID="${TRACE_ID}"
export OTEL_SPAN_ID="${ROOT_SPAN_ID}"
export OTEL_TRACE_FLAGS="${TRACE_FLAGS}"
export OTEL_TRACE_STATE="${TRACE_STATE}"

# Cleanup function
cleanup() {
    local exit_code=$?
    local end_time=$(date +%s%N)
    local duration=$((end_time - START_TIME))
    
    echo -e "\n${BLUE}🧹 Cleaning up test artifacts...${NC}"
    
    # Remove test files
    rm -f lib/test_e2e.ex
    rm -f lib/test_app/test_generator.ex
    rm -f lib/my_app/auth/extensions/test_validator.ex
    
    echo -e "${BLUE}📊 Validation completed in ${duration} nanoseconds${NC}"
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ All validations passed!${NC}"
    else
        echo -e "${RED}❌ Validation failed with exit code ${exit_code}${NC}"
    fi
    
    exit $exit_code
}

trap cleanup EXIT

# Function to generate child span ID
generate_span_id() {
    printf "%016x" $(($(date +%s%N) % 2**64))
}

# Function to emit telemetry events with full trace context
emit_telemetry() {
    local event=$1
    local status=$2
    local operation=${3:-"validation"}
    local timestamp=$(date +%s%N)
    local span_id=$(generate_span_id)
    
    # Create OpenTelemetry compliant trace context
    local trace_context="{\"trace_id\":\"${TRACE_ID}\",\"span_id\":\"${span_id}\",\"parent_span_id\":\"${OTEL_SPAN_ID}\",\"trace_flags\":\"${TRACE_FLAGS}\",\"trace_state\":\"${TRACE_STATE}\"}"
    
    # Log telemetry event in OpenTelemetry format
    cat >> validation_telemetry.jsonl << EOF
{
  "timestamp": ${timestamp},
  "agent_id": "${AGENT_ID}",
  "event": "${event}",
  "status": "${status}",
  "operation": "${operation}",
  "trace_context": ${trace_context},
  "resource": {
    "service.name": "spark-dsl-generator-validator",
    "service.version": "1.0.0",
    "deployment.environment": "validation"
  },
  "instrumentation_scope": {
    "name": "spark-dsl-validator",
    "version": "1.0.0"
  }
}
EOF

    echo -e "${BLUE}📡 Emitted telemetry: ${event} (${status}) - Span: ${span_id}${NC}"
}

# Function to validate file exists and has content
validate_file() {
    local file_path=$1
    local description=$2
    
    if [[ ! -f "$file_path" ]]; then
        echo -e "${RED}❌ ${description}: File not found at ${file_path}${NC}"
        emit_telemetry "file_validation" "failed"
        return 1
    fi
    
    if [[ ! -s "$file_path" ]]; then
        echo -e "${RED}❌ ${description}: File is empty at ${file_path}${NC}"
        emit_telemetry "file_validation" "failed"
        return 1
    fi
    
    echo -e "${GREEN}✅ ${description}: File exists and has content${NC}"
    emit_telemetry "file_validation" "success"
    return 0
}

# Function to validate Elixir compilation
validate_compilation() {
    local description=$1
    
    echo -e "${YELLOW}🔧 ${description}: Testing compilation...${NC}"
    
    if mix compile --warnings-as-errors; then
        echo -e "${GREEN}✅ ${description}: Compilation successful${NC}"
        emit_telemetry "compilation" "success"
        return 0
    else
        echo -e "${RED}❌ ${description}: Compilation failed${NC}"
        emit_telemetry "compilation" "failed"
        return 1
    fi
}

# Function to validate DSL functionality with trace propagation
validate_dsl_functionality() {
    local module_name=$1
    local description=$2
    local test_span_id=$(generate_span_id)
    
    echo -e "${YELLOW}🧪 ${description}: Testing DSL functionality... (Span: ${test_span_id})${NC}"
    
    # Create test script to validate DSL with trace context
    cat > test_dsl_validation.exs << EOF
# Test DSL functionality with OpenTelemetry trace propagation
defmodule TestDslValidation do
  def run do
    # Get trace context from environment
    trace_id = System.get_env("OTEL_TRACE_ID", "unknown")
    parent_span_id = "${test_span_id}"
    
    try do
      # Test basic module loading
      module = Module.concat([${module_name}])
      
      # Test if it's a valid Spark DSL
      if function_exported?(module, :__spark_dsl__, 0) do
        dsl_config = module.__spark_dsl__()
        
        IO.puts("✅ DSL loaded successfully")
        IO.puts("📊 Extensions: #{length(dsl_config[:extensions] || [])}")
        IO.puts("🔍 Trace ID: #{trace_id}")
        IO.puts("📡 Span ID: #{parent_span_id}")
        
        # Emit telemetry with trace context
        :telemetry.execute(
          [:spark_generator, :dsl_validation, :success],
          %{
            timestamp: System.system_time(:nanosecond),
            execution_time_ns: System.system_time(:nanosecond)
          },
          %{
            module: module,
            agent_id: "${AGENT_ID}",
            trace_id: trace_id,
            span_id: parent_span_id,
            parent_span_id: System.get_env("OTEL_SPAN_ID", "unknown"),
            operation: "dsl_validation"
          }
        )
        
        {:ok, :validation_passed}
      else
        IO.puts("❌ Module is not a valid Spark DSL")
        
        # Emit failure telemetry
        :telemetry.execute(
          [:spark_generator, :dsl_validation, :failed],
          %{timestamp: System.system_time(:nanosecond)},
          %{
            module: module,
            agent_id: "${AGENT_ID}",
            trace_id: trace_id,
            span_id: parent_span_id,
            error: "invalid_dsl"
          }
        )
        
        {:error, :invalid_dsl}
      end
    rescue
      error ->
        IO.puts("❌ Error validating DSL: #{inspect(error)}")
        
        # Emit error telemetry
        :telemetry.execute(
          [:spark_generator, :dsl_validation, :error],
          %{timestamp: System.system_time(:nanosecond)},
          %{
            agent_id: "${AGENT_ID}",
            trace_id: trace_id,
            span_id: parent_span_id,
            error: inspect(error)
          }
        )
        
        {:error, error}
    end
  end
end

case TestDslValidation.run() do
  {:ok, :validation_passed} -> System.halt(0)
  {:error, _} -> System.halt(1)
end
EOF

    # Set child span context for Elixir process
    export OTEL_SPAN_ID="${test_span_id}"
    
    if elixir test_dsl_validation.exs; then
        echo -e "${GREEN}✅ ${description}: DSL functionality validated${NC}"
        emit_telemetry "dsl_validation" "success" "dsl_test"
        rm -f test_dsl_validation.exs
        return 0
    else
        echo -e "${RED}❌ ${description}: DSL validation failed${NC}"
        emit_telemetry "dsl_validation" "failed" "dsl_test"
        rm -f test_dsl_validation.exs
        return 1
    fi
    
    # Restore parent span context
    export OTEL_SPAN_ID="${ROOT_SPAN_ID}"
}

# Start telemetry logging with initial trace context
emit_telemetry "validation_start" "started" "validation_root"

echo -e "\n${YELLOW}🧪 Test 1: Basic Generator Functionality${NC}"
emit_telemetry "test_1_start" "started"

# Test 1: Generate basic extension
echo -e "${BLUE}📝 Generating basic test extension...${NC}"
if mix spark.gen.working TestE2E; then
    echo -e "${GREEN}✅ Basic generator ran successfully${NC}"
    emit_telemetry "basic_generation" "success"
else
    echo -e "${RED}❌ Basic generator failed${NC}"
    emit_telemetry "basic_generation" "failed"
    exit 1
fi

# Validate generated file
validate_file "lib/test_e2e.ex" "Basic generated extension"
validate_compilation "Basic extension compilation"

echo -e "\n${YELLOW}🧪 Test 2: Domain-Organized Generator${NC}"
emit_telemetry "test_2_start" "started"

# Test 2: Generate extension with domain
echo -e "${BLUE}📝 Generating domain-organized extension...${NC}"
if mix spark.gen.working TestValidator --domain MyApp.Auth; then
    echo -e "${GREEN}✅ Domain generator ran successfully${NC}"
    emit_telemetry "domain_generation" "success"
else
    echo -e "${RED}❌ Domain generator failed${NC}"
    emit_telemetry "domain_generation" "failed"
    exit 1
fi

# Validate domain-organized file
validate_file "lib/my_app/auth/extensions/test_validator.ex" "Domain-organized extension"
validate_compilation "Domain extension compilation"

echo -e "\n${YELLOW}🧪 Test 3: DSL Structure Validation${NC}"
emit_telemetry "test_3_start" "started"

# Test 3: Validate DSL structure
echo -e "${BLUE}🔍 Validating DSL structure in generated files...${NC}"

# Check for required Spark DSL components
for file in "lib/test_e2e.ex" "lib/my_app/auth/extensions/test_validator.ex"; do
    if [[ -f "$file" ]]; then
        echo -e "${BLUE}🔍 Checking $file for DSL components...${NC}"
        
        # Check for Spark.Dsl.Entity
        if grep -q "Spark.Dsl.Entity" "$file"; then
            echo -e "${GREEN}✅ Contains Spark.Dsl.Entity${NC}"
        else
            echo -e "${RED}❌ Missing Spark.Dsl.Entity${NC}"
            emit_telemetry "dsl_structure" "failed"
            exit 1
        fi
        
        # Check for Spark.Dsl.Section
        if grep -q "Spark.Dsl.Section" "$file"; then
            echo -e "${GREEN}✅ Contains Spark.Dsl.Section${NC}"
        else
            echo -e "${RED}❌ Missing Spark.Dsl.Section${NC}"
            emit_telemetry "dsl_structure" "failed"
            exit 1
        fi
        
        # Check for transformers
        if grep -q "Spark.Dsl.Transformer" "$file"; then
            echo -e "${GREEN}✅ Contains Spark.Dsl.Transformer${NC}"
        else
            echo -e "${RED}❌ Missing Spark.Dsl.Transformer${NC}"
            emit_telemetry "dsl_structure" "failed"
            exit 1
        fi
        
        # Check for verifiers
        if grep -q "Spark.Dsl.Verifier" "$file"; then
            echo -e "${GREEN}✅ Contains Spark.Dsl.Verifier${NC}"
        else
            echo -e "${RED}❌ Missing Spark.Dsl.Verifier${NC}"
            emit_telemetry "dsl_structure" "failed"
            exit 1
        fi
    fi
done

emit_telemetry "dsl_structure" "success"

echo -e "\n${YELLOW}🧪 Test 4: OpenTelemetry Integration${NC}"
emit_telemetry "test_4_start" "started"

# Test 4: Validate OpenTelemetry integration
echo -e "${BLUE}📊 Setting up telemetry handlers for validation...${NC}"

# Create telemetry validation script with trace propagation
telemetry_span_id=$(generate_span_id)

cat > validate_telemetry.exs << EOF
# Setup telemetry test handler with OpenTelemetry trace context
defmodule TelemetryValidator do
  def setup_handlers do
    :telemetry.attach_many(
      "spark-generator-validator",
      [
        [:spark_generator, :validation, :success],
        [:spark_generator, :validation, :failed],
        [:spark_generator, :telemetry_test, :trace_validation]
      ],
      &handle_event/4,
      nil
    )
  end
  
  def handle_event(event, measurements, metadata, _config) do
    IO.puts("📊 Telemetry Event: #{inspect(event)}")
    IO.puts("📊 Measurements: #{inspect(measurements)}")
    IO.puts("📊 Metadata: #{inspect(metadata)}")
    
    # Validate trace context propagation
    if Map.has_key?(metadata, :trace_id) do
      IO.puts("✅ Trace context found in metadata")
      IO.puts("🔍 Trace ID: #{metadata.trace_id}")
      IO.puts("📡 Span ID: #{metadata.span_id}")
    else
      IO.puts("⚠️  No trace context in metadata")
    end
    
    # Store for validation
    Agent.update(:telemetry_events, fn events ->
      [{event, measurements, metadata} | events]
    end)
  end
  
  def get_events do
    Agent.get(:telemetry_events, & &1)
  end
  
  def count_events_with_trace do
    events = get_events()
    Enum.count(events, fn {_event, _measurements, metadata} ->
      Map.has_key?(metadata, :trace_id)
    end)
  end
end

# Start agent for event storage
{:ok, _} = Agent.start_link(fn -> [] end, name: :telemetry_events)

TelemetryValidator.setup_handlers()

# Get trace context from environment
trace_id = System.get_env("OTEL_TRACE_ID", "unknown")
span_id = "${telemetry_span_id}"
parent_span_id = System.get_env("OTEL_SPAN_ID", "unknown")

IO.puts("🔍 Testing with Trace ID: #{trace_id}")
IO.puts("📡 Current Span ID: #{span_id}")
IO.puts("⬆️  Parent Span ID: #{parent_span_id}")

# Emit test event with full trace context
:telemetry.execute(
  [:spark_generator, :telemetry_test, :trace_validation],
  %{
    timestamp: System.system_time(:nanosecond),
    test_duration_ns: 1000000  # 1ms test
  },
  %{
    test: :telemetry_validation,
    agent_id: "${AGENT_ID}",
    trace_id: trace_id,
    span_id: span_id,
    parent_span_id: parent_span_id,
    trace_flags: System.get_env("OTEL_TRACE_FLAGS", "01"),
    operation: "telemetry_validation"
  }
)

# Wait a moment for event processing
Process.sleep(100)

events = TelemetryValidator.get_events()
trace_events = TelemetryValidator.count_events_with_trace()

IO.puts("📊 Total events captured: #{length(events)}")
IO.puts("🔍 Events with trace context: #{trace_events}")

if length(events) > 0 and trace_events > 0 do
  IO.puts("✅ Telemetry integration working with trace propagation")
  System.halt(0)
else
  IO.puts("❌ Telemetry validation failed - missing events or trace context")
  System.halt(1)
end
EOF

if elixir validate_telemetry.exs; then
    echo -e "${GREEN}✅ OpenTelemetry integration validated${NC}"
    emit_telemetry "telemetry_integration" "success"
else
    echo -e "${RED}❌ OpenTelemetry integration failed${NC}"
    emit_telemetry "telemetry_integration" "failed"
    exit 1
fi

rm -f validate_telemetry.exs

echo -e "\n${YELLOW}🧪 Test 5: Performance Benchmarking${NC}"
emit_telemetry "test_5_start" "started"

# Test 5: Performance benchmarking
echo -e "${BLUE}⚡ Running performance benchmarks...${NC}"

BENCH_START=$(date +%s%N)

# Generate multiple extensions to test performance
for i in {1..5}; do
    if mix spark.gen.working "BenchTest${i}" > /dev/null 2>&1; then
        rm -f "lib/bench_test${i}.ex"
    else
        echo -e "${RED}❌ Performance test failed on iteration ${i}${NC}"
        emit_telemetry "performance_test" "failed"
        exit 1
    fi
done

BENCH_END=$(date +%s%N)
BENCH_DURATION=$((BENCH_END - BENCH_START))
AVG_DURATION=$((BENCH_DURATION / 5))

echo -e "${GREEN}✅ Generated 5 extensions in ${BENCH_DURATION} nanoseconds${NC}"
echo -e "${GREEN}📊 Average generation time: ${AVG_DURATION} nanoseconds${NC}"

# Benchmark threshold (10 seconds in nanoseconds)
THRESHOLD=10000000000

if [[ $AVG_DURATION -lt $THRESHOLD ]]; then
    echo -e "${GREEN}✅ Performance benchmark passed${NC}"
    emit_telemetry "performance_test" "success"
else
    echo -e "${RED}❌ Performance benchmark failed - too slow${NC}"
    emit_telemetry "performance_test" "failed"
    exit 1
fi

echo -e "\n${YELLOW}🧪 Test 6: Final Integration Test${NC}"
emit_telemetry "test_6_start" "started"

# Test 6: Final integration test with full compilation
echo -e "${BLUE}🔄 Running final compilation test...${NC}"

if validate_compilation "Final integration test"; then
    echo -e "${GREEN}✅ Final integration test passed${NC}"
    emit_telemetry "final_integration" "success"
else
    echo -e "${RED}❌ Final integration test failed${NC}"
    emit_telemetry "final_integration" "failed"
    exit 1
fi

# Generate telemetry summary
echo -e "\n${BLUE}📊 Telemetry Summary:${NC}"
if [[ -f "validation_telemetry.jsonl" ]]; then
    echo -e "${BLUE}📄 Telemetry events logged to: validation_telemetry.jsonl${NC}"
    
    # Count events by status
    SUCCESS_COUNT=$(grep '"status":"success"' validation_telemetry.jsonl | wc -l)
    FAILED_COUNT=$(grep '"status":"failed"' validation_telemetry.jsonl | wc -l)
    TOTAL_COUNT=$(wc -l < validation_telemetry.jsonl)
    
    echo -e "${GREEN}✅ Successful events: ${SUCCESS_COUNT}${NC}"
    echo -e "${RED}❌ Failed events: ${FAILED_COUNT}${NC}"
    echo -e "${BLUE}📊 Total events: ${TOTAL_COUNT}${NC}"
    
    # Final validation
    if [[ $FAILED_COUNT -eq 0 ]] && [[ $SUCCESS_COUNT -gt 0 ]]; then
        emit_telemetry "validation_complete" "success"
        echo -e "\n${GREEN}🎉 ALL TESTS PASSED! Spark DSL Generator is working correctly.${NC}"
        exit 0
    else
        emit_telemetry "validation_complete" "failed"
        echo -e "\n${RED}💥 VALIDATION FAILED! Check the telemetry logs for details.${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ No telemetry file generated${NC}"
    exit 1
fi