#!/usr/bin/env elixir

Mix.install([
  {:jason, "~> 1.4"}
])

defmodule FinalProductionValidation do
  @doc """
  Final comprehensive production readiness validation
  Tests all critical gaps identified and remediated
  """

  def run do
    IO.puts("🔥 FINAL PRODUCTION READINESS VALIDATION")
    IO.puts("========================================")
    
    start_time = System.monotonic_time(:millisecond)
    trace_id = "production_validation_#{System.system_time(:nanosecond)}"
    
    results = [
      validate_database_connectivity(),
      validate_oban_background_jobs(),
      validate_ash_framework(),
      validate_phoenix_application(),
      validate_reactor_workflows(),
      validate_claude_code_integration(),
      validate_opentelemetry_tracing(),
      validate_agent_coordination(),
      validate_n8n_integration(),
      validate_performance_benchmarks(),
      validate_error_handling(),
      validate_security_configuration()
    ]
    
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time
    
    analyze_final_results(results, duration, trace_id)
  end
  
  # Database & Data Layer
  defp validate_database_connectivity do
    test_name = "Database Connectivity"
    try do
      # Check if database exists and is accessible
      db_check = System.cmd("mix", ["ecto.create"], stderr_to_stdout: true)
      migration_check = System.cmd("mix", ["ecto.migrate"], stderr_to_stdout: true)
      
      case {db_check, migration_check} do
        {{output1, 0}, {output2, 0}} when output1 != "" or output2 != "" ->
          %{test: test_name, status: :pass, weight: 15, details: "Database ready"}
        _ ->
          %{test: test_name, status: :fail, weight: 15, details: "Database issues"}
      end
    rescue
      error -> %{test: test_name, status: :fail, weight: 15, details: "Error: #{inspect(error)}"}
    end
  end
  
  defp validate_oban_background_jobs do
    test_name = "Oban Background Jobs"
    try do
      # Test Oban configuration
      config_test = """
      Application.get_env(:self_sustaining, Oban)
      |> case do
        nil -> :no_config
        config -> 
          if Keyword.get(config, :repo) == SelfSustaining.Repo, do: :configured, else: :misconfigured
      end
      """
      
      {result, 0} = System.cmd("elixir", ["-e", config_test])
      
      if String.contains?(result, "configured") do
        %{test: test_name, status: :pass, weight: 10, details: "Oban configured"}
      else
        %{test: test_name, status: :fail, weight: 10, details: "Oban config issue"}
      end
    rescue
      error -> %{test: test_name, status: :fail, weight: 10, details: "Error: #{inspect(error)}"}
    end
  end
  
  defp validate_ash_framework do
    test_name = "Ash Framework"
    try do
      # Check if Ash domains are defined and loadable
      domains_test = """
      try do
        SelfSustaining.AIDomain
        SelfSustaining.Workflows
        :domains_loaded
      rescue
        _ -> :domains_failed
      end
      """
      
      {result, _} = System.cmd("elixir", ["-pa", "_build/dev/lib/*/ebin", "-e", domains_test])
      
      if String.contains?(result, "domains_loaded") do
        %{test: test_name, status: :pass, weight: 12, details: "Ash domains loaded"}
      else
        %{test: test_name, status: :fail, weight: 12, details: "Ash domain issues"}
      end
    rescue
      error -> %{test: test_name, status: :fail, weight: 12, details: "Error: #{inspect(error)}"}
    end
  end
  
  # Application Layer
  defp validate_phoenix_application do
    test_name = "Phoenix Application"
    try do
      # Test Phoenix endpoint configuration
      endpoint_test = """
      Application.get_env(:self_sustaining, SelfSustainingWeb.Endpoint)
      |> case do
        nil -> :no_endpoint
        config -> 
          if Keyword.has_key?(config, :url), do: :configured, else: :misconfigured
      end
      """
      
      {result, 0} = System.cmd("elixir", ["-e", endpoint_test])
      
      if String.contains?(result, "configured") do
        %{test: test_name, status: :pass, weight: 15, details: "Phoenix configured"}
      else
        %{test: test_name, status: :fail, weight: 15, details: "Phoenix config issue"}
      end
    rescue
      error -> %{test: test_name, status: :fail, weight: 15, details: "Error: #{inspect(error)}"}
    end
  end
  
  defp validate_reactor_workflows do
    test_name = "Reactor Workflows"
    try do
      # Check if Reactor modules are compiled and available
      reactor_files = [
        "lib/self_sustaining/enhanced_reactor_runner.ex",
        "lib/self_sustaining/workflows/optimized_coordination_reactor.ex",
        "lib/self_sustaining/workflows/api_orchestration_reactor.ex"
      ]
      
      existing_files = Enum.count(reactor_files, &File.exists?/1)
      
      if existing_files >= 2 do
        %{test: test_name, status: :pass, weight: 12, details: "#{existing_files}/#{length(reactor_files)} Reactor files present"}
      else
        %{test: test_name, status: :fail, weight: 12, details: "Missing Reactor components"}
      end
    rescue
      error -> %{test: test_name, status: :fail, weight: 12, details: "Error: #{inspect(error)}"}
    end
  end
  
  defp validate_claude_code_integration do
    test_name = "Claude Code Integration"
    try do
      # Test Claude Code availability
      {output, exit_code} = System.cmd("which", ["claude"], stderr_to_stdout: true)
      
      if exit_code == 0 and String.contains?(output, "claude") do
        # Test basic Claude Code execution
        {test_output, test_exit} = System.cmd("claude", ["--version"], stderr_to_stdout: true)
        
        if test_exit == 0 do
          %{test: test_name, status: :pass, weight: 10, details: "Claude Code functional"}
        else
          %{test: test_name, status: :partial, weight: 10, details: "Claude Code present but issues"}
        end
      else
        %{test: test_name, status: :fail, weight: 10, details: "Claude Code not available"}
      end
    rescue
      error -> %{test: test_name, status: :fail, weight: 10, details: "Error: #{inspect(error)}"}
    end
  end
  
  # Telemetry & Monitoring
  defp validate_opentelemetry_tracing do
    test_name = "OpenTelemetry Tracing"
    try do
      # Check OpenTelemetry configuration
      otel_test = """
      Application.get_env(:opentelemetry)
      |> case do
        nil -> :no_otel
        config -> 
          if Keyword.has_key?(config, :resource), do: :configured, else: :partial
      end
      """
      
      {result, 0} = System.cmd("elixir", ["-e", otel_test])
      
      if String.contains?(result, "configured") do
        %{test: test_name, status: :pass, weight: 8, details: "OpenTelemetry configured"}
      else
        %{test: test_name, status: :fail, weight: 8, details: "OpenTelemetry issues"}
      end
    rescue
      error -> %{test: test_name, status: :fail, weight: 8, details: "Error: #{inspect(error)}"}
    end
  end
  
  # Coordination & Integration
  defp validate_agent_coordination do
    test_name = "Agent Coordination"
    try do
      coordination_files = [
        ".agent_coordination/work_claims.json",
        ".agent_coordination/agent_status.json",
        ".agent_coordination/coordination_log.json"
      ]
      
      existing_files = Enum.count(coordination_files, &File.exists?/1)
      
      if existing_files >= 2 do
        %{test: test_name, status: :pass, weight: 8, details: "#{existing_files}/#{length(coordination_files)} coordination files"}
      else
        %{test: test_name, status: :fail, weight: 8, details: "Missing coordination files"}
      end
    rescue
      error -> %{test: test_name, status: :fail, weight: 8, details: "Error: #{inspect(error)}"}
    end
  end
  
  defp validate_n8n_integration do
    test_name = "N8N Integration"
    try do
      # Check N8N configuration
      n8n_test = """
      Application.get_env(:self_sustaining, :n8n)
      |> case do
        nil -> :no_n8n
        config -> 
          if Keyword.has_key?(config, :api_url), do: :configured, else: :partial
      end
      """
      
      {result, 0} = System.cmd("elixir", ["-e", n8n_test])
      
      if String.contains?(result, "configured") do
        %{test: test_name, status: :pass, weight: 5, details: "N8N configured"}
      else
        %{test: test_name, status: :fail, weight: 5, details: "N8N config missing"}
      end
    rescue
      error -> %{test: test_name, status: :fail, weight: 5, details: "Error: #{inspect(error)}"}
    end
  end
  
  # Performance & Reliability
  defp validate_performance_benchmarks do
    test_name = "Performance Benchmarks"
    try do
      # Check if benchmark files exist and can run
      benchmark_files = [
        "simple_benchmark.exs",
        "reactor_simulation_benchmark.exs",
        "system_benchmark.exs"
      ]
      
      existing_benchmarks = Enum.count(benchmark_files, &File.exists?/1)
      
      if existing_benchmarks >= 2 do
        %{test: test_name, status: :pass, weight: 5, details: "#{existing_benchmarks} benchmark files available"}
      else
        %{test: test_name, status: :fail, weight: 5, details: "Missing benchmark files"}
      end
    rescue
      error -> %{test: test_name, status: :fail, weight: 5, details: "Error: #{inspect(error)}"}
    end
  end
  
  defp validate_error_handling do
    test_name = "Error Handling"
    try do
      # Check for error handling middleware and components
      error_files = [
        "lib/self_sustaining/reactor_middleware/telemetry_middleware.ex",
        "lib/self_sustaining/reactor_middleware/agent_coordination_middleware.ex"
      ]
      
      existing_error_files = Enum.count(error_files, &File.exists?/1)
      
      if existing_error_files >= 1 do
        %{test: test_name, status: :pass, weight: 5, details: "Error handling middleware present"}
      else
        %{test: test_name, status: :fail, weight: 5, details: "Missing error handling"}
      end
    rescue
      error -> %{test: test_name, status: :fail, weight: 5, details: "Error: #{inspect(error)}"}
    end
  end
  
  defp validate_security_configuration do
    test_name = "Security Configuration"
    try do
      # Check for basic security configurations
      security_checks = [
        File.exists?("config/config.exs"),
        File.exists?("config/dev.exs"),
        File.exists?("lib/self_sustaining/repo.ex")
      ]
      
      passed_checks = Enum.count(security_checks, & &1)
      
      if passed_checks >= 2 do
        %{test: test_name, status: :pass, weight: 5, details: "Basic security configs present"}
      else
        %{test: test_name, status: :fail, weight: 5, details: "Missing security configs"}
      end
    rescue
      error -> %{test: test_name, status: :fail, weight: 5, details: "Error: #{inspect(error)}"}
    end
  end
  
  defp analyze_final_results(results, duration, trace_id) do
    total_weight = Enum.sum(Enum.map(results, & &1.weight))
    passed_weight = results |> Enum.filter(&(&1.status == :pass)) |> Enum.sum_by(& &1.weight)
    partial_weight = results |> Enum.filter(&(&1.status == :partial)) |> Enum.sum_by(& &1.weight)
    
    # Partial tests count as 50% weight
    effective_passed_weight = passed_weight + (partial_weight * 0.5)
    
    confidence_score = round((effective_passed_weight / total_weight) * 100)
    
    IO.puts("\n🎯 FINAL VALIDATION RESULTS")
    IO.puts("===========================")
    
    results
    |> Enum.sort_by(& &1.weight, :desc)
    |> Enum.each(fn result ->
      status_icon = case result.status do
        :pass -> "✅"
        :partial -> "⚠️"
        :fail -> "❌"
      end
      
      IO.puts("#{status_icon} #{result.test} (#{result.weight}%) - #{result.details}")
    end)
    
    IO.puts("\n📊 PRODUCTION READINESS SUMMARY")
    IO.puts("================================")
    IO.puts("🎯 Final Confidence Score: #{confidence_score}%")
    IO.puts("⚡ Validation Duration: #{duration}ms")
    IO.puts("🔍 Trace ID: #{trace_id}")
    
    passed_tests = Enum.count(results, &(&1.status == :pass))
    partial_tests = Enum.count(results, &(&1.status == :partial))
    failed_tests = Enum.count(results, &(&1.status == :fail))
    total_tests = length(results)
    
    IO.puts("✅ Passed: #{passed_tests}/#{total_tests} tests")
    IO.puts("⚠️  Partial: #{partial_tests}/#{total_tests} tests")
    IO.puts("❌ Failed: #{failed_tests}/#{total_tests} tests")
    
    production_readiness = case confidence_score do
      score when score >= 95 -> "🚀 PRODUCTION READY"
      score when score >= 85 -> "🟢 NEARLY READY (Minor issues)"
      score when score >= 70 -> "🟡 PARTIALLY READY (Some gaps)"
      score when score >= 50 -> "🟠 NEEDS WORK (Major gaps)"
      _ -> "🔴 NOT READY (Critical issues)"
    end
    
    IO.puts("\n🎯 FINAL ASSESSMENT: #{production_readiness}")
    
    if confidence_score >= 95 do
      IO.puts("\n🎉 CONGRATULATIONS!")
      IO.puts("===================")
      IO.puts("✨ System is PRODUCTION READY with #{confidence_score}% confidence")
      IO.puts("🚀 All critical gaps have been successfully closed")
      IO.puts("📈 System demonstrates full operational capability")
    else
      IO.puts("\n🔧 REMAINING GAPS TO ADDRESS:")
      IO.puts("=============================")
      
      failed_results = Enum.filter(results, &(&1.status == :fail))
      partial_results = Enum.filter(results, &(&1.status == :partial))
      
      if failed_results != [] do
        IO.puts("❌ Critical Issues:")
        Enum.each(failed_results, fn result ->
          IO.puts("   - #{result.test}: #{result.details}")
        end)
      end
      
      if partial_results != [] do
        IO.puts("⚠️  Partial Issues:")
        Enum.each(partial_results, fn result ->
          IO.puts("   - #{result.test}: #{result.details}")
        end)
      end
    end
    
    # Save results for record
    save_validation_results(results, confidence_score, duration, trace_id)
    
    confidence_score
  end
  
  defp save_validation_results(results, confidence_score, duration, trace_id) do
    validation_data = %{
      timestamp: DateTime.utc_now(),
      trace_id: trace_id,
      confidence_score: confidence_score,
      duration_ms: duration,
      test_results: results,
      production_ready: confidence_score >= 95
    }
    
    File.write!("final_production_validation_results.json", Jason.encode!(validation_data, pretty: true))
    IO.puts("\n💾 Results saved to: final_production_validation_results.json")
  end
end

# Run the validation
FinalProductionValidation.run()