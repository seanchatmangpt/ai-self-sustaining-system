Mix.install([
  {:telemetry, "~> 1.0"},
  {:jason, "~> 1.4"}
])

defmodule SimpleJTBDE2EBenchmark do
  @moduledoc """
  Simple end-to-end JTBD (Jobs to be Done) benchmark for AI self-sustaining system.
  
  Tests the core job: "As an AI system, I need to improve myself when performance degrades"
  
  This benchmark follows the simplest JTBD flow:
  1. Detect degradation (trigger)
  2. Analyze current state 
  3. Generate improvement plan
  4. Validate plan safety
  5. Execute improvement
  6. Monitor results
  """

  def run_jtbd_benchmark do
    IO.puts("🎯 JTBD End-to-End Benchmark: Self-Improvement Process")
    IO.puts("=" |> String.duplicate(60))
    
    # Setup telemetry collection
    telemetry_ref = setup_telemetry_collection()
    
    start_time = System.monotonic_time(:microsecond)
    
    # Execute the complete JTBD flow
    jtbd_result = execute_self_improvement_jtbd()
    
    end_time = System.monotonic_time(:microsecond)
    
    # Collect telemetry events
    telemetry_events = collect_telemetry_events(telemetry_ref, 1000)
    
    # Generate report
    generate_jtbd_report(jtbd_result, end_time - start_time, telemetry_events)
    
    jtbd_result
  end

  defp execute_self_improvement_jtbd do
    IO.puts("\n🔄 Executing JTBD: Self-Improvement Process")
    
    # JTBD Context: System detects performance degradation
    degradation_context = %{
      trigger: "performance_degradation_detected",
      current_response_time: 150, # ms (degraded from normal 45ms)
      error_rate: 0.05, # 5% (degraded from normal 0.02%)
      urgency: "medium",
      user_impact: "moderate"
    }
    
    IO.puts("  • Context: #{degradation_context.trigger}")
    IO.puts("  • Response time: #{degradation_context.current_response_time}ms")
    IO.puts("  • Error rate: #{degradation_context.error_rate * 100}%")
    
    # Step 1: Analyze System State
    {analysis_time, analysis_result} = :timer.tc(fn ->
      analyze_system_state(degradation_context)
    end)
    emit_telemetry([:jtbd, :analyze_system_state, :complete], %{duration: analysis_time}, %{})
    
    IO.puts("  ✅ Analysis completed (#{analysis_time / 1000}ms)")
    
    # Step 2: Generate Improvement Plan  
    {plan_time, plan_result} = :timer.tc(fn ->
      generate_improvement_plan(analysis_result)
    end)
    emit_telemetry([:jtbd, :generate_plan, :complete], %{duration: plan_time}, %{})
    
    IO.puts("  ✅ Plan generated (#{plan_time / 1000}ms)")
    
    # Step 3: Validate Plan
    {validation_time, validation_result} = :timer.tc(fn ->
      validate_improvement_plan(plan_result)
    end)
    emit_telemetry([:jtbd, :validate_plan, :complete], %{duration: validation_time}, %{})
    
    IO.puts("  ✅ Plan validated (#{validation_time / 1000}ms)")
    
    # Step 4: Execute Improvement (if valid)
    {execution_time, execution_result} = :timer.tc(fn ->
      if validation_result.is_valid do
        execute_improvement(plan_result)
      else
        {:error, "Plan validation failed"}
      end
    end)
    emit_telemetry([:jtbd, :execute_improvement, :complete], %{duration: execution_time}, %{})
    
    if validation_result.is_valid do
      IO.puts("  ✅ Improvement executed (#{execution_time / 1000}ms)")
    else
      IO.puts("  ❌ Execution skipped - validation failed")
    end
    
    # Step 5: Monitor Results
    {monitoring_time, monitoring_result} = :timer.tc(fn ->
      monitor_improvement_results(execution_result, analysis_result)
    end)
    emit_telemetry([:jtbd, :monitor_results, :complete], %{duration: monitoring_time}, %{})
    
    IO.puts("  ✅ Results monitored (#{monitoring_time / 1000}ms)")
    
    # Calculate JTBD success
    jtbd_success = validation_result.is_valid and 
                   match?({:ok, _}, execution_result) and 
                   monitoring_result.improvement_achieved
    
    total_time = analysis_time + plan_time + validation_time + execution_time + monitoring_time
    
    %{
      success: jtbd_success,
      total_time: total_time,
      step_times: %{
        analysis: analysis_time,
        planning: plan_time,
        validation: validation_time,
        execution: execution_time,
        monitoring: monitoring_time
      },
      context: degradation_context,
      analysis: analysis_result,
      plan: plan_result,
      validation: validation_result,
      execution: execution_result,
      monitoring: monitoring_result
    }
  end

  defp analyze_system_state(context) do
    emit_telemetry([:jtbd, :analyze_system_state, :start], %{}, %{})
    
    # Simulate analysis work
    :timer.sleep(Enum.random(20..80))
    
    %{
      current_metrics: %{
        response_time: context.current_response_time,
        error_rate: context.error_rate,
        cpu_usage: 75.2,
        memory_usage: 68.5
      },
      baseline_metrics: %{
        response_time: 45,
        error_rate: 0.02,
        cpu_usage: 45.0,
        memory_usage: 55.0
      },
      improvement_areas: [
        "database_query_optimization",
        "error_handling_enhancement",
        "caching_improvements"
      ],
      priority_score: calculate_priority_score(context),
      root_cause: "database_connection_pool_exhaustion"
    }
  end

  defp generate_improvement_plan(analysis) do
    emit_telemetry([:jtbd, :generate_plan, :start], %{}, %{})
    
    # Simulate planning work
    :timer.sleep(Enum.random(30..100))
    
    %{
      improvement_type: "performance_optimization",
      target_metrics: %{
        response_time: 50, # target: back to ~50ms
        error_rate: 0.025  # target: reduce to 2.5%
      },
      implementation_steps: [
        %{action: "increase_db_connection_pool", estimated_time: 5, risk: "low"},
        %{action: "optimize_slow_queries", estimated_time: 15, risk: "medium"},
        %{action: "add_query_caching", estimated_time: 10, risk: "low"}
      ],
      estimated_total_time: 30, # minutes
      expected_improvement: %{
        response_time_reduction: 60, # percent
        error_rate_reduction: 50    # percent
      }
    }
  end

  defp validate_improvement_plan(plan) do
    emit_telemetry([:jtbd, :validate_plan, :start], %{}, %{})
    
    # Simulate validation work
    :timer.sleep(Enum.random(15..50))
    
    # Simple validation logic
    is_safe = plan.estimated_total_time < 60 # under 1 hour
    has_rollback = Enum.all?(plan.implementation_steps, fn step -> step.risk in ["low", "medium"] end)
    
    %{
      is_valid: is_safe and has_rollback,
      safety_checks: %{
        time_acceptable: is_safe,
        has_rollback_plan: has_rollback,
        resource_available: true
      },
      approval_required: plan.estimated_total_time > 20
    }
  end

  defp execute_improvement(plan) do
    emit_telemetry([:jtbd, :execute_improvement, :start], %{}, %{})
    
    # Simulate executing each step
    results = Enum.map(plan.implementation_steps, fn step ->
      emit_telemetry([:jtbd, :execute_step, :start], %{}, %{step: step.action})
      
      # Simulate step execution time
      execution_time = step.estimated_time * 1000 + Enum.random(0..2000) # convert to ms + variance
      :timer.sleep(min(execution_time, 200)) # cap simulation time
      
      success = step.risk == "low" or Enum.random(1..10) > 2 # 80% success for medium risk
      
      emit_telemetry([:jtbd, :execute_step, :complete], %{duration: execution_time}, %{
        step: step.action,
        success: success
      })
      
      %{
        step: step.action,
        success: success,
        execution_time: execution_time
      }
    end)
    
    all_successful = Enum.all?(results, & &1.success)
    
    if all_successful do
      {:ok, %{
        status: "completed", 
        results: results,
        total_execution_time: Enum.sum(Enum.map(results, & &1.execution_time))
      }}
    else
      {:error, %{
        status: "failed",
        results: results,
        failed_steps: Enum.filter(results, &(not &1.success))
      }}
    end
  end

  defp monitor_improvement_results(execution_result, original_analysis) do
    emit_telemetry([:jtbd, :monitor_results, :start], %{}, %{})
    
    # Simulate monitoring delay
    :timer.sleep(Enum.random(25..75))
    
    case execution_result do
      {:ok, _} ->
        # Simulate improved metrics
        new_metrics = %{
          response_time: original_analysis.baseline_metrics.response_time + Enum.random(0..10),
          error_rate: original_analysis.baseline_metrics.error_rate * (1 + Enum.random(0..5) / 100),
          cpu_usage: original_analysis.current_metrics.cpu_usage - Enum.random(5..15),
          memory_usage: original_analysis.current_metrics.memory_usage - Enum.random(2..8)
        }
        
        response_time_improvement = (original_analysis.current_metrics.response_time - new_metrics.response_time) / 
                                  original_analysis.current_metrics.response_time * 100
                                  
        error_rate_improvement = (original_analysis.current_metrics.error_rate - new_metrics.error_rate) /
                               original_analysis.current_metrics.error_rate * 100
        
        %{
          new_metrics: new_metrics,
          improvement_achieved: response_time_improvement > 0 and error_rate_improvement > 0,
          performance_delta: %{
            response_time_improvement: Float.round(response_time_improvement, 1),
            error_rate_improvement: Float.round(error_rate_improvement, 1)
          },
          jtbd_completed: true
        }
        
      {:error, _} ->
        %{
          new_metrics: original_analysis.current_metrics,
          improvement_achieved: false,
          performance_delta: %{
            response_time_improvement: 0.0,
            error_rate_improvement: 0.0
          },
          jtbd_completed: false
        }
    end
  end

  defp calculate_priority_score(context) do
    base_score = case context.urgency do
      "high" -> 80
      "medium" -> 60
      "low" -> 40
    end
    
    # Adjust based on impact
    impact_modifier = case context.user_impact do
      "severe" -> 20
      "moderate" -> 10
      "minimal" -> 0
    end
    
    min(base_score + impact_modifier, 100)
  end

  defp emit_telemetry(event, measurements, metadata) do
    :telemetry.execute(event, measurements, metadata)
  end

  defp setup_telemetry_collection do
    ref = make_ref()
    
    events = [
      [:jtbd, :analyze_system_state, :start],
      [:jtbd, :analyze_system_state, :complete],
      [:jtbd, :generate_plan, :start],
      [:jtbd, :generate_plan, :complete],
      [:jtbd, :validate_plan, :start],
      [:jtbd, :validate_plan, :complete],
      [:jtbd, :execute_improvement, :start],
      [:jtbd, :execute_improvement, :complete],
      [:jtbd, :execute_step, :start],
      [:jtbd, :execute_step, :complete],
      [:jtbd, :monitor_results, :start],
      [:jtbd, :monitor_results, :complete]
    ]
    
    for event <- events do
      :telemetry.attach(
        "jtbd-benchmark-#{System.unique_integer()}",
        event,
        fn event_name, measurements, metadata, {pid, events_ref} ->
          send(pid, {:telemetry_event, events_ref, %{
            event: event_name,
            measurements: measurements,
            metadata: metadata,
            timestamp: System.system_time(:microsecond)
          }})
        end,
        {self(), ref}
      )
    end
    
    ref
  end

  defp collect_telemetry_events(ref, timeout) do
    collect_events_loop(ref, [], System.monotonic_time(:millisecond) + timeout)
  end

  defp collect_events_loop(ref, events, end_time) do
    if System.monotonic_time(:millisecond) >= end_time do
      Enum.reverse(events)
    else
      receive do
        {:telemetry_event, ^ref, event} ->
          collect_events_loop(ref, [event | events], end_time)
      after
        50 ->
          collect_events_loop(ref, events, end_time)
      end
    end
  end

  defp generate_jtbd_report(result, total_duration, telemetry_events) do
    IO.puts("\n" <> "=" |> String.duplicate(60))
    IO.puts("📊 JTBD BENCHMARK REPORT")
    IO.puts("=" |> String.duplicate(60))
    
    IO.puts("\n🎯 JTBD Context:")
    IO.puts("  • Job: Fix performance degradation")
    IO.puts("  • Trigger: Response time degraded to #{result.context.current_response_time}ms")
    IO.puts("  • Error rate: #{result.context.error_rate * 100}%")
    
    IO.puts("\n⏱️  Execution Times:")
    IO.puts("  • Total JTBD Time: #{Float.round(total_duration / 1000, 1)}ms")
    IO.puts("  • Analysis: #{Float.round(result.step_times.analysis / 1000, 1)}ms")
    IO.puts("  • Planning: #{Float.round(result.step_times.planning / 1000, 1)}ms") 
    IO.puts("  • Validation: #{Float.round(result.step_times.validation / 1000, 1)}ms")
    IO.puts("  • Execution: #{Float.round(result.step_times.execution / 1000, 1)}ms")
    IO.puts("  • Monitoring: #{Float.round(result.step_times.monitoring / 1000, 1)}ms")
    
    IO.puts("\n✅ JTBD Success Metrics:")
    IO.puts("  • Overall Success: #{if result.success, do: "✅ YES", else: "❌ NO"}")
    IO.puts("  • Plan Validated: #{if result.validation.is_valid, do: "✅ YES", else: "❌ NO"}")
    IO.puts("  • Improvement Achieved: #{if result.monitoring.improvement_achieved, do: "✅ YES", else: "❌ NO"}")
    
    if result.monitoring.improvement_achieved do
      IO.puts("  • Response Time Improved: #{result.monitoring.performance_delta.response_time_improvement}%")
      IO.puts("  • Error Rate Improved: #{result.monitoring.performance_delta.error_rate_improvement}%")
    end
    
    IO.puts("\n📈 Telemetry Events Captured: #{length(telemetry_events)}")
    
    # Step performance analysis
    step_events = Enum.group_by(telemetry_events, fn event -> 
      event.event |> Enum.at(1)  # Get the step name (analyze_system_state, generate_plan, etc.)
    end)
    
    IO.puts("\n🔍 Step Performance Analysis:")
    for {step, events} <- step_events do
      start_events = Enum.filter(events, fn e -> List.last(e.event) == :start end)
      complete_events = Enum.filter(events, fn e -> List.last(e.event) == :complete end)
      
      if length(start_events) > 0 and length(complete_events) > 0 do
        IO.puts("  • #{step}: #{length(complete_events)} executions")
      end
    end
    
    # JTBD efficiency score
    efficiency_score = calculate_jtbd_efficiency(result, total_duration)
    IO.puts("\n🏆 JTBD Efficiency Score: #{Float.round(efficiency_score * 100, 1)}%")
    
    # Recommendations
    generate_jtbd_recommendations(result, total_duration)
    
    IO.puts("\n" <> "=" |> String.duplicate(60))
  end

  defp calculate_jtbd_efficiency(result, total_duration) do
    # Factors affecting JTBD efficiency
    success_factor = if result.success, do: 1.0, else: 0.0
    speed_factor = max(0.1, min(1.0, 10000 / total_duration)) # Bonus for completing under 10s
    improvement_factor = if result.monitoring.improvement_achieved, do: 1.0, else: 0.5
    
    (success_factor + speed_factor + improvement_factor) / 3
  end

  defp generate_jtbd_recommendations(result, total_duration) do
    IO.puts("\n💡 JTBD Optimization Recommendations:")
    
    cond do
      not result.success ->
        IO.puts("  • ⚠️  JTBD failed - investigate validation or execution issues")
        
      total_duration > 1_000_000 ->  # > 1 second
        IO.puts("  • 🐌 JTBD taking too long - optimize step execution times")
        
      not result.monitoring.improvement_achieved ->
        IO.puts("  • 📉 Improvements not effective - review analysis and planning quality")
        
      true ->
        IO.puts("  • 🎉 JTBD performing well - maintain current process quality")
    end
    
    # Specific step recommendations
    slowest_step = Enum.max_by(result.step_times, fn {_step, time} -> time end)
    {step_name, step_time} = slowest_step
    
    if step_time > 100_000 do  # > 100ms
      IO.puts("  • ⏰ #{step_name} is the bottleneck (#{Float.round(step_time / 1000, 1)}ms)")
    end
  end
end

# Run the benchmark
if System.argv() == [] do
  SimpleJTBDE2EBenchmark.run_jtbd_benchmark()
else
  IO.puts("Usage: elixir simple_jtbd_e2e_benchmark.exs")
  IO.puts("This benchmark tests the core JTBD: AI system self-improvement")
end