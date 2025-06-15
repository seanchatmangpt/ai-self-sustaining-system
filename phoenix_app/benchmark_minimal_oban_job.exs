#!/usr/bin/env mix run
# Benchmark script for minimal Oban job with OpenTelemetry

# Load the current application
Code.require_file("config/config.exs")
Code.require_file("config/dev.exs")

# Ensure required dependencies are started
Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto_sql)
Application.ensure_all_started(:opentelemetry)
Application.ensure_all_started(:oban)

defmodule ObanJobBenchmark do
  @moduledoc """
  Benchmarks for minimal Oban job performance with OpenTelemetry.
  """
  
  alias SelfSustaining.Jobs.MinimalBenchmarkJob
  
  def benchmark_job_enqueueing do
    Benchee.run(
      %{
        "enqueue_minimal_job" => fn counter ->
          MinimalBenchmarkJob.new(%{counter: counter})
          |> Oban.insert()
        end,
        "enqueue_batch_10" => fn counter ->
          jobs = for i <- 1..10 do
            MinimalBenchmarkJob.new(%{counter: counter + i})
          end
          Oban.insert_all(jobs)
        end,
        "enqueue_batch_100" => fn counter ->
          jobs = for i <- 1..100 do
            MinimalBenchmarkJob.new(%{counter: counter + i})
          end
          Oban.insert_all(jobs)
        end
      },
      inputs: %{
        "small_counter" => 1,
        "medium_counter" => 1000,
        "large_counter" => 1_000_000
      },
      time: 10,
      memory_time: 2,
      formatters: [
        Benchee.Formatters.HTML,
        Benchee.Formatters.Console
      ],
      html: %{file: "/Users/sac/dev/ai-self-sustaining-system/phoenix_app/benchmark_results.html"}
    )
  end
  
  def benchmark_job_processing do
    # Create a test job instance
    job = MinimalBenchmarkJob.new(%{counter: 42})
    
    # Convert to Oban.Job struct for direct performance testing
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
    
    Benchee.run(
      %{
        "process_minimal_job" => fn ->
          MinimalBenchmarkJob.perform(oban_job)
        end,
        "process_without_telemetry" => fn ->
          # Direct minimal work without OpenTelemetry
          counter = Map.get(oban_job.args, "counter", 0)
          counter + 1
          :ok
        end
      },
      time: 10,
      memory_time: 2,
      formatters: [
        Benchee.Formatters.Console
      ]
    )
  end
  
  def collect_telemetry_metrics do
    # Enable telemetry collection
    :telemetry.attach_many(
      "oban-benchmark-metrics",
      [
        [:oban, :job, :start],
        [:oban, :job, :stop],
        [:oban, :job, :exception]
      ],
      &handle_telemetry_event/4,
      %{}
    )
    
    # Process some jobs and collect metrics
    jobs = for i <- 1..1000 do
      MinimalBenchmarkJob.new(%{counter: i})
    end
    
    start_time = System.monotonic_time(:microsecond)
    
    {:ok, inserted_jobs} = Oban.insert_all(jobs)
    
    enqueue_time = System.monotonic_time(:microsecond)
    
    IO.puts("Enqueued #{length(inserted_jobs)} jobs in #{enqueue_time - start_time} microseconds")
    IO.puts("Average enqueue time: #{(enqueue_time - start_time) / length(inserted_jobs)} microseconds per job")
    
    # Wait a moment for jobs to process
    Process.sleep(5000)
    
    IO.puts("Benchmark completed. Check OpenTelemetry traces for detailed performance data.")
  end
  
  defp handle_telemetry_event([:oban, :job, :start], measurements, metadata, _config) do
    IO.puts("Job started: #{metadata.worker} - Duration so far: #{measurements.system_time}")
  end
  
  defp handle_telemetry_event([:oban, :job, :stop], measurements, metadata, _config) do
    IO.puts("Job completed: #{metadata.worker} - Duration: #{measurements.duration} microseconds")
  end
  
  defp handle_telemetry_event([:oban, :job, :exception], measurements, metadata, _config) do
    IO.puts("Job failed: #{metadata.worker} - Duration: #{measurements.duration} microseconds")
  end
end

# Run the benchmarks
IO.puts("=== Benchmarking Oban Job Enqueueing ===")
ObanJobBenchmark.benchmark_job_enqueueing()

IO.puts("\n=== Benchmarking Oban Job Processing ===")
ObanJobBenchmark.benchmark_job_processing()

IO.puts("\n=== Collecting Telemetry Metrics ===")
ObanJobBenchmark.collect_telemetry_metrics()