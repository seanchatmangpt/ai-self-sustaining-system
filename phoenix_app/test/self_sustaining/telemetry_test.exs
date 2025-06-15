defmodule SelfSustaining.TelemetryTest do
  use ExUnit.Case, async: true
  
  require OpenTelemetry.Tracer
  
  describe "OpenTelemetry instrumentation" do
    test "basic tracing functionality" do
      # Test that spans can be created without errors
      result = OpenTelemetry.Tracer.with_span "test_span" do
        OpenTelemetry.Tracer.set_attributes([
          {"test.attribute", "value"},
          {"test.number", 42}
        ])
        "test_result"
      end
      
      assert result == "test_result"
    end
    
    test "telemetry events are emitted" do
      # Set up a test handler
      test_pid = self()
      
      :telemetry.attach(
        "test-handler",
        [:self_sustaining, :test],
        fn event, measurements, metadata, _ ->
          send(test_pid, {:telemetry_event, event, measurements, metadata})
        end,
        %{}
      )
      
      # Emit a test event
      :telemetry.execute(
        [:self_sustaining, :test],
        %{duration: 100},
        %{test: true}
      )
      
      # Verify the event was received
      assert_receive {:telemetry_event, [:self_sustaining, :test], %{duration: 100}, %{test: true}}
      
      # Clean up
      :telemetry.detach("test-handler")
    end
    
    test "AI telemetry configuration helper" do
      alias SelfSustaining.Telemetry.OpenTelemetryConfig
      
      # Test that the AI span helper works
      result = OpenTelemetryConfig.ai_span("test_operation", %{"test" => "value"}, fn ->
        "ai_test_result"
      end)
      
      assert result == "ai_test_result"
    end
    
    test "workflow telemetry configuration helper" do
      alias SelfSustaining.Telemetry.OpenTelemetryConfig
      
      # Test that the workflow span helper works
      result = OpenTelemetryConfig.workflow_span("test_operation", TestModule, %{"test" => "value"}, fn ->
        "workflow_test_result"
      end)
      
      assert result == "workflow_test_result"
    end
    
    test "telemetry metrics collection" do
      # Test the telemetry supervisor starts correctly
      {:ok, _pid} = SelfSustainingWeb.Telemetry.start_link([])
      
      # Test that metrics are properly defined
      metrics = SelfSustainingWeb.Telemetry.metrics()
      
      assert is_list(metrics)
      assert length(metrics) > 0
      
      # Verify we have AI-specific metrics
      ai_metrics = Enum.filter(metrics, fn metric ->
        metric.name |> to_string() |> String.contains?("ai")
      end)
      
      assert length(ai_metrics) > 0
    end
  end
  
  describe "Performance monitoring" do
    test "periodic metrics dispatch" do
      # Test that AI metrics can be dispatched without errors
      assert :ok == SelfSustainingWeb.Telemetry.dispatch_ai_metrics()
    end
    
    test "system health metrics dispatch" do
      # Test that system health metrics can be dispatched without errors
      assert :ok == SelfSustainingWeb.Telemetry.dispatch_system_health_metrics()
    end
    
    test "workflow metrics dispatch" do
      # Test that workflow metrics can be dispatched without errors
      assert :ok == SelfSustainingWeb.Telemetry.dispatch_workflow_metrics()
    end
  end
  
  describe "Error handling in telemetry" do
    test "span creation with error handling" do
      # Test error handling in spans
      result = OpenTelemetry.Tracer.with_span "error_test_span" do
        try do
          raise "test error"
        rescue
          error ->
            SelfSustaining.Telemetry.OpenTelemetryConfig.set_error_status(error, "test context")
            "error_handled"
        end
      end
      
      assert result == "error_handled"
    end
  end
end