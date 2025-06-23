defmodule Mix.Tasks.Otel.Mi.Score do
  @moduledoc """
  Mix task for measuring mutual information efficiency of OpenTelemetry templates.
  
  ## Purpose
  
  Analyzes real telemetry data to calculate mutual information scores and validate
  the efficiency claims of information-theoretic templates. Provides scientific
  measurement of observability signal quality.
  
  ## Usage
  
  ```bash
  # Analyze telemetry data from JSONL file
  mix otel.mi.score spans.jsonl
  
  # Analyze with specific context template
  mix otel.mi.score spans.jsonl --context high_mi
  
  # Export detailed analysis
  mix otel.mi.score spans.jsonl --output analysis.json --detailed
  
  # Compare multiple templates
  mix otel.mi.score spans.jsonl --compare traditional,high_mi,minimal
  
  # Real-time analysis from live system
  mix otel.mi.score --live --duration 300  # 5 minutes
  ```
  
  ## Output Metrics
  
  - **Mutual Information**: I(R;S_T) in bits
  - **Bytes per Event**: Average byte overhead
  - **Efficiency Score**: bits/byte ratio
  - **Component Analysis**: Per-component entropy contributions
  - **Optimization Recommendations**: Suggested improvements
  
  ## Scientific Validation
  
  Validates claims from information theory research:
  - High-MI templates achieve ≈46 bits mutual information
  - Efficiency target of 0.26 bits/byte
  - 3-4× improvement over traditional templates
  """
  
  use Mix.Task
  
  alias AiSelfSustainingMinimal.Telemetry.{Context, Span}
  
  @shortdoc "Measure mutual information efficiency of OpenTelemetry templates"
  
  @switches [
    context: :string,
    output: :string,
    detailed: :boolean,
    compare: :string,
    live: :boolean,
    duration: :integer,
    format: :string,
    help: :boolean
  ]
  
  @aliases [
    c: :context,
    o: :output,
    d: :detailed,
    h: :help
  ]
  
  @impl Mix.Task
  def run(args) do
    # Start required applications
    Mix.Task.run("app.start")
    
    {opts, args, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)
    
    if opts[:help] do
      print_help()
    else
      cond do
        opts[:live] and length(args) == 0 ->
          run_live_analysis(opts)
        
        length(args) == 1 ->
          [input_file] = args
          run_file_analysis(input_file, opts)
        
        length(args) == 0 ->
          Mix.shell().error("Please provide input file or use --live option")
          print_help()
        
        true ->
          Mix.shell().error("Too many arguments")
          print_help()
      end
    end
  end
  
  # ========================================================================
  # Live Analysis
  # ========================================================================
  
  defp run_live_analysis(opts) do
    duration = opts[:duration] || 60  # Default 1 minute
    
    Mix.shell().info("Starting live telemetry analysis for #{duration} seconds...")
    
    # Set up telemetry collection
    :telemetry.attach_many(
      "mi_analysis_collector",
      [
        [:coordination, :work, :claim],
        [:coordination, :work, :complete],
        [:coordination, :agent, :register],
        [:telemetry, :event, :record],
        [:autonomous, :analysis, :health]
      ],
      &collect_live_telemetry/4,
      %{start_time: System.monotonic_time(:second)}
    )
    
    # Start collection
    Agent.start_link(fn -> [] end, name: :live_telemetry_collector)
    
    # Wait for collection period
    Mix.shell().info("Collecting telemetry data...")
    :timer.sleep(duration * 1000)
    
    # Get collected data
    collected_events = Agent.get(:live_telemetry_collector, & &1)
    Agent.stop(:live_telemetry_collector)
    :telemetry.detach("mi_analysis_collector")
    
    Mix.shell().info("Collected #{length(collected_events)} telemetry events")
    
    if length(collected_events) > 0 do
      # Analyze collected data
      analyze_telemetry_data(collected_events, opts)
    else
      Mix.shell().error("No telemetry data collected. System may not be active.")
    end
  end
  
  defp collect_live_telemetry(event_name, measurements, metadata, config) do
    event = %{
      "event_name" => event_name,
      "measurements" => stringify_keys(measurements),
      "metadata" => stringify_keys(metadata),
      "timestamp" => System.system_time(:microsecond),
      "collection_time" => System.monotonic_time(:second) - config.start_time
    }
    
    Agent.update(:live_telemetry_collector, fn events ->
      [event | events]
    end)
  end
  
  # ========================================================================
  # File Analysis
  # ========================================================================
  
  defp run_file_analysis(input_file, opts) do
    unless File.exists?(input_file) do
      Mix.shell().error("Input file not found: #{input_file}")
      System.halt(1)
    end
    
    Mix.shell().info("Loading telemetry data from #{input_file}...")
    
    telemetry_data = case Path.extname(input_file) do
      ".jsonl" -> load_jsonl_data(input_file)
      ".json" -> load_json_data(input_file)
      ext -> 
        Mix.shell().error("Unsupported file format: #{ext}")
        System.halt(1)
    end
    
    Mix.shell().info("Loaded #{length(telemetry_data)} telemetry events")
    
    analyze_telemetry_data(telemetry_data, opts)
  end
  
  defp load_jsonl_data(file_path) do
    file_path
    |> File.stream!()
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Stream.map(fn line ->
      case Jason.decode(line) do
        {:ok, data} -> data
        {:error, _} -> nil
      end
    end)
    |> Stream.reject(&is_nil/1)
    |> Enum.to_list()
  end
  
  defp load_json_data(file_path) do
    case File.read!(file_path) |> Jason.decode() do
      {:ok, data} when is_list(data) -> data
      {:ok, data} -> [data]  # Single event
      {:error, error} ->
        Mix.shell().error("Failed to parse JSON: #{inspect(error)}")
        System.halt(1)
    end
  end
  
  # ========================================================================
  # Analysis Engine
  # ========================================================================
  
  defp analyze_telemetry_data(telemetry_data, opts) do
    if opts[:compare] do
      run_comparison_analysis(telemetry_data, opts)
    else
      run_single_analysis(telemetry_data, opts)
    end
  end
  
  defp run_single_analysis(telemetry_data, opts) do
    context_name = String.to_atom(opts[:context] || "high_mi")
    context = get_context_template(context_name)
    
    Mix.shell().info("\n=== Mutual Information Analysis ===")
    Mix.shell().info("Context Template: #{context.name}")
    Mix.shell().info("Sample Size: #{length(telemetry_data)} events")
    
    # Calculate MI score
    mi_score = Context.calculate_mi_score(context, telemetry_data)
    
    # Print results
    print_mi_results(context.name, mi_score, opts[:detailed])
    
    # Generate recommendations
    recommendations = generate_optimization_recommendations(mi_score, context)
    print_recommendations(recommendations)
    
    # Export if requested
    if opts[:output] do
      export_analysis_results(opts[:output], %{
        context: context.name,
        sample_size: length(telemetry_data),
        mi_score: mi_score,
        recommendations: recommendations
      }, opts)
    end
  end
  
  defp run_comparison_analysis(telemetry_data, opts) do
    context_names = 
      opts[:compare]
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.to_atom/1)
    
    Mix.shell().info("\n=== Comparative Mutual Information Analysis ===")
    Mix.shell().info("Sample Size: #{length(telemetry_data)} events")
    Mix.shell().info("Comparing #{length(context_names)} context templates")
    
    # Analyze each context
    results = 
      Enum.map(context_names, fn context_name ->
        context = get_context_template(context_name)
        mi_score = Context.calculate_mi_score(context, telemetry_data)
        {context, mi_score}
      end)
    
    # Print comparison table
    print_comparison_table(results)
    
    # Find best performing context
    {best_context, best_score} = 
      results
      |> Enum.max_by(fn {_context, score} -> score.bits_per_byte end)
    
    Mix.shell().info("\n🏆 Best Performing Context: #{best_context.name}")
    Mix.shell().info("   Efficiency: #{Float.round(best_score.bits_per_byte, 3)} bits/byte")
    
    # Export comparison if requested
    if opts[:output] do
      export_comparison_results(opts[:output], results, opts)
    end
  end
  
  # ========================================================================
  # Context Templates
  # ========================================================================
  
  defp get_context_template(:high_mi) do
    %Context{
      name: :high_mi,
      filepath: true,
      namespace: true,
      function: true,
      commit_id: true,
      custom_tags: [:agent_id, :session_id, :operation_type],
      mi_target: 0.26
    }
  end
  
  defp get_context_template(:traditional) do
    %Context{
      name: :traditional,
      filepath: false,
      namespace: true,
      function: true,
      commit_id: false,
      custom_tags: [],
      mi_target: 0.08
    }
  end
  
  defp get_context_template(:minimal) do
    %Context{
      name: :minimal,
      filepath: false,
      namespace: true,
      function: false,
      commit_id: false,
      custom_tags: [],
      mi_target: 0.05
    }
  end
  
  defp get_context_template(:module_only) do
    %Context{
      name: :module_only,
      filepath: false,
      namespace: true,
      function: false,
      commit_id: false,
      custom_tags: [],
      mi_target: 0.03
    }
  end
  
  defp get_context_template(name) do
    Mix.shell().error("Unknown context template: #{name}")
    Mix.shell().info("Available templates: high_mi, traditional, minimal, module_only")
    System.halt(1)
  end
  
  # ========================================================================
  # Output Formatting
  # ========================================================================
  
  defp print_mi_results(context_name, mi_score, detailed) do
    Mix.shell().info("\n📊 Results for #{context_name}:")
    Mix.shell().info("   Mutual Information: #{Float.round(mi_score.mutual_information, 2)} bits")
    Mix.shell().info("   Bytes per Event: #{mi_score.bytes_per_event} bytes")
    Mix.shell().info("   Efficiency Score: #{Float.round(mi_score.bits_per_byte, 3)} bits/byte")
    
    # Validate against targets
    efficiency = mi_score.bits_per_byte
    cond do
      efficiency >= 0.25 -> Mix.shell().info("   ✅ Excellent efficiency (≥0.25 bits/byte)")
      efficiency >= 0.15 -> Mix.shell().info("   ✅ Good efficiency (≥0.15 bits/byte)")
      efficiency >= 0.08 -> Mix.shell().info("   ⚠️  Fair efficiency (≥0.08 bits/byte)")
      true -> Mix.shell().info("   ❌ Poor efficiency (<0.08 bits/byte)")
    end
    
    if detailed do
      print_detailed_analysis(mi_score)
    end
  end
  
  defp print_detailed_analysis(mi_score) do
    Mix.shell().info("\n🔍 Detailed Analysis:")
    
    entropy_breakdown = mi_score.entropy_breakdown
    Mix.shell().info("   Total Entropy: #{Float.round(entropy_breakdown.total, 2)} bits")
    Mix.shell().info("   Conditional Entropy: #{Float.round(entropy_breakdown.conditional, 2)} bits")
    Mix.shell().info("   Mutual Information: #{Float.round(entropy_breakdown.mutual_information, 2)} bits")
    
    if Map.has_key?(mi_score, :component_analysis) do
      Mix.shell().info("\n📈 Component Contributions:")
      
      Enum.each(mi_score.component_analysis, fn {component, analysis} ->
        if analysis.enabled do
          Mix.shell().info("   #{component}: #{Float.round(analysis.entropy, 2)} bits (#{analysis.unique_values} unique values)")
        end
      end)
    end
  end
  
  defp print_comparison_table(results) do
    Mix.shell().info("\n📋 Comparison Results:")
    Mix.shell().info("#{String.pad_trailing("Context", 15)} | #{String.pad_trailing("MI (bits)", 10)} | #{String.pad_trailing("Bytes", 8)} | #{String.pad_trailing("Efficiency", 12)} | Rating")
    Mix.shell().info(String.duplicate("-", 70))
    
    Enum.each(results, fn {context, score} ->
      rating = get_efficiency_rating(score.bits_per_byte)
      
      row = "#{String.pad_trailing(Atom.to_string(context.name), 15)} | " <>
            "#{String.pad_trailing(Float.to_string(Float.round(score.mutual_information, 1)), 10)} | " <>
            "#{String.pad_trailing(Integer.to_string(score.bytes_per_event), 8)} | " <>
            "#{String.pad_trailing(Float.to_string(Float.round(score.bits_per_byte, 3)), 12)} | " <>
            "#{rating}"
      
      Mix.shell().info(row)
    end)
  end
  
  defp get_efficiency_rating(bits_per_byte) do
    cond do
      bits_per_byte >= 0.25 -> "🏆 Excellent"
      bits_per_byte >= 0.15 -> "✅ Good"
      bits_per_byte >= 0.08 -> "⚠️  Fair"
      true -> "❌ Poor"
    end
  end
  
  defp generate_optimization_recommendations(mi_score, context) do
    recommendations = []
    
    efficiency = mi_score.bits_per_byte
    
    recommendations = if efficiency < 0.1 do
      ["Consider enabling more context components (filepath, commit_id)" | recommendations]
    else
      recommendations
    end
    
    recommendations = if mi_score.bytes_per_event > 300 do
      ["High byte overhead - consider reducing custom tags or context components" | recommendations]
    else
      recommendations
    end
    
    recommendations = if efficiency < context.mi_target do
      target_gap = context.mi_target - efficiency
      ["Current efficiency #{Float.round(efficiency, 3)} below target #{context.mi_target} (gap: #{Float.round(target_gap, 3)})" | recommendations]
    else
      recommendations
    end
    
    if length(recommendations) == 0 do
      ["Context template is well-optimized for current workload"]
    else
      recommendations
    end
  end
  
  defp print_recommendations(recommendations) do
    Mix.shell().info("\n💡 Optimization Recommendations:")
    
    Enum.each(recommendations, fn rec ->
      Mix.shell().info("   • #{rec}")
    end)
  end
  
  # ========================================================================
  # Export Functions
  # ========================================================================
  
  defp export_analysis_results(output_file, results, opts) do
    format = String.to_atom(opts[:format] || "json")
    
    case format do
      :json ->
        export_json(output_file, results)
      
      :csv ->
        export_csv(output_file, results)
      
      _ ->
        Mix.shell().error("Unsupported export format: #{format}")
    end
  end
  
  defp export_comparison_results(output_file, results, opts) do
    format = String.to_atom(opts[:format] || "json")
    
    comparison_data = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      comparison_type: "context_templates",
      results: Enum.map(results, fn {context, score} ->
        %{
          context_name: context.name,
          mutual_information: score.mutual_information,
          bytes_per_event: score.bytes_per_event,
          bits_per_byte: score.bits_per_byte,
          efficiency_rating: get_efficiency_rating(score.bits_per_byte)
        }
      end)
    }
    
    case format do
      :json -> export_json(output_file, comparison_data)
      :csv -> export_comparison_csv(output_file, comparison_data)
      _ -> Mix.shell().error("Unsupported export format: #{format}")
    end
  end
  
  defp export_json(output_file, data) do
    json_data = Jason.encode!(data, pretty: true)
    File.write!(output_file, json_data)
    Mix.shell().info("Results exported to #{output_file}")
  end
  
  defp export_csv(output_file, results) do
    csv_content = """
    context,mutual_information,bytes_per_event,bits_per_byte,efficiency_rating
    #{results.context},#{results.mi_score.mutual_information},#{results.mi_score.bytes_per_event},#{results.mi_score.bits_per_byte},#{get_efficiency_rating(results.mi_score.bits_per_byte)}
    """
    
    File.write!(output_file, csv_content)
    Mix.shell().info("Results exported to #{output_file}")
  end
  
  defp export_comparison_csv(output_file, comparison_data) do
    header = "context_name,mutual_information,bytes_per_event,bits_per_byte,efficiency_rating\n"
    
    rows = 
      comparison_data.results
      |> Enum.map(fn result ->
        "#{result.context_name},#{result.mutual_information},#{result.bytes_per_event},#{result.bits_per_byte},#{result.efficiency_rating}"
      end)
      |> Enum.join("\n")
    
    csv_content = header <> rows
    File.write!(output_file, csv_content)
    Mix.shell().info("Comparison results exported to #{output_file}")
  end
  
  defp stringify_keys(map) when is_map(map) do
    Enum.into(map, %{}, fn {key, value} ->
      {to_string(key), value}
    end)
  end
  defp stringify_keys(other), do: other
  
  # ========================================================================
  # Help Text
  # ========================================================================
  
  defp print_help do
    Mix.shell().info("""
    
    mix otel.mi.score - Measure OpenTelemetry mutual information efficiency
    
    USAGE:
        mix otel.mi.score TELEMETRY_FILE [OPTIONS]
        mix otel.mi.score --live [OPTIONS]
    
    ARGUMENTS:
        TELEMETRY_FILE    Path to telemetry data file (.json or .jsonl)
    
    OPTIONS:
        -c, --context CONTEXT        Context template to analyze (default: high_mi)
        -o, --output FILE            Export analysis results to file
        -d, --detailed               Show detailed component analysis
        --compare CONTEXTS           Compare multiple contexts (comma-separated)
        --live                       Analyze live telemetry data
        --duration SECONDS           Duration for live analysis (default: 60)
        --format FORMAT              Export format: json, csv (default: json)
        -h, --help                   Show this help message
    
    EXAMPLES:
        # Analyze telemetry file with high-MI template
        mix otel.mi.score telemetry_spans.jsonl
        
        # Compare multiple templates
        mix otel.mi.score spans.jsonl --compare high_mi,traditional,minimal
        
        # Live analysis for 5 minutes with detailed output
        mix otel.mi.score --live --duration 300 --detailed
        
        # Export results to CSV
        mix otel.mi.score spans.jsonl --output analysis.csv --format csv
    
    CONTEXT TEMPLATES:
        high_mi       High mutual information template (filepath+namespace+function+commit)
        traditional   Traditional template (namespace+function only)
        minimal       Minimal template (namespace only)
        module_only   Module name only
    
    """)
  end
end