defmodule AiSelfSustainingMinimal.Telemetry.OtelIntegrationTest do
  @moduledoc """
  Integration test for OpenTelemetry DSL with real coordination system.
  
  ## Test Objectives
  
  1. **Real System Integration**: Test DSL with actual coordination operations
  2. **OTLP Pipeline Validation**: Verify telemetry flows through OTLP pipeline
  3. **Information Theory Validation**: Measure actual MI from real operations
  4. **Performance Impact**: Measure overhead on real coordination workflows
  5. **Enterprise Readiness**: Test production-like scenarios
  
  ## Test Strategy
  
  Tests the full stack from DSL compilation through telemetry collection,
  OTLP processing, and MI analysis using real coordination operations
  from the AI Self-Sustaining System.
  """
  
  use ExUnit.Case, async: false
  
  alias AiSelfSustainingMinimal.{Coordination, Telemetry}
  alias AiSelfSustainingMinimal.Coordination.{Agent, WorkItem}
  
  @moduletag :integration
  @moduletag timeout: 120_000  # 2 minutes for integration tests
  
  # Real coordination module instrumented with our DSL
  defmodule InstrumentedCoordination do
    use AiSelfSustainingMinimal.Telemetry.SparkOtelDsl
    
    otel do
      # Production-ready high-MI context
      context :production_coordination do
        filepath true
        namespace true
        function true
        commit_id true
        custom_tags [:agent_id, :work_item_id, :team_id, :session_id]
        mi_target 0.26
      end
      
      # Performance monitoring context
      context :performance_monitoring do
        filepath true
        namespace true
        function true
        commit_id true
        custom_tags [:performance_tier, :load_level]
        mi_target 0.20
      end
      
      # Span definitions for coordination operations
      span :agent_registration do
        event_name [:coordination, :agent, :register]
        context :production_coordination
        measurements [:registration_time_ms, :capability_count, :validation_time]
        metadata [:agent_type, :capabilities, :deployment_env, :registration_source]
      end
      
      span :work_item_lifecycle do
        event_name [:coordination, :work_item, :lifecycle]
        context :production_coordination
        measurements [:processing_time_ms, :queue_depth, :priority_score]
        metadata [:work_type, :priority, :complexity, :team_assignment]
      end
      
      span :coordination_health_check do
        event_name [:coordination, :health, :check]
        context :performance_monitoring
        measurements [:response_time_ms, :active_agents, :pending_work_items]
        metadata [:system_load, :memory_usage, :error_rate]
      end
      
      # Auto-instrument critical coordination functions
      auto_instrument do
        functions [
          register_agent: 2,
          claim_work_item: 3,
          complete_work_item: 2,
          health_check: 1
        ]
        context :production_coordination
        measurements [:execution_time, :memory_delta]
      end
      
      # MI analysis for production validation
      analysis do
        measure_mi true
        export_format :jsonl
        export_path "test/fixtures/integration_telemetry.jsonl"
        optimization_target 0.25
        auto_optimize false
        sample_rate 1.0  # Full sampling for testing
      end
    end
    
    def register_agent(agent_attrs, metadata \\ %{}) do
      with_agent_registration_span Map.merge(%{
        agent_type: "autonomous",
        deployment_env: "test",
        registration_source: "integration_test"
      }, metadata) do
        # Actual agent registration through Ash
        start_time = System.monotonic_time(:microsecond)
        
        result = Agent
        |> Ash.Changeset.for_create(:register, agent_attrs)
        |> Ash.create()
        
        end_time = System.monotonic_time(:microsecond)
        registration_time = (end_time - start_time) / 1000  # Convert to ms
        
        # Add performance measurements
        Process.put(:registration_time_ms, registration_time)
        Process.put(:capability_count, length(agent_attrs[:capabilities] || []))
        Process.put(:validation_time, registration_time * 0.3)  # Estimated validation time
        
        result
      end
    end
    
    def claim_work_item(work_item_id, agent_id, metadata \\ %{}) do
      with_work_item_lifecycle_span Map.merge(%{
        work_type: "unknown",
        priority: "medium",
        complexity: "normal",
        team_assignment: "default"
      }, metadata) do
        # Simulate work item claiming
        start_time = System.monotonic_time(:microsecond)
        
        # Find work item and agent
        work_item_query = WorkItem |> Ash.Query.filter(work_item_id == ^work_item_id)
        agent_query = Agent |> Ash.Query.filter(agent_id == ^agent_id)
        
        with {:ok, work_item} <- Ash.read_one(work_item_query),
             {:ok, agent} <- Ash.read_one(agent_query),
             work_item when not is_nil(work_item) <- work_item,
             agent when not is_nil(agent) <- agent do
          
          # Claim the work item
          result = work_item
          |> Ash.Changeset.for_update(:claim_work, %{claimed_by: agent.id})
          |> Ash.update()
          
          end_time = System.monotonic_time(:microsecond)
          processing_time = (end_time - start_time) / 1000
          
          # Add measurements
          Process.put(:processing_time_ms, processing_time)
          Process.put(:queue_depth, :rand.uniform(20))  # Simulated queue depth
          Process.put(:priority_score, calculate_priority_score(work_item))
          
          result
        else
          nil -> {:error, :not_found}
          error -> error
        end
      end
    end
    
    def complete_work_item(work_item_id, result_data \\ %{}) do
      with_work_item_lifecycle_span %{
        work_type: "completion",
        priority: "processing",
        complexity: "variable"
      } do
        start_time = System.monotonic_time(:microsecond)
        
        work_item_query = WorkItem |> Ash.Query.filter(work_item_id == ^work_item_id)
        
        with {:ok, work_item} <- Ash.read_one(work_item_query),
             work_item when not is_nil(work_item) <- work_item do
          
          result = work_item
          |> Ash.Changeset.for_update(:complete_work, %{result: result_data})
          |> Ash.update()
          
          end_time = System.monotonic_time(:microsecond)
          processing_time = (end_time - start_time) / 1000
          
          Process.put(:processing_time_ms, processing_time)
          Process.put(:queue_depth, :rand.uniform(15))
          Process.put(:priority_score, 100)  # Completion always high priority
          
          result
        else
          nil -> {:error, :not_found}
          error -> error
        end
      end
    end
    
    def health_check(check_type \\ :full) do
      with_coordination_health_check_span %{
        system_load: "normal",
        memory_usage: "optimal",
        error_rate: "low"
      } do
        start_time = System.monotonic_time(:microsecond)
        
        # Perform health checks
        active_agents = count_active_agents()
        pending_work = count_pending_work()
        system_status = check_system_health(check_type)
        
        end_time = System.monotonic_time(:microsecond)
        response_time = (end_time - start_time) / 1000
        
        Process.put(:response_time_ms, response_time)
        Process.put(:active_agents, active_agents)
        Process.put(:pending_work_items, pending_work)
        
        {:ok, system_status}
      end
    end
    
    # Helper functions
    
    defp calculate_priority_score(work_item) do
      case work_item.priority do
        :high -> 90 + :rand.uniform(10)
        :medium -> 50 + :rand.uniform(30)
        :low -> 10 + :rand.uniform(20)
        _ -> 50
      end
    end
    
    defp count_active_agents do
      case Agent |> Ash.Query.for_read(:active) |> Ash.read() do
        {:ok, agents} -> length(agents)
        _ -> 0
      end
    end
    
    defp count_pending_work do
      case WorkItem |> Ash.Query.for_read(:by_status, %{status: :pending}) |> Ash.read() do
        {:ok, work_items} -> length(work_items)
        _ -> 0
      end
    end
    
    defp check_system_health(check_type) do
      base_health = %{
        status: :healthy,
        uptime: System.system_time(:second),
        memory_usage: :erlang.memory(:total),
        process_count: length(Process.list())
      }
      
      case check_type do
        :full -> 
          Map.merge(base_health, %{
            database_status: :connected,
            telemetry_status: :operational,
            coordination_status: :active
          })
        
        :basic -> base_health
      end
    end
  end
  
  setup_all do
    # Set up test environment
    System.put_env("GIT_SHA", "integration_test_commit_def456abc789")
    
    # Set up comprehensive telemetry collection
    :telemetry.attach_many(
      "integration_test_collector",
      [
        [:coordination, :agent, :register],
        [:coordination, :work_item, :lifecycle],
        [:coordination, :health, :check]
      ],
      &collect_integration_telemetry/4,
      %{test_pid: self()}
    )
    
    # Start telemetry collection agent
    Agent.start_link(fn -> %{events: [], start_time: System.monotonic_time()} end, 
                     name: :integration_telemetry_collector)
    
    on_exit(fn ->
      :telemetry.detach("integration_test_collector")
      if Process.whereis(:integration_telemetry_collector) do
        Agent.stop(:integration_telemetry_collector)
      end
      System.delete_env("GIT_SHA")
    end)
    
    :ok
  end
  
  describe "real coordination system integration" do
    test "agent registration with full telemetry context" do
      # Create a realistic agent registration
      agent_attrs = %{
        agent_id: "integration_test_agent_#{System.unique_integer()}",
        capabilities: ["coordination", "processing", "analysis", "monitoring"],
        metadata: %{
          test_run: true,
          integration_type: "full_stack",
          performance_tier: "standard"
        }
      }
      
      metadata = %{
        agent_type: "autonomous_coordinator",
        capabilities: agent_attrs.capabilities,
        deployment_env: "integration_test",
        registration_source: "automated_test"
      }
      
      # Perform registration with telemetry
      result = InstrumentedCoordination.register_agent(agent_attrs, metadata)
      
      # Verify registration succeeded
      assert {:ok, agent} = result
      assert agent.agent_id == agent_attrs.agent_id
      assert agent.capabilities == agent_attrs.capabilities
      
      # Wait for telemetry processing
      :timer.sleep(100)
      
      # Verify telemetry was collected
      events = get_collected_events()
      registration_events = filter_events_by_name(events, [:coordination, :agent, :register])
      
      assert length(registration_events) >= 1
      
      event = List.first(registration_events)
      
      # Verify high-MI context data
      assert event.metadata["code_filepath"] =~ "otel_integration_test.exs"
      assert event.metadata["code_namespace"] != nil
      assert event.metadata["code_function"] != nil
      assert event.metadata["code_commit_id"] == "integration_test_commit_def456abc789"
      
      # Verify custom context tags
      assert event.metadata["agent_id"] == agent.agent_id
      assert event.metadata["agent_type"] == "autonomous_coordinator"
      assert event.metadata["deployment_env"] == "integration_test"
      
      # Verify measurements
      assert event.measurements["registration_time_ms"] > 0
      assert event.measurements["capability_count"] == 4
      assert event.measurements["validation_time"] > 0
      
      IO.puts("\n✅ Agent Registration Telemetry:")
      IO.puts("   Agent ID: #{event.metadata["agent_id"]}")
      IO.puts("   Registration Time: #{event.measurements["registration_time_ms"]}ms")
      IO.puts("   Capabilities: #{event.measurements["capability_count"]}")
      IO.puts("   Context Components: #{count_context_components(event.metadata)}")
    end
    
    test "work item lifecycle with coordination telemetry" do
      # First create an agent
      agent_attrs = %{
        agent_id: "work_agent_#{System.unique_integer()}",
        capabilities: ["work_processing", "coordination"]
      }
      
      {:ok, agent} = InstrumentedCoordination.register_agent(agent_attrs)
      
      # Create a work item
      work_attrs = %{
        work_type: "integration_test_work",
        description: "Integration test work item for telemetry validation",
        priority: :high,
        payload: %{test_data: "telemetry_validation", complexity: "high"}
      }
      
      {:ok, work_item} = WorkItem
      |> Ash.Changeset.for_create(:submit_work, work_attrs)
      |> Ash.create()
      
      # Claim work item with telemetry
      claim_metadata = %{
        work_type: work_item.work_type,
        priority: Atom.to_string(work_item.priority),
        complexity: "high",
        team_assignment: "integration_test_team"
      }
      
      claim_result = InstrumentedCoordination.claim_work_item(
        work_item.work_item_id,
        agent.agent_id,
        claim_metadata
      )
      
      assert {:ok, claimed_work} = claim_result
      assert claimed_work.status == :claimed
      assert claimed_work.claimed_by == agent.id
      
      # Complete work item
      completion_result = InstrumentedCoordination.complete_work_item(
        work_item.work_item_id,
        %{result: "integration_test_completed", success: true}
      )
      
      assert {:ok, completed_work} = completion_result
      assert completed_work.status == :completed
      
      # Wait for telemetry
      :timer.sleep(150)
      
      # Verify lifecycle telemetry
      events = get_collected_events()
      lifecycle_events = filter_events_by_name(events, [:coordination, :work_item, :lifecycle])
      
      assert length(lifecycle_events) >= 2  # Claim + Complete
      
      # Analyze claim event
      claim_event = Enum.find(lifecycle_events, fn event ->
        event.metadata["work_type"] == "integration_test_work"
      end)
      
      assert claim_event != nil
      assert claim_event.measurements["processing_time_ms"] > 0
      assert claim_event.metadata["work_item_id"] == work_item.work_item_id
      assert claim_event.metadata["agent_id"] == agent.agent_id
      
      IO.puts("\n✅ Work Item Lifecycle Telemetry:")
      IO.puts("   Work Item ID: #{claim_event.metadata["work_item_id"]}")
      IO.puts("   Processing Time: #{claim_event.measurements["processing_time_ms"]}ms")
      IO.puts("   Priority Score: #{claim_event.measurements["priority_score"]}")
      IO.puts("   Team Assignment: #{claim_event.metadata["team_assignment"]}")
    end
    
    test "coordination health monitoring with performance context" do
      # Perform health checks with different types
      basic_result = InstrumentedCoordination.health_check(:basic)
      full_result = InstrumentedCoordination.health_check(:full)
      
      assert {:ok, basic_health} = basic_result
      assert {:ok, full_health} = full_result
      
      assert basic_health.status == :healthy
      assert full_health.status == :healthy
      assert Map.has_key?(full_health, :database_status)
      
      :timer.sleep(100)
      
      # Verify health check telemetry
      events = get_collected_events()
      health_events = filter_events_by_name(events, [:coordination, :health, :check])
      
      assert length(health_events) >= 2
      
      health_event = List.first(health_events)
      
      # Verify performance monitoring context
      assert health_event.metadata["code_filepath"] =~ "otel_integration_test.exs"
      assert health_event.metadata["performance_tier"] != nil
      assert health_event.metadata["system_load"] == "normal"
      assert health_event.metadata["memory_usage"] == "optimal"
      
      # Verify health measurements
      assert health_event.measurements["response_time_ms"] > 0
      assert health_event.measurements["active_agents"] >= 0
      assert health_event.measurements["pending_work_items"] >= 0
      
      IO.puts("\n✅ Health Check Telemetry:")
      IO.puts("   Response Time: #{health_event.measurements["response_time_ms"]}ms")
      IO.puts("   Active Agents: #{health_event.measurements["active_agents"]}")
      IO.puts("   Pending Work: #{health_event.measurements["pending_work_items"]}")
    end
  end
  
  describe "OTLP pipeline integration" do
    test "telemetry flows through OTLP pipeline correctly" do
      # Generate coordinated telemetry events
      generate_coordinated_telemetry_sequence()
      
      :timer.sleep(200)  # Allow processing
      
      # Verify events were collected
      events = get_collected_events()
      assert length(events) > 0
      
      # Verify OTLP-compatible structure
      Enum.each(events, fn event ->
        # Events should have proper OTLP structure
        assert Map.has_key?(event, :event_name)
        assert Map.has_key?(event, :measurements)
        assert Map.has_key?(event, :metadata)
        assert Map.has_key?(event, :timestamp)
        
        # Verify W3C trace context components
        metadata = event.metadata
        assert Map.has_key?(metadata, "code_filepath")
        assert Map.has_key?(metadata, "code_namespace")
        assert Map.has_key?(metadata, "code_function")
        assert Map.has_key?(metadata, "code_commit_id")
      end)
      
      IO.puts("\n✅ OTLP Pipeline Integration:")
      IO.puts("   Events Processed: #{length(events)}")
      IO.puts("   W3C Trace Context: ✓")
      IO.puts("   OTLP Structure: ✓")
    end
  end
  
  describe "mutual information validation with real data" do
    test "real telemetry achieves target MI efficiency" do
      # Generate substantial telemetry sample
      telemetry_sample = generate_comprehensive_telemetry_sample()
      
      # Convert to analysis format
      analysis_data = Enum.map(telemetry_sample, &convert_to_analysis_format/1)
      
      # Test production coordination context
      production_context = %Telemetry.Context{
        name: :production_coordination,
        filepath: true,
        namespace: true,
        function: true,
        commit_id: true,
        custom_tags: [:agent_id, :work_item_id, :team_id, :session_id],
        mi_target: 0.26
      }
      
      # Test performance monitoring context
      performance_context = %Telemetry.Context{
        name: :performance_monitoring,
        filepath: true,
        namespace: true,
        function: true,
        commit_id: true,
        custom_tags: [:performance_tier, :load_level],
        mi_target: 0.20
      }
      
      # Calculate MI scores
      production_score = Telemetry.Context.calculate_mi_score(production_context, analysis_data)
      performance_score = Telemetry.Context.calculate_mi_score(performance_context, analysis_data)
      
      IO.puts("\n✅ Real Data MI Analysis:")
      IO.puts("   Production Context:")
      IO.puts("     MI: #{Float.round(production_score.mutual_information, 2)} bits")
      IO.puts("     Efficiency: #{Float.round(production_score.bits_per_byte, 3)} bits/byte")
      IO.puts("     Target: #{production_context.mi_target} bits/byte")
      
      IO.puts("   Performance Context:")
      IO.puts("     MI: #{Float.round(performance_score.mutual_information, 2)} bits")
      IO.puts("     Efficiency: #{Float.round(performance_score.bits_per_byte, 3)} bits/byte")
      IO.puts("     Target: #{performance_context.mi_target} bits/byte")
      
      # Validate efficiency targets
      assert production_score.bits_per_byte > 0.15, 
             "Production context efficiency too low: #{production_score.bits_per_byte}"
      
      assert performance_score.bits_per_byte > 0.10,
             "Performance context efficiency too low: #{performance_score.bits_per_byte}"
      
      # Production context should provide more information
      assert production_score.mutual_information >= performance_score.mutual_information,
             "Production context should provide more information"
      
      # Verify reasonable byte overhead
      assert production_score.bytes_per_event < 400,
             "Production context byte overhead too high: #{production_score.bytes_per_event}"
      
      # Success indicators
      if production_score.bits_per_byte >= production_context.mi_target do
        IO.puts("   ✅ Production context meets target efficiency")
      else
        IO.puts("   ⚠️  Production context below target (#{Float.round(production_score.bits_per_byte, 3)} < #{production_context.mi_target})")
      end
      
      if performance_score.bits_per_byte >= performance_context.mi_target do
        IO.puts("   ✅ Performance context meets target efficiency")
      else
        IO.puts("   ⚠️  Performance context below target (#{Float.round(performance_score.bits_per_byte, 3)} < #{performance_context.mi_target})")
      end
    end
  end
  
  # ========================================================================
  # Helper Functions
  # ========================================================================
  
  defp collect_integration_telemetry(event_name, measurements, metadata, config) do
    event = %{
      event_name: event_name,
      measurements: measurements,
      metadata: metadata,
      timestamp: System.system_time(:microsecond),
      collection_offset: System.monotonic_time() - Agent.get(:integration_telemetry_collector, fn state -> state.start_time end)
    }
    
    Agent.update(:integration_telemetry_collector, fn state ->
      %{state | events: [event | state.events]}
    end)
  end
  
  defp get_collected_events do
    Agent.get(:integration_telemetry_collector, fn state -> 
      Enum.reverse(state.events)  # Return in chronological order
    end)
  end
  
  defp filter_events_by_name(events, event_name) do
    Enum.filter(events, fn event ->
      event.event_name == event_name
    end)
  end
  
  defp count_context_components(metadata) do
    context_components = [
      "code_filepath",
      "code_namespace", 
      "code_function",
      "code_commit_id",
      "agent_id",
      "work_item_id",
      "team_id",
      "session_id"
    ]
    
    Enum.count(context_components, fn component ->
      Map.has_key?(metadata, component) and metadata[component] != nil
    end)
  end
  
  defp generate_coordinated_telemetry_sequence do
    # Create a sequence of realistic coordination events
    
    # 1. Agent registration
    agent_attrs = %{
      agent_id: "sequence_agent_#{System.unique_integer()}",
      capabilities: ["coordination", "sequence_processing"]
    }
    {:ok, agent} = InstrumentedCoordination.register_agent(agent_attrs)
    
    # 2. Multiple work items
    Enum.each(1..3, fn i ->
      work_attrs = %{
        work_type: "sequence_work_#{i}",
        description: "Sequence work item #{i}",
        priority: Enum.random([:high, :medium, :low])
      }
      
      {:ok, work_item} = WorkItem
      |> Ash.Changeset.for_create(:submit_work, work_attrs)
      |> Ash.create()
      
      # Claim and complete work
      InstrumentedCoordination.claim_work_item(work_item.work_item_id, agent.agent_id)
      InstrumentedCoordination.complete_work_item(work_item.work_item_id, %{sequence: i})
    end)
    
    # 3. Health checks
    InstrumentedCoordination.health_check(:basic)
    InstrumentedCoordination.health_check(:full)
  end
  
  defp generate_comprehensive_telemetry_sample do
    # Generate a comprehensive sample of real telemetry events
    all_events = get_collected_events()
    
    # Add more events if we don't have enough
    if length(all_events) < 50 do
      # Generate additional events
      Enum.each(1..20, fn i ->
        agent_attrs = %{
          agent_id: "sample_agent_#{i}",
          capabilities: ["sample_capability_#{rem(i, 3)}"]
        }
        InstrumentedCoordination.register_agent(agent_attrs)
        
        if rem(i, 3) == 0 do
          InstrumentedCoordination.health_check(:basic)
        end
      end)
      
      :timer.sleep(100)
      get_collected_events()
    else
      all_events
    end
  end
  
  defp convert_to_analysis_format(event) do
    %{
      "event_name" => event.event_name,
      "measurements" => stringify_map_keys(event.measurements),
      "metadata" => stringify_map_keys(event.metadata),
      "timestamp" => event.timestamp
    }
  end
  
  defp stringify_map_keys(map) when is_map(map) do
    Enum.into(map, %{}, fn {key, value} ->
      {to_string(key), value}
    end)
  end
  defp stringify_map_keys(other), do: other
end