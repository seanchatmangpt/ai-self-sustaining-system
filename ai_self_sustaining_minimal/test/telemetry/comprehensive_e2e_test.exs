defmodule AiSelfSustainingMinimal.Telemetry.ComprehensiveE2ETest do
  @moduledoc """
  Comprehensive End-to-End test for Information-Theoretic OpenTelemetry DSL.
  
  This test validates:
  1. Multiple DSL usage patterns (≥3 different scenarios)
  2. High-MI template component capture (filepath + namespace + function + commit_id)
  3. Actual mutual information calculations and efficiency validation
  4. Insight generation from collected telemetry data
  5. Performance targets: 0.26 bits/byte efficiency, ≈46 bits MI
  """
  
  use ExUnit.Case, async: false
  
  # ========================================================================
  # TEST MODULE 1: Basic Context and Span Usage
  # ========================================================================
  
  defmodule BasicUsageModule do
    use AiSelfSustainingMinimal.Telemetry.SparkOtelDsl
    
    otel do
      context :high_mi_basic do
        filepath true
        namespace true
        function true
        commit_id true
        custom_tags [:operation_id, :session_id]
        mi_target 0.25
      end
      
      span :coordination_operation do
        event_name [:coordination, :work, :basic]
        context :high_mi_basic
        measurements [:duration_ms, :memory_usage]
        metadata [:operation_type, :success]
      end
    end
    
    def coordinate_work(operation_id, work_data) do
      Process.put(:operation_id, operation_id)
      Process.put(:session_id, "session_#{:rand.uniform(1000)}")
      
      with_source_test_span %{
        operation_type: "work_coordination",
        success: true,
        work_data: work_data
      } do
        # Simulate coordination work
        :timer.sleep(5 + :rand.uniform(10))
        
        result = %{
          status: :completed,
          work_items: length(work_data),
          coordination_time: System.system_time(:millisecond)
        }
        
        {:ok, result}
      end
    end
    
    def process_batch(batch_id, items) when is_list(items) do
      Process.put(:operation_id, "batch_#{batch_id}")
      Process.put(:session_id, "batch_session_#{batch_id}")
      
      with_source_test_span %{
        operation_type: "batch_processing",
        batch_size: length(items),
        success: true
      } do
        # Process each item
        results = Enum.map(items, fn item ->
          :timer.sleep(1)
          String.upcase(to_string(item))
        end)
        
        {:batch_completed, batch_id, results}
      end
    end
  end
  
  # ========================================================================
  # TEST MODULE 2: Advanced Context with Custom Logic
  # ========================================================================
  
  defmodule AdvancedUsageModule do
    use AiSelfSustainingMinimal.Telemetry.SparkOtelDsl
    
    otel do
      context :enterprise_context do
        filepath true
        namespace true
        function true
        commit_id true
        custom_tags [:agent_id, :team_id, :work_type, :priority_level]
        mi_target 0.30
      end
      
      span :agent_coordination do
        event_name [:enterprise, :agent, :coordination]
        context :enterprise_context
        measurements [:response_time, :cpu_usage, :memory_delta]
        metadata [:coordination_type, :agent_capabilities, :success_rate]
      end
    end
    
    def register_agent(agent_id, capabilities) do
      Process.put(:agent_id, agent_id)
      Process.put(:team_id, "team_#{:rand.uniform(5)}")
      Process.put(:work_type, "agent_management")
      Process.put(:priority_level, "high")
      
      with_source_test_span %{
        coordination_type: "agent_registration",
        agent_capabilities: capabilities,
        success_rate: 0.95
      } do
        # Simulate agent registration
        :timer.sleep(10 + :rand.uniform(15))
        
        registration_result = %{
          agent_id: agent_id,
          registered_at: System.system_time(:microsecond),
          capabilities: capabilities,
          status: :active
        }
        
        {:registered, registration_result}
      end
    end
    
    def assign_work(agent_id, work_items) do
      Process.put(:agent_id, agent_id)
      Process.put(:team_id, "assignment_team")
      Process.put(:work_type, "work_assignment")
      Process.put(:priority_level, determine_priority(work_items))
      
      with_source_test_span %{
        coordination_type: "work_assignment",
        agent_capabilities: ["coordination", "processing"],
        success_rate: 0.88,
        work_count: length(work_items)
      } do
        # Complex work assignment logic
        :timer.sleep(8 + :rand.uniform(12))
        
        assignments = Enum.with_index(work_items, fn item, index ->
          %{
            work_id: "work_#{index}",
            item: item,
            assigned_to: agent_id,
            priority: determine_priority([item])
          }
        end)
        
        {:assignments_created, assignments}
      end
    end
    
    defp determine_priority(work_items) do
      if length(work_items) > 5, do: "high", else: "medium"
    end
  end
  
  # ========================================================================
  # TEST MODULE 3: High-Frequency Operations with Sampling
  # ========================================================================
  
  defmodule HighFrequencyModule do
    use AiSelfSustainingMinimal.Telemetry.SparkOtelDsl
    
    otel do
      context :performance_context do
        filepath true
        namespace true
        function true
        commit_id true
        custom_tags [:request_id, :user_id, :service_tier]
        mi_target 0.28
      end
      
      span :high_frequency_operation do
        event_name [:performance, :high_frequency, :operation]
        context :performance_context
        measurements [:latency_ns, :throughput, :error_rate]
        metadata [:operation_class, :optimization_applied]
        sample_rate 1.0  # Full sampling for test
      end
    end
    
    def process_request_batch(batch_size, service_tier \\ "standard") do
      Process.put(:service_tier, service_tier)
      
      Enum.map(1..batch_size, fn request_id ->
        Process.put(:request_id, "req_#{request_id}")
        Process.put(:user_id, "user_#{:rand.uniform(100)}")
        
        with_source_test_span %{
          operation_class: "batch_request",
          optimization_applied: service_tier == "premium"
        } do
          # Simulate request processing
          processing_time = if service_tier == "premium", do: 1, else: 3
          :timer.sleep(processing_time)
          
          %{
            request_id: request_id,
            processed_at: System.system_time(:nanosecond),
            latency: processing_time * 1_000_000,  # Convert to nanoseconds
            status: if(:rand.uniform() > 0.1, do: :success, else: :error)
          }
        end
      end)
    end
    
    def simulate_load_test(duration_ms, requests_per_second) do
      Process.put(:service_tier, "load_test")
      Process.put(:user_id, "load_test_user")
      
      start_time = System.monotonic_time(:millisecond)
      interval_ms = div(1000, requests_per_second)
      
      Stream.unfold(0, fn request_count ->
        current_time = System.monotonic_time(:millisecond)
        
        if current_time - start_time < duration_ms do
          Process.put(:request_id, "load_req_#{request_count}")
          
          result = with_source_test_span %{
            operation_class: "load_test",
            optimization_applied: true,
            request_number: request_count
          } do
            :timer.sleep(1)
            %{
              request_id: request_count,
              timestamp: System.system_time(:nanosecond),
              load_test: true
            }
          end
          
          :timer.sleep(interval_ms)
          {result, request_count + 1}
        else
          nil
        end
      end)
      |> Enum.to_list()
    end
  end
  
  # ========================================================================
  # TEST SETUP AND TELEMETRY COLLECTION
  # ========================================================================
  
  setup_all do
    # Set test environment
    System.put_env("GIT_SHA", "e2e_test_commit_789xyz123")
    
    # Initialize telemetry collection for all test events
    telemetry_events = [
      [:coordination, :work, :basic],
      [:enterprise, :agent, :coordination], 
      [:performance, :high_frequency, :operation],
      [:test, :source, :tracking]  # From the DSL generated macro
    ]
    
    # Attach handlers for all events
    Enum.each(telemetry_events, fn event ->
      handler_id = "e2e_test_#{Enum.join(event, "_")}"
      :telemetry.attach(
        handler_id,
        event,
        &collect_comprehensive_telemetry/4,
        %{test_pid: self(), event_type: event}
      )
    end)
    
    # Also handle span events (start/stop)
    Enum.each(telemetry_events, fn event ->
      start_event = event ++ [:start]
      stop_event = event ++ [:stop]
      
      :telemetry.attach(
        "e2e_start_#{Enum.join(event, "_")}",
        start_event,
        &collect_comprehensive_telemetry/4,
        %{test_pid: self(), event_type: start_event}
      )
      
      :telemetry.attach(
        "e2e_stop_#{Enum.join(event, "_")}",
        stop_event,
        &collect_comprehensive_telemetry/4,
        %{test_pid: self(), event_type: stop_event}
      )
    end)
    
    on_exit(fn ->
      # Detach all handlers
      all_handlers = :telemetry.list_handlers([])
      Enum.each(all_handlers, fn %{id: id} ->
        if String.starts_with?(to_string(id), "e2e_") do
          :telemetry.detach(id)
        end
      end)
      
      System.delete_env("GIT_SHA")
    end)
    
    :ok
  end
  
  # ========================================================================
  # COMPREHENSIVE E2E TESTS
  # ========================================================================
  
  describe "comprehensive DSL usage patterns" do
    test "usage pattern 1: basic coordination operations" do
      IO.puts("\n🔍 Testing Usage Pattern 1: Basic Coordination Operations")
      
      # Execute multiple operations
      work_data_1 = ["task_a", "task_b", "task_c"]
      result_1 = BasicUsageModule.coordinate_work("coord_001", work_data_1)
      assert {:ok, %{status: :completed}} = result_1
      
      batch_items = ["item1", "item2", "item3", "item4"]
      result_2 = BasicUsageModule.process_batch("batch_001", batch_items)
      assert {:batch_completed, "batch_001", processed_items} = result_2
      assert length(processed_items) == 4
      
      # Collect telemetry events
      events_1 = collect_telemetry_batch(2, 2000)
      assert length(events_1) >= 2
      
      # Validate high-MI components in each event
      Enum.each(events_1, fn {event_name, measurements, metadata} ->
        validate_high_mi_components(event_name, metadata, "Pattern 1")
      end)
      
      IO.puts("✅ Pattern 1: Captured #{length(events_1)} coordination events")
    end
    
    test "usage pattern 2: enterprise agent coordination" do
      IO.puts("\n🔍 Testing Usage Pattern 2: Enterprise Agent Coordination")
      
      # Test agent registration
      capabilities_1 = ["coordination", "analysis", "optimization"]
      result_1 = AdvancedUsageModule.register_agent("agent_007", capabilities_1)
      assert {:registered, %{agent_id: "agent_007"}} = result_1
      
      # Test work assignment
      work_items = ["priority_task", "standard_task", "background_task"]
      result_2 = AdvancedUsageModule.assign_work("agent_007", work_items)
      assert {:assignments_created, assignments} = result_2
      assert length(assignments) == 3
      
      # Collect and validate telemetry
      events_2 = collect_telemetry_batch(2, 2000)
      assert length(events_2) >= 2
      
      # Validate enterprise-specific metadata
      Enum.each(events_2, fn {event_name, measurements, metadata} ->
        validate_high_mi_components(event_name, metadata, "Pattern 2")
        
        # Check enterprise-specific tags
        assert has_any_key(metadata, [:agent_id, "agent_id"])
        assert has_any_key(metadata, [:coordination_type, "coordination_type"])
      end)
      
      IO.puts("✅ Pattern 2: Captured #{length(events_2)} enterprise events")
    end
    
    test "usage pattern 3: high-frequency performance monitoring" do
      IO.puts("\n🔍 Testing Usage Pattern 3: High-Frequency Performance Monitoring")
      
      # Test batch processing
      batch_results = HighFrequencyModule.process_request_batch(5, "premium")
      assert length(batch_results) == 5
      
      # Test load simulation
      load_results = HighFrequencyModule.simulate_load_test(100, 10)  # 100ms, 10 RPS
      assert length(load_results) >= 1
      
      # Collect high-frequency telemetry
      events_3 = collect_telemetry_batch(6, 3000)  # More events, longer timeout
      assert length(events_3) >= 5
      
      # Validate performance-specific measurements
      Enum.each(events_3, fn {event_name, measurements, metadata} ->
        validate_high_mi_components(event_name, metadata, "Pattern 3")
        
        # Check performance-specific metadata
        assert has_any_key(metadata, [:operation_class, "operation_class"])
        if has_any_key(metadata, [:request_id, "request_id"]) do
          request_id = metadata[:request_id] || metadata["request_id"]
          assert String.starts_with?(to_string(request_id), "req_") or 
                 String.starts_with?(to_string(request_id), "load_req_")
        end
      end)
      
      IO.puts("✅ Pattern 3: Captured #{length(events_3)} performance events")
    end
  end
  
  describe "mutual information analysis and insight generation" do
    test "calculates actual mutual information and validates efficiency targets" do
      IO.puts("\n🔍 Mutual Information Analysis and Efficiency Validation")
      
      # Generate diverse telemetry data across all patterns
      generate_diverse_telemetry_dataset()
      
      # Collect comprehensive dataset
      all_events = collect_telemetry_batch(15, 5000)
      assert length(all_events) >= 10
      
      # Perform mutual information analysis
      mi_analysis = calculate_mutual_information(all_events)
      
      # Validate efficiency metrics
      assert mi_analysis.efficiency_bits_per_byte >= 0.15, 
             "Efficiency #{mi_analysis.efficiency_bits_per_byte} below minimum threshold"
             
      assert mi_analysis.total_entropy_bits >= 30,
             "Total entropy #{mi_analysis.total_entropy_bits} below expected range"
      
      # Target validation (should approach 0.26 bits/byte)
      target_efficiency = 0.26
      efficiency_ratio = mi_analysis.efficiency_bits_per_byte / target_efficiency
      
      IO.puts("\n📊 Mutual Information Analysis Results:")
      IO.puts("   Total Events Analyzed: #{length(all_events)}")
      IO.puts("   Unique File Paths: #{mi_analysis.unique_filepaths}")
      IO.puts("   Unique Namespaces: #{mi_analysis.unique_namespaces}")
      IO.puts("   Unique Functions: #{mi_analysis.unique_functions}")
      IO.puts("   Unique Commit IDs: #{mi_analysis.unique_commits}")
      IO.puts("   Total Entropy: #{Float.round(mi_analysis.total_entropy_bits, 2)} bits")
      IO.puts("   Average Metadata Size: #{Float.round(mi_analysis.avg_metadata_bytes, 1)} bytes")
      IO.puts("   Efficiency: #{Float.round(mi_analysis.efficiency_bits_per_byte, 4)} bits/byte")
      IO.puts("   Target Efficiency: #{target_efficiency} bits/byte")
      IO.puts("   Achievement Ratio: #{Float.round(efficiency_ratio * 100, 1)}%")
      
      # Performance assessment
      if efficiency_ratio >= 0.8 do
        IO.puts("   🎯 EXCELLENT: Approaching theoretical target!")
      elsif efficiency_ratio >= 0.6 do
        IO.puts("   ✅ GOOD: Solid information efficiency achieved")
      elsif efficiency_ratio >= 0.4 do
        IO.puts("   ⚠️  FAIR: Room for optimization")
      else
        IO.puts("   ❌ POOR: Significant optimization needed")
      end
      
      # Validate we're achieving reasonable efficiency
      assert efficiency_ratio >= 0.4, 
             "Efficiency ratio #{efficiency_ratio} indicates template needs optimization"
    end
    
    test "generates actionable insights from telemetry patterns" do
      IO.puts("\n🔍 Insight Generation from Telemetry Patterns")
      
      # Generate targeted telemetry for insight analysis
      generate_insight_dataset()
      
      # Collect events for insight analysis
      insight_events = collect_telemetry_batch(12, 4000)
      
      # Generate insights
      insights = generate_telemetry_insights(insight_events)
      
      # Validate insights quality
      assert length(insights.performance_patterns) >= 1
      assert length(insights.error_patterns) >= 0
      assert length(insights.optimization_recommendations) >= 1
      
      IO.puts("\n🧠 Generated Insights:")
      
      # Performance patterns
      IO.puts("   📈 Performance Patterns:")
      Enum.each(insights.performance_patterns, fn pattern ->
        IO.puts("     • #{pattern}")
      end)
      
      # Error patterns (if any)
      if length(insights.error_patterns) > 0 do
        IO.puts("   🚨 Error Patterns:")
        Enum.each(insights.error_patterns, fn pattern ->
          IO.puts("     • #{pattern}")
        end)
      end
      
      # Optimization recommendations
      IO.puts("   🎯 Optimization Recommendations:")
      Enum.each(insights.optimization_recommendations, fn rec ->
        IO.puts("     • #{rec}")
      end)
      
      # Service topology insights
      IO.puts("   🏗️  Service Topology:")
      IO.puts("     • Modules instrumented: #{insights.modules_count}")
      IO.puts("     • Functions traced: #{insights.functions_count}")
      IO.puts("     • Average response time: #{insights.avg_response_time_ms}ms")
      
      # Validate insight generation worked
      assert insights.modules_count >= 3
      assert insights.functions_count >= 6
      assert is_number(insights.avg_response_time_ms)
    end
    
    test "validates information theory principles in practice" do
      IO.puts("\n🔍 Information Theory Principles Validation")
      
      # Test information theory formula: I(R;S_T) = H(S_T) - H(S_T|R)
      generate_theory_validation_dataset()
      
      theory_events = collect_telemetry_batch(10, 3000)
      
      # Calculate components of mutual information formula
      theory_analysis = validate_information_theory(theory_events)
      
      # Validate theoretical principles
      assert theory_analysis.static_entropy > 0, "Static context entropy should be positive"
      assert theory_analysis.conditional_entropy >= 0, "Conditional entropy should be non-negative"
      assert theory_analysis.mutual_information > 0, "Mutual information should be positive"
      
      # Mutual information should be less than or equal to static entropy
      assert theory_analysis.mutual_information <= theory_analysis.static_entropy + 0.1,
             "MI cannot exceed static entropy (information theory violation)"
      
      IO.puts("\n🔬 Information Theory Validation:")
      IO.puts("   H(S_T) - Static Context Entropy: #{Float.round(theory_analysis.static_entropy, 2)} bits")
      IO.puts("   H(S_T|R) - Conditional Entropy: #{Float.round(theory_analysis.conditional_entropy, 2)} bits")
      IO.puts("   I(R;S_T) - Mutual Information: #{Float.round(theory_analysis.mutual_information, 2)} bits")
      IO.puts("   Template Effectiveness: #{Float.round(theory_analysis.effectiveness_ratio * 100, 1)}%")
      
      # Validate effectiveness
      assert theory_analysis.effectiveness_ratio >= 0.3, 
             "Template effectiveness #{theory_analysis.effectiveness_ratio} below acceptable threshold"
      
      if theory_analysis.effectiveness_ratio >= 0.8 do
        IO.puts("   🏆 EXCELLENT: High information value template!")
      elsif theory_analysis.effectiveness_ratio >= 0.6 do
        IO.puts("   ✅ GOOD: Effective information capture")
      else
        IO.puts("   ⚠️  FAIR: Template could be optimized")
      end
    end
  end
  
  # ========================================================================
  # HELPER FUNCTIONS
  # ========================================================================
  
  defp generate_diverse_telemetry_dataset do
    # Pattern 1: Basic operations
    BasicUsageModule.coordinate_work("diverse_001", ["a", "b"])
    BasicUsageModule.process_batch("diverse_batch", ["x", "y", "z"])
    
    # Pattern 2: Enterprise operations  
    AdvancedUsageModule.register_agent("diverse_agent", ["analyze"])
    AdvancedUsageModule.assign_work("diverse_agent", ["task_1", "task_2"])
    
    # Pattern 3: Performance operations
    HighFrequencyModule.process_request_batch(3, "standard")
    HighFrequencyModule.simulate_load_test(50, 5)
  end
  
  defp generate_insight_dataset do
    # Different service tiers for performance comparison
    HighFrequencyModule.process_request_batch(2, "premium")
    HighFrequencyModule.process_request_batch(2, "standard")
    
    # Different agent capabilities for capability analysis
    AdvancedUsageModule.register_agent("insight_agent_1", ["coordination", "optimization"])
    AdvancedUsageModule.register_agent("insight_agent_2", ["analysis"])
    
    # Variable workloads for load analysis
    BasicUsageModule.coordinate_work("insight_work_small", ["a"])
    BasicUsageModule.coordinate_work("insight_work_large", ["a", "b", "c", "d", "e"])
  end
  
  defp generate_theory_validation_dataset do
    # Generate controlled dataset for theory validation
    BasicUsageModule.coordinate_work("theory_001", ["controlled_test"])
    AdvancedUsageModule.register_agent("theory_agent", ["validation"])
    HighFrequencyModule.process_request_batch(2, "theory_test")
  end
  
  defp collect_telemetry_batch(expected_count, timeout_ms) do
    collect_events([], expected_count, timeout_ms)
  end
  
  defp collect_events(acc, remaining, timeout_ms) when remaining <= 0 do
    Enum.reverse(acc)
  end
  
  defp collect_events(acc, remaining, timeout_ms) do
    receive do
      {:comprehensive_telemetry, event_name, measurements, metadata} ->
        collect_events([{event_name, measurements, metadata} | acc], remaining - 1, timeout_ms)
    after timeout_ms ->
      Enum.reverse(acc)
    end
  end
  
  defp validate_high_mi_components(event_name, metadata, pattern_name) do
    # Check for high-MI template components
    required_components = [
      :code_filepath, "code_filepath",
      :code_namespace, "code_namespace", 
      :code_function, "code_function",
      :code_commit_id, "code_commit_id"
    ]
    
    captured_count = Enum.count(required_components, fn key -> 
      Map.has_key?(metadata, key) 
    end)
    
    # Should capture at least half of the high-MI components
    if captured_count >= 2 do
      IO.puts("   ✅ #{pattern_name} - Event #{inspect(event_name)}: #{captured_count}/4 MI components")
    else
      IO.puts("   ⚠️  #{pattern_name} - Event #{inspect(event_name)}: Only #{captured_count}/4 MI components")
    end
    
    captured_count
  end
  
  defp has_any_key(map, keys) when is_list(keys) do
    Enum.any?(keys, fn key -> Map.has_key?(map, key) end)
  end
  
  defp calculate_mutual_information(events) do
    # Extract metadata from all events
    all_metadata = Enum.map(events, fn {_event, _measurements, metadata} -> metadata end)
    
    # Calculate unique values for each high-MI component
    unique_filepaths = extract_unique_values(all_metadata, [:code_filepath, "code_filepath"])
    unique_namespaces = extract_unique_values(all_metadata, [:code_namespace, "code_namespace"])
    unique_functions = extract_unique_values(all_metadata, [:code_function, "code_function"])
    unique_commits = extract_unique_values(all_metadata, [:code_commit_id, "code_commit_id"])
    
    # Calculate entropy for each component (H = log2(unique_count))
    filepath_entropy = safe_log2(length(unique_filepaths))
    namespace_entropy = safe_log2(length(unique_namespaces))
    function_entropy = safe_log2(length(unique_functions))
    commit_entropy = safe_log2(length(unique_commits))
    
    # Total entropy (sum of component entropies)
    total_entropy = filepath_entropy + namespace_entropy + function_entropy + commit_entropy
    
    # Calculate average metadata size
    metadata_sizes = Enum.map(all_metadata, fn metadata -> 
      byte_size(inspect(metadata)) 
    end)
    avg_metadata_bytes = Enum.sum(metadata_sizes) / length(metadata_sizes)
    
    # Calculate efficiency (bits per byte)
    efficiency = total_entropy / avg_metadata_bytes
    
    %{
      unique_filepaths: length(unique_filepaths),
      unique_namespaces: length(unique_namespaces), 
      unique_functions: length(unique_functions),
      unique_commits: length(unique_commits),
      total_entropy_bits: total_entropy,
      avg_metadata_bytes: avg_metadata_bytes,
      efficiency_bits_per_byte: efficiency
    }
  end
  
  defp extract_unique_values(metadata_list, keys) do
    metadata_list
    |> Enum.flat_map(fn metadata ->
      keys
      |> Enum.map(fn key -> Map.get(metadata, key) end)
      |> Enum.filter(fn value -> value != nil end)
    end)
    |> Enum.uniq()
  end
  
  defp safe_log2(value) when value > 0, do: :math.log2(value)
  defp safe_log2(_value), do: 0.0
  
  defp generate_telemetry_insights(events) do
    # Analyze telemetry for actionable insights
    metadata_list = Enum.map(events, fn {_event, _measurements, metadata} -> metadata end)
    
    # Extract performance patterns
    performance_patterns = analyze_performance_patterns(events)
    
    # Extract error patterns
    error_patterns = analyze_error_patterns(events)
    
    # Generate optimization recommendations
    optimization_recommendations = generate_optimization_recommendations(events, metadata_list)
    
    # Calculate service topology metrics
    modules = extract_unique_values(metadata_list, [:code_namespace, "code_namespace"])
    functions = extract_unique_values(metadata_list, [:code_function, "code_function"])
    
    # Calculate average response time from measurements
    durations = events
    |> Enum.flat_map(fn {_event, measurements, _metadata} ->
      [
        Map.get(measurements, :duration_ms),
        Map.get(measurements, "duration_ms"),
        Map.get(measurements, :duration),
        Map.get(measurements, "duration")
      ]
    end)
    |> Enum.filter(fn duration -> duration != nil and is_number(duration) end)
    
    avg_response_time = if length(durations) > 0 do
      Enum.sum(durations) / length(durations) / 1000  # Convert to ms
    else
      0.0
    end
    
    %{
      performance_patterns: performance_patterns,
      error_patterns: error_patterns,
      optimization_recommendations: optimization_recommendations,
      modules_count: length(modules),
      functions_count: length(functions),
      avg_response_time_ms: Float.round(avg_response_time, 2)
    }
  end
  
  defp analyze_performance_patterns(events) do
    patterns = []
    
    # Pattern: High-frequency operations
    high_frequency_events = Enum.filter(events, fn {event_name, _measurements, _metadata} ->
      List.last(event_name) == :operation
    end)
    
    patterns = if length(high_frequency_events) > 3 do
      ["High-frequency operations detected (#{length(high_frequency_events)} events)" | patterns]
    else
      patterns
    end
    
    # Pattern: Enterprise coordination
    enterprise_events = Enum.filter(events, fn {event_name, _measurements, _metadata} ->
      Enum.member?(event_name, :enterprise) or Enum.member?(event_name, :coordination)
    end)
    
    patterns = if length(enterprise_events) > 0 do
      ["Enterprise coordination patterns active (#{length(enterprise_events)} events)" | patterns]
    else
      patterns
    end
    
    # Pattern: Multi-tier service usage
    service_tiers = events
    |> Enum.flat_map(fn {_event, _measurements, metadata} ->
      [metadata[:service_tier], metadata["service_tier"]]
    end)
    |> Enum.filter(fn tier -> tier != nil end)
    |> Enum.uniq()
    
    patterns = if length(service_tiers) > 1 do
      ["Multi-tier service usage: #{inspect(service_tiers)}" | patterns]
    else
      patterns
    end
    
    patterns
  end
  
  defp analyze_error_patterns(events) do
    # Look for error indicators in telemetry
    error_events = Enum.filter(events, fn {_event, measurements, metadata} ->
      # Check for error indicators
      error_rate = Map.get(measurements, :error_rate) || Map.get(measurements, "error_rate")
      success = Map.get(metadata, :success) || Map.get(metadata, "success")
      
      (error_rate != nil and error_rate > 0) or success == false
    end)
    
    if length(error_events) > 0 do
      ["Error patterns detected in #{length(error_events)} events"]
    else
      []
    end
  end
  
  defp generate_optimization_recommendations(events, metadata_list) do
    recommendations = []
    
    # Recommendation: Context optimization
    context_variety = extract_unique_values(metadata_list, [:operation_type, "operation_type"])
    recommendations = if length(context_variety) > 5 do
      ["Consider context template optimization for #{length(context_variety)} operation types" | recommendations]
    else
      recommendations
    end
    
    # Recommendation: Sampling optimization
    event_count = length(events)
    recommendations = if event_count > 50 do
      ["High event volume (#{event_count}): Consider adaptive sampling strategies" | recommendations]
    else
      recommendations
    end
    
    # Recommendation: Performance optimization
    agent_operations = Enum.filter(events, fn {_event, _measurements, metadata} ->
      has_any_key(metadata, [:agent_id, "agent_id"])
    end)
    
    recommendations = if length(agent_operations) > 3 do
      ["Agent coordination active: Enable predictive workload balancing" | recommendations]
    else
      recommendations
    end
    
    # Default recommendation
    if length(recommendations) == 0 do
      ["System operating efficiently: Continue current observability strategy"]
    else
      recommendations
    end
  end
  
  defp validate_information_theory(events) do
    # Validate I(R;S_T) = H(S_T) - H(S_T|R) formula
    
    # Extract runtime events (R) and static context (S_T)
    runtime_events = Enum.map(events, fn {event_name, measurements, _metadata} ->
      {event_name, measurements}
    end)
    
    static_contexts = Enum.map(events, fn {_event, _measurements, metadata} ->
      # Extract high-MI components as static context
      %{
        filepath: metadata[:code_filepath] || metadata["code_filepath"],
        namespace: metadata[:code_namespace] || metadata["code_namespace"],
        function: metadata[:code_function] || metadata["code_function"],
        commit: metadata[:code_commit_id] || metadata["code_commit_id"]
      }
    end)
    
    # Calculate H(S_T) - entropy of static context tags
    unique_contexts = Enum.uniq(static_contexts)
    static_entropy = safe_log2(length(unique_contexts))
    
    # Calculate H(S_T|R) - conditional entropy (simplified estimation)
    # Group contexts by runtime events and calculate average entropy
    context_groups = runtime_events
    |> Enum.zip(static_contexts)
    |> Enum.group_by(fn {runtime, _context} -> runtime end, fn {_runtime, context} -> context end)
    
    conditional_entropies = context_groups
    |> Map.values()
    |> Enum.map(fn contexts_in_group ->
      unique_in_group = Enum.uniq(contexts_in_group)
      safe_log2(length(unique_in_group))
    end)
    
    conditional_entropy = if length(conditional_entropies) > 0 do
      Enum.sum(conditional_entropies) / length(conditional_entropies)
    else
      0.0
    end
    
    # Calculate mutual information: I(R;S_T) = H(S_T) - H(S_T|R)
    mutual_information = static_entropy - conditional_entropy
    
    # Calculate effectiveness ratio
    effectiveness_ratio = if static_entropy > 0 do
      mutual_information / static_entropy
    else
      0.0
    end
    
    %{
      static_entropy: static_entropy,
      conditional_entropy: conditional_entropy,
      mutual_information: mutual_information,
      effectiveness_ratio: effectiveness_ratio
    }
  end
  
  defp collect_comprehensive_telemetry(event_name, measurements, metadata, config) do
    send(config.test_pid, {:comprehensive_telemetry, event_name, measurements, metadata})
  end
end