#!/usr/bin/env elixir

# Comprehensive API Orchestration Test with Trace ID Propagation Validation

Mix.install([
  {:jason, "~> 1.4"},
  {:reactor, "~> 0.15.4"},
  {:benchee, "~> 1.3"}
])

Code.require_file("lib/self_sustaining/workflows/api_orchestration_reactor.ex", __DIR__)
Code.require_file("lib/self_sustaining/workflows/optimized_coordination_reactor.ex", __DIR__)

defmodule ApiOrchestrationTraceTest do
  @moduledoc """
  Comprehensive test for API orchestration with trace ID propagation validation.
  
  Tests:
  1. Trace ID propagation through all API calls
  2. Telemetry event collection and trace correlation
  3. Error handling and compensation with trace context
  4. Performance benchmarking of orchestrated workflows
  5. Integration with coordination system
  """

  require Logger

  def run_comprehensive_test do
    IO.puts("🔍 API Orchestration Trace Propagation Test")
    IO.puts("=" |> String.duplicate(60))
    
    # Setup telemetry collection
    setup_telemetry_collection()
    
    # Setup test environment
    setup_test_environment()
    
    # Run trace propagation tests
    run_trace_propagation_tests()
    
    # Run error scenario tests  
    run_error_scenario_tests()
    
    # Run performance benchmarks
    run_performance_benchmarks()
    
    # Analyze collected telemetry
    analyze_telemetry_results()
    
    # Cleanup
    cleanup_test_environment()
    
    IO.puts("\n🎯 API Orchestration Test Complete!")
  end

  defp setup_telemetry_collection do
    # Start telemetry collection process
    {:ok, collector_pid} = TelemetryCollector.start_link()
    Process.register(collector_pid, :telemetry_collector)
    
    # Attach telemetry handlers for all orchestration events
    orchestration_events = [
      [:api_orchestration, :auth, :success],
      [:api_orchestration, :auth, :failure],
      [:api_orchestration, :profile, :success],
      [:api_orchestration, :profile, :failure],
      [:api_orchestration, :permissions, :success],
      [:api_orchestration, :permissions, :failure],
      [:api_orchestration, :resource_validation, :success],
      [:api_orchestration, :resource_validation, :failure],
      [:api_orchestration, :coordination, :success],
      [:api_orchestration, :coordination, :failure],
      [:api_orchestration, :aggregation, :success],
      [:coordination, :claims, :read],
      [:coordination, :write, :success],
      [:coordination, :write, :failure]
    ]
    
    for event <- orchestration_events do
      :telemetry.attach(
        "test_#{Enum.join(event, "_")}",
        event,
        &TelemetryCollector.handle_event/4,
        %{collector: :telemetry_collector}
      )
    end
    
    IO.puts("📊 Telemetry collection setup complete")
  end

  defp setup_test_environment do
    # Create coordination directory
    File.mkdir_p(".api_orchestration_test")
    
    # Initialize ETS cache for coordination
    try do
      :ets.new(:coordination_cache, [:named_table, :public, {:read_concurrency, true}])
    catch
      :error, :badarg -> :ok
    end
    
    # Create initial coordination claims file
    initial_claims = []
    claims_file = ".api_orchestration_test/orchestration_claims.json"
    File.write!(claims_file, Jason.encode!(initial_claims, pretty: true))
    
    IO.puts("🛠️  Test environment setup complete")
  end

  defp run_trace_propagation_tests do
    IO.puts("\n🔗 Testing Trace ID Propagation")
    IO.puts("-" |> String.duplicate(40))
    
    # Test 1: Successful orchestration with trace propagation
    IO.puts("\n📋 Test 1: Successful Orchestration Trace Flow")
    
    master_trace_id = "master_trace_#{System.system_time(:nanosecond)}"
    
    test_config = prepare_test_config()
    
    start_time = System.monotonic_time(:microsecond)
    
    case Reactor.run(
      SelfSustaining.Workflows.ApiOrchestrationReactor,
      %{
        user_id: "test_user_001",
        resource_id: "resource_abc_123",
        coordination_config: test_config[:coordination_config],
        api_config: test_config[:api_config]
      },
      %{
        trace_id: master_trace_id,
        test_scenario: "successful_orchestration"
      }
    ) do
      {:ok, result} ->
        duration = System.monotonic_time(:microsecond) - start_time
        
        IO.puts("  ✅ Orchestration successful")
        IO.puts("     Duration: #{Float.round(duration / 1000, 2)}ms")
        IO.puts("     Orchestration ID: #{result.orchestration_id}")
        IO.puts("     Master Trace ID: #{master_trace_id}")
        IO.puts("     Result Trace ID: #{result.trace_id}")
        IO.puts("     Steps Completed: #{length(result.steps_completed)}")
        IO.puts("     Coordination Work ID: #{result.coordination_claim.work_item_id}")
        
        # Validate trace ID consistency
        if result.trace_id == master_trace_id do
          IO.puts("     ✅ Trace ID propagated correctly through orchestration")
        else
          IO.puts("     ❌ Trace ID mismatch - propagation failed")
        end
        
        # Validate coordination claim has trace metadata
        if Map.has_key?(result.coordination_claim, :metadata) and
           Map.get(result.coordination_claim.metadata, :trace_id) == master_trace_id do
          IO.puts("     ✅ Trace ID propagated to coordination system")
        else
          IO.puts("     ❌ Trace ID not found in coordination metadata")
        end
        
        {:ok, result}
      
      {:error, reason} ->
        duration = System.monotonic_time(:microsecond) - start_time
        IO.puts("  ❌ Orchestration failed: #{inspect(reason)}")
        IO.puts("     Duration: #{Float.round(duration / 1000, 2)}ms")
        {:error, reason}
    end
    
    # Test 2: Multiple concurrent orchestrations with different trace IDs
    IO.puts("\n📋 Test 2: Concurrent Orchestration Trace Isolation")
    
    concurrent_tasks = Enum.map(1..3, fn i ->
      Task.async(fn ->
        trace_id = "concurrent_trace_#{i}_#{System.system_time(:nanosecond)}"
        
        Reactor.run(
          SelfSustaining.Workflows.ApiOrchestrationReactor,
          %{
            user_id: "concurrent_user_#{i}",
            resource_id: "concurrent_resource_#{i}",
            coordination_config: test_config[:coordination_config],
            api_config: test_config[:api_config]
          },
          %{
            trace_id: trace_id,
            test_scenario: "concurrent_orchestration",
            concurrent_id: i
          }
        )
      end)
    end)
    
    concurrent_results = Task.await_many(concurrent_tasks, 15000)
    
    IO.puts("  Concurrent orchestration results:")
    Enum.with_index(concurrent_results, 1)
    |> Enum.each(fn {result, index} ->
      case result do
        {:ok, orchestration_result} ->
          IO.puts("    Task #{index}: ✅ Success - Trace: #{String.slice(orchestration_result.trace_id, -8, 8)}")
        {:error, reason} ->
          IO.puts("    Task #{index}: ❌ Failed - #{inspect(reason)}")
      end
    end)
  end

  defp run_error_scenario_tests do
    IO.puts("\n🚨 Testing Error Scenarios with Trace Propagation")
    IO.puts("-" |> String.duplicate(50))
    
    # Test 1: Auth failure scenario
    IO.puts("\n📋 Test 1: Authentication Failure Scenario")
    
    auth_failure_trace = "auth_fail_trace_#{System.system_time(:nanosecond)}"
    
    failed_config = prepare_test_config()
    failed_config = put_in(failed_config[:api_config][:auth_enabled], false)
    
    case Reactor.run(
      SelfSustaining.Workflows.ApiOrchestrationReactor,
      %{
        user_id: "auth_fail_user",
        resource_id: "auth_fail_resource",
        coordination_config: failed_config[:coordination_config],
        api_config: failed_config[:api_config]
      },
      %{
        trace_id: auth_failure_trace,
        test_scenario: "auth_failure"
      }
    ) do
      {:ok, _result} ->
        IO.puts("  ❌ Expected authentication failure but orchestration succeeded")
      
      {:error, reason} ->
        IO.puts("  ✅ Authentication failure handled correctly")
        IO.puts("     Error: #{inspect(reason)}")
        IO.puts("     Trace ID: #{auth_failure_trace}")
        
        # Check if telemetry events were emitted with correct trace ID
        :timer.sleep(100)  # Allow telemetry to process
        
        auth_events = TelemetryCollector.get_events_by_trace(:telemetry_collector, auth_failure_trace)
        IO.puts("     Telemetry events captured: #{length(auth_events)}")
        
        auth_failure_events = Enum.filter(auth_events, fn event ->
          event.event_name == [:api_orchestration, :auth, :failure]
        end)
        
        if length(auth_failure_events) > 0 do
          IO.puts("     ✅ Auth failure telemetry event captured with trace ID")
        else
          IO.puts("     ❌ Auth failure telemetry event missing")
        end
    end
    
    # Test 2: Resource access denied scenario  
    IO.puts("\n📋 Test 2: Resource Access Denied Scenario")
    
    access_denied_trace = "access_denied_trace_#{System.system_time(:nanosecond)}"
    
    # This will trigger access denied in validation logic
    case Reactor.run(
      SelfSustaining.Workflows.ApiOrchestrationReactor,
      %{
        user_id: "limited_user",
        resource_id: "restricted_resource",
        coordination_config: test_config[:coordination_config],
        api_config: test_config[:api_config]
      },
      %{
        trace_id: access_denied_trace,
        test_scenario: "access_denied",
        force_access_denied: true
      }
    ) do
      {:ok, result} ->
        if result.resource_access.access_level == "none" do
          IO.puts("  ✅ Access level correctly set to 'none'")
        else
          IO.puts("  ⚠️  Orchestration succeeded with access level: #{result.resource_access.access_level}")
        end
      
      {:error, reason} ->
        IO.puts("  ✅ Resource access properly denied")
        IO.puts("     Error: #{inspect(reason)}")
        IO.puts("     Trace ID: #{access_denied_trace}")
    end
  end

  defp run_performance_benchmarks do
    IO.puts("\n🚀 Performance Benchmarking with Trace Monitoring")
    IO.puts("-" |> String.duplicate(50))
    
    test_config = prepare_test_config()
    
    # Benchmark different orchestration scenarios
    Benchee.run(
      %{
        "Single API Orchestration" => fn ->
          trace_id = "bench_single_#{System.system_time(:nanosecond)}"
          
          Reactor.run(
            SelfSustaining.Workflows.ApiOrchestrationReactor,
            %{
              user_id: "bench_user_#{Enum.random(1..1000)}",
              resource_id: "bench_resource_#{Enum.random(1..100)}",
              coordination_config: test_config[:coordination_config],
              api_config: test_config[:api_config]
            },
            %{
              trace_id: trace_id,
              test_scenario: "benchmark_single"
            }
          )
        end,
        
        "High Priority Orchestration" => fn ->
          trace_id = "bench_priority_#{System.system_time(:nanosecond)}"
          
          high_priority_config = put_in(test_config[:api_config][:priority_mode], true)
          
          Reactor.run(
            SelfSustaining.Workflows.ApiOrchestrationReactor,
            %{
              user_id: "priority_user_#{Enum.random(1..100)}",
              resource_id: "priority_resource_#{Enum.random(1..50)}",
              coordination_config: test_config[:coordination_config],
              api_config: high_priority_config
            },
            %{
              trace_id: trace_id,
              test_scenario: "benchmark_priority"
            }
          )
        end,
        
        "Bulk Orchestration" => fn ->
          # Process multiple orchestrations in sequence
          1..3
          |> Stream.map(fn i ->
            trace_id = "bench_bulk_#{i}_#{System.system_time(:nanosecond)}"
            
            Reactor.run(
              SelfSustaining.Workflows.ApiOrchestrationReactor,
              %{
                user_id: "bulk_user_#{i}",
                resource_id: "bulk_resource_#{i}",
                coordination_config: test_config[:coordination_config],
                api_config: test_config[:api_config]
              },
              %{
                trace_id: trace_id,
                test_scenario: "benchmark_bulk",
                bulk_index: i
              }
            )
          end)
          |> Enum.to_list()
        end
      },
      time: 5,
      memory_time: 2,
      formatters: [
        {Benchee.Formatters.Console, 
         comparison: true, 
         extended_statistics: true}
      ]
    )
  end

  defp analyze_telemetry_results do
    IO.puts("\n📊 Telemetry Analysis - Trace Correlation")
    IO.puts("-" |> String.duplicate(50))
    
    :timer.sleep(500)  # Allow all telemetry to process
    
    all_events = TelemetryCollector.get_all_events(:telemetry_collector)
    
    IO.puts("Total telemetry events captured: #{length(all_events)}")
    
    # Group events by trace ID
    events_by_trace = Enum.group_by(all_events, & &1.metadata[:trace_id])
    
    IO.puts("Unique trace IDs: #{map_size(events_by_trace)}")
    
    # Analyze trace completeness
    complete_traces = Enum.filter(events_by_trace, fn {_trace_id, events} ->
      event_types = Enum.map(events, & &1.event_name) |> Enum.uniq()
      
      # Check for key orchestration events
      has_auth = Enum.any?(event_types, fn event -> 
        event == [:api_orchestration, :auth, :success] or
        event == [:api_orchestration, :auth, :failure]
      end)
      
      has_coordination = Enum.any?(event_types, fn event ->
        event == [:api_orchestration, :coordination, :success] or
        event == [:api_orchestration, :coordination, :failure]
      end)
      
      has_auth and has_coordination
    end)
    
    IO.puts("Complete trace workflows: #{length(complete_traces)}")
    
    # Show sample trace analysis
    if length(complete_traces) > 0 do
      {sample_trace_id, sample_events} = List.first(complete_traces)
      
      IO.puts("\n📋 Sample Trace Analysis:")
      IO.puts("Trace ID: #{sample_trace_id}")
      IO.puts("Events in trace: #{length(sample_events)}")
      
      sample_events
      |> Enum.sort_by(& &1.timestamp)
      |> Enum.each(fn event ->
        event_name = Enum.join(event.event_name, ".")
        duration = Map.get(event.measurements, :duration, 0)
        IO.puts("  #{event_name}: #{Float.round(duration / 1000, 2)}ms")
      end)
      
      # Calculate total orchestration time
      first_event = Enum.min_by(sample_events, & &1.timestamp)
      last_event = Enum.max_by(sample_events, & &1.timestamp)
      total_duration = last_event.timestamp - first_event.timestamp
      
      IO.puts("Total orchestration duration: #{Float.round(total_duration / 1000, 2)}ms")
    end
    
    # Performance statistics
    auth_events = Enum.filter(all_events, fn event ->
      event.event_name == [:api_orchestration, :auth, :success]
    end)
    
    if length(auth_events) > 0 do
      auth_durations = Enum.map(auth_events, &Map.get(&1.measurements, :duration, 0))
      avg_auth_duration = Enum.sum(auth_durations) / length(auth_durations)
      
      IO.puts("\n📈 Performance Statistics:")
      IO.puts("Average auth duration: #{Float.round(avg_auth_duration / 1000, 2)}ms")
      IO.puts("Auth success rate: #{length(auth_events)} successes analyzed")
    end
  end

  defp prepare_test_config do
    %{
      coordination_config: %{
        coordination_dir: ".api_orchestration_test",
        claims_file: "orchestration_claims.json",
        timeout: 5000
      },
      api_config: %{
        auth_enabled: true,
        api_timeout: 5000,
        retry_attempts: 3
      }
    }
  end

  defp cleanup_test_environment do
    File.rm_rf(".api_orchestration_test")
    
    try do
      :ets.delete(:coordination_cache)
    catch
      :error, :badarg -> :ok
    end
    
    # Detach telemetry handlers
    :telemetry.list_handlers([])
    |> Enum.filter(fn handler -> String.starts_with?(handler.id, "test_") end)
    |> Enum.each(fn handler -> :telemetry.detach(handler.id) end)
    
    # Stop telemetry collector
    if Process.whereis(:telemetry_collector) do
      GenServer.stop(:telemetry_collector)
    end
    
    IO.puts("🧹 Test environment cleaned up")
  end
