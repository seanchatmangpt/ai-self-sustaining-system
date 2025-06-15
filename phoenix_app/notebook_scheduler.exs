#!/usr/bin/env elixir

# Notebook Analytics Scheduler
# Runs Livebook notebook analytics on a schedule and generates reports

Mix.install([
  {:jason, "~> 1.4"},
  {:req, "~> 0.5.0"}
])

defmodule NotebookScheduler do
  @moduledoc """
  Scheduler for running Livebook notebook analytics at regular intervals.
  Provides automated monitoring and reporting capabilities.
  """

  def start_monitoring(interval_minutes \\ 30) do
    IO.puts("📊 Starting Notebook Analytics Scheduler")
    IO.puts("⏰ Running analysis every #{interval_minutes} minutes")
    IO.puts("🔄 Press Ctrl+C to stop")
    
    schedule_analytics(interval_minutes)
  end

  def run_hourly_report do
    IO.puts("⏰ Running Hourly System Report...")
    
    timestamp = DateTime.utc_now()
    
    # Run comprehensive analysis
    case System.cmd("elixir", ["run_notebook_analytics.exs", "all"], 
                    stderr_to_stdout: true, cd: ".") do
      {output, 0} ->
        IO.puts("✅ Hourly report completed successfully")
        save_hourly_log(timestamp, output, :success)
        
      {output, _} ->
        IO.puts("❌ Hourly report failed")
        save_hourly_log(timestamp, output, :error)
    end
  end

  def run_daily_summary do
    IO.puts("📈 Generating Daily Summary Report...")
    
    # Collect all analytics files from today
    today = Date.utc_today()
    files = find_analytics_files(today)
    
    if length(files) > 0 do
      summary = generate_daily_summary(files)
      save_daily_summary(today, summary)
      
      IO.puts("📊 Daily Summary Generated:")
      IO.puts("  • Analysis Runs: #{summary.total_runs}")
      IO.puts("  • Average Health Score: #{summary.avg_health_score}")
      IO.puts("  • Peak Memory Usage: #{summary.peak_memory_mb} MB")
      IO.puts("  • Agent Efficiency Trend: #{summary.efficiency_trend}")
    else
      IO.puts("⚠️ No analytics data found for today")
    end
  end

  def check_system_alerts do
    IO.puts("🚨 Checking System Alerts...")
    
    # Run quick performance check
    case System.cmd("elixir", ["run_notebook_analytics.exs", "performance"], 
                    stderr_to_stdout: true, cd: ".") do
      {output, 0} ->
        # Parse performance results for alerts
        alerts = detect_performance_alerts(output)
        
        if length(alerts) > 0 do
          IO.puts("🚨 ALERTS DETECTED:")
          Enum.each(alerts, fn alert ->
            IO.puts("  • #{alert}")
          end)
          
          # Save alert notification
          save_alert_notification(alerts)
        else
          IO.puts("✅ No system alerts")
        end
        
      {output, _} ->
        IO.puts("❌ Failed to check system alerts")
        IO.puts(output)
    end
  end

  def cleanup_old_files(days \\ 7) do
    IO.puts("🧹 Cleaning up analytics files older than #{days} days...")
    
    cutoff_date = Date.add(Date.utc_today(), -days)
    
    case File.ls(".") do
      {:ok, files} ->
        old_files = 
          files
          |> Enum.filter(&String.ends_with?(&1, ".json"))
          |> Enum.filter(&String.contains?(&1, "_analysis_"))
          |> Enum.filter(&is_file_old?(&1, cutoff_date))
        
        Enum.each(old_files, fn file ->
          File.rm!(file)
          IO.puts("  🗑️ Removed #{file}")
        end)
        
        IO.puts("✅ Cleanup completed: #{length(old_files)} files removed")
        
      {:error, _} ->
        IO.puts("❌ Failed to list files for cleanup")
    end
  end

  # Private implementation

  defp schedule_analytics(interval_minutes) do
    interval_ms = interval_minutes * 60 * 1000
    
    # Initial run
    run_scheduled_analysis()
    
    # Schedule recurring runs
    Stream.interval(interval_ms)
    |> Enum.each(fn _ ->
      run_scheduled_analysis()
    end)
  end

  defp run_scheduled_analysis do
    timestamp = DateTime.utc_now() |> DateTime.to_string()
    IO.puts("\n⏰ #{timestamp} - Running Scheduled Analysis...")
    
    # Run comprehensive analysis
    case System.cmd("elixir", ["run_notebook_analytics.exs"], 
                    stderr_to_stdout: true, cd: ".") do
      {output, 0} ->
        IO.puts("✅ Analysis completed successfully")
        
        # Check for any critical issues
        if String.contains?(output, "🔴") do
          IO.puts("⚠️ Critical issues detected - review required")
        end
        
      {output, _} ->
        IO.puts("❌ Analysis failed:")
        IO.puts(String.slice(output, 0, 500) <> "...")
    end
  end

  defp save_hourly_log(timestamp, output, status) do
    log_data = %{
      timestamp: timestamp,
      status: status,
      output: output
    }
    
    filename = "hourly_log_#{Date.utc_today()}.json"
    
    # Append to existing log or create new
    existing_logs = case File.read(filename) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, logs} when is_list(logs) -> logs
          _ -> []
        end
      _ -> []
    end
    
    updated_logs = existing_logs ++ [log_data]
    
    case Jason.encode(updated_logs, pretty: true) do
      {:ok, json} ->
        File.write!(filename, json)
        IO.puts("💾 Hourly log saved to #{filename}")
      {:error, _} ->
        IO.puts("❌ Failed to save hourly log")
    end
  end

  defp find_analytics_files(date) do
    date_str = Date.to_string(date)
    
    case File.ls(".") do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".json"))
        |> Enum.filter(&String.contains?(&1, "_analysis_"))
        |> Enum.filter(&String.contains?(&1, date_str))
        
      {:error, _} -> []
    end
  end

  defp generate_daily_summary(files) do
    analyses = 
      files
      |> Enum.map(&read_analysis_file/1)
      |> Enum.filter(&(&1 != nil))
    
    if length(analyses) > 0 do
      %{
        total_runs: length(analyses),
        avg_health_score: calculate_avg_health_score(analyses),
        peak_memory_mb: calculate_peak_memory(analyses),
        efficiency_trend: calculate_efficiency_trend(analyses),
        first_run: analyses |> List.first() |> Map.get(:timestamp),
        last_run: analyses |> List.last() |> Map.get(:timestamp)
      }
    else
      %{
        total_runs: 0,
        avg_health_score: 0,
        peak_memory_mb: 0,
        efficiency_trend: "no_data"
      }
    end
  end

  defp read_analysis_file(filename) do
    case File.read(filename) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> Map.put(data, :filename, filename)
          _ -> nil
        end
      _ -> nil
    end
  end

  defp calculate_avg_health_score(analyses) do
    scores = 
      analyses
      |> Enum.map(&extract_health_score/1)
      |> Enum.filter(&(&1 != nil))
    
    if length(scores) > 0 do
      Float.round(Enum.sum(scores) / length(scores), 1)
    else
      0
    end
  end

  defp extract_health_score(analysis) do
    # Try to extract health score from different analysis types
    cond do
      Map.has_key?(analysis, "system_health") ->
        Map.get(analysis["system_health"], "overall_score")
      Map.has_key?(analysis, "performance_score") ->
        Map.get(analysis, "performance_score")
      Map.has_key?(analysis, "efficiency_score") ->
        Map.get(analysis, "efficiency_score")
      true -> nil
    end
  end

  defp calculate_peak_memory(analyses) do
    memory_values = 
      analyses
      |> Enum.map(&extract_memory_usage/1)
      |> Enum.filter(&(&1 != nil))
    
    if length(memory_values) > 0 do
      Enum.max(memory_values)
    else
      0
    end
  end

  defp extract_memory_usage(analysis) do
    Map.get(analysis, "memory_mb") || Map.get(analysis, "peak_memory_mb")
  end

  defp calculate_efficiency_trend(analyses) do
    if length(analyses) >= 2 do
      first_efficiency = analyses |> List.first() |> extract_efficiency()
      last_efficiency = analyses |> List.last() |> extract_efficiency()
      
      cond do
        last_efficiency > first_efficiency + 10 -> "improving"
        last_efficiency < first_efficiency - 10 -> "declining" 
        true -> "stable"
      end
    else
      "insufficient_data"
    end
  end

  defp extract_efficiency(analysis) do
    Map.get(analysis, "efficiency_score") || 50
  end

  defp save_daily_summary(date, summary) do
    filename = "daily_summary_#{date}.json"
    
    case Jason.encode(summary, pretty: true) do
      {:ok, json} ->
        File.write!(filename, json)
        IO.puts("💾 Daily summary saved to #{filename}")
      {:error, _} ->
        IO.puts("❌ Failed to save daily summary")
    end
  end

  defp detect_performance_alerts(output) do
    alerts = []
    
    # Check for memory alerts
    alerts = if String.contains?(output, "Memory Usage:") do
      memory_line = output |> String.split("\n") |> Enum.find(&String.contains?(&1, "Memory Usage:"))
      if memory_line && String.contains?(memory_line, " MB") do
        memory_mb = extract_number_from_line(memory_line)
        if memory_mb > 1000 do
          ["High memory usage: #{memory_mb} MB" | alerts]
        else
          alerts
        end
      else
        alerts
      end
    else
      alerts
    end
    
    # Check for process count alerts
    alerts = if String.contains?(output, "Process Count:") do
      process_line = output |> String.split("\n") |> Enum.find(&String.contains?(&1, "Process Count:"))
      if process_line do
        process_count = extract_number_from_line(process_line)
        if process_count > 75000 do
          ["High process count: #{process_count}" | alerts]
        else
          alerts
        end
      else
        alerts
      end
    else
      alerts
    end
    
    # Check for bottlenecks
    alerts = if String.contains?(output, "🔴") || String.contains?(output, "Needs Attention") do
      ["System performance needs attention" | alerts]
    else
      alerts
    end
    
    alerts
  end

  defp extract_number_from_line(line) do
    case Regex.run(~r/(\d+(?:\.\d+)?)/, line) do
      [_, number_str] ->
        case Float.parse(number_str) do
          {number, _} -> number
          :error -> 0
        end
      _ -> 0
    end
  end

  defp save_alert_notification(alerts) do
    alert_data = %{
      timestamp: DateTime.utc_now(),
      alerts: alerts,
      severity: determine_alert_severity(alerts)
    }
    
    filename = "alerts_#{Date.utc_today()}.json"
    
    case Jason.encode(alert_data, pretty: true) do
      {:ok, json} ->
        File.write!(filename, json)
        IO.puts("🚨 Alert notification saved to #{filename}")
      {:error, _} ->
        IO.puts("❌ Failed to save alert notification")
    end
  end

  defp determine_alert_severity(alerts) do
    cond do
      Enum.any?(alerts, &String.contains?(&1, "High memory")) -> "critical"
      Enum.any?(alerts, &String.contains?(&1, "High process")) -> "warning"
      true -> "info"
    end
  end

  defp is_file_old?(filename, cutoff_date) do
    # Extract date from filename (assumes format includes YYYY-MM-DD)
    case Regex.run(~r/(\d{4}-\d{2}-\d{2})/, filename) do
      [_, date_str] ->
        case Date.from_iso8601(date_str) do
          {:ok, file_date} -> Date.compare(file_date, cutoff_date) == :lt
          _ -> false
        end
      _ -> false
    end
  end
