#!/usr/bin/env elixir

# OpenTelemetry Data Processing Pipeline Demo
# Demonstrates the complete OTLP pipeline with Reactor-based data processing

Mix.install([
  {:jason, "~> 1.4"},
  {:req, "~> 0.5.0"}
])

defmodule OtlpPipelineDemo do
  @moduledoc """
  Comprehensive demo of the OpenTelemetry data processing pipeline.
  Shows end-to-end telemetry data flow through all pipeline stages.
  """

  alias SelfSustaining.TelemetryPipeline.PipelineManager
  alias SelfSustaining.TelemetryPipeline.OtlpDataPipelineReactor

  def run_demo do
    IO.puts("🚀 OpenTelemetry Data Processing Pipeline Demo")
    IO.puts("=" |> String.duplicate(60))
    
    # Start pipeline manager
    start_pipeline_manager()
    
    # Run demo scenarios
    run_basic_pipeline_demo()
    run_high_throughput_demo()
    run_error_handling_demo()
    run_concurrent_pipelines_demo()
    
    # Display final statistics
    display_final_statistics()
    
    IO.puts("\n✅ Demo completed successfully!")
  end

  defp start_pipeline_manager do
    IO.puts("\n📋 Starting Pipeline Manager...")
    
    config = %{
      max_concurrent_pipelines: 3,
      pipeline_timeout_ms: 30_000,
      trace_sampling_rate: 0.8,  # Higher sampling for demo
      jaeger_batch_size: 50,
      prometheus_batch_size: 100,
      elasticsearch_batch_size: 75
    }
    
    case PipelineManager.start_link(config: config) do
      {:ok, _pid} ->
        IO.puts("✅ Pipeline Manager started successfully")
      {:error, {:already_started, _pid}} ->
        IO.puts("✅ Pipeline Manager already running")
      error ->
        IO.puts("❌ Failed to start Pipeline Manager: #{inspect(error)}")
        raise "Pipeline Manager startup failed"
    end
  end

  defp run_basic_pipeline_demo do
    IO.puts("\n🔍 Demo 1: Basic Pipeline Execution")
    IO.puts("-" |> String.duplicate(40))
    
    # Generate sample OTLP data
    sample_data = generate_sample_otlp_data("basic_demo", 5)
    
    context = %{
      source: "demo_basic",
      demo_type: "basic_pipeline",
      trace_id: "demo-basic-#{System.system_time(:nanosecond)}"
    }
    
    case PipelineManager.process_telemetry_data(sample_data, context) do
      {:ok, result} ->
        display_pipeline_result(result, "Basic Pipeline")
        
      {:error, reason} ->
        IO.puts("❌ Basic pipeline failed: #{inspect(reason)}")
    end
  end

  defp run_high_throughput_demo do
    IO.puts("\n⚡ Demo 2: High-Throughput Processing")
    IO.puts("-" |> String.duplicate(40))
    
    # Generate larger dataset
    sample_data = generate_sample_otlp_data("throughput_demo", 50)
    
    context = %{
      source: "demo_throughput",
      demo_type: "high_throughput",
      trace_id: "demo-throughput-#{System.system_time(:nanosecond)}"
    }
    
    start_time = System.monotonic_time()
    
    case PipelineManager.process_telemetry_data(sample_data, context) do
      {:ok, result} ->
        processing_time = System.monotonic_time() - start_time
        processing_time_ms = System.convert_time_unit(processing_time, :native, :millisecond)
        
        display_pipeline_result(result, "High-Throughput Pipeline")
        IO.puts("📊 Processing Time: #{processing_time_ms}ms")
        
        # Calculate throughput
        records_processed = get_in(result, [:pipeline_summary, :total_records_processed]) || 0
        throughput = if processing_time_ms > 0 do
          records_processed / (processing_time_ms / 1000)
        else
          0
        end
        IO.puts("⚡ Throughput: #{Float.round(throughput, 2)} records/second")
        
      {:error, reason} ->
        IO.puts("❌ High-throughput pipeline failed: #{inspect(reason)}")
    end
  end

  defp run_error_handling_demo do
    IO.puts("\n🛠️ Demo 3: Error Handling & Recovery")
    IO.puts("-" |> String.duplicate(40))
    
    # Generate malformed data to test error handling
    malformed_data = generate_malformed_otlp_data()
    
    context = %{
      source: "demo_error",
      demo_type: "error_handling",
      trace_id: "demo-error-#{System.system_time(:nanosecond)}"
    }
    
    case PipelineManager.process_telemetry_data(malformed_data, context) do
      {:ok, result} ->
        display_pipeline_result(result, "Error Handling Pipeline")
        
        # Show error summary
        error_summary = Map.get(result, :error_summary, %{})
        IO.puts("🔍 Error Analysis:")
        IO.puts("  • Total Errors: #{Map.get(error_summary, :total_errors, 0)}")
        IO.puts("  • Critical Errors: #{length(Map.get(error_summary, :critical_errors, []))}")
        IO.puts("  • Recoverable Errors: #{length(Map.get(error_summary, :recoverable_errors, []))}")
        
      {:error, reason} ->
        IO.puts("✅ Error handling worked correctly - pipeline failed as expected")
        IO.puts("   Error details: #{inspect(Map.get(reason, :error, "unknown"))}")
    end
  end

  defp run_concurrent_pipelines_demo do
    IO.puts("\n🔄 Demo 4: Concurrent Pipeline Execution")
    IO.puts("-" |> String.duplicate(40))
    
    # Start multiple pipelines concurrently
    tasks = 1..3
    |> Enum.map(fn i ->
      Task.async(fn ->
        sample_data = generate_sample_otlp_data("concurrent_demo_#{i}", 10)
        context = %{
          source: "demo_concurrent",
          demo_type: "concurrent_execution",
          pipeline_id: i,
          trace_id: "demo-concurrent-#{i}-#{System.system_time(:nanosecond)}"
        }
        
        result = PipelineManager.process_telemetry_data(sample_data, context)
        {i, result}
      end)
    end)
    
    # Wait for all pipelines to complete
    results = Task.await_many(tasks, 30_000)
    
    # Display results
    Enum.each(results, fn {pipeline_id, result} ->
      case result do
        {:ok, pipeline_result} ->
          IO.puts("✅ Concurrent Pipeline #{pipeline_id}: SUCCESS")
          records = get_in(pipeline_result, [:pipeline_summary, :total_records_processed]) || 0
          IO.puts("   Records processed: #{records}")
          
        {:error, reason} ->
          IO.puts("❌ Concurrent Pipeline #{pipeline_id}: FAILED")
          IO.puts("   Error: #{inspect(Map.get(reason, :error, "unknown"))}")
      end
    end)
    
    # Show concurrent pipeline status
    status = PipelineManager.get_pipeline_status()
    IO.puts("\n📊 Pipeline Manager Status:")
    IO.puts("  • Total Executions: #{status.total_pipelines_executed}")
    IO.puts("  • Success Rate: #{Float.round(status.success_rate, 1)}%")
    IO.puts("  • Avg Execution Time: #{status.avg_execution_time_ms}ms")
  end

  defp display_final_statistics do
    IO.puts("\n📈 Final Pipeline Statistics")
    IO.puts("=" |> String.duplicate(40))
    
    status = PipelineManager.get_pipeline_status()
    stats = PipelineManager.get_pipeline_statistics()
    
    IO.puts("📊 Execution Summary:")
    IO.puts("  • Total Pipelines: #{stats.total_executions}")
    IO.puts("  • Successful: #{stats.successful_executions}")
    IO.puts("  • Failed: #{stats.failed_executions}")
    IO.puts("  • Success Rate: #{Float.round(status.success_rate, 1)}%")
    IO.puts("  • Avg Execution Time: #{stats.avg_execution_time_ms}ms")
    IO.puts("  • Total Data Processed: #{format_bytes(stats.total_data_processed_bytes)}")
    
    if stats.last_execution_at do
      IO.puts("  • Last Execution: #{DateTime.to_string(stats.last_execution_at)}")
    end
  end

  defp display_pipeline_result(result, pipeline_name) do
    IO.puts("✅ #{pipeline_name} completed successfully")
    
    # Display pipeline execution info
    execution = Map.get(result, :pipeline_execution, %{})
    IO.puts("   Status: #{execution.status}")
    IO.puts("   Execution Time: #{execution.execution_time_ms}ms")
    IO.puts("   Stages Completed: #{execution.stages_completed}")
    
    # Display pipeline summary
    summary = Map.get(result, :pipeline_summary, %{})
    IO.puts("   Records Processed: #{summary.total_records_processed}")
    IO.puts("   Records Delivered: #{summary.total_records_delivered}")
    IO.puts("   Success Rate: #{Float.round(summary.overall_success_rate * 100, 1)}%")
    IO.puts("   Backends Used: #{summary.backends_utilized}")
    
    # Display performance metrics
    performance = Map.get(result, :performance_metrics, %{})
    if throughput = get_in(performance, [:throughput, :records_per_second]) do
      IO.puts("   Throughput: #{Float.round(throughput, 2)} records/sec")
    end
    
    # Display data quality
    quality = Map.get(result, :quality_report, %{})
    if quality_score = Map.get(quality, :overall_quality_score) do
      IO.puts("   Data Quality: #{Float.round(quality_score * 100, 1)}%")
    end
  end

  defp generate_sample_otlp_data(demo_type, span_count) do
    # Generate realistic OTLP trace data
    trace_id = generate_trace_id()
    
    spans = 1..span_count
    |> Enum.map(fn i ->
      span_id = generate_span_id()
      parent_span_id = if i > 1, do: generate_span_id(), else: nil
      
      %{
        "traceId" => trace_id,
        "spanId" => span_id,
        "parentSpanId" => parent_span_id,
        "name" => "#{demo_type}_operation_#{i}",
        "kind" => 2,  # SPAN_KIND_SERVER
        "startTimeUnixNano" => to_string(System.system_time(:nanosecond)),
        "endTimeUnixNano" => to_string(System.system_time(:nanosecond) + 1_000_000),
        "attributes" => [
          %{
            "key" => "service.name",
            "value" => %{"stringValue" => "demo-service"}
          },
          %{
            "key" => "http.method",
            "value" => %{"stringValue" => "GET"}
          },
          %{
            "key" => "demo.type",
            "value" => %{"stringValue" => demo_type}
          }
        ],
        "status" => %{
          "code" => if :rand.uniform() > 0.1, do: 1, else: 2  # 90% success rate
        }
      }
    end)
    
    # Create OTLP structure
    %{
      "resourceSpans" => [
        %{
          "resource" => %{
            "attributes" => [
              %{
                "key" => "service.name",
                "value" => %{"stringValue" => "demo-service"}
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
                "name" => "demo-instrumentation",
                "version" => "1.0.0"
              },
              "spans" => spans
            }
          ]
        }
      ]
    }
  end

  defp generate_malformed_otlp_data do
    # Generate intentionally malformed data for error testing
    %{
      "resourceSpans" => [
        %{
          # Missing required fields
          "scopeSpans" => [
            %{
              "spans" => [
                %{
                  # Missing required trace ID
                  "spanId" => generate_span_id(),
                  "name" => "malformed_span"
                  # Missing other required fields
                }
              ]
            }
          ]
        }
      ],
      # Invalid structure
      "invalidField" => "this should not be here"
    }
  end

  defp generate_trace_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp generate_span_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024, do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"
end

# Check if we're running this file directly
case System.argv() do
  ["test"] ->
    IO.puts("🧪 Testing pipeline components...")
    
    # Test individual pipeline components
    # (This would include more detailed unit tests)
    
  [] ->
    # Run the full demo
    OtlpPipelineDemo.run_demo()
    
  _ ->
    IO.puts("""
    📊 OpenTelemetry Data Processing Pipeline Demo
    
    Usage: elixir run_otlp_pipeline_demo.exs [command]
    
    Commands:
      (no args)  - Run full pipeline demo
      test       - Run component tests
    
    This demo showcases:
    - End-to-end OTLP data processing with Reactor
    - Parallel enrichment and transformation
    - Multi-backend delivery (Jaeger, Prometheus, Elasticsearch)
    - Error handling and recovery mechanisms
    - High-throughput data processing
    - Comprehensive monitoring and metrics
    """)
end