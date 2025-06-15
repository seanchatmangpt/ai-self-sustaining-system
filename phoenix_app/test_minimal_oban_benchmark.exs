# Simple benchmark test for minimal Oban job with OpenTelemetry
# Run with: mix run test_minimal_oban_benchmark.exs

alias SelfSustaining.Jobs.MinimalBenchmarkJob

defmodule ObanBenchmarkTest do
  def run_simple_benchmark do
    IO.puts("=== Starting Oban Job Benchmark ===")
    
    # Test direct job performance
    start_time = System.monotonic_time(:microsecond)
    
    # Create test job
    oban_job = %Oban.Job{
      id: 1,
      args: %{"counter" => 42},
      worker: "SelfSustaining.Jobs.MinimalBenchmarkJob",
      queue: "ash_oban",
      attempt: 1,
      max_attempts: 3,
      inserted_at: DateTime.utc_now(),
      scheduled_at: DateTime.utc_now()
    }
    
    # Run job directly 1000 times
    for i <- 1..1000 do
      MinimalBenchmarkJob.perform(%{oban_job | args: %{"counter" => i}})
    end
    
    end_time = System.monotonic_time(:microsecond)
    total_time = end_time - start_time
    
    IO.puts("Processed 1000 jobs in #{total_time} microseconds")
    IO.puts("Average time per job: #{total_time / 1000} microseconds")
    IO.puts("Jobs per second: #{1_000_000 / (total_time / 1000)}")
    
    # Test enqueueing performance
    IO.puts("\n=== Testing Job Enqueueing ===")
    start_enqueue = System.monotonic_time(:microsecond)
    
    jobs = for i <- 1..100 do
      MinimalBenchmarkJob.new(%{counter: i})
    end
    
    {:ok, inserted_jobs} = Oban.insert_all(jobs)
    
    end_enqueue = System.monotonic_time(:microsecond)
    enqueue_time = end_enqueue - start_enqueue
    
    IO.puts("Enqueued #{length(inserted_jobs)} jobs in #{enqueue_time} microseconds")
    IO.puts("Average enqueue time: #{enqueue_time / length(inserted_jobs)} microseconds per job")
    
    # Wait for jobs to process and show queue stats
    Process.sleep(2000)
    
    # Check job stats from database
    completed_count = Ecto.Adapters.SQL.query!(SelfSustaining.Repo, 
      "SELECT COUNT(*) FROM oban_jobs WHERE queue = 'ash_oban' AND state = 'completed'", [])
    count = completed_count.rows |> List.first() |> List.first()
    IO.puts("Completed jobs in queue: #{count}")
    
    IO.puts("\n=== Benchmark Complete ===")
  end
  
  def run_telemetry_benchmark do
    IO.puts("\n=== OpenTelemetry Performance Impact ===")
    
    # Test without telemetry
    start_without = System.monotonic_time(:microsecond)
    
    for i <- 1..1000 do
      # Minimal work without OpenTelemetry
      counter = i
      _result = counter + 1
    end
    
    end_without = System.monotonic_time(:microsecond)
    time_without = end_without - start_without
    
    # Test with telemetry
    start_with = System.monotonic_time(:microsecond)
    
    for i <- 1..1000 do
      OpenTelemetry.Tracer.with_span "benchmark_test" do
        OpenTelemetry.Tracer.set_attributes([
          {"counter", i},
          {"started_at", System.system_time(:microsecond)}
        ])
        counter = i
        result = counter + 1
        OpenTelemetry.Tracer.set_attributes([
          {"result", result},
          {"completed_at", System.system_time(:microsecond)}
        ])
      end
    end
    
    end_with = System.monotonic_time(:microsecond)
    time_with = end_with - start_with
    
    IO.puts("Time without OpenTelemetry: #{time_without} microseconds")
    IO.puts("Time with OpenTelemetry: #{time_with} microseconds")
    IO.puts("OpenTelemetry overhead: #{time_with - time_without} microseconds (#{((time_with - time_without) / time_without * 100) |> Float.round(2)}%)")
  end
end

# Run the benchmarks
ObanBenchmarkTest.run_simple_benchmark()
ObanBenchmarkTest.run_telemetry_benchmark()

IO.puts("\nTo run full application with Oban processing:")
IO.puts("mix phx.server")
IO.puts("\nTo view OpenTelemetry traces, check your configured exporter.")