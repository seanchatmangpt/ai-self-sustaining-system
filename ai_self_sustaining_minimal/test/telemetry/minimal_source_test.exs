defmodule AiSelfSustainingMinimal.Telemetry.MinimalSourceTest do
  @moduledoc """
  Minimal test to verify source tracking without complex DSL.
  """
  
  use ExUnit.Case, async: false
  
  # Simple module with basic macro for source tracking
  defmodule SimpleSourceTracker do
    defmacro with_tracking(metadata \\ %{}, do: body) do
      # Capture source information at call site
      caller_file = __CALLER__.file
      caller_module = __CALLER__.module
      caller_function = __CALLER__.function
      
      quote do
        # Build context with captured source info
        context_info = %{
          code_filepath: unquote(caller_file),
          code_namespace: unquote(caller_module),
          code_function: unquote(caller_function),
          code_commit_id: System.get_env("GIT_SHA") || "dev",
          captured_at: System.system_time(:microsecond)
        }
        
        # Merge with metadata
        full_metadata = Map.merge(context_info, unquote(metadata))
        
        # Execute with telemetry
        start_time = System.monotonic_time(:microsecond)
        result = unquote(body)
        end_time = System.monotonic_time(:microsecond)
        
        # Emit telemetry event
        :telemetry.execute(
          [:minimal, :source, :test],
          %{duration_us: end_time - start_time},
          full_metadata
        )
        
        result
      end
    end
  end
  
  setup_all do
    # Set test environment
    System.put_env("GIT_SHA", "minimal_test_abc123")
    
    # Attach telemetry handler
    :telemetry.attach(
      "minimal_source_test",
      [:minimal, :source, :test],
      &collect_minimal_telemetry/4,
      %{test_pid: self()}
    )
    
    on_exit(fn ->
      :telemetry.detach("minimal_source_test")
      System.delete_env("GIT_SHA")
    end)
    
    :ok
  end
  
  describe "minimal source tracking" do
    test "captures file path correctly" do
      import SimpleSourceTracker
      
      # Call macro that should capture source info
      result = with_tracking %{test_type: "filepath"} do
        :timer.sleep(5)
        "test_result"
      end
      
      assert result == "test_result"
      
      # Check telemetry
      assert_receive {:minimal_telemetry, event_name, measurements, metadata}, 1000
      
      assert event_name == [:minimal, :source, :test]
      assert measurements.duration_us > 0
      
      # Verify file path captured
      assert metadata.code_filepath =~ "minimal_source_test.exs"
      
      IO.puts("\n✅ Minimal Source Tracking Test:")
      IO.puts("   File: #{metadata.code_filepath}")
      IO.puts("   Module: #{metadata.code_namespace}")
      IO.puts("   Function: #{inspect(metadata.code_function)}")
      IO.puts("   Commit: #{metadata.code_commit_id}")
      IO.puts("   Duration: #{measurements.duration_us}μs")
    end
    
    test "captures function names from different locations" do
      import SimpleSourceTracker
      
      # Test from test function
      result1 = test_function_one()
      assert result1 == "function_one"
      
      # Test from another function  
      result2 = test_function_two()
      assert result2 == "function_two"
      
      # Collect telemetry events
      events = collect_all_events()
      assert length(events) >= 2
      
      # Verify different functions captured
      functions = 
        events
        |> Enum.map(fn {_name, _measurements, metadata} -> metadata.code_function end)
        |> Enum.uniq()
      
      assert length(functions) >= 2
      
      IO.puts("\n✅ Function Differentiation:")
      Enum.each(functions, fn func ->
        IO.puts("   Function: #{inspect(func)}")
      end)
    end
    
    test "information theory validation with real data" do
      import SimpleSourceTracker
      
      # Generate multiple telemetry events
      Enum.each(1..10, fn i ->
        with_tracking %{iteration: i, test_batch: "mi_validation"} do
          :timer.sleep(i)  # Variable duration
          "result_#{i}"
        end
      end)
      
      # Collect all events
      events = collect_all_events()
      assert length(events) >= 10
      
      # Calculate information metrics
      unique_filepaths = events |> Enum.map(fn {_,_,m} -> m.code_filepath end) |> Enum.uniq() |> length()
      unique_functions = events |> Enum.map(fn {_,_,m} -> m.code_function end) |> Enum.uniq() |> length()
      unique_commits = events |> Enum.map(fn {_,_,m} -> m.code_commit_id end) |> Enum.uniq() |> length()
      
      # Estimate entropy (simplified)
      estimated_entropy = 
        :math.log2(unique_filepaths) + 
        :math.log2(max(unique_functions, 1)) + 
        :math.log2(max(unique_commits, 1))
      
      # Estimate bytes (simplified)
      sample_metadata = events |> List.first() |> elem(2)
      estimated_bytes = byte_size(inspect(sample_metadata))
      
      efficiency = estimated_entropy / estimated_bytes
      
      IO.puts("\n✅ Information Theory Validation:")
      IO.puts("   Unique Filepaths: #{unique_filepaths}")
      IO.puts("   Unique Functions: #{unique_functions}")
      IO.puts("   Unique Commits: #{unique_commits}")
      IO.puts("   Estimated Entropy: #{Float.round(estimated_entropy, 2)} bits")
      IO.puts("   Estimated Bytes: #{estimated_bytes}")
      IO.puts("   Efficiency: #{Float.round(efficiency, 4)} bits/byte")
      
      # Should achieve reasonable efficiency
      assert efficiency > 0.01, "Efficiency too low: #{efficiency}"
      assert estimated_entropy > 1.0, "Entropy too low: #{estimated_entropy}"
    end
  end
  
  # Helper functions for testing different call sites
  
  defp test_function_one do
    import SimpleSourceTracker
    
    with_tracking %{source: "function_one"} do
      "function_one"
    end
  end
  
  defp test_function_two do
    import SimpleSourceTracker
    
    with_tracking %{source: "function_two"} do
      "function_two"
    end
  end
  
  defp collect_all_events do
    collect_events([])
  end
  
  defp collect_events(acc) do
    receive do
      {:minimal_telemetry, event_name, measurements, metadata} ->
        collect_events([{event_name, measurements, metadata} | acc])
    after 100 ->
      Enum.reverse(acc)
    end
  end
  
  defp collect_minimal_telemetry(event_name, measurements, metadata, config) do
    send(config.test_pid, {:minimal_telemetry, event_name, measurements, metadata})
  end
end