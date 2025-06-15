defmodule SelfSustaining.ReactorMiddleware.DebugMiddlewareTest do
  use ExUnit.Case, async: true
  
  import ExUnit.CaptureLog
  require Logger
  
  defmodule TestReactor do
    use Reactor
    
    input :test_value
    
    step :simple_step do
      argument :value, input(:test_value)
      
      run fn args, _context ->
        {:ok, "processed_#{args.value}"}
      end
    end
    
    step :final_step do
      argument :processed, result(:simple_step)
      
      run fn args, _context ->
        {:ok, "final_#{args.processed}"}
      end
    end
    
    return :final_step
  end
  
  test "debug middleware logs reactor execution events" do
    # Enable info level logging for this test
    Logger.configure(level: :info)
    
    context = %{
      verbose: false
    }
    
    log_output = capture_log(fn ->
      {:ok, reactor_with_middleware} = Reactor.Builder.add_middleware(TestReactor.reactor(), SelfSustaining.ReactorMiddleware.DebugMiddleware)
      result = Reactor.run(reactor_with_middleware, %{test_value: "hello"}, context)
      
      assert {:ok, "final_processed_hello"} = result
    end)
    
    # Verify the debug middleware logged the events
    assert log_output =~ "🚀 SelfSustaining Reactor started execution."
    assert log_output =~ "▶️ Step `simple_step` started"
    assert log_output =~ "✅ Step `simple_step` completed successfully"
    assert log_output =~ "▶️ Step `final_step` started"
    assert log_output =~ "✅ Step `final_step` completed successfully"
    assert log_output =~ "✅ SelfSustaining Reactor execution completed successfully."
  end
  
  test "debug middleware logs verbose context information when verbose is enabled" do
    Logger.configure(level: :info)
    
    context = %{
      verbose: true,
      agent_id: "test_agent_123"
    }
    
    log_output = capture_log(fn ->
      {:ok, reactor_with_middleware} = Reactor.Builder.add_middleware(TestReactor.reactor(), SelfSustaining.ReactorMiddleware.DebugMiddleware)
      result = Reactor.run(reactor_with_middleware, %{test_value: "verbose_test"}, context)
      
      assert {:ok, "final_processed_verbose_test"} = result
    end)
    
    # Verify verbose context information is logged
    assert log_output =~ "🚀 SelfSustaining Reactor started execution."
    assert log_output =~ "📌 Context:"
    assert log_output =~ "agent_id"
    assert log_output =~ "test_agent_123"
  end
  
  test "debug middleware logs errors when step fails" do
    defmodule FailingReactor do
      use Reactor
      
      input :test_value
      
      step :failing_step do
        argument :value, input(:test_value)
        
        run fn _args, _context ->
          {:error, "intentional failure"}
        end
      end
      
      return :failing_step
    end
    
    Logger.configure(level: :info)
    
    log_output = capture_log(fn ->
      {:ok, reactor_with_middleware} = Reactor.Builder.add_middleware(FailingReactor.reactor(), SelfSustaining.ReactorMiddleware.DebugMiddleware)
      result = Reactor.run(reactor_with_middleware, %{test_value: "test"})
      
      assert {:error, _} = result
    end)
    
    # Verify error logging
    assert log_output =~ "🚀 SelfSustaining Reactor started execution."
    assert log_output =~ "▶️ Step `failing_step` started"
    assert log_output =~ "❌ Step `failing_step` encountered an error"
  end
end