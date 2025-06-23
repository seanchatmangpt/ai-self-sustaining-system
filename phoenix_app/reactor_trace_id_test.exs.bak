#!/usr/bin/env elixir

Mix.install([
  {:telemetry, "~> 1.0"},
  {:jason, "~> 1.4"},
  {:req, "~> 0.5"},
  {:reactor, "~> 0.15.4"},
  {:opentelemetry, "~> 1.3"},
  {:opentelemetry_api, "~> 1.2"}
])

defmodule ReactorTraceIdTest do
  @moduledoc """
  Test actual Reactor execution with trace ID middleware to verify
  trace ID propagation through the real TelemetryMiddleware.
  """
  
  use Reactor
  
  require Logger
  require OpenTelemetry.Tracer
  
  # Define a test reactor that simulates n8n workflow
  step :start_with_trace do
    run fn arguments, context ->
      trace_id = Map.get(context, :trace_id, "no-trace-id")
      Logger.info("Step 1: Trace ID = #{trace_id}")
      
      # Emit telemetry to track trace ID
      :telemetry.execute([:test_reactor, :step, :start], %{
        step: :start_with_trace,
        trace_id: trace_id,
        timestamp: System.system_time(:microsecond)
      }, context)
      
      {:ok, %{
        step: :start_with_trace,
        trace_id: trace_id,
        data: Map.get(arguments, :input_data, %{})
      }}
    end
  end
  
  step :simulate_n8n_export do
    argument :input, from_result(:start_with_trace)
    
    run fn arguments, context ->
      trace_id = Map.get(context, :trace_id, "no-trace-id")
      input_trace_id = get_in(arguments, [:input, :trace_id])
      
      Logger.info("Step 2: Context Trace ID = #{trace_id}")
      Logger.info("Step 2: Input Trace ID = #{input_trace_id}")
      Logger.info("Step 2: Trace consistency = #{trace_id == input_trace_id}")
      
      # Simulate N8N export work
      :timer.sleep(50)
      
      # Emit telemetry
      :telemetry.execute([:test_reactor, :step, :n8n_export], %{
        step: :simulate_n8n_export,
        trace_id: trace_id,
        input_trace_id: input_trace_id,
        consistent: trace_id == input_trace_id,
        timestamp: System.system_time(:microsecond)
      }, context)
      
      {:ok, %{
        step: :simulate_n8n_export,
        trace_id: trace_id,
        n8n_workflow_id: "n8n_wf_#{System.unique_integer()}",
        export_success: true
      }}
    end
  end
  
  step :simulate_workflow_execution do
    argument :export_result, from_result(:simulate_n8n_export)
    
    run fn arguments, context ->
      trace_id = Map.get(context, :trace_id, "no-trace-id")
      export_trace_id = get_in(arguments, [:export_result, :trace_id])
      
      Logger.info("Step 3: Context Trace ID = #{trace_id}")
      Logger.info("Step 3: Export Trace ID = #{export_trace_id}")
      Logger.info("Step 3: Trace consistency = #{trace_id == export_trace_id}")
      
      # Simulate workflow execution
      :timer.sleep(30)
      
      # Emit telemetry
      :telemetry.execute([:test_reactor, :step, :execution], %{
        step: :simulate_workflow_execution,
        trace_id: trace_id,
        export_trace_id: export_trace_id,
        consistent: trace_id == export_trace_id,
        timestamp: System.system_time(:microsecond)
      }, context)
      
      {:ok, %{
        step: :simulate_workflow_execution,
        trace_id: trace_id,
        execution_id: "exec_#{System.unique_integer()}",
        final_result: %{
          success: true,
          trace_verified: trace_id == export_trace_id
        }
      }}
    end
  end
  
  def run_reactor_trace_test do
    IO.puts("🚀 Reactor Trace ID Middleware Test")
    IO.puts("=" |> String.duplicate(50))
    
    # Setup telemetry collection
    telemetry_ref = setup_test_telemetry()
    
    # Test with custom trace ID
    test_trace_id = "reactor-test-#{System.system_time(:nanosecond)}"
    IO.puts("Generated test trace ID: #{test_trace_id}")
    
    # Run reactor with trace ID in context
    IO.puts("\n🔧 Running reactor with TelemetryMiddleware...")
    
    start_time = System.monotonic_time()
    
    result = Reactor.run(__MODULE__, %{
      input_data: %{
        test: "trace_propagation",
        expected_trace_id: test_trace_id
      }
    }, %{
      trace_id: test_trace_id,
      test_mode: true
    })
    
    end_time = System.monotonic_time()
    duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)
    
    IO.puts("Reactor execution completed in #{duration}ms")
    
    case result do
      {:ok, final_result} ->
        IO.puts("✅ Reactor execution successful!")
        IO.puts("Final result trace ID: #{final_result.trace_id}")
        IO.puts("Trace ID match: #{final_result.trace_id == test_trace_id}")
        IO.puts("Trace verification: #{get_in(final_result, [:final_result, :trace_verified])}")
        
        # Collect and analyze telemetry
        :timer.sleep(100) # Allow telemetry events to arrive
        telemetry_events = collect_test_telemetry(telemetry_ref, 1000)
        analyze_reactor_trace_telemetry(telemetry_events, test_trace_id)
        
      {:error, reason} ->
        IO.puts("❌ Reactor execution failed: #{inspect(reason)}")
    end
    
    cleanup_test_telemetry(telemetry_ref)
    
    IO.puts("\n✅ Reactor Trace ID Test Complete")
  end
  
  def run_concurrent_reactor_test do
    IO.puts("\n⚡ Concurrent Reactor Trace ID Test")
    IO.puts("=" |> String.duplicate(50))
    
    # Setup telemetry
    telemetry_ref = setup_test_telemetry()
    
    # Run 3 concurrent reactors with different trace IDs
    reactor_count = 3
    
    tasks = Enum.map(1..reactor_count, fn i ->
      Task.async(fn ->
        trace_id = "concurrent-reactor-#{i}-#{System.system_time(:nanosecond)}"
        
        Logger.info("Starting concurrent reactor #{i} with trace ID: #{trace_id}")
        
        result = Reactor.run(__MODULE__, %{
          input_data: %{
            reactor_index: i,
            test: "concurrent_trace_isolation"
          }
        }, %{
          trace_id: trace_id,
          reactor_index: i
        })
        
        case result do
          {:ok, final_result} ->
            %{
              reactor_index: i,
              trace_id: trace_id,
              final_trace_id: final_result.trace_id,
              success: true,
              trace_consistent: final_result.trace_id == trace_id
            }
          {:error, reason} ->
            %{
              reactor_index: i,
              trace_id: trace_id,
              success: false,
              error: reason
            }
        end
      end)
    end)
    
    concurrent_results = Task.await_many(tasks, 30_000)
    
    # Analyze concurrent execution
    successful_reactors = Enum.count(concurrent_results, & &1.success)
    trace_consistent_reactors = Enum.count(concurrent_results, & &1[:trace_consistent])
    
    IO.puts("Concurrent reactors executed: #{reactor_count}")
    IO.puts("Successful executions: #{successful_reactors}/#{reactor_count}")
    IO.puts("Trace-consistent executions: #{trace_consistent_reactors}/#{reactor_count}")
    
    for result <- concurrent_results do
      status = if result.success, do: "✅", else: "❌"
      trace_status = if result[:trace_consistent], do: "✅", else: "❌"
      
      IO.puts("  Reactor #{result.reactor_index}: #{status} Success, #{trace_status} Trace consistent")
      IO.puts("    Trace ID: #{result.trace_id}")
      if result[:final_trace_id] do
        IO.puts("    Final Trace ID: #{result.final_trace_id}")
      end
    end
    
    # Analyze telemetry for concurrent execution
    :timer.sleep(200) # Allow all telemetry events to arrive
    telemetry_events = collect_test_telemetry(telemetry_ref, 2000)
    analyze_concurrent_trace_telemetry(telemetry_events, concurrent_results)
    
    cleanup_test_telemetry(telemetry_ref)
    
    concurrent_results
  end
  
  # Telemetry functions
  
  defp setup_test_telemetry do
    ref = make_ref()
    
    events = [
      [:test_reactor, :step, :start],
      [:test_reactor, :step, :n8n_export],
      [:test_reactor, :step, :execution],
      [:self_sustaining, :reactor, :execution, :start],
      [:self_sustaining, :reactor, :execution, :complete],
      [:self_sustaining, :reactor, :step, :start],
      [:self_sustaining, :reactor, :step, :complete]
    ]
    
    for event <- events do
      :telemetry.attach(
        "reactor-trace-test-#{System.unique_integer()}",
        event,
        fn event_name, measurements, metadata, {pid, events_ref} ->
          send(pid, {:reactor_trace_event, events_ref, %{
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
  
  defp collect_test_telemetry(ref, timeout) do
    collect_telemetry_loop(ref, [], System.monotonic_time(:millisecond) + timeout)
  end
  
  defp collect_telemetry_loop(ref, events, end_time) do
    if System.monotonic_time(:millisecond) >= end_time do
      events
    else
      receive do
        {:reactor_trace_event, ^ref, event} ->
          collect_telemetry_loop(ref, [event | events], end_time)
      after
        50 ->
          collect_telemetry_loop(ref, events, end_time)
      end
    end
  end
  
  defp cleanup_test_telemetry(_ref) do
    :telemetry.list_handlers([])
    |> Enum.filter(fn handler -> String.starts_with?(handler.id, "reactor-trace-test-") end)
    |> Enum.each(fn handler -> :telemetry.detach(handler.id) end)
  end
  
  defp analyze_reactor_trace_telemetry(events, expected_trace_id) do
    IO.puts("\n📊 Reactor Trace Telemetry Analysis")
    IO.puts("-" |> String.duplicate(40))
    
    IO.puts("Total telemetry events: #{length(events)}")
    IO.puts("Expected trace ID: #{expected_trace_id}")
    
    # Group events by source
    step_events = Enum.filter(events, fn event ->
      match?([:test_reactor, :step, _], event.event)
    end)
    
    middleware_events = Enum.filter(events, fn event ->
      match?([:self_sustaining, :reactor, _, _], event.event)
    end)
    
    IO.puts("Step events: #{length(step_events)}")
    IO.puts("Middleware events: #{length(middleware_events)}")
    
    # Check trace ID consistency in step events
    step_trace_consistency = Enum.map(step_events, fn event ->
      trace_id = get_in(event, [:measurements, :trace_id])
      %{
        event: List.last(event.event),
        trace_id: trace_id,
        consistent: trace_id == expected_trace_id
      }
    end)
    
    IO.puts("\nStep Trace ID Analysis:")
    for step <- step_trace_consistency do
      status = if step.consistent, do: "✅", else: "❌"
      IO.puts("  #{step.event}: #{status} #{step.trace_id}")
    end
    
    # Check middleware trace ID consistency  
    middleware_trace_consistency = Enum.map(middleware_events, fn event ->
      trace_id = get_in(event, [:measurements, :trace_id])
      %{
        event: Enum.take(event.event, -1) |> List.first(),
        trace_id: trace_id,
        consistent: trace_id == expected_trace_id
      }
    end)
    
    IO.puts("\nMiddleware Trace ID Analysis:")
    for middleware <- middleware_trace_consistency do
      status = if middleware.consistent, do: "✅", else: "❌"
      IO.puts("  #{middleware.event}: #{status} #{middleware.trace_id}")
    end
    
    # Overall consistency
    all_consistent = Enum.all?(step_trace_consistency ++ middleware_trace_consistency, & &1.consistent)
    IO.puts("\nOverall trace ID consistency: #{if all_consistent, do: "✅ PERFECT", else: "❌ ISSUES"}")
  end
  
  defp analyze_concurrent_trace_telemetry(events, concurrent_results) do
    IO.puts("\n📊 Concurrent Trace Telemetry Analysis")
    IO.puts("-" |> String.duplicate(40))
    
    # Group events by trace ID
    events_by_trace = Enum.group_by(events, fn event ->
      get_in(event, [:measurements, :trace_id])
    end)
    
    expected_trace_ids = Enum.map(concurrent_results, & &1.trace_id) |> Enum.reject(&is_nil/1)
    
    IO.puts("Expected trace IDs: #{length(expected_trace_ids)}")
    IO.puts("Actual trace IDs in telemetry: #{map_size(events_by_trace)}")
    
    # Check if all expected trace IDs appear in telemetry
    missing_traces = expected_trace_ids -- Map.keys(events_by_trace)
    unexpected_traces = Map.keys(events_by_trace) -- expected_trace_ids
    
    IO.puts("Missing trace IDs: #{length(missing_traces)}")
    IO.puts("Unexpected trace IDs: #{length(unexpected_traces)}")
    
    if length(missing_traces) > 0 do
      IO.puts("  Missing: #{inspect(missing_traces)}")
    end
    
    if length(unexpected_traces) > 0 do
      IO.puts("  Unexpected: #{inspect(unexpected_traces)}")
    end
    
    # Analyze trace isolation
    for {trace_id, trace_events} <- events_by_trace do
      reactor_indices = trace_events
                       |> Enum.map(fn event -> get_in(event, [:metadata, :reactor_index]) end)
                       |> Enum.uniq()
                       |> Enum.reject(&is_nil/1)
      
      isolation_ok = length(reactor_indices) <= 1
      status = if isolation_ok, do: "✅", else: "⚠️"
      
      IO.puts("  #{trace_id}: #{status} #{length(trace_events)} events, reactors: #{inspect(reactor_indices)}")
    end
    
    # Overall assessment
    perfect_isolation = missing_traces == [] and unexpected_traces == [] and 
                       Enum.all?(events_by_trace, fn {_trace_id, trace_events} ->
                         reactor_indices = trace_events
                                          |> Enum.map(fn event -> get_in(event, [:metadata, :reactor_index]) end)
                                          |> Enum.uniq()
                                          |> Enum.reject(&is_nil/1)
                         length(reactor_indices) <= 1
                       end)
    
    IO.puts("\nConcurrent trace isolation: #{if perfect_isolation, do: "✅ PERFECT", else: "⚠️ ISSUES"}")
  end
end

# Run the tests
case System.argv() do
  [] ->
    ReactorTraceIdTest.run_reactor_trace_test()
    ReactorTraceIdTest.run_concurrent_reactor_test()
  ["single"] ->
    ReactorTraceIdTest.run_reactor_trace_test()
  ["concurrent"] ->
    ReactorTraceIdTest.run_concurrent_reactor_test()
  _ ->
    IO.puts("Usage: elixir reactor_trace_id_test.exs [single|concurrent]")
    IO.puts("Or run without arguments for full test suite")
end