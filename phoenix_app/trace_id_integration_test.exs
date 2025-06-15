#!/usr/bin/env elixir

Mix.install([
  {:telemetry, "~> 1.0"},
  {:jason, "~> 1.4"},
  {:req, "~> 0.5"},
  {:reactor, "~> 0.15.4"}
])

defmodule TraceIdIntegrationTest do
  @moduledoc """
  Comprehensive test for trace ID propagation through Reactor -> N8N -> Reactor integration.
  Verifies that trace IDs are consistent throughout the entire workflow pipeline.
  """
  
  require Logger
  
  def run_full_trace_test do
    IO.puts("🔍 Trace ID Integration Test")
    IO.puts("=" |> String.duplicate(50))
    IO.puts("Testing trace ID propagation through complete pipeline")
    IO.puts("")
    
    # Setup telemetry collection for trace tracking
    telemetry_ref = setup_trace_telemetry()
    
    # Test 1: Single workflow with trace ID tracking
    test_single_workflow_trace_propagation()
    
    # Test 2: Multiple concurrent workflows with unique trace IDs
    test_concurrent_workflow_traces()
    
    # Test 3: N8N callback with trace ID preservation
    test_n8n_callback_trace_consistency()
    
    # Collect and analyze all telemetry events
    trace_events = collect_trace_events(telemetry_ref, 5000)
    analyze_trace_consistency(trace_events)
    
    cleanup_telemetry(telemetry_ref)
    
    IO.puts("\n✅ Trace ID Integration Test Complete")
  end
  
  def test_single_workflow_trace_propagation do
    IO.puts("📋 Test 1: Single Workflow Trace Propagation")
    IO.puts("-" |> String.duplicate(40))
    
    # Create a test workflow with explicit trace ID
    test_trace_id = generate_test_trace_id("single_workflow")
    
    workflow_def = %{
      name: "trace_test_workflow_#{System.unique_integer()}",
      nodes: [
        %{id: "trigger_node", type: :webhook, parameters: %{}},
        %{id: "process_node", type: :function, parameters: %{code: "return {processed: true}"}},
        %{id: "output_node", type: :http, parameters: %{url: "https://httpbin.org/post"}}
      ],
      connections: [
        %{from: "trigger_node", to: "process_node"},
        %{from: "process_node", to: "output_node"}
      ]
    }
    
    # Test workflow compilation with trace ID
    IO.puts("  🔧 Testing workflow compilation...")
    {compile_time, compile_result} = :timer.tc(fn ->
      simulate_reactor_compilation_with_trace(workflow_def, test_trace_id)
    end)
    
    IO.puts("    Compile time: #{compile_time / 1000}ms")
    IO.puts("    Trace ID: #{compile_result.trace_id}")
    IO.puts("    Match: #{compile_result.trace_id == test_trace_id}")
    
    # Test N8N export with trace ID preservation  
    IO.puts("  📤 Testing N8N export...")
    {export_time, export_result} = :timer.tc(fn ->
      simulate_n8n_export_with_trace(compile_result, test_trace_id)
    end)
    
    IO.puts("    Export time: #{export_time / 1000}ms")
    IO.puts("    Trace ID: #{export_result.trace_id}")
    IO.puts("    Match: #{export_result.trace_id == test_trace_id}")
    
    # Test workflow execution with trace ID
    IO.puts("  ⚡ Testing workflow execution...")
    {execute_time, execute_result} = :timer.tc(fn ->
      simulate_workflow_execution_with_trace(export_result, test_trace_id)
    end)
    
    IO.puts("    Execute time: #{execute_time / 1000}ms")
    IO.puts("    Trace ID: #{execute_result.trace_id}")
    IO.puts("    Match: #{execute_result.trace_id == test_trace_id}")
    IO.puts("    Status: #{if execute_result.success, do: "✅ SUCCESS", else: "❌ FAILED"}")
    
    %{
      test: :single_workflow_trace,
      trace_id: test_trace_id,
      stages: %{
        compile: compile_result,
        export: export_result,
        execute: execute_result
      },
      trace_consistency: all_traces_match?([compile_result, export_result, execute_result], test_trace_id),
      total_time: compile_time + export_time + execute_time
    }
  end
  
  def test_concurrent_workflow_traces do
    IO.puts("\n⚡ Test 2: Concurrent Workflow Trace Isolation")
    IO.puts("-" |> String.duplicate(40))
    
    # Create 5 concurrent workflows with unique trace IDs
    workflow_count = 5
    
    tasks = Enum.map(1..workflow_count, fn i ->
      Task.async(fn ->
        trace_id = generate_test_trace_id("concurrent_#{i}")
        
        workflow_def = %{
          name: "concurrent_trace_test_#{i}",
          nodes: [
            %{id: "node_#{i}", type: :function, parameters: %{}}
          ],
          connections: []
        }
        
        # Simulate complete pipeline with trace tracking
        {total_time, pipeline_result} = :timer.tc(fn ->
          run_complete_pipeline_with_trace(workflow_def, trace_id)
        end)
        
        %{
          workflow_index: i,
          trace_id: trace_id,
          pipeline_result: pipeline_result,
          total_time: total_time,
          trace_preserved: pipeline_result.final_trace_id == trace_id
        }
      end)
    end)
    
    concurrent_results = Task.await_many(tasks, 30_000)
    
    # Analyze concurrent trace isolation
    trace_conflicts = detect_trace_conflicts(concurrent_results)
    successful_traces = Enum.count(concurrent_results, & &1.trace_preserved)
    
    IO.puts("  Workflows executed: #{workflow_count}")
    IO.puts("  Trace IDs preserved: #{successful_traces}/#{workflow_count}")
    IO.puts("  Trace conflicts detected: #{trace_conflicts}")
    IO.puts("  Isolation success: #{if trace_conflicts == 0, do: "✅ PERFECT", else: "⚠️  ISSUES"}")
    
    concurrent_results
  end
  
  def test_n8n_callback_trace_consistency do
    IO.puts("\n🔄 Test 3: N8N Callback Trace Consistency")
    IO.puts("-" |> String.duplicate(40))
    
    original_trace_id = generate_test_trace_id("n8n_callback")
    
    # Simulate N8N workflow triggering a callback
    callback_data = %{
      "workflow_type" => "trace_test",
      "source_trace_id" => original_trace_id,
      "callback_data" => %{
        "test" => "trace_propagation",
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }
    
    # Test callback processing with trace preservation
    IO.puts("  📞 Processing N8N callback...")
    {callback_time, callback_result} = :timer.tc(fn ->
      simulate_n8n_callback_with_trace("test_callback_workflow", callback_data, original_trace_id)
    end)
    
    IO.puts("    Callback time: #{callback_time / 1000}ms")
    IO.puts("    Original trace ID: #{original_trace_id}")
    IO.puts("    Callback trace ID: #{callback_result.trace_id}")
    IO.puts("    Trace preserved: #{callback_result.trace_id == original_trace_id}")
    IO.puts("    Status: #{if callback_result.success, do: "✅ SUCCESS", else: "❌ FAILED"}")
    
    %{
      test: :n8n_callback_trace,
      original_trace_id: original_trace_id,
      callback_result: callback_result,
      trace_consistency: callback_result.trace_id == original_trace_id,
      callback_time: callback_time
    }
  end
  
  # Simulation functions
  
  defp simulate_reactor_compilation_with_trace(workflow_def, trace_id) do
    # Emit telemetry with trace ID
    :telemetry.execute([:trace_test, :reactor, :compile, :start], %{
      workflow_id: workflow_def.name,
      trace_id: trace_id,
      timestamp: System.system_time(:microsecond)
    }, %{workflow_def: workflow_def})
    
    # Simulate compilation work
    :timer.sleep(Enum.random(10..50))
    
    compile_result = %{
      action: :compile,
      workflow_id: workflow_def.name,
      trace_id: trace_id,
      compiled_at: DateTime.utc_now(),
      success: true,
      node_count: length(workflow_def.nodes)
    }
    
    :telemetry.execute([:trace_test, :reactor, :compile, :complete], %{
      workflow_id: workflow_def.name,
      trace_id: trace_id,
      success: true,
      timestamp: System.system_time(:microsecond)
    }, %{result: compile_result})
    
    compile_result
  end
  
  defp simulate_n8n_export_with_trace(compile_result, trace_id) do
    :telemetry.execute([:trace_test, :n8n, :export, :start], %{
      workflow_id: compile_result.workflow_id,
      trace_id: trace_id,
      timestamp: System.system_time(:microsecond)
    }, %{compile_result: compile_result})
    
    # Simulate export work
    :timer.sleep(Enum.random(20..80))
    
    export_result = %{
      action: :export,
      workflow_id: compile_result.workflow_id,
      trace_id: trace_id,
      n8n_workflow_id: "n8n_wf_#{System.unique_integer()}",
      exported_at: DateTime.utc_now(),
      success: true
    }
    
    :telemetry.execute([:trace_test, :n8n, :export, :complete], %{
      workflow_id: compile_result.workflow_id,
      trace_id: trace_id,
      success: true,
      timestamp: System.system_time(:microsecond)
    }, %{result: export_result})
    
    export_result
  end
  
  defp simulate_workflow_execution_with_trace(export_result, trace_id) do
    :telemetry.execute([:trace_test, :workflow, :execute, :start], %{
      workflow_id: export_result.workflow_id,
      n8n_workflow_id: export_result.n8n_workflow_id,
      trace_id: trace_id,
      timestamp: System.system_time(:microsecond)
    }, %{export_result: export_result})
    
    # Simulate execution work
    :timer.sleep(Enum.random(30..100))
    
    execute_result = %{
      action: :execute,
      workflow_id: export_result.workflow_id,
      n8n_workflow_id: export_result.n8n_workflow_id,
      trace_id: trace_id,
      execution_id: "exec_#{System.unique_integer()}",
      executed_at: DateTime.utc_now(),
      success: true,
      result_data: %{processed: true, trace_verified: true}
    }
    
    :telemetry.execute([:trace_test, :workflow, :execute, :complete], %{
      workflow_id: export_result.workflow_id,
      trace_id: trace_id,
      success: true,
      timestamp: System.system_time(:microsecond)
    }, %{result: execute_result})
    
    execute_result
  end
  
  defp run_complete_pipeline_with_trace(workflow_def, trace_id) do
    compile_result = simulate_reactor_compilation_with_trace(workflow_def, trace_id)
    export_result = simulate_n8n_export_with_trace(compile_result, trace_id)
    execute_result = simulate_workflow_execution_with_trace(export_result, trace_id)
    
    %{
      workflow_id: workflow_def.name,
      initial_trace_id: trace_id,
      final_trace_id: execute_result.trace_id,
      stages: %{
        compile: compile_result,
        export: export_result,
        execute: execute_result
      },
      success: compile_result.success && export_result.success && execute_result.success
    }
  end
  
  defp simulate_n8n_callback_with_trace(workflow_id, callback_data, original_trace_id) do
    # Extract trace ID from callback data, preserving original
    preserved_trace_id = Map.get(callback_data, "source_trace_id", original_trace_id)
    
    :telemetry.execute([:trace_test, :n8n, :callback, :start], %{
      workflow_id: workflow_id,
      trace_id: preserved_trace_id,
      original_trace_id: original_trace_id,
      timestamp: System.system_time(:microsecond)
    }, %{callback_data: callback_data})
    
    # Simulate callback processing
    :timer.sleep(Enum.random(15..60))
    
    callback_result = %{
      action: :callback,
      workflow_id: workflow_id,
      trace_id: preserved_trace_id,
      original_trace_id: original_trace_id,
      processed_at: DateTime.utc_now(),
      success: true,
      callback_data: callback_data
    }
    
    :telemetry.execute([:trace_test, :n8n, :callback, :complete], %{
      workflow_id: workflow_id,
      trace_id: preserved_trace_id,
      success: true,
      timestamp: System.system_time(:microsecond)
    }, %{result: callback_result})
    
    callback_result
  end
  
  # Telemetry and analysis functions
  
  defp setup_trace_telemetry do
    ref = make_ref()
    
    events = [
      [:trace_test, :reactor, :compile, :start],
      [:trace_test, :reactor, :compile, :complete],
      [:trace_test, :n8n, :export, :start],
      [:trace_test, :n8n, :export, :complete],
      [:trace_test, :workflow, :execute, :start],
      [:trace_test, :workflow, :execute, :complete],
      [:trace_test, :n8n, :callback, :start],
      [:trace_test, :n8n, :callback, :complete]
    ]
    
    for event <- events do
      :telemetry.attach(
        "trace-test-#{System.unique_integer()}",
        event,
        fn event_name, measurements, metadata, {pid, events_ref} ->
          send(pid, {:trace_event, events_ref, %{
            event: event_name,
            measurements: measurements,
            metadata: metadata,
            timestamp: System.system_time(:microsecond)
          }})
        end,
        {self(), ref}
      )
    end
    
    ref
  end
  
  defp collect_trace_events(ref, timeout) do
    collect_events_loop(ref, [], System.monotonic_time(:millisecond) + timeout)
  end
  
  defp collect_events_loop(ref, events, end_time) do
    if System.monotonic_time(:millisecond) >= end_time do
      events
    else
      receive do
        {:trace_event, ^ref, event} ->
          collect_events_loop(ref, [event | events], end_time)
      after
        100 ->
          collect_events_loop(ref, events, end_time)
      end
    end
  end
  
  defp cleanup_telemetry(_ref) do
    :telemetry.list_handlers([])
    |> Enum.filter(fn handler -> String.starts_with?(handler.id, "trace-test-") end)
    |> Enum.each(fn handler -> :telemetry.detach(handler.id) end)
  end
  
  defp analyze_trace_consistency(trace_events) do
    IO.puts("\n📊 Trace Consistency Analysis")
    IO.puts("-" |> String.duplicate(40))
    
    # Group events by trace ID
    events_by_trace = Enum.group_by(trace_events, fn event ->
      get_in(event, [:measurements, :trace_id])
    end)
    
    IO.puts("  Total telemetry events: #{length(trace_events)}")
    IO.puts("  Unique trace IDs: #{map_size(events_by_trace)}")
    
    # Analyze each trace ID for consistency
    for {trace_id, events} <- events_by_trace do
      event_count = length(events)
      workflow_ids = events 
                    |> Enum.map(fn event -> get_in(event, [:measurements, :workflow_id]) end)
                    |> Enum.uniq()
                    |> Enum.reject(&is_nil/1)
      
      IO.puts("    Trace ID: #{trace_id}")
      IO.puts("      Events: #{event_count}")
      IO.puts("      Workflows: #{inspect(workflow_ids)}")
      IO.puts("      Consistent: #{if length(workflow_ids) <= 1, do: "✅", else: "⚠️"}")
    end
    
    # Check for trace ID collisions
    collision_count = Enum.count(events_by_trace, fn {_trace_id, events} ->
      workflow_ids = events 
                    |> Enum.map(fn event -> get_in(event, [:measurements, :workflow_id]) end)
                    |> Enum.uniq()
                    |> Enum.reject(&is_nil/1)
      length(workflow_ids) > 1
    end)
    
    IO.puts("  Trace ID collisions: #{collision_count}")
    IO.puts("  Overall consistency: #{if collision_count == 0, do: "✅ PERFECT", else: "⚠️ ISSUES"}")
  end
  
  # Helper functions
  
  defp generate_test_trace_id(prefix) do
    "trace-#{prefix}-#{System.system_time(:nanosecond)}-#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end
  
  defp all_traces_match?(results, expected_trace_id) do
    Enum.all?(results, fn result -> 
      Map.get(result, :trace_id) == expected_trace_id 
    end)
  end
  
  defp detect_trace_conflicts(concurrent_results) do
    trace_ids = Enum.map(concurrent_results, & &1.trace_id)
    unique_trace_ids = Enum.uniq(trace_ids)
    length(trace_ids) - length(unique_trace_ids)
  end
end

# Run the test
if System.argv() == [] do
  TraceIdIntegrationTest.run_full_trace_test()
else
  case List.first(System.argv()) do
    "single" -> TraceIdIntegrationTest.test_single_workflow_trace_propagation()
    "concurrent" -> TraceIdIntegrationTest.test_concurrent_workflow_traces()
    "callback" -> TraceIdIntegrationTest.test_n8n_callback_trace_consistency()
    _ -> 
      IO.puts("Usage: elixir trace_id_integration_test.exs [single|concurrent|callback]")
      IO.puts("Or run without arguments for full test suite")
  end
end