end

# CLI interface
case System.argv() do
  ["monitor"] -> NotebookScheduler.start_monitoring()
  ["monitor", interval] -> 
    {minutes, _} = Integer.parse(interval)
    NotebookScheduler.start_monitoring(minutes)
  ["hourly"] -> NotebookScheduler.run_hourly_report()
  ["daily"] -> NotebookScheduler.run_daily_summary()
  ["alerts"] -> NotebookScheduler.check_system_alerts()
  ["cleanup"] -> NotebookScheduler.cleanup_old_files()
  ["cleanup", days] ->
    {day_count, _} = Integer.parse(days)
    NotebookScheduler.cleanup_old_files(day_count)
  [] ->
    IO.puts("""
    📊 Notebook Analytics Scheduler
    
    Usage: elixir notebook_scheduler.exs [command] [options]
    
    Commands:
      monitor [minutes]  - Start continuous monitoring (default: 30 min)
      hourly            - Run hourly report
      daily             - Generate daily summary
      alerts            - Check for system alerts
      cleanup [days]    - Clean up old files (default: 7 days)
    
    Examples:
      elixir notebook_scheduler.exs monitor 15    # Monitor every 15 minutes
      elixir notebook_scheduler.exs hourly        # Generate hourly report
      elixir notebook_scheduler.exs alerts        # Check for alerts
      elixir notebook_scheduler.exs cleanup 14    # Clean files older than 14 days
    """)
  _ ->
    IO.puts("❌ Invalid command. Run without arguments for help.")
end