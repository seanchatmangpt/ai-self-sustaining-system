#!/usr/bin/env elixir

IO.puts("🚀 Comprehensive System Performance Benchmark")
IO.puts("=============================================")

# System information
system_info = %{
  elixir: System.version(),
  otp: System.otp_release(),
  schedulers: System.schedulers_online(),
  memory: :erlang.memory(:total) |> div(1024*1024),
  architecture: :erlang.system_info(:system_architecture),
  processes: :erlang.system_info(:process_count)
}

IO.puts("System Information:")
Enum.each(system_info, fn {key, value} ->
  IO.puts("  #{String.capitalize(to_string(key))}: #{value}")
end)

defmodule SystemBenchmark do
  def benchmark(name, iterations, fun) when is_function(fun, 0) do
    IO.puts("\n🔄 Running #{name} (#{iterations} iterations)...")
    
    times = for _ <- 1..iterations do
      {time, _} = :timer.tc(fun)
      time
    end
    
    avg = Enum.sum(times) / length(times)
    min_time = Enum.min(times)
    max_time = Enum.max(times)
    
    %{
      name: name,
      iterations: iterations,
      avg_microseconds: avg,
      min_microseconds: min_time,
      max_microseconds: max_time,
      avg_milliseconds: avg / 1000,
      min_milliseconds: min_time / 1000,
      max_milliseconds: max_time / 1000
    }
  end
  
  def print_results(results) do
    IO.puts("  Average: #{Float.round(results.avg_milliseconds, 2)}ms")
    IO.puts("  Min:     #{Float.round(results.min_milliseconds, 2)}ms")
    IO.puts("  Max:     #{Float.round(results.max_milliseconds, 2)}ms")
  end
  
  # Test functions
  def fibonacci(n) when n <= 1, do: n
  def fibonacci(n), do: fibonacci(n-1) + fibonacci(n-2)
  
  def prime_check(n) do
    if n < 2, do: false, else: not Enum.any?(2..trunc(:math.sqrt(n)), &(rem(n, &1) == 0))
  end
  
  def json_processing do
    data = %{
      users: for i <- 1..100 do
        %{id: i, name: "User#{i}", active: rem(i, 2) == 0}
      end
    }
    
    data
    |> Jason.encode!()
    |> Jason.decode!()
    |> get_in(["users"])
    |> Enum.filter(&(&1["active"]))
    |> length()
  end
  
  def process_spawning do
    parent = self()
    
    tasks = for i <- 1..50 do
      spawn(fn -> 
        result = i * i
        send(parent, {:result, result})
      end)
    end
    
    results = for _ <- 1..50 do
      receive do
        {:result, result} -> result
      end
    end
    
    Enum.sum(results)
  end
  
  def memory_operations do
    # Create and manipulate data structures
    list = Enum.to_list(1..1000)
    map = Enum.into(list, %{}, fn x -> {x, x * x} end)
    
    map
    |> Map.values()
    |> Enum.sum()
  end
end

# Run benchmarks
IO.puts("\n📊 Benchmark Results:")
IO.puts("====================")

# Check if Jason is available for JSON test
json_available = Code.ensure_loaded?(Jason)

benchmarks = [
  {"CPU - Fibonacci(25)", 10, fn -> SystemBenchmark.fibonacci(25) end},
  {"CPU - Prime Check (97)", 100, fn -> SystemBenchmark.prime_check(97) end},
  {"Memory - Data Structures", 50, fn -> SystemBenchmark.memory_operations() end},
  {"Concurrency - Process Spawning", 20, fn -> SystemBenchmark.process_spawning() end}
]

# Add JSON benchmark if available
benchmarks = if json_available do
  benchmarks ++ [{"I/O - JSON Processing", 50, fn -> SystemBenchmark.json_processing() end}]
else
  IO.puts("ℹ️  Skipping JSON benchmark (Jason not available)")
  benchmarks
end

results = Enum.map(benchmarks, fn {name, iterations, fun} ->
  result = SystemBenchmark.benchmark(name, iterations, fun)
  SystemBenchmark.print_results(result)
  result
end)

# Summary
IO.puts("\n📈 Performance Summary:")
IO.puts("======================")

total_avg = results |> Enum.map(&(&1.avg_milliseconds)) |> Enum.sum()
IO.puts("Total Average Time: #{Float.round(total_avg, 2)}ms")

fastest = results |> Enum.min_by(&(&1.avg_milliseconds))
slowest = results |> Enum.max_by(&(&1.avg_milliseconds))

IO.puts("Fastest Operation: #{fastest.name} (#{Float.round(fastest.avg_milliseconds, 2)}ms)")
IO.puts("Slowest Operation: #{slowest.name} (#{Float.round(slowest.avg_milliseconds, 2)}ms)")

# Performance rating
rating = cond do
  total_avg < 50 -> "🚀 EXCELLENT"
  total_avg < 100 -> "✅ GOOD"
  total_avg < 200 -> "⚠️  FAIR"
  true -> "🐌 NEEDS OPTIMIZATION"
end

IO.puts("Performance Rating: #{rating}")
IO.puts("\n✅ Comprehensive benchmark completed")