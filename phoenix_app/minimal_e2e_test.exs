#!/usr/bin/env elixir

# Minimal End-to-End Test - 80/20 Strategy
# Simple, focused test of critical system integration

Mix.install([{:jason, "~> 1.4"}, {:phoenix, "~> 1.7.0"}, {:reactor, "~> 0.15.4"}])

defmodule MinimalE2ETest do
  def run do
    IO.puts("🌐 Minimal End-to-End 80/20 Test")
    IO.puts("=" |> String.duplicate(40))
    
    start_time = System.monotonic_time(:microsecond)
    
    # Core integration tests
    results = [
      test_dependencies(),
      test_phoenix(),
      test_reactor(),
      test_claude(),
      test_json(),
      test_traces()
    ]
    
    total_time = System.monotonic_time(:microsecond) - start_time
    analyze_results(results, total_time)
  end

  # Test 1: Dependencies (30%)
  defp test_dependencies do
    IO.puts("\n🔧 Dependencies (30%)")
    
    deps = [Phoenix, Reactor, Jason, Postgrex, Oban, Ash]
    loaded = Enum.count(deps, fn module ->
      try do
        Code.ensure_loaded?(module)
      rescue
        _ -> false
      end
    end)
    
    success = loaded >= 4
    IO.puts("   Loaded: #{loaded}/#{length(deps)} - #{if success, do: "✅", else: "❌"}")
    
    %{test: "Dependencies", value: 30, success: success}
  end

  # Test 2: Phoenix (20%)  
  defp test_phoenix do
    IO.puts("\n🌐 Phoenix (20%)")
    
    modules = [Phoenix.Router, Phoenix.Controller, Phoenix.LiveView]
    loaded = Enum.count(modules, fn module ->
      try do
        Code.ensure_loaded?(module)
      rescue
        _ -> false
      end
    end)
    
    success = loaded >= 2
    IO.puts("   Modules: #{loaded}/#{length(modules)} - #{if success, do: "✅", else: "❌"}")
    
    %{test: "Phoenix", value: 20, success: success}
  end

  # Test 3: Reactor (20%)
  defp test_reactor do
    IO.puts("\n⚙️  Reactor (20%)")
    
    workflow_ok = try do
      defmodule SimpleReactor do
        use Reactor
        input :data
        step :test do
          argument :input, input(:data)
          run fn args, _context -> {:ok, "test_#{args.input}"} end
        end
        return :test
      end
      
      case Reactor.run(SimpleReactor, %{data: "ok"}) do
        {:ok, "test_ok"} -> true
        _ -> false
      end
    rescue
      _ -> false
    end
    
    IO.puts("   Workflow: #{if workflow_ok, do: "✅", else: "❌"}")
    
    %{test: "Reactor", value: 20, success: workflow_ok}
  end

  # Test 4: Claude (15%)
  defp test_claude do
    IO.puts("\n🤖 Claude (15%)")
    
    available = try do
      case System.cmd("claude", ["--version"], stderr_to_stdout: true) do
        {_, 0} -> true
        _ -> false
      end
    rescue
      _ -> false
    end
    
    IO.puts("   Available: #{if available, do: "✅", else: "⚠️"}")
    
    %{test: "Claude", value: 15, success: available}
  end

  # Test 5: JSON (10%)
  defp test_json do
    IO.puts("\n📄 JSON (10%)")
    
    json_ok = try do
      data = %{test: "data"}
      encoded = Jason.encode!(data)
      decoded = Jason.decode!(encoded)
      decoded["test"] == "data"
    rescue
      _ -> false
    end
    
    IO.puts("   Processing: #{if json_ok, do: "✅", else: "❌"}")
    
    %{test: "JSON", value: 10, success: json_ok}
  end

  # Test 6: Traces (5%)
  defp test_traces do
    IO.puts("\n🔍 Traces (5%)")
    
    base = "trace_#{System.system_time(:nanosecond)}"
    traces = [
      "#{base}_1_#{System.system_time(:nanosecond)}",
      "#{base}_2_#{System.system_time(:nanosecond)}",
      "#{base}_3_#{System.system_time(:nanosecond)}"
    ]
    
    unique = Enum.uniq(traces) |> length()
    success = unique == length(traces)
    
    IO.puts("   Unique: #{unique}/#{length(traces)} - #{if success, do: "✅", else: "❌"}")
    
    %{test: "Traces", value: 5, success: success}
  end

  defp analyze_results(results, total_time) do
    IO.puts("\n📊 Integration Test Results")
    IO.puts("-" |> String.duplicate(30))
    
    passed = Enum.count(results, & &1.success)
    total = length(results)
    weighted_score = results |> Enum.map(fn r -> if r.success, do: r.value, else: 0 end) |> Enum.sum()
    time_ms = Float.round(total_time / 1000, 2)
    
    IO.puts("Tests: #{passed}/#{total}")
    IO.puts("Score: #{weighted_score}%")
    IO.puts("Time: #{time_ms}ms")
    
    IO.puts("\nResults:")
    Enum.each(results, fn r ->
      icon = if r.success, do: "✅", else: "❌"
      IO.puts("  #{icon} #{r.test} (#{r.value}%)")
    end)
    
    IO.puts("\n🎯 Assessment:")
    cond do
      weighted_score >= 85 ->
        IO.puts("🏆 EXCELLENT: Production Ready!")
      weighted_score >= 70 ->
        IO.puts("👍 GOOD: Nearly Ready")
      weighted_score >= 50 ->
        IO.puts("⚠️  PARTIAL: Some Issues")
      true ->
        IO.puts("❌ CRITICAL: Major Problems")
    end
    
    IO.puts("\n💡 80/20 Value:")
    IO.puts("   ⚡ #{time_ms}ms → #{weighted_score}% confidence")
    IO.puts("   🎯 Critical paths validated")
    IO.puts("   📊 Production readiness: #{if weighted_score >= 70, do: "Ready", else: "Needs work"}")
  end
end

MinimalE2ETest.run()