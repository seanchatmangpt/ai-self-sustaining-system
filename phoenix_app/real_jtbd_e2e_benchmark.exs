#!/usr/bin/env elixir

# Real JTBD E2E Benchmark using actual system components
# This benchmark exercises the real SelfImprovementReactor with actual middleware

# Load the Phoenix application dependencies
Mix.install([
  {:phoenix, "~> 1.7.0"},
  {:telemetry, "~> 1.0"},
  {:jason, "~> 1.4"},
  {:reactor, "~> 0.15.4"},
  {:opentelemetry, "~> 1.3"},
  {:opentelemetry_api, "~> 1.2"}
])

# Ensure the self_sustaining app modules are loaded
Code.require_file("lib/self_sustaining/application.ex", __DIR__)
Code.require_file("lib/self_sustaining/workflows/self_improvement_reactor.ex", __DIR__)
Code.require_file("lib/self_sustaining/enhanced_reactor_runner.ex", __DIR__)
Code.require_file("lib/self_sustaining/reactor_middleware/telemetry_middleware.ex", __DIR__)
Code.require_file("lib/self_sustaining/reactor_middleware/agent_coordination_middleware.ex", __DIR__)

defmodule RealJTBDE2EBenchmark do
  @moduledoc """
  Real end-to-end JTBD benchmark using actual SelfImprovementReactor and middleware.
  
  This benchmark tests the actual implementation of:
  - SelfSustaining.Workflows.SelfImprovementReactor
  - SelfSustaining.EnhancedReactorRunner  
  - SelfSustaining.ReactorMiddleware.TelemetryMiddleware
  - SelfSustaining.ReactorMiddleware.AgentCoordinationMiddleware
  
  The JTBD being tested: "When system performance degrades, automatically improve it"
  """

  require Logger

  def run_real_jtbd_benchmark do
    IO.puts("🎯 REAL JTBD End-to-End Benchmark: Actual SelfImprovementReactor")
    IO.puts("=" |> String.duplicate(70))
    
    # Initialize telemetry collection for the benchmark
    telemetry_events = setup_comprehensive_telemetry()
    
    # Start timer for total benchmark
    benchmark_start = System.monotonic_time(:microsecond)
    
    # Test scenarios representing real JTBD use cases
    scenarios = [
      %{
        name: "Performance Degradation Recovery",
        improvement_request: %{
          type: "performance",
          urgency: "high",
          trigger: "response_time_degraded",
          baseline_metrics: %{response_time: 45, error_rate: 0.02}
        },
        context: %{
          current_metrics: %{response_time: 150, error_rate: 0.05},
          degradation_detected: true,
          user_impact: "moderate"
        }
      },
      %{
        name: "Security Vulnerability Mitigation", 
        improvement_request: %{
          type: "security",
          urgency: "high",
          trigger: "vulnerability_detected",
          baseline_metrics: %{security_score: 85}
        },
        context: %{
          vulnerabilities: ["CVE-2024-001", "CVE-2024-002"],
          security_score: 72,
          threat_level: "medium"
        }
      },
      %{
        name: "Code Quality Enhancement",
        improvement_request: %{
          type: "quality",
          urgency: "medium", 
          trigger: "code_quality_degraded",
          baseline_metrics: %{complexity: 5, coverage: 85}
        },
        context: %{
          complexity_score: 8,
          test_coverage: 78,
          maintainability: "low"
        }
      }
    ]
    
    # Execute each scenario with the real reactor
    scenario_results = Enum.map(scenarios, fn scenario ->
      execute_real_jtbd_scenario(scenario, telemetry_events)
    end)
    
    benchmark_end = System.monotonic_time(:microsecond)
    
    # Collect all telemetry events
    collected_events = collect_telemetry_events(telemetry_events, 2000)
    
    # Generate comprehensive report
    generate_real_benchmark_report(scenario_results, benchmark_end - benchmark_start, collected_events)
    
    scenario_results
  end

  defp execute_real_jtbd_scenario(scenario, _telemetry_events) do
    IO.puts("\n🔄 Executing Real JTBD Scenario: #{scenario.name}")
    IO.puts("  • Type: #{scenario.improvement_request.type}")
    IO.puts("  • Urgency: #{scenario.improvement_request.urgency}")
    
    scenario_start = System.monotonic_time(:microsecond)
    
    # Use the actual EnhancedReactorRunner with real middleware
    result = try do
      case SelfSustaining.EnhancedReactorRunner.run_with_metrics(
        SelfSustaining.Workflows.SelfImprovementReactor,
        %{
          improvement_request: scenario.improvement_request,
          context: scenario.context
        },
        [
          verbose: true,
          telemetry_dashboard: false,  # Don't spawn dashboard for benchmark
          agent_coordination: true,
          retry_attempts: 2,
          timeout: 30_000,
          work_type: "self_improvement",
          priority: scenario.improvement_request.urgency
        ]
      ) do
        {:ok, reactor_result, metrics} ->
          IO.puts("  ✅ Reactor completed successfully")
          IO.puts("  ⏱️  Execution time: #{Float.round(metrics.execution_time_ms, 2)}ms")
          IO.puts("  💾 Memory used: #{metrics.memory_used_bytes} bytes")
          
          {:ok, %{
            reactor_result: reactor_result,
            execution_metrics: metrics,
            success: true
          }}
        
        {:error, reason} ->
          IO.puts("  ❌ Reactor execution failed: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      error ->
        IO.puts("  💥 Exception during reactor execution: #{inspect(error)}")
        {:error, {:exception, error}}
    end
    
    scenario_end = System.monotonic_time(:microsecond)
    scenario_duration = scenario_end - scenario_start
    
    # Analyze the actual reactor result for JTBD completion
    jtbd_analysis = analyze_jtbd_completion(result, scenario)
    
    %{
      scenario: scenario,
      result: result,
      scenario_duration_ms: scenario_duration / 1000,
      jtbd_analysis: jtbd_analysis,
      timestamp: DateTime.utc_now()
    }
  end

  defp analyze_jtbd_completion(result, scenario) do
    case result do
      {:ok, %{reactor_result: reactor_result, execution_metrics: metrics}} ->
        # Analyze if the JTBD was actually completed based on reactor result
        improvement_achieved = analyze_improvement_achievement(reactor_result, scenario)
        
        %{
          jtbd_completed: improvement_achieved,
          reactor_success: true,
          execution_time_ms: metrics.execution_time_ms,
          memory_efficiency: calculate_memory_efficiency(metrics),
          improvement_score: calculate_improvement_score(reactor_result, scenario),
          quality_metrics: extract_quality_metrics(reactor_result)
        }
      
      {:error, reason} ->
        %{
          jtbd_completed: false,
          reactor_success: false,
          failure_reason: reason,
          improvement_score: 0,
          quality_metrics: %{}
        }
    end
  end

  defp analyze_improvement_achievement(reactor_result, scenario) do
    # Check if the reactor actually produced meaningful improvements
    case reactor_result do
      %{status: "completed"} = monitoring_result ->
        # Check if metrics actually improved
        improvement_metrics = Map.get(monitoring_result, :improvement_metrics, %{})
        
        case scenario.improvement_request.type do
          "performance" ->
            # Check if performance actually improved
            performance_delta = Map.get(improvement_metrics, :performance_delta)
            is_binary(performance_delta) and String.contains?(performance_delta, "+")
          
          "security" ->
            # Check if security score improved
            security_improvement = Map.get(improvement_metrics, :overall_score_improvement)
            is_binary(security_improvement) and String.contains?(security_improvement, "+")
          
          "quality" ->
            # Check if code quality improved
            error_reduction = Map.get(improvement_metrics, :error_reduction)
            is_binary(error_reduction) and String.contains?(error_reduction, "-")
          
          _ ->
            # Generic improvement check
            Map.has_key?(improvement_metrics, :overall_score_improvement)
        end
      
      _ ->
        false
    end
  end

  defp calculate_memory_efficiency(metrics) do
    # Calculate memory efficiency score (lower memory usage = higher efficiency)
    base_memory = 10_000_000  # 10MB baseline
    efficiency = max(0, 100 - (metrics.memory_used_bytes / base_memory * 100))
    Float.round(efficiency, 2)
  end

  defp calculate_improvement_score(reactor_result, scenario) do
    case reactor_result do
      %{success_rate: success_rate} when is_float(success_rate) ->
        # Use actual success rate from reactor
        success_rate
      
      %{status: "completed"} ->
        # If reactor completed, give base score adjusted by urgency
        base_score = 75.0
        urgency_modifier = case scenario.improvement_request.urgency do
          "high" -> 10.0
          "medium" -> 5.0
          "low" -> 0.0
        end
        base_score + urgency_modifier
      
      _ ->
        0.0
    end
  end

  defp extract_quality_metrics(reactor_result) do
    case reactor_result do
      %{improvement_metrics: metrics} when is_map(metrics) ->
        metrics
      
      %{monitoring_result: %{improvement_metrics: metrics}} when is_map(metrics) ->
        metrics
      
      _ ->
        %{}
    end
  end

  defp setup_comprehensive_telemetry do
    # Setup telemetry handlers for all reactor middleware events
    telemetry_ref = make_ref()
    
    events = [
      # Reactor execution events
      [:self_sustaining, :reactor, :execution, :start],
      [:self_sustaining, :reactor, :execution, :complete],
      [:self_sustaining, :reactor, :execution, :halt],
      [:self_sustaining, :reactor, :error],
      
      # Step-level events
      [:self_sustaining, :reactor, :step, :start],
      [:self_sustaining, :reactor, :step, :complete],
      [:self_sustaining, :reactor, :step, :error],
      [:self_sustaining, :reactor, :step, :retry],
      [:self_sustaining, :reactor, :step, :performance],
      
      # Coordination middleware events
      [:self_sustaining, :reactor, :coordination, :start],
      [:self_sustaining, :reactor, :coordination, :complete],
      [:self_sustaining, :reactor, :coordination, :error],
      [:self_sustaining, :reactor, :coordination, :halt],
      [:self_sustaining, :reactor, :step, :coordination_start],
      [:self_sustaining, :reactor, :step, :coordination_complete],
      
      # Performance and monitoring events
      [:self_sustaining, :reactor, :performance, :summary],
      [:self_sustaining, :art, :velocity, :update]
    ]
    
    # Attach handlers for each event
    for event <- events do
      :telemetry.attach(
        "real-benchmark-#{System.unique_integer()}",
        event,
        fn event_name, measurements, metadata, {pid, ref} ->
          send(pid, {:telemetry_event, ref, %{
            event: event_name,
            measurements: measurements,
            metadata: metadata,
            timestamp: System.system_time(:microsecond),
            node: node()
          }})
        end,
        {self(), telemetry_ref}
      )
    end
    
    telemetry_ref
  end

  defp collect_telemetry_events(ref, timeout_ms) do
    end_time = System.monotonic_time(:millisecond) + timeout_ms
    collect_events_loop(ref, [], end_time)
  end

  defp collect_events_loop(ref, events, end_time) do
    if System.monotonic_time(:millisecond) >= end_time do
      Enum.reverse(events)
    else
      receive do
        {:telemetry_event, ^ref, event} ->
          collect_events_loop(ref, [event | events], end_time)
      after
        100 ->
          collect_events_loop(ref, events, end_time)
      end
    end
  end

  defp generate_real_benchmark_report(scenario_results, total_duration_us, telemetry_events) do
    IO.puts("\n" <> "=" |> String.duplicate(70))
    IO.puts("📊 REAL JTBD BENCHMARK REPORT")
    IO.puts("=" |> String.duplicate(70))
    
    total_duration_ms = total_duration_us / 1000
    successful_scenarios = Enum.count(scenario_results, fn r -> r.jtbd_analysis.jtbd_completed end)
    
    IO.puts("\n🎯 Overall JTBD Performance:")
    IO.puts("  • Total Benchmark Time: #{Float.round(total_duration_ms, 2)}ms")
    IO.puts("  • Scenarios Executed: #{length(scenario_results)}")
    IO.puts("  • JTBD Success Rate: #{successful_scenarios}/#{length(scenario_results)} (#{Float.round(successful_scenarios / length(scenario_results) * 100, 1)}%)")
    IO.puts("  • Telemetry Events Captured: #{length(telemetry_events)}")
    
    IO.puts("\n📋 Scenario Details:")
    for {result, index} <- Enum.with_index(scenario_results, 1) do
      IO.puts("\n  #{index}. #{result.scenario.name}")
      IO.puts("     • Reactor Success: #{if result.jtbd_analysis.reactor_success, do: "✅", else: "❌"}")
      IO.puts("     • JTBD Completed: #{if result.jtbd_analysis.jtbd_completed, do: "✅", else: "❌"}")
      IO.puts("     • Duration: #{Float.round(result.scenario_duration_ms, 2)}ms")
      
      if result.jtbd_analysis.reactor_success do
        IO.puts("     • Execution Time: #{Float.round(result.jtbd_analysis.execution_time_ms, 2)}ms")
        IO.puts("     • Memory Efficiency: #{result.jtbd_analysis.memory_efficiency}%")
        IO.puts("     • Improvement Score: #{Float.round(result.jtbd_analysis.improvement_score, 1)}")
      else
        IO.puts("     • Failure: #{inspect(result.jtbd_analysis.failure_reason)}")
      end
    end
    
    # Telemetry analysis
    IO.puts("\n📈 Telemetry Analysis:")
    telemetry_by_type = Enum.group_by(telemetry_events, fn event ->
      event.event |> Enum.take(3) |> Enum.join(".")
    end)
    
    for {event_type, events} <- telemetry_by_type do
      IO.puts("  • #{event_type}: #{length(events)} events")
    end
    
    # Performance analysis
    execution_events = Map.get(telemetry_by_type, "self_sustaining.reactor.execution", [])
    step_events = Map.get(telemetry_by_type, "self_sustaining.reactor.step", [])
    coordination_events = Map.get(telemetry_by_type, "self_sustaining.reactor.coordination", [])
    
    IO.puts("\n⚡ Performance Insights:")
    IO.puts("  • Reactor Executions: #{length(execution_events)} tracked")
    IO.puts("  • Step Operations: #{length(step_events)} tracked")
    IO.puts("  • Coordination Operations: #{length(coordination_events)} tracked")
    
    # Calculate system efficiency
    overall_efficiency = calculate_system_efficiency(scenario_results, telemetry_events)
    IO.puts("\n🏆 Overall System Efficiency: #{Float.round(overall_efficiency * 100, 1)}%")
    
    # Generate recommendations
    generate_real_recommendations(scenario_results, telemetry_events)
    
    IO.puts("\n" <> "=" |> String.duplicate(70))
  end

  defp calculate_system_efficiency(scenario_results, telemetry_events) do
    # Calculate efficiency based on multiple factors
    success_rate = Enum.count(scenario_results, & &1.jtbd_analysis.jtbd_completed) / length(scenario_results)
    
    avg_improvement_score = scenario_results
      |> Enum.map(& &1.jtbd_analysis.improvement_score)
      |> Enum.sum()
      |> Kernel./(length(scenario_results))
      |> Kernel./(100)  # Normalize to 0-1
    
    telemetry_completeness = if length(telemetry_events) > 0, do: 1.0, else: 0.0
    
    # Weight the factors
    (success_rate * 0.5) + (avg_improvement_score * 0.3) + (telemetry_completeness * 0.2)
  end

  defp generate_real_recommendations(scenario_results, telemetry_events) do
    IO.puts("\n💡 System Optimization Recommendations:")
    
    failed_scenarios = Enum.filter(scenario_results, fn r -> not r.jtbd_analysis.jtbd_completed end)
    
    if length(failed_scenarios) > 0 do
      IO.puts("  • ⚠️  #{length(failed_scenarios)} JTBD scenarios failed - investigate reactor reliability")
      
      failure_reasons = failed_scenarios
        |> Enum.map(& &1.jtbd_analysis.failure_reason)
        |> Enum.frequencies()
      
      for {reason, count} <- failure_reasons do
        IO.puts("    - #{reason}: #{count} occurrences")
      end
    end
    
    # Analyze execution times
    execution_times = scenario_results
      |> Enum.filter(& &1.jtbd_analysis.reactor_success)
      |> Enum.map(& &1.jtbd_analysis.execution_time_ms)
    
    if length(execution_times) > 0 do
      avg_execution_time = Enum.sum(execution_times) / length(execution_times)
      
      if avg_execution_time > 1000 do
        IO.puts("  • 🐌 Average execution time is high (#{Float.round(avg_execution_time, 1)}ms) - optimize reactor steps")
      end
      
      max_execution_time = Enum.max(execution_times)
      if max_execution_time > 2000 do
        IO.puts("  • ⏰ Slowest execution: #{Float.round(max_execution_time, 1)}ms - investigate performance bottlenecks")
      end
    end
    
    # Check telemetry coverage
    if length(telemetry_events) < (length(scenario_results) * 10) do
      IO.puts("  • 📊 Low telemetry event count - verify middleware configuration")
    end
    
    if length(failed_scenarios) == 0 and length(execution_times) > 0 do
      avg_time = Enum.sum(execution_times) / length(execution_times)
      if avg_time < 500 do
        IO.puts("  • 🎉 Excellent performance - system is operating efficiently")
      end
    end
  end
end

# Execute the benchmark if run directly
if System.argv() == [] do
  Logger.configure(level: :info)
  RealJTBDE2EBenchmark.run_real_jtbd_benchmark()
else
  IO.puts("Usage: elixir real_jtbd_e2e_benchmark.exs")
  IO.puts("This benchmark tests the real SelfImprovementReactor implementation")
end