end

defmodule TelemetryCollector do
  @moduledoc """
  Collects telemetry events for analysis and trace correlation.
  """
  
  use GenServer

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{events: []})
  end

  def handle_event(event_name, measurements, metadata, config) do
    collector_pid = Map.get(config, :collector)
    
    if collector_pid do
      event_data = %{
        event_name: event_name,
        measurements: measurements,
        metadata: metadata,
        timestamp: System.monotonic_time(:microsecond)
      }
      
      GenServer.cast(collector_pid, {:collect_event, event_data})
    end
  end

  def get_all_events(collector_pid) do
    GenServer.call(collector_pid, :get_all_events)
  end

  def get_events_by_trace(collector_pid, trace_id) do
    GenServer.call(collector_pid, {:get_events_by_trace, trace_id})
  end

  # GenServer callbacks

  def init(state) do
    {:ok, state}
  end

  def handle_cast({:collect_event, event_data}, state) do
    updated_state = Map.update(state, :events, [event_data], fn events ->
      [event_data | events]
    end)
    
    {:noreply, updated_state}
  end

  def handle_call(:get_all_events, _from, state) do
    events = Map.get(state, :events, [])
    {:reply, Enum.reverse(events), state}
  end

  def handle_call({:get_events_by_trace, trace_id}, _from, state) do
    events = Map.get(state, :events, [])
    
    matching_events = Enum.filter(events, fn event ->
      Map.get(event.metadata, :trace_id) == trace_id
    end)
    
    {:reply, Enum.reverse(matching_events), state}
  end
end

# Run the comprehensive test
ApiOrchestrationTraceTest.run_comprehensive_test()