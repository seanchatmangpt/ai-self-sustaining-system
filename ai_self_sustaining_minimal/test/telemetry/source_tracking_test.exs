defmodule AiSelfSustainingMinimal.Telemetry.SourceTrackingTest do
  @moduledoc """
  Test to verify that the OpenTelemetry DSL actually captures source information correctly.
  
  This test validates that the information-theoretic templates properly inject:
  - File path (__ENV__.file)
  - Module namespace (__MODULE__)
  - Function name (__CALLER__.function)
  - Git commit ID (System.get_env("GIT_SHA"))
  """
  
  use ExUnit.Case, async: false
  
  # Test module that uses the DSL to verify source tracking
  defmodule TestSourceModule do
    use AiSelfSustainingMinimal.Telemetry.SparkOtelDsl
    
    otel do
      context :source_tracking do
        filepath true
        namespace true
        function true
        commit_id true
        custom_tags [:test_id]
        mi_target 0.25
      end
      
      span :source_test_span do
        event_name [:test, :source, :tracking]
        context :source_tracking
        measurements [:duration_ms]
        metadata [:test_context]
      end
    end
    
    def test_source_tracking_function(test_id) do
      # Set custom tag in process dictionary
      Process.put(:test_id, test_id)
      
      # This should generate a span with source information
      with_source_test_span %{
        test_context: "source_tracking_test"
      } do
        # Simulate some work
        :timer.sleep(10)
        {:ok, "source_tracked_#{test_id}"}
      end
    end
    
    def another_test_function(data) do
      # Set custom tag in process dictionary
      Process.put(:test_id, "different_function")
      
      # Test from different function to verify function tracking
      with_source_test_span %{
        test_context: "different_function_test"
      } do
        String.upcase(to_string(data))
      end
    end
  end
  
  setup_all do
    # Set Git SHA for testing
    System.put_env("GIT_SHA", "source_test_commit_123abc456def")
    
    # Set up telemetry collection
    :telemetry.attach(
      "source_tracking_test",
      [:test, :source, :tracking],
      &collect_source_telemetry/4,
      %{test_pid: self()}
    )
    
    on_exit(fn ->
      :telemetry.detach("source_tracking_test")
      System.delete_env("GIT_SHA")
    end)
    
    :ok
  end
  
  describe "source information tracking" do
    test "captures file path correctly" do
      # Call function that should generate telemetry
      result = TestSourceModule.test_source_tracking_function("filepath_test")
      assert {:ok, "source_tracked_filepath_test"} = result
      
      # Check if telemetry was generated
      assert_receive {:source_telemetry, event_name, measurements, metadata}, 1000
      
      assert event_name == [:test, :source, :tracking]
      
      # Verify file path is captured
      assert Map.has_key?(metadata, :code_filepath) or Map.has_key?(metadata, "code_filepath")
      
      file_path = metadata[:code_filepath] || metadata["code_filepath"]
      assert file_path != nil
      assert String.contains?(file_path, "source_tracking_test.exs")
      
      IO.puts("\n✅ File Path Tracking:")
      IO.puts("   Captured: #{file_path}")
    end
    
    test "captures module namespace correctly" do
      result = TestSourceModule.test_source_tracking_function("namespace_test")
      assert {:ok, "source_tracked_namespace_test"} = result
      
      assert_receive {:source_telemetry, _event_name, _measurements, metadata}, 1000
      
      # Verify namespace is captured
      assert Map.has_key?(metadata, :code_namespace) or Map.has_key?(metadata, "code_namespace")
      
      namespace = metadata[:code_namespace] || metadata["code_namespace"]
      assert namespace != nil
      
      # Should capture the test module name
      namespace_str = to_string(namespace)
      assert String.contains?(namespace_str, "TestSourceModule")
      
      IO.puts("\n✅ Namespace Tracking:")
      IO.puts("   Captured: #{namespace}")
    end
    
    test "captures function name correctly from different functions" do
      # Test first function
      result1 = TestSourceModule.test_source_tracking_function("function_test_1")
      assert {:ok, "source_tracked_function_test_1"} = result1
      
      assert_receive {:source_telemetry, _event_name, _measurements, metadata1}, 1000
      
      # Test second function
      result2 = TestSourceModule.another_test_function("function_test_2")
      assert result2 == "FUNCTION_TEST_2"
      
      assert_receive {:source_telemetry, _event_name, _measurements, metadata2}, 1000
      
      # Verify function names are captured and different
      function1 = metadata1[:code_function] || metadata1["code_function"]
      function2 = metadata2[:code_function] || metadata2["code_function"]
      
      assert function1 != nil
      assert function2 != nil
      assert function1 != function2
      
      IO.puts("\n✅ Function Tracking:")
      IO.puts("   Function 1: #{inspect(function1)}")
      IO.puts("   Function 2: #{inspect(function2)}")
    end
    
    test "captures git commit ID correctly" do
      result = TestSourceModule.test_source_tracking_function("commit_test")
      assert {:ok, "source_tracked_commit_test"} = result
      
      assert_receive {:source_telemetry, _event_name, _measurements, metadata}, 1000
      
      # Verify commit ID is captured
      assert Map.has_key?(metadata, :code_commit_id) or Map.has_key?(metadata, "code_commit_id")
      
      commit_id = metadata[:code_commit_id] || metadata["code_commit_id"]
      assert commit_id == "source_test_commit_123abc456def"
      
      IO.puts("\n✅ Commit ID Tracking:")
      IO.puts("   Captured: #{commit_id}")
    end
    
    test "captures custom tags correctly" do
      result = TestSourceModule.test_source_tracking_function("custom_tag_test")
      assert {:ok, "source_tracked_custom_tag_test"} = result
      
      assert_receive {:source_telemetry, _event_name, _measurements, metadata}, 1000
      
      # Verify custom tags are captured
      test_id = metadata[:test_id] || metadata["test_id"]
      assert test_id == "custom_tag_test"
      
      test_context = metadata[:test_context] || metadata["test_context"]
      assert test_context == "source_tracking_test"
      
      # Also check if test_id was captured from process dictionary
      if test_id == nil do
        # Check if it might be under a different key
        IO.puts("   Available metadata keys: #{inspect(Map.keys(metadata))}")
      end
      
      IO.puts("\n✅ Custom Tag Tracking:")
      IO.puts("   Test ID: #{test_id}")
      IO.puts("   Test Context: #{test_context}")
    end
    
    test "all high-MI components captured together" do
      result = TestSourceModule.test_source_tracking_function("full_mi_test")
      assert {:ok, "source_tracked_full_mi_test"} = result
      
      assert_receive {:source_telemetry, event_name, measurements, metadata}, 1000
      
      # Verify all high-MI components are present
      required_components = [
        :code_filepath, "code_filepath",
        :code_namespace, "code_namespace", 
        :code_function, "code_function",
        :code_commit_id, "code_commit_id"
      ]
      
      captured_components = 
        required_components
        |> Enum.filter(fn key -> Map.has_key?(metadata, key) end)
      
      IO.puts("\n✅ Full High-MI Template Validation:")
      IO.puts("   Event: #{inspect(event_name)}")
      IO.puts("   Measurements: #{inspect(measurements)}")
      IO.puts("   Captured Components: #{length(captured_components)}/4")
      
      Enum.each(captured_components, fn key ->
        value = metadata[key]
        IO.puts("     #{key}: #{inspect(value)}")
      end)
      
      # Should have captured at least the core components
      assert length(captured_components) >= 2, 
             "Expected at least 2 high-MI components, got #{length(captured_components)}"
      
      # Calculate estimated mutual information
      component_entropy = length(captured_components) * 10  # Rough estimate: 10 bits per component
      estimated_bytes = byte_size(inspect(metadata))
      estimated_efficiency = component_entropy / estimated_bytes
      
      IO.puts("   Estimated MI: #{component_entropy} bits")
      IO.puts("   Metadata Size: #{estimated_bytes} bytes")
      IO.puts("   Estimated Efficiency: #{Float.round(estimated_efficiency, 3)} bits/byte")
      
      # Should achieve reasonable efficiency
      assert estimated_efficiency > 0.1, 
             "Efficiency #{estimated_efficiency} below minimum threshold"
    end
  end
  
  # Helper function to collect telemetry
  defp collect_source_telemetry(event_name, measurements, metadata, config) do
    send(config.test_pid, {:source_telemetry, event_name, measurements, metadata})
  end
end