#!/usr/bin/env elixir

IO.puts("🚀 Simple Performance Benchmark")
IO.puts("==============================")

# Basic system info
IO.puts("System Information:")
IO.puts("  Elixir: #{System.version()}")
IO.puts("  OTP: #{System.otp_release()}")
IO.puts("  CPU cores: #{System.schedulers_online()}")
IO.puts("  Memory: #{:erlang.memory(:total) |> div(1024*1024)} MB")

# Basic performance tests
defmodule SimpleBenchmark do
  def measure_time(fun) do
    {time, result} = :timer.tc(fun)
    {time, result}
  end

  def cpu_intensive_task(n) do
    Enum.reduce(1..n, 0, fn i, acc -> 
      acc + :math.pow(i, 2) |> round()
    end)
  end

  def memory_intensive_task(n) do
    1..n
    |> Enum.map(&Integer.to_string/1)
    |> Enum.map(&String.reverse/1)
    |> length()
  end
end

# Run benchmarks
IO.puts("\nBenchmark Results:")
IO.puts("==================")

# CPU test
{cpu_time, _} = SimpleBenchmark.measure_time(fn -> 
  SimpleBenchmark.cpu_intensive_task(10000)
end)
IO.puts("CPU Test (10k iterations): #{cpu_time |> div(1000)} ms")

# Memory test  
{mem_time, _} = SimpleBenchmark.measure_time(fn ->
  SimpleBenchmark.memory_intensive_task(1000)
end)
IO.puts("Memory Test (1k items): #{mem_time |> div(1000)} ms")

# Spawn test
{spawn_time, _} = SimpleBenchmark.measure_time(fn ->
  tasks = for i <- 1..100 do
    Task.async(fn -> i * i end)
  end
  Enum.map(tasks, &Task.await/1)
end)
IO.puts("Concurrency Test (100 tasks): #{spawn_time |> div(1000)} ms")

IO.puts("\n✅ Simple benchmark completed")