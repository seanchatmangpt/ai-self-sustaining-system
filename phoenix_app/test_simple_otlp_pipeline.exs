#!/usr/bin/env elixir

# Simple OpenTelemetry Pipeline Test
# Tests basic functionality of the OTLP data processing pipeline

Mix.install([
  {:jason, "~> 1.4"}
])

defmodule SimpleOtlpPipelineTest do
  @moduledoc """
  Simple test to validate the OpenTelemetry data processing pipeline works correctly.
  """

  alias SelfSustaining.TelemetryPipeline.OtlpDataPipelineReactor

  def run_test do
    IO.puts("🧪 Testing OpenTelemetry Data Processing Pipeline")
    IO.puts("=" |> String.duplicate(50))

    # Generate simple test data
    test_data = generate_simple_otlp_data()
    config = get_test_config()
    context = get_test_context()

    # Test the pipeline
    pipeline_inputs = %{
      telemetry_data: test_data,
      pipeline_config: config,
      processing_context: context
    }

    IO.puts("📊 Running pipeline with test data...")
    start_time = System.monotonic_time()

    case Reactor.run(OtlpDataPipelineReactor, pipeline_inputs) do
      {:ok, result} ->
        processing_time = System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond)
        
        IO.puts("✅ Pipeline executed successfully!")
        display_results(result, processing_time)
        
      {:error, reason} ->
        IO.puts("❌ Pipeline failed:")
        IO.puts("   Error: #{inspect(reason)}")
        false
    end
  end

  defp generate_simple_otlp_data do
    trace_id = generate_trace_id()
    span_id = generate_span_id()

    %{
      "resourceSpans" => [
        %{
          "resource" => %{
            "attributes" => [
              %{
                "key" => "service.name",
                "value" => %{"stringValue" => "test-service"}
              },
              %{
                "key" => "service.version", 
                "value" => %{"stringValue" => "1.0.0"}
              }
            ]
          },
          "scopeSpans" => [
            %{
              "scope" => %{
                "name" => "test-instrumentation",
                "version" => "1.0.0"
              },
              "spans" => [
                %{
                  "traceId" => trace_id,
                  "spanId" => span_id,
                  "name" => "test_operation",
                  "kind" => 2, # SPAN_KIND_SERVER
                  "startTimeUnixNano" => to_string(System.system_time(:nanosecond)),
                  "endTimeUnixNano" => to_string(System.system_time(:nanosecond) + 1_000_000),
                  "attributes" => [
                    %{
                      "key" => "http.method",
                      "value" => %{"stringValue" => "GET"}
                    }
                  ],
                  "status" => %{
                    "code" => 1 # OK
                  }
                }
              ]
            }
          ]
        }
      ]
    }
  end

  defp get_test_config do
    %{
      # Sampling configuration - allow everything through for testing
      trace_sampling_rate: 1.0,
      metric_sampling_rate: 1.0,
      log_sampling_rate: 1.0,
      
      # Backend configuration - use localhost defaults
      jaeger_endpoint: "http://localhost:14268/api/traces",
      prometheus_endpoint: "http://localhost:9090/api/v1/write", 
      elasticsearch_endpoint: "http://localhost:9200/_bulk",
      
      # Batch configuration - small batches for testing
      jaeger_batch_size: 10,
      prometheus_batch_size: 10,
      elasticsearch_batch_size: 10
    }
  end

  defp get_test_context do
    %{
      source: "simple_test",
      test_run: true,
      trace_id: "test-#{System.system_time(:nanosecond)}"
    }
  end

  defp display_results(result, processing_time) do
    IO.puts("\n📈 Pipeline Results:")
    IO.puts("   Processing Time: #{processing_time}ms")
    
    # Display pipeline execution info
    if execution = Map.get(result, :pipeline_execution) do
      IO.puts("   Status: #{execution.status}")
      IO.puts("   Stages Completed: #{execution.stages_completed}")
    end
    
    # Display pipeline summary
    if summary = Map.get(result, :pipeline_summary) do
      IO.puts("   Records Processed: #{summary.total_records_processed}")
      IO.puts("   Records Delivered: #{summary.total_records_delivered}")
      IO.puts("   Success Rate: #{Float.round(summary.overall_success_rate * 100, 1)}%")
      IO.puts("   Backends Used: #{summary.backends_utilized}")
    end
    
    # Display delivery statistics
    if delivery_stats = Map.get(result, :delivery_statistics) do
      IO.puts("\n🚀 Delivery Statistics:")
      IO.puts("   Jaeger: #{delivery_stats.jaeger.status} (#{delivery_stats.jaeger.records_sent} records)")
      IO.puts("   Prometheus: #{delivery_stats.prometheus.status} (#{delivery_stats.prometheus.records_sent} records)")
      IO.puts("   Elasticsearch: #{delivery_stats.elasticsearch.status} (#{delivery_stats.elasticsearch.records_sent} records)")
    end
    
    # Display error summary if any
    if error_summary = Map.get(result, :error_summary) do
      if error_summary.total_errors > 0 do
        IO.puts("\n⚠️ Errors Detected:")
        IO.puts("   Total Errors: #{error_summary.total_errors}")
        IO.puts("   Critical Errors: #{length(error_summary.critical_errors)}")
      else
        IO.puts("\n✅ No errors detected")
      end
    end

    # Display performance metrics if available
    if performance = Map.get(result, :performance_metrics) do
      if throughput = get_in(performance, [:throughput, :records_per_second]) do
        IO.puts("\n⚡ Performance:")
        IO.puts("   Throughput: #{Float.round(throughput, 2)} records/sec")
      end
    end

    true
  end

  defp generate_trace_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp generate_span_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end

# Run the test
IO.puts("Starting simple OpenTelemetry pipeline test...")

case SimpleOtlpPipelineTest.run_test() do
  true ->
    IO.puts("\n🎉 Test completed successfully!")
    System.halt(0)
  false ->
    IO.puts("\n💥 Test failed!")
    System.halt(1)
end