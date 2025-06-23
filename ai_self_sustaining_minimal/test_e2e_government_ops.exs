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
