defmodule AiSelfSustainingMinimal.Telemetry.SimpleDslTest do
  @moduledoc """
  Simple test to verify basic DSL compilation and functionality.
  """
  
  use ExUnit.Case, async: false
  
  alias AiSelfSustainingMinimal.Telemetry.{Context, Span}
  
  describe "basic DSL functionality" do
    test "Context struct creation and validation" do
      # Test valid context
      valid_context = %Context{
        name: :test_context,
        filepath: true,
        namespace: true,
        function: true,
        commit_id: true,
        custom_tags: [:agent_id],
        mi_target: 0.25
      }
      
      assert valid_context.name == :test_context
      assert valid_context.filepath == true
      assert valid_context.mi_target == 0.25
      
      # Test validation
      assert Context.validate(valid_context) == :ok
      
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
    
    test "Span struct creation and validation" do
      # Test valid span
      valid_span = %Span{
        name: :test_span,
        event_name: [:test, :operation],
        context: :high_mi,
        measurements: [:duration_ms, :memory_usage],
        metadata: [:operation_type, :agent_id],
        sample_rate: 1.0,
        enabled: true
      }
      
      assert valid_span.name == :test_span
      assert valid_span.event_name == [:test, :operation]
      assert valid_span.context == :high_mi
      
      # Test validation
      assert Span.validate(valid_span) == :ok
      
      # Test invalid span  
      invalid_span = %Span{
        name: :invalid,
        event_name: [],  # Empty event name
        measurements: [],
        metadata: []
      }
      
      assert {:error, errors} = Span.validate(invalid_span)
      assert "Empty event_name" in errors
    end
    
    test "MI calculation with sample data" do
      # Create a high-MI context
      high_mi_context = %Context{
        name: :high_mi_test,
        filepath: true,
        namespace: true,
        function: true,
        commit_id: true,
        custom_tags: [:agent_id, :session_id],
        mi_target: 0.25
      }
      
      # Generate sample telemetry data
      sample_data = generate_sample_data(50)
      
      # Calculate MI score
      mi_score = Context.calculate_mi_score(high_mi_context, sample_data)
      
      # Verify reasonable results
      assert mi_score.mutual_information > 0
      assert mi_score.bytes_per_event > 0
      assert mi_score.bits_per_byte > 0
      
      IO.puts("\nSimple MI Test Results:")
      IO.puts("  Mutual Information: #{Float.round(mi_score.mutual_information, 2)} bits")
      IO.puts("  Bytes per Event: #{mi_score.bytes_per_event}")
      IO.puts("  Efficiency: #{Float.round(mi_score.bits_per_byte, 3)} bits/byte")
    end
    
    test "telemetry event collection" do
      # Set up telemetry handler
      test_pid = self()
      
      :telemetry.attach(
        "simple_test_handler",
        [:simple, :test, :event],
        fn event_name, measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, event_name, measurements, metadata})
        end,
        %{}
      )
      
      # Emit a test event
      :telemetry.execute(
        [:simple, :test, :event],
        %{duration: 100, success: true},
        %{
          code_filepath: __ENV__.file,
          code_namespace: __MODULE__,
          code_function: :test,
          agent_id: "test_agent_123"
        }
      )
      
      # Verify event was received
      assert_receive {:telemetry_event, [:simple, :test, :event], measurements, metadata}, 1000
      
      assert measurements.duration == 100
      assert measurements.success == true
      assert metadata.agent_id == "test_agent_123"
      assert metadata.code_filepath =~ "simple_dsl_test.exs"
      
      # Clean up
      :telemetry.detach("simple_test_handler")
      
      IO.puts("\n✅ Basic telemetry event collection working")
    end
  end
  
  # Helper function to generate sample telemetry data
  defp generate_sample_data(count) do
    Enum.map(1..count, fn i ->
      %{
        "event_name" => [:test, :operation],
        "measurements" => %{
          "duration_ms" => :rand.uniform(1000),
          "memory_usage" => :rand.uniform(1000000),
          "success" => Enum.random([true, false])
        },
        "metadata" => %{
          "code_filepath" => "/app/lib/module_#{rem(i, 5)}.ex",
          "code_namespace" => "TestModule#{rem(i, 3)}",
          "code_function" => "function_#{rem(i, 4)}",
          "code_commit_id" => "abc123def456",
          "agent_id" => "agent_#{rem(i, 3)}",
          "session_id" => "session_#{rem(i, 2)}",
          "operation_type" => Enum.random(["claim", "complete", "start"])
        },
        "timestamp" => System.system_time(:microsecond)
      }
    end)
  end
end