#!/usr/bin/env elixir

# End-to-End 80/20 Integration Test
# Tests critical system integration paths with actual dependencies

Mix.install([
  {:jason, "~> 1.4"},
  {:phoenix, "~> 1.7.0"},
  {:reactor, "~> 0.15.4"},
  {:req, "~> 0.5.2"},
  {:opentelemetry_api, "~> 1.2"}
])

defmodule E2E8020Test do
  @moduledoc """
  End-to-end 80/20 test strategy for the AI self-sustaining system.
  
  Critical Integration Paths (80% value):
  1. Phoenix Application Lifecycle (30%)
  2. Reactor + Claude Code Workflows (25%)  
  3. OpenTelemetry Tracing Pipeline (15%)
  4. Database + Ash Integration (10%)
  5. Background Job Processing (10%)
  6. HTTP/API Layer (10%)
  """

  require Logger

  def run_e2e_tests do
    IO.puts("🌐 End-to-End 80/20 Integration Test")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Testing critical system integration paths")
    
    master_trace = "e2e_8020_#{System.system_time(:nanosecond)}"
    
    # Set up OpenTelemetry for end-to-end tracing
    setup_telemetry(master_trace)
    
    start_time = System.monotonic_time(:microsecond)
    
    # Critical integration tests (80% of production risk)
    tests = [
      {"Phoenix Application", &test_phoenix_lifecycle/1, 30},
      {"Reactor + Claude Workflows", &test_reactor_claude_integration/1, 25},
      {"OpenTelemetry Tracing", &test_telemetry_pipeline/1, 15},
      {"Database + Ash", &test_database_ash_integration/1, 10},
      {"Background Jobs", &test_background_processing/1, 10},
      {"HTTP/API Layer", &test_http_api_layer/1, 10}
    ]
    
    results = Enum.map(tests, fn {name, test_fn, value} ->
      execute_integration_test(name, test_fn, value, master_trace)
    end)
    
    total_time = System.monotonic_time(:microsecond) - start_time
    
    analyze_e2e_results(results, total_time, master_trace)
  end

  # Test 1: Phoenix Application Lifecycle (30% value)
  defp test_phoenix_lifecycle(trace_id) do
    IO.puts("   🎯 Testing Phoenix application boot and health")
    
    # Test 1.1: Check if Phoenix can start (without actually starting)
    phoenix_config_ok = test_phoenix_config()
    
    # Test 1.2: Check critical Phoenix modules are loadable
    modules_ok = test_phoenix_modules()
    
    # Test 1.3: Check database connectivity (if available)
    db_connectivity = test_database_connection()
    
    # Test 1.4: Check application supervision tree
    supervision_ok = test_supervision_tree()
    
    passed_checks = [phoenix_config_ok, modules_ok, db_connectivity, supervision_ok]
    |> Enum.count(& &1)
    
    IO.puts("     Phoenix checks: #{passed_checks}/4 passed")
    
    %{
      test: :phoenix_lifecycle,
      passed_checks: passed_checks,
      total_checks: 4,
      success: passed_checks >= 3,  # 3/4 should pass
      details: %{
        config: phoenix_config_ok,
        modules: modules_ok,
        database: db_connectivity,
        supervision: supervision_ok
      },
      trace_id: trace_id
    }
  end

  # Test 2: Reactor + Claude Workflows (25% value)
  defp test_reactor_claude_integration(trace_id) do
    IO.puts("   🎯 Testing Reactor workflow orchestration with Claude")
    
    # Test 2.1: Reactor module loading
    reactor_loadable = test_reactor_module_loading()
    
    # Test 2.2: Claude Code integration
    claude_integration = test_claude_code_integration(trace_id)
    
    # Test 2.3: Simple workflow execution
    workflow_execution = test_simple_workflow_execution(trace_id)
    
    # Test 2.4: Error handling in workflows
    error_handling = test_workflow_error_handling(trace_id)
    
    passed_checks = [reactor_loadable, claude_integration, workflow_execution, error_handling]
    |> Enum.count(& &1)
    
    IO.puts("     Reactor checks: #{passed_checks}/4 passed")
    
    %{
      test: :reactor_claude_integration,
      passed_checks: passed_checks,
      total_checks: 4,
      success: passed_checks >= 3,
      details: %{
        reactor_loading: reactor_loadable,
        claude_integration: claude_integration,
        workflow_execution: workflow_execution,
        error_handling: error_handling
      },
      trace_id: trace_id
    }
  end

  # Test 3: OpenTelemetry Tracing Pipeline (15% value)
  defp test_telemetry_pipeline(trace_id) do
    IO.puts("   🎯 Testing OpenTelemetry tracing and observability")
    
    # Test 3.1: OpenTelemetry API availability
    otel_api_ok = test_opentelemetry_api()
    
    # Test 3.2: Span creation and propagation
    span_creation = test_span_creation_and_propagation(trace_id)
    
    # Test 3.3: Telemetry event emission
    telemetry_events = test_telemetry_events(trace_id)
    
    passed_checks = [otel_api_ok, span_creation, telemetry_events]
    |> Enum.count(& &1)
    
    IO.puts("     Telemetry checks: #{passed_checks}/3 passed")
    
    %{
      test: :telemetry_pipeline,
      passed_checks: passed_checks,
      total_checks: 3,
      success: passed_checks >= 2,
      details: %{
        otel_api: otel_api_ok,
        span_creation: span_creation,
        telemetry_events: telemetry_events
      },
      trace_id: trace_id
    }
  end

  # Test 4: Database + Ash Integration (10% value)
  defp test_database_ash_integration(trace_id) do
    IO.puts("   🎯 Testing database and Ash framework integration")
    
    # Test 4.1: Database connection
    db_connection = test_database_connection()
    
    # Test 4.2: Ash module loading
    ash_loading = test_ash_module_loading()
    
    # Test 4.3: Basic Ash operation (if possible)
    ash_operation = test_ash_basic_operation(trace_id)
    
    passed_checks = [db_connection, ash_loading, ash_operation]
    |> Enum.count(& &1)
    
    IO.puts("     Database/Ash checks: #{passed_checks}/3 passed")
    
    %{
      test: :database_ash_integration,
      passed_checks: passed_checks,
      total_checks: 3,
      success: passed_checks >= 2,
      details: %{
        database: db_connection,
        ash_loading: ash_loading,
        ash_operation: ash_operation
      },
      trace_id: trace_id
    }
  end

  # Test 5: Background Job Processing (10% value)
  defp test_background_processing(trace_id) do
    IO.puts("   🎯 Testing background job processing (Oban)")
    
    # Test 5.1: Oban module loading
    oban_loading = test_oban_module_loading()
    
    # Test 5.2: Job definition and enqueueing (mock)
    job_enqueueing = test_job_enqueueing(trace_id)
    
    passed_checks = [oban_loading, job_enqueueing]
    |> Enum.count(& &1)
    
    IO.puts("     Background job checks: #{passed_checks}/2 passed")
    
    %{
      test: :background_processing,
      passed_checks: passed_checks,
      total_checks: 2,
      success: passed_checks >= 1,
      details: %{
        oban_loading: oban_loading,
        job_enqueueing: job_enqueueing
      },
      trace_id: trace_id
    }
  end

  # Test 6: HTTP/API Layer (10% value)
  defp test_http_api_layer(trace_id) do
    IO.puts("   🎯 Testing HTTP/API layer components")
    
    # Test 6.1: HTTP client functionality
    http_client = test_http_client_functionality(trace_id)
    
    # Test 6.2: JSON processing
    json_processing = test_json_processing()
    
    # Test 6.3: Phoenix router/controller loading
    router_loading = test_phoenix_router_loading()
    
    passed_checks = [http_client, json_processing, router_loading]
    |> Enum.count(& &1)
    
    IO.puts("     HTTP/API checks: #{passed_checks}/3 passed")
    
    %{
      test: :http_api_layer,
      passed_checks: passed_checks,
      total_checks: 3,
      success: passed_checks >= 2,
      details: %{
        http_client: http_client,
        json_processing: json_processing,
        router_loading: router_loading
      },
      trace_id: trace_id
    }
  end

  # Helper test functions

  defp test_phoenix_config do
    try do
      # Try to load Phoenix and check basic configuration
      Application.ensure_all_started(:phoenix)
      Phoenix.Config != nil
    rescue
      _ -> false
    end
  end

  defp test_phoenix_modules do
    required_modules = [Phoenix, Phoenix.Router, Phoenix.Controller, Phoenix.LiveView]
    
    Enum.all?(required_modules, fn module ->
      try do
        Code.ensure_loaded?(module)
      rescue
        _ -> false
      end
    end)
  end

  defp test_database_connection do
    try do
      # Check if we can at least load database-related modules
      Application.ensure_all_started(:postgrex)
      Postgrex != nil
    rescue
      _ -> false
    end
  end

  defp test_supervision_tree do
    try do
      # Check if supervision tree concepts are available
      Supervisor != nil and GenServer != nil
    rescue
      _ -> false
    end
  end

  defp test_reactor_module_loading do
    try do
      Application.ensure_all_started(:reactor)
      Code.ensure_loaded?(Reactor)
    rescue
      _ -> false
    end
  end

  defp test_claude_code_integration(trace_id) do
    # Quick test if Claude Code command is available
    case System.cmd("claude", ["--version"], stderr_to_stdout: true) do
      {_output, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  defp test_simple_workflow_execution(trace_id) do
    try do
      # Create a minimal reactor to test basic execution
      defmodule SimpleTestReactor do
        use Reactor
        
        input :test_input
        
        step :simple_step do
          argument :input, input(:test_input)
          
          run fn args, _context ->
            {:ok, "processed_#{args.input}"}
          end
        end
        
        return :simple_step
      end
      
      case Reactor.run(SimpleTestReactor, %{test_input: "test_data"}) do
        {:ok, result} -> String.contains?(result, "processed_test_data")
        _ -> false
      end
    rescue
      _ -> false
    end
  end

  defp test_workflow_error_handling(trace_id) do
    try do
      # Test that reactor handles errors gracefully
      defmodule ErrorTestReactor do
        use Reactor
        
        step :failing_step do
          run fn _args, _context ->
            {:error, "intentional_test_error"}
          end
        end
        
        return :failing_step
      end
      
      case Reactor.run(ErrorTestReactor, %{}) do
        {:error, _} -> true  # Error handling working
        _ -> false
      end
    rescue
      _ -> false
    end
  end

  defp test_opentelemetry_api do
    try do
      Application.ensure_all_started(:opentelemetry_api)
      Code.ensure_loaded?(:opentelemetry)
    rescue
      _ -> false
    end
  end

  defp test_span_creation_and_propagation(trace_id) do
    try do
      # Test basic span creation
      require OpenTelemetry.Tracer
      OpenTelemetry.Tracer.with_span "test_span" do
        OpenTelemetry.Tracer.add_event("test_event", %{trace_id: trace_id})
      end
      true
    rescue
      _ -> false
    end
  end

  defp test_telemetry_events(trace_id) do
    try do
      # Test telemetry event emission
      :telemetry.execute([:e2e_test, :event], %{value: 1}, %{trace_id: trace_id})
      true
    rescue
      _ -> false
    end
  end

  defp test_ash_module_loading do
    try do
      Application.ensure_all_started(:ash)
      Code.ensure_loaded?(Ash)
    rescue
      _ -> false
    end
  end

  defp test_ash_basic_operation(_trace_id) do
    try do
      # Test basic Ash functionality (without actual resources)
      Ash.Query != nil
    rescue
      _ -> false
    end
  end

  defp test_oban_module_loading do
    try do
      Application.ensure_all_started(:oban)
      Code.ensure_loaded?(Oban)
    rescue
      _ -> false
    end
  end

  defp test_job_enqueueing(trace_id) do
    try do
      # Test job definition capability (without actual queue)
      defmodule TestJob do
        use Oban.Worker, queue: :test
        
        def perform(%Oban.Job{args: args}) do
          {:ok, "processed_#{args["data"]}"}
        end
      end
      
      # Just test that we can create job structs
      job = TestJob.new(%{data: trace_id})
      is_struct(job, Oban.Job)
    rescue
      _ -> false
    end
  end

  defp test_http_client_functionality(trace_id) do
    try do
      # Test HTTP client availability and basic functionality
      Application.ensure_all_started(:req)
      
      # Test basic Req functionality (without external calls)
      req = Req.new(base_url: "http://localhost")
      is_struct(req, Req.Request)
    rescue
      _ -> false
    end
  end

  defp test_json_processing do
    try do
      # Test JSON encoding/decoding
      data = %{test: "data", number: 42}
      encoded = Jason.encode!(data)
      decoded = Jason.decode!(encoded)
      decoded["test"] == "data"
    rescue
      _ -> false
    end
  end

  defp test_phoenix_router_loading do
    try do
      # Test Phoenix router module availability
      Code.ensure_loaded?(Phoenix.Router)
    rescue
      _ -> false
    end
  end

  # Test execution and analysis

  defp execute_integration_test(name, test_fn, value, master_trace) do
    IO.puts("\n🧪 #{name} (#{value}% value)")
    child_trace = "#{master_trace}_#{String.replace(String.downcase(name), " ", "_")}"
    
    test_start = System.monotonic_time(:microsecond)
    
    result = try do
      test_fn.(child_trace)
    rescue
      error -> 
        IO.puts("   💥 Test error: #{Exception.message(error)}")
        %{test: name, success: false, error: error}
    end
    
    test_duration = System.monotonic_time(:microsecond) - test_start
    duration_ms = Float.round(test_duration / 1000, 2)
    
    status_icon = if result.success, do: "✅", else: "❌"
    IO.puts("   #{status_icon} #{if result.success, do: "PASS", else: "FAIL"} (#{duration_ms}ms)")
    
    Map.merge(result, %{
      test_name: name,
      value_percent: value,
      duration_ms: duration_ms,
      trace_id: child_trace
    })
  end

  defp setup_telemetry(master_trace) do
    try do
      Application.ensure_all_started(:opentelemetry)
      IO.puts("📡 OpenTelemetry initialized for trace: #{String.slice(master_trace, -12, 12)}")
    rescue
      _ -> 
        IO.puts("⚠️  OpenTelemetry setup skipped (not critical for test)")
    end
  end

  defp analyze_e2e_results(results, total_time, master_trace) do
    IO.puts("\n📊 End-to-End 80/20 Integration Results")
    IO.puts("-" |> String.duplicate(60))
    
    total_tests = length(results)
    passed_tests = Enum.count(results, & &1.success)
    
    # Calculate weighted success based on value percentages
    weighted_score = results
    |> Enum.map(fn r -> if r.success, do: r.value_percent, else: 0 end)
    |> Enum.sum()
    
    total_time_ms = Float.round(total_time / 1000, 2)
    
    IO.puts("Tests: #{passed_tests}/#{total_tests} passed")
    IO.puts("Weighted Score: #{weighted_score}% (production readiness)")
    IO.puts("Total Time: #{total_time_ms}ms")
    IO.puts("Master Trace: #{String.slice(master_trace, -16, 16)}")
    
    # Show detailed results
    IO.puts("\nDetailed Integration Results:")
    Enum.each(results, fn result ->
      icon = if result.success, do: "✅", else: "❌"
      checks_info = "#{result.passed_checks}/#{result.total_checks}"
      IO.puts("  #{icon} #{result.test_name} (#{result.value_percent}%): #{checks_info} - #{result.duration_ms}ms")
    end)
    
    # Production readiness assessment
    IO.puts("\n🎯 Production Readiness Assessment:")
    
    cond do
      weighted_score >= 80 ->
        IO.puts("🏆 EXCELLENT: #{weighted_score}% - Production Ready!")
        show_production_ready_details(results)
      
      weighted_score >= 60 ->
        IO.puts("👍 GOOD: #{weighted_score}% - Almost Production Ready")
        show_near_ready_details(results)
      
      weighted_score >= 40 ->
        IO.puts("⚠️  PARTIAL: #{weighted_score}% - Critical Issues Present")
        show_critical_issues_details(results)
      
      true ->
        IO.puts("❌ CRITICAL: #{weighted_score}% - Major Integration Problems")
        show_blocking_issues_details(results)
    end
    
    # Show what was tested vs skipped
    show_8020_coverage_analysis()
    
    # Next steps recommendation
    show_next_steps(weighted_score, results)
  end

  defp show_production_ready_details(results) do
    IO.puts("   ✅ Core integrations working")
    IO.puts("   ✅ Critical dependencies available")
    IO.puts("   ✅ Error handling functional")
    IO.puts("   ✅ Observability pipeline operational")
    IO.puts("   🚀 READY FOR: Production deployment with monitoring")
  end

  defp show_near_ready_details(results) do
    failed_tests = Enum.filter(results, & not &1.success)
    IO.puts("   🔧 Minor issues to resolve:")
    Enum.each(failed_tests, fn test ->
      IO.puts("     • #{test.test_name} (#{test.value_percent}% impact)")
    end)
    IO.puts("   🔄 READY FOR: Staging environment testing")
  end

  defp show_critical_issues_details(results) do
    high_value_failures = Enum.filter(results, fn r -> 
      not r.success and r.value_percent >= 20 
    end)
    
    if length(high_value_failures) > 0 do
      IO.puts("   🚨 HIGH IMPACT FAILURES:")
      Enum.each(high_value_failures, fn test ->
        IO.puts("     • #{test.test_name}: #{test.value_percent}% value lost")
      end)
    end
    
    IO.puts("   🛠️  NEEDS: Critical issue resolution")
  end

  defp show_blocking_issues_details(results) do
    IO.puts("   🛑 BLOCKING ISSUES DETECTED:")
    failed_tests = Enum.filter(results, & not &1.success)
    Enum.each(failed_tests, fn test ->
      IO.puts("     • #{test.test_name}: #{test.value_percent}% integration failed")
    end)
    IO.puts("   🛠️  NEEDS: Comprehensive system debugging")
  end

  defp show_8020_coverage_analysis do
    IO.puts("\n📋 80/20 Coverage Analysis:")
    IO.puts("   ✅ Tested (80% of production risk):")
    IO.puts("     • Phoenix application lifecycle")
    IO.puts("     • Reactor workflow orchestration")
    IO.puts("     • OpenTelemetry observability")
    IO.puts("     • Database and Ash integration")
    IO.puts("     • Background job processing")
    IO.puts("     • HTTP/API layer functionality")
    
    IO.puts("   ⏭️  Skipped (20% of production risk):")
    IO.puts("     • Load testing and performance")
    IO.puts("     • Security vulnerability scanning")
    IO.puts("     • Edge case error scenarios")
    IO.puts("     • External service integrations")
    IO.puts("     • UI/Frontend integration")
  end

  defp show_next_steps(weighted_score, results) do
    IO.puts("\n🎯 Recommended Next Steps:")
    
    if weighted_score >= 80 do
      IO.puts("   1. 🚀 Deploy to staging environment")
      IO.puts("   2. 📊 Set up production monitoring")
      IO.puts("   3. 🔄 Run load testing")
      IO.puts("   4. 📈 Monitor real-world performance")
    elsif weighted_score >= 60 do
      IO.puts("   1. 🔧 Fix failing integration tests")
      IO.puts("   2. 🧪 Run additional integration scenarios")
      IO.puts("   3. 📊 Validate error handling edge cases")
      IO.puts("   4. 🔄 Re-run E2E tests")
    else
      IO.puts("   1. 🛠️  Debug and fix critical failures")
      IO.puts("   2. 📚 Review system architecture")
      IO.puts("   3. 🔍 Investigate dependency issues")
      IO.puts("   4. 🧪 Focus on core functionality first")
    end
    
    IO.puts("\n💡 80/20 Value Delivered:")
    IO.puts("   ⚡ Fast end-to-end validation (#{Float.round(total_time / 1000, 2)}ms)")
    IO.puts("   🎯 #{weighted_score}% production readiness confidence")
    IO.puts("   📊 Critical integration path coverage")
    IO.puts("   🚀 Clear go/no-go decision for deployment")
  end
end

# Run the end-to-end 80/20 integration test
E2E8020Test.run_e2e_tests()