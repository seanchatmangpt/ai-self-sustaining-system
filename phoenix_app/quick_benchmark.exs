# Quick benchmark for minimal job with OpenTelemetry
alias SelfSustaining.Jobs.MinimalBenchmarkJob

# Direct job performance test
start_time = System.monotonic_time(:microsecond)

for i <- 1..1000 do
  oban_job = %Oban.Job{
    id: i,
    args: %{"counter" => i},
    worker: "SelfSustaining.Jobs.MinimalBenchmarkJob",
    queue: "ash_oban",
    attempt: 1,
    max_attempts: 3,
    inserted_at: DateTime.utc_now(),
    scheduled_at: DateTime.utc_now()
  }
  MinimalBenchmarkJob.perform(oban_job)
end

end_time = System.monotonic_time(:microsecond)
total_time = end_time - start_time

IO.puts("=== Oban Job Performance with OpenTelemetry ===")
IO.puts("Jobs processed: 1000")
IO.puts("Total time: #{total_time} microseconds (#{total_time / 1000} ms)")
IO.puts("Average per job: #{total_time / 1000} microseconds")
IO.puts("Jobs per second: #{1_000_000 / (total_time / 1000) |> Float.round(0)}")

# OpenTelemetry overhead test
IO.puts("\n=== OpenTelemetry Overhead Comparison ===")

# Without OpenTelemetry
start_without = System.monotonic_time(:microsecond)
for i <- 1..1000 do
  counter = i
  _result = counter + 1
end
end_without = System.monotonic_time(:microsecond)
time_without = end_without - start_without

# With OpenTelemetry
start_with = System.monotonic_time(:microsecond)
for i <- 1..1000 do
  OpenTelemetry.Tracer.with_span "benchmark_test" do
    OpenTelemetry.Tracer.set_attributes([{"counter", i}])
    counter = i
    result = counter + 1
    OpenTelemetry.Tracer.set_attributes([{"result", result}])
  end
end
end_with = System.monotonic_time(:microsecond)
time_with = end_with - start_with

overhead = time_with - time_without
overhead_percent = (overhead / time_without * 100) |> Float.round(2)

IO.puts("Without OpenTelemetry: #{time_without} μs")
IO.puts("With OpenTelemetry: #{time_with} μs") 
IO.puts("Overhead: #{overhead} μs (#{overhead_percent}%)")
IO.puts("Per operation overhead: #{overhead / 1000} μs")