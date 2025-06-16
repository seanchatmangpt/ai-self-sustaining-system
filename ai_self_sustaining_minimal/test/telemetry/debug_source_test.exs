defmodule AiSelfSustainingMinimal.Telemetry.DebugSourceTest.TestMacro do
  @moduledoc false
  
  defmacro test_with_source(do: body) do
    caller_file = __CALLER__.file
    caller_module = __CALLER__.module
    caller_function = __CALLER__.function
    
    quote do
      IO.puts("📍 Macro executing...")
      IO.puts("   File: #{unquote(caller_file)}")
      IO.puts("   Module: #{unquote(caller_module)}")
      IO.puts("   Function: #{unquote(inspect(caller_function))}")
      
      result = unquote(body)
      
      :telemetry.execute(
        [:debug, :test],
        %{macro_test: true},
        %{
          code_filepath: unquote(caller_file),
          code_namespace: unquote(caller_module),
          code_function: unquote(caller_function)
        }
      )
      
      result
    end
  end
end

defmodule AiSelfSustainingMinimal.Telemetry.DebugSourceTest do
  @moduledoc """
  Debug test to verify basic telemetry functionality.
  """
  
  use ExUnit.Case, async: false
  
  setup_all do
    # Attach telemetry handler
    :telemetry.attach(
      "debug_test",
      [:debug, :test],
      fn event_name, measurements, metadata, config ->
        IO.puts("📡 Telemetry received: #{inspect(event_name)}")
        IO.puts("   Measurements: #{inspect(measurements)}")
        IO.puts("   Metadata: #{inspect(metadata)}")
        send(config.test_pid, {:debug_telemetry, event_name, measurements, metadata})
      end,
      %{test_pid: self()}
    )
    
    on_exit(fn ->
      :telemetry.detach("debug_test")
    end)
    
    :ok
  end
  
  describe "basic telemetry debug" do
    test "direct telemetry execute works" do
      IO.puts("\n🔍 Testing direct telemetry execution...")
      
      # Direct telemetry call
      :telemetry.execute(
        [:debug, :test],
        %{test_value: 42},
        %{source: "direct_call", file: __ENV__.file, module: __MODULE__}
      )
      
      # Check if we receive it
      assert_receive {:debug_telemetry, event_name, measurements, metadata}, 1000
      
      assert event_name == [:debug, :test]
      assert measurements.test_value == 42
      assert metadata.source == "direct_call"
      
      IO.puts("✅ Direct telemetry works!")
    end
    
    test "macro with source tracking" do
      IO.puts("\n🔍 Testing macro with source tracking...")
      
      import AiSelfSustainingMinimal.Telemetry.DebugSourceTest.TestMacro
      
      result = test_with_source do
        "macro_result"
      end
      
      assert result == "macro_result"
      
      # Check telemetry
      assert_receive {:debug_telemetry, event_name, measurements, metadata}, 1000
      
      assert event_name == [:debug, :test]
      assert measurements.macro_test == true
      assert metadata.code_filepath =~ "debug_source_test.exs"
      
      IO.puts("✅ Macro source tracking works!")
      IO.puts("   Captured file: #{metadata.code_filepath}")
      IO.puts("   Captured module: #{metadata.code_namespace}")
      IO.puts("   Captured function: #{inspect(metadata.code_function)}")
    end
    
    test "telemetry span works" do
      IO.puts("\n🔍 Testing telemetry span...")
      
      # Test telemetry span
      result = :telemetry.span(
        [:debug, :test],
        %{span_test: true, file: __ENV__.file},
        fn ->
          :timer.sleep(10)
          "span_result"
        end
      )
      
      assert result == "span_result"
      
      # Should receive start and stop events
      assert_receive {:debug_telemetry, [:debug, :test, :start], start_measurements, start_metadata}, 1000
      assert_receive {:debug_telemetry, [:debug, :test, :stop], stop_measurements, stop_metadata}, 1000
      
      assert start_metadata.span_test == true
      assert stop_measurements.duration > 0
      
      IO.puts("✅ Telemetry span works!")
      IO.puts("   Start metadata: #{inspect(start_metadata)}")
      IO.puts("   Stop duration: #{stop_measurements.duration}")
    end
  end
end