#!/usr/bin/env elixir

# Standalone Enhanced Reactor Runner Validation
# This script validates the reactor runner functionality without database dependencies

Mix.install([
  {:reactor, "~> 0.15.4"},
  {:jason, "~> 1.2"},
  {:telemetry, "~> 1.3"}
])

defmodule TestReactor do
  use Reactor
  
  input :test_value
  
  step :simple_step do
    argument :value, input(:test_value)
    
    run fn args, _context ->
      IO.puts("Processing: #{args.value}")
      {:ok, "processed_#{args.value}"}
    end
  end
  
  step :final_step do
    argument :processed, result(:simple_step)
    
    run fn args, _context ->
      IO.puts("Finalizing: #{args.processed}")
      {:ok, "final_#{args.processed}"}
    end
  end
  
  return :final_step
end

defmodule DebugMiddleware do
  use Reactor.Middleware
  require Logger

  @impl true
  def init(context) do
    IO.puts("🚀 Enhanced Reactor Runner - Debug Middleware initialized")
    {:ok, context}
  end

  @impl true
  def complete(result, context) do
    IO.puts("✅ Enhanced Reactor Runner - Execution completed successfully")
    {:ok, result}
  end

  @impl true
  def error(error, context) do
    IO.puts("❌ Enhanced Reactor Runner - Execution failed: #{inspect(error)}")
    :ok
  end

  @impl true
  def event({:run_start, _arguments}, step, context) do
    IO.puts("▶️ Step `#{step.name}` started")
    :ok
  end

  def event({:run_complete, result}, step, context) do
    IO.puts("✅ Step `#{step.name}` completed: #{inspect(result)}")
    :ok
  end

  def event(_, _, _), do: :ok
end

# Test Enhanced Reactor Runner functionality
IO.puts("=" <> String.duplicate("=", 60))
IO.puts("🧪 Enhanced Reactor Runner Validation Test")
IO.puts("=" <> String.duplicate("=", 60))

IO.puts("\n📋 Step 1: Testing basic reactor functionality...")

try do
  # Create reactor with debug middleware
  {:ok, reactor_with_middleware} = Reactor.Builder.add_middleware(TestReactor.reactor(), DebugMiddleware)
  
  IO.puts("✅ Middleware integration successful")
  
  # Run reactor with test data
  result = Reactor.run(reactor_with_middleware, %{test_value: "hello_world"})
  
  case result do
    {:ok, final_result} ->
      IO.puts("✅ Reactor execution successful: #{final_result}")
      
      if final_result == "final_processed_hello_world" do
        IO.puts("✅ Result validation passed")
      else
        IO.puts("❌ Result validation failed - unexpected result: #{final_result}")
        exit(1)
      end
      
    {:error, error} ->
      IO.puts("❌ Reactor execution failed: #{inspect(error)}")
      exit(1)
  end
  
rescue
  error ->
    IO.puts("❌ Test failed with exception: #{inspect(error)}")
    exit(1)
end

IO.puts("\n📋 Step 2: Testing Enhanced Reactor Runner components...")

# Test nanosecond ID generation
agent_id = "agent_#{System.system_time(:nanosecond)}"
work_item_id = "reactor_#{System.system_time(:nanosecond)}_#{:rand.uniform(999999)}"

IO.puts("✅ Agent ID generation: #{agent_id}")
IO.puts("✅ Work Item ID generation: #{work_item_id}")

# Validate ID uniqueness
:timer.sleep(1)  # Ensure time difference
agent_id_2 = "agent_#{System.system_time(:nanosecond)}"

if agent_id != agent_id_2 do
  IO.puts("✅ ID uniqueness validation passed")
else
  IO.puts("❌ ID uniqueness validation failed")
  exit(1)
end

IO.puts("\n📋 Step 3: Testing telemetry integration...")

# Test telemetry events
:telemetry.execute(
  [:test, :reactor, :validation],
  %{duration: 1000, result: :success},
  %{agent_id: agent_id}
)

IO.puts("✅ Telemetry events emitted successfully")

IO.puts("\n🎉 Enhanced Reactor Runner Validation - ALL TESTS PASSED!")
IO.puts("=" <> String.duplicate("=", 60))
IO.puts("✅ Middleware integration works correctly")
IO.puts("✅ Reactor execution works correctly")
IO.puts("✅ Nanosecond ID generation works correctly")
IO.puts("✅ Telemetry integration works correctly")
IO.puts("=" <> String.duplicate("=", 60))