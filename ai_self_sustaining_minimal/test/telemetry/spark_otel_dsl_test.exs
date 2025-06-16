defmodule AiSelfSustainingMinimal.Telemetry.SparkOtelDslTest do
  @moduledoc """
  Comprehensive test suite for Spark OpenTelemetry DSL with real integration validation.
  
  ## Test Objectives
  
  1. **DSL Compilation**: Verify DSL compiles to working macros
  2. **OpenTelemetry Integration**: Test actual telemetry data collection
  3. **MI Calculation Validation**: Verify information theory calculations
  4. **Performance Validation**: Measure claimed efficiency improvements
  5. **Real-world Usage**: Test with coordination operations
  """
  
  use ExUnit.Case, async: false
  
  import ExUnit.CaptureLog
  
  alias AiSelfSustainingMinimal.Telemetry.{Context, Span}
  
  # Test module that uses the DSL
  defmodule TestCoordinationModule do
    use AiSelfSustainingMinimal.Telemetry.SparkOtelDsl
    
    otel do
      # High-MI context template
      context :test_high_mi do
        filepath true
        namespace true
        function true
        commit_id true
        custom_tags [:agent_id, :operation_type]
        mi_target 0.25
      end
      
      # Low-MI context for comparison
      context :test_low_mi do
        filepath false
        namespace true
        function false
        commit_id false
        custom_tags []
        mi_target 0.1
      end
      
      # Test spans with different contexts
      span :coordination_operation do
        event_name [:test, :coordination, :operation]
        context :test_high_mi
        measurements [:duration_ms, :memory_usage, :success]
        metadata [:agent_capabilities, :work_type, :priority]
      end
      
      span :simple_operation do
        event_name [:test, :simple]
        context :test_low_mi
        measurements [:duration_ms]
        metadata []
      end
      
      # Auto-instrumentation test
      auto_instrument do
        functions [test_function: 2, instrumented_call: 1]
        context :test_high_mi
        measurements [:response_time, :cpu_usage]
      end
      
      # MI analysis configuration
      analysis do
        measure_mi true
        export_format :jsonl
        export_path "test/fixtures/telemetry_test_output.jsonl"
        optimization_target 0.25
        auto_optimize false
        sample_rate 1.0
      end
    end
    
    def test_function(arg1, arg2) do
      # This should be auto-instrumented
      :timer.sleep(10)
      {arg1, arg2}
    end
    
    def instrumented_call(data) do
      # This should also be auto-instrumented
      String.upcase(to_string(data))
    end
    
    def coordination_operation_with_span(agent_id, work_item) do
      with_coordination_operation_span %{
        agent_id: agent_id,
        operation_type: "work_claim",
        agent_capabilities: ["coordination", "processing"],
        work_type: work_item.type,
        priority: work_item.priority
      } do
        # Simulate coordination work
        :timer.sleep(50)
        perform_coordination_logic(agent_id, work_item)
      end
    end
    
    def simple_operation_with_span(data) do
      with_simple_operation_span %{} do
        # Simple operation
        :timer.sleep(5)
        String.length(to_string(data))
      end
    end
    
    defp perform_coordination_logic(agent_id, work_item) do
      # Simulate complex coordination
      {:ok, "#{agent_id} processed #{work_item.id}"}
    end
  end
  
  setup_all do
    # Set up test environment variables
    System.put_env("GIT_SHA", "test_commit_abc123def456")
    
    # Set up telemetry collection
    :telemetry.attach_many(
      "test_otel_handler",
      [
        [:test, :coordination, :operation],
        [:test, :simple],
        [:test, :function, :test_function],
        [:test, :function, :instrumented_call]
      ],
      &collect_test_telemetry/4,
      %{collector_pid: self()}
    )
    
    # Initialize test data collection
    Agent.start_link(fn -> [] end, name: :test_telemetry_collector)
    
    on_exit(fn ->
      :telemetry.detach("test_otel_handler")
      Agent.stop(:test_telemetry_collector)
      System.delete_env("GIT_SHA")
    end)
    
    :ok
  end
  
  describe "DSL compilation and validation" do
    test "DSL compiles without errors" do
      # Verify the test module compiled successfully
      assert function_exported?(TestCoordinationModule, :test_function, 2)
      assert function_exported?(TestCoordinationModule, :coordination_operation_with_span, 2)
    end
    
    test "context validation works" do
      high_mi_context = %Context{
        name: :test_high_mi,
        filepath: true,
        namespace: true,
        function: true,
        commit_id: true,
        custom_tags: [:agent_id, :operation_type],
        mi_target: 0.25
      }
      
      assert Context.validate(high_mi_context) == :ok
      
      # Test invalid context
      invalid_context = %Context{
        name: nil,
        filepath: false,
        namespace: false,
        function: false,
        commit_id: false,
        custom_tags: [],
        mi_target: -1.0
      }
      
      assert {:error, errors} = Context.validate(invalid_context)
      assert length(errors) > 0
    end
    
    test "span validation works" do
      valid_span = %Span{
        name: :test_span,
        event_name: [:test, :operation],
        context: :test_high_mi,
        measurements: [:duration_ms],
        metadata: [:operation_type]
      }
      
      assert Span.validate(valid_span) == :ok
      
      # Test invalid span
      invalid_span = %Span{
        name: :test_span,
        event_name: [],
        measurements: [],
        metadata: []
      }
      
      assert {:error, errors} = Span.validate(invalid_span)
      assert "Empty event_name" in errors
    end
  end
  
  describe "OpenTelemetry integration" do
    test "high-MI spans generate expected telemetry data" do
      work_item = %{id: "work_123", type: "optimization", priority: "high"}
      
      result = TestCoordinationModule.coordination_operation_with_span("agent_456", work_item)
      
      # Verify operation completed
      assert {:ok, "agent_456 processed work_123"} = result
      
      # Wait for telemetry to be processed
      :timer.sleep(100)
      
      # Check telemetry was collected
      telemetry_events = Agent.get(:test_telemetry_collector, & &1)
      
      coordination_events = 
        Enum.filter(telemetry_events, fn event ->
          event.event_name == [:test, :coordination, :operation]
        end)
      
      assert length(coordination_events) > 0
      
      # Verify high-MI context data
      event = List.first(coordination_events)
      assert event.measurements[:duration_ms] > 0
      assert event.metadata[:agent_id] == "agent_456"
      assert event.metadata[:operation_type] == "work_claim"
      assert event.metadata[:work_type] == "optimization"
      assert event.metadata[:priority] == "high"
      
      # Verify context includes expected high-MI components
      assert String.contains?(event.metadata[:code_filepath] || "", ".exs")
      assert event.metadata[:code_namespace] != nil
      assert event.metadata[:code_function] != nil
      assert event.metadata[:code_commit_id] == "test_commit_abc123def456"
    end
    
    test "low-MI spans have minimal overhead" do
      result = TestCoordinationModule.simple_operation_with_span("test_data")
      
      assert result == 9  # Length of "test_data"
      
      :timer.sleep(50)
      
      telemetry_events = Agent.get(:test_telemetry_collector, & &1)
      
      simple_events = 
        Enum.filter(telemetry_events, fn event ->
          event.event_name == [:test, :simple]
        end)
      
      assert length(simple_events) > 0
      
      event = List.first(simple_events)
      
      # Low-MI context should have minimal data
      assert event.metadata[:code_filepath] == nil  # Disabled in low-MI context
      assert event.metadata[:code_function] == nil  # Disabled in low-MI context
      assert event.metadata[:code_commit_id] == nil # Disabled in low-MI context
      assert event.metadata[:code_namespace] != nil # Only namespace enabled
    end
    
    test "auto-instrumentation captures function calls" do
      # Call auto-instrumented functions
      result1 = TestCoordinationModule.test_function("arg1", "arg2")
      result2 = TestCoordinationModule.instrumented_call("hello")
      
      assert result1 == {"arg1", "arg2"}
      assert result2 == "HELLO"
      
      :timer.sleep(100)
      
      telemetry_events = Agent.get(:test_telemetry_collector, & &1)
      
      # Check for auto-instrumented events
      function_events = 
        Enum.filter(telemetry_events, fn event ->
          case event.event_name do
            [:test, :function, :test_function] -> true
            [:test, :function, :instrumented_call] -> true
            _ -> false
          end
        end)
      
      assert length(function_events) >= 2
    end
  end
  
  describe "mutual information calculations" do
    test "MI calculation produces reasonable results" do
      # Generate sample telemetry data
      sample_spans = generate_sample_telemetry_data(100)
      
      high_mi_context = %Context{
        name: :test_high_mi,
        filepath: true,
        namespace: true,
        function: true,
        commit_id: true,
        custom_tags: [:agent_id],
        mi_target: 0.25
      }
      
      low_mi_context = %Context{
        name: :test_low_mi,
        filepath: false,
        namespace: true,
        function: false,
        commit_id: false,
        custom_tags: [],
        mi_target: 0.1
      }
      
      high_mi_score = Context.calculate_mi_score(high_mi_context, sample_spans)
      low_mi_score = Context.calculate_mi_score(low_mi_context, sample_spans)
      
      # High-MI context should have more mutual information
      assert high_mi_score.mutual_information > low_mi_score.mutual_information
      
      # High-MI context should have higher bits per byte (better efficiency)
      assert high_mi_score.bits_per_byte > low_mi_score.bits_per_byte
      
      # Verify reasonable ranges
      assert high_mi_score.mutual_information > 10.0  # Should have significant information
      assert high_mi_score.bits_per_byte > 0.1        # Should be reasonably efficient
      assert high_mi_score.bytes_per_event < 500      # Should not be excessive
      
      IO.puts("\n=== Mutual Information Analysis ===")
      IO.puts("High-MI Context:")
      IO.puts("  Mutual Information: #{Float.round(high_mi_score.mutual_information, 2)} bits")
      IO.puts("  Bytes per Event: #{high_mi_score.bytes_per_event}")
      IO.puts("  Efficiency: #{Float.round(high_mi_score.bits_per_byte, 3)} bits/byte")
      
      IO.puts("\nLow-MI Context:")
      IO.puts("  Mutual Information: #{Float.round(low_mi_score.mutual_information, 2)} bits")
      IO.puts("  Bytes per Event: #{low_mi_score.bytes_per_event}")
      IO.puts("  Efficiency: #{Float.round(low_mi_score.bits_per_byte, 3)} bits/byte")
      
      efficiency_improvement = high_mi_score.bits_per_byte / low_mi_score.bits_per_byte
      IO.puts("\nEfficiency Improvement: #{Float.round(efficiency_improvement, 2)}x")
    end
    
    test "span MI contribution analysis" do
      sample_data = generate_sample_telemetry_data(50)
      
      coordination_span = %Span{
        name: :coordination_operation,
        event_name: [:test, :coordination, :operation],
        context: :test_high_mi,
        measurements: [:duration_ms, :memory_usage, :success],
        metadata: [:agent_capabilities, :work_type, :priority]
      }
      
      simple_span = %Span{
        name: :simple_operation,
        event_name: [:test, :simple],
        context: :test_low_mi,
        measurements: [:duration_ms],
        metadata: []
      }
      
      coord_analysis = Span.calculate_mi_contribution(coordination_span, sample_data)
      simple_analysis = Span.calculate_mi_contribution(simple_span, sample_data)
      
      # Coordination span should provide more unique information
      assert coord_analysis.unique_information > simple_analysis.unique_information
      
      # But should also have higher overhead
      assert coord_analysis.byte_overhead > simple_analysis.byte_overhead
      
      IO.puts("\n=== Span MI Contribution Analysis ===")
      IO.puts("Coordination Span:")
      IO.puts("  Unique Information: #{Float.round(coord_analysis.unique_information, 2)} bits")
      IO.puts("  Byte Overhead: #{coord_analysis.byte_overhead}")
      IO.puts("  Efficiency: #{Float.round(coord_analysis.efficiency_score, 3)} bits/byte")
      
      IO.puts("\nSimple Span:")
      IO.puts("  Unique Information: #{Float.round(simple_analysis.unique_information, 2)} bits")
      IO.puts("  Byte Overhead: #{simple_analysis.byte_overhead}")
      IO.puts("  Efficiency: #{Float.round(simple_analysis.efficiency_score, 3)} bits/byte")
    end
  end
  
  describe "performance characteristics" do
    test "span creation overhead is minimal" do
      # Measure overhead of creating spans
      {time_without_span, _} = :timer.tc(fn ->
        Enum.each(1..1000, fn _i ->
          :timer.sleep(1)
          "result"
        end)
      end)
      
      {time_with_span, _} = :timer.tc(fn ->
        Enum.each(1..1000, fn i ->
          TestCoordinationModule.simple_operation_with_span(i)
        end)
      end)
      
      overhead_per_span = (time_with_span - time_without_span) / 1000
      
      IO.puts("\n=== Performance Analysis ===")
      IO.puts("Time without spans: #{time_without_span} μs")
      IO.puts("Time with spans: #{time_with_span} μs")  
      IO.puts("Overhead per span: #{Float.round(overhead_per_span, 2)} μs")
      
      # Overhead should be less than 1ms per span
      assert overhead_per_span < 1000, "Span overhead too high: #{overhead_per_span} μs"
    end
    
    test "memory usage is reasonable" do
      # Measure memory before and after creating many spans
      :erlang.garbage_collect()
      {memory_before, _} = :erlang.process_info(self(), :memory)
      
      # Create many spans
      Enum.each(1..100, fn i ->
        TestCoordinationModule.coordination_operation_with_span(
          "agent_#{i}",
          %{id: "work_#{i}", type: "test", priority: "normal"}
        )
      end)
      
      :timer.sleep(200)  # Let telemetry process
      :erlang.garbage_collect()
      {memory_after, _} = :erlang.process_info(self(), :memory)
      
      memory_per_span = (memory_after - memory_before) / 100
      
      IO.puts("\n=== Memory Usage Analysis ===")
      IO.puts("Memory before: #{memory_before} bytes")
      IO.puts("Memory after: #{memory_after} bytes")
      IO.puts("Memory per span: #{Float.round(memory_per_span, 2)} bytes")
      
      # Memory per span should be reasonable (less than 1KB)
      assert memory_per_span < 1024, "Memory usage per span too high: #{memory_per_span} bytes"
    end
  end
  
  describe "real-world integration" do
    test "integration with coordination operations" do
      # Test integration with actual coordination module if available
      if Code.ensure_loaded?(AiSelfSustainingMinimal.Coordination.Agent) do
        # Create a test agent
        {:ok, agent} = AiSelfSustainingMinimal.Coordination.Agent
        |> Ash.Changeset.for_create(:register, %{
          agent_id: "test_agent_otel_#{System.unique_integer()}",
          capabilities: ["testing", "telemetry"],
          metadata: %{test: true}
        })
        |> Ash.create()
        
        # Simulate coordination operations with telemetry
        coordination_result = TestCoordinationModule.coordination_operation_with_span(
          agent.agent_id,
          %{id: "integration_test_work", type: "validation", priority: "high"}
        )
        
        assert {:ok, _} = coordination_result
        
        :timer.sleep(100)
        
        # Verify telemetry was collected with agent context
        telemetry_events = Agent.get(:test_telemetry_collector, & &1)
        
        coordination_events = 
          Enum.filter(telemetry_events, fn event ->
            event.event_name == [:test, :coordination, :operation] and
            event.metadata[:agent_id] == agent.agent_id
          end)
        
        assert length(coordination_events) > 0
        
        event = List.first(coordination_events)
        assert event.metadata[:agent_id] == agent.agent_id
        assert event.metadata[:work_type] == "validation"
        assert event.metadata[:priority] == "high"
      end
    end
  end
  
  # ========================================================================
  # Helper Functions
  # ========================================================================
  
  defp collect_test_telemetry(event_name, measurements, metadata, %{collector_pid: pid}) do
    telemetry_event = %{
      event_name: event_name,
      measurements: measurements,
      metadata: metadata,
      timestamp: System.system_time(:microsecond)
    }
    
    Agent.update(:test_telemetry_collector, fn events ->
      [telemetry_event | events]
    end)
  end
  
  defp generate_sample_telemetry_data(count) do
    Enum.map(1..count, fn i ->
      %{
        "event_name" => Enum.random([
          [:test, :coordination, :operation],
          [:test, :simple],
          [:test, :performance, :metric]
        ]),
        "measurements" => %{
          "duration_ms" => :rand.uniform(1000),
          "memory_usage" => :rand.uniform(1000000),
          "success" => Enum.random([true, false])
        },
        "metadata" => %{
          "code_filepath" => "/app/lib/module_#{rem(i, 10)}.ex",
          "code_namespace" => :"Module#{rem(i, 5)}",
          "code_function" => :"function_#{rem(i, 8)}",
          "code_commit_id" => "abc123def456",
          "agent_id" => "agent_#{rem(i, 3)}",
          "operation_type" => Enum.random(["claim", "complete", "start"]),
          "work_type" => Enum.random(["optimization", "validation", "analysis"])
        },
        "timestamp" => System.system_time(:microsecond)
      }
    end)
  end
end