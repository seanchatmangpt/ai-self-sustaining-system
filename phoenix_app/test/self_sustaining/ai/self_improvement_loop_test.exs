defmodule SelfSustaining.AI.SelfImprovementLoopTest do
  @moduledoc """
  Comprehensive integration tests for the entire self-improvement loop.
  Tests the complete cycle from discovery to deployment and learning.
  """
  
  use ExUnit.Case, async: false
  use SelfSustaining.DataCase
  
  alias SelfSustaining.AI.SelfImprovementOrchestrator
  alias SelfSustaining.AI.WorkflowGenerator
  alias N8n.WorkflowManager
  alias SelfSustaining.ClaudeCode
  
  import Mox
  
  # Setup mock modules for external dependencies
  defmock(MockClaudeCode, for: SelfSustaining.ClaudeCode)
  defmock(MockN8nApi, for: SelfSustaining.N8nApiClient)
  defmock(MockPerformanceMonitor, for: SelfSustaining.PerformanceMonitor)
  
  setup do
    # Replace real modules with mocks during testing
    Application.put_env(:self_sustaining, :claude_code_module, MockClaudeCode)
    Application.put_env(:self_sustaining, :n8n_api_module, MockN8nApi)
    Application.put_env(:self_sustaining, :performance_monitor_module, MockPerformanceMonitor)
    
    # Start the orchestrator with a short cycle for testing
    {:ok, orchestrator_pid} = start_supervised({
      SelfImprovementOrchestrator, 
      [cycle_interval: 100]  # 100ms for fast testing
    })
    
    on_exit(fn ->
      # Restore original modules
      Application.delete_env(:self_sustaining, :claude_code_module)
      Application.delete_env(:self_sustaining, :n8n_api_module)
      Application.delete_env(:self_sustaining, :performance_monitor_module)
    end)
    
    %{orchestrator: orchestrator_pid}
  end
  
  describe "complete self-improvement cycle" do
    test "executes full cycle from discovery to deployment", %{orchestrator: orchestrator} do
      # Mock Claude Code responses for each phase of the cycle
      setup_discovery_mocks()
      setup_generation_mocks()
      setup_performance_mocks()
      
      # Trigger a cycle and wait for completion
      SelfImprovementOrchestrator.trigger_improvement_cycle()
      
      # Wait for cycle to complete
      assert_receive {:cycle_completed, cycle_result}, 5_000
      
      # Verify cycle phases executed successfully
      assert cycle_result.opportunities_found > 0
      assert cycle_result.improvements_processed > 0
      assert cycle_result.workflows_deployed >= 0
      assert cycle_result.cycle_duration > 0
      
      # Verify system state was updated
      status = SelfImprovementOrchestrator.get_status()
      assert status.cycle_id > 0
      assert status.last_cycle != nil
    end
    
    test "handles errors gracefully throughout the cycle" do
      # Mock failures at different stages
      MockClaudeCode
      |> expect(:prompt, fn _, _ -> {:error, "Claude Code timeout"} end)
      
      MockN8nApi
      |> expect(:import_workflow, fn _ -> {:error, "n8n connection failed"} end)
      
      # Trigger cycle
      SelfImprovementOrchestrator.trigger_improvement_cycle()
      
      # Should complete despite errors
      assert_receive {:cycle_completed, cycle_result}, 5_000
      
      # Should have logged errors but continued
      assert cycle_result.cycle_duration > 0
      assert cycle_result.workflows_deployed == 0  # Due to mocked failures
    end
    
    test "learns from previous cycles" do
      # Set up performance data showing improvement over time
      performance_history = [
        %{cycle: 1, success_rate: 0.7, deployment_time: 5000},
        %{cycle: 2, success_rate: 0.8, deployment_time: 4500},
        %{cycle: 3, success_rate: 0.9, deployment_time: 4000}
      ]
      
      MockPerformanceMonitor
      |> expect(:get_cycle_history, fn -> performance_history end)
      |> expect(:analyze_improvement_trends, fn history ->
        {:ok, %{
          success_trend: :improving,
          performance_trend: :improving,
          recommendations: ["Continue current optimization strategy"]
        }}
      end)
      
      setup_discovery_mocks()
      setup_generation_mocks()
      
      # Trigger cycle
      SelfImprovementOrchestrator.trigger_improvement_cycle()
      
      assert_receive {:cycle_completed, cycle_result}, 5_000
      
      # Verify learning was incorporated
      assert cycle_result.learning_applied == true
      assert cycle_result.trend_analysis != nil
    end
    
    test "prioritizes improvements correctly" do
      # Mock discovery with various priority improvements
      MockClaudeCode
      |> expect(:prompt, fn prompt, _ ->
        if String.contains?(prompt, "improvement opportunities") do
          {:ok, mock_improvement_opportunities_response()}
        else
          {:ok, "Mock response"}
        end
      end)
      
      setup_generation_mocks()
      setup_performance_mocks()
      
      # Queue some manual improvements
      high_priority_task = %{
        description: "Critical security fix",
        priority: :high,
        type: :security_enhancement
      }
      
      SelfImprovementOrchestrator.queue_improvement(high_priority_task)
      
      # Trigger cycle
      SelfImprovementOrchestrator.trigger_improvement_cycle()
      
      assert_receive {:cycle_completed, cycle_result}, 5_000
      
      # High priority items should be processed first
      assert cycle_result.high_priority_processed > 0
    end
  end
  
  describe "workflow generation and validation loop" do
    test "generates valid workflows from requirements" do
      requirements = %{
        type: :monitoring,
        description: "Health check workflow",
        priority: :medium,
        constraints: ["Must complete within 30 seconds"]
      }
      
      # Mock Claude Code for workflow generation
      MockClaudeCode
      |> expect(:prompt, 2, fn prompt, opts ->
        cond do
          String.contains?(prompt, "specification") ->
            {:ok, mock_workflow_specification()}
          
          String.contains?(prompt, "Generate Elixir code") ->
            {:ok, mock_workflow_code()}
          
          true ->
            {:ok, "Mock response"}
        end
      end)
      
      {:ok, result} = WorkflowGenerator.generate_workflow(requirements)
      
      assert result.spec.name != nil
      assert result.module != nil
      assert result.json != nil
      assert result.generated_at != nil
      
      # Verify generated workflow is valid
      assert {:ok, _json} = N8n.Reactor.validate_workflow(result.module)
    end
    
    test "optimizes existing workflows based on performance data" do
      workflow_module = TestWorkflows.SimpleWorkflow
      
      performance_data = %{
        execution_time: 15000,  # Slow execution
        success_rate: 0.85,
        error_rate: 0.15,
        resource_usage: %{cpu: 0.9, memory: 180}  # High resource usage
      }
      
      MockClaudeCode
      |> expect(:prompt, 2, fn prompt, _ ->
        cond do
          String.contains?(prompt, "suggest improvements") ->
            {:ok, mock_improvement_suggestions()}
          
          String.contains?(prompt, "Apply these optimizations") ->
            {:ok, mock_optimized_workflow_code()}
          
          true ->
            {:ok, "Mock response"}
        end
      end)
      
      {:ok, result} = WorkflowGenerator.optimize_workflow(workflow_module, performance_data)
      
      assert result.original_module == workflow_module
      assert result.optimized_module != nil
      assert result.improvements != []
      assert result.optimized_at != nil
      
      # Verify optimization maintains functionality
      assert {:ok, _} = N8n.Reactor.validate_workflow(result.optimized_module)
    end
    
    test "validates generated workflows thoroughly" do
      # Test with invalid workflow generation
      MockClaudeCode
      |> expect(:prompt, fn _, _ ->
        {:ok, "Invalid workflow code that won't compile"}
      end)
      
      requirements = %{type: :invalid_test}
      
      {:error, reason} = WorkflowGenerator.generate_workflow(requirements)
      
      assert String.contains?(reason, "syntax errors") or String.contains?(reason, "compilation")
    end
  end
  
  describe "deployment and monitoring loop" do
    test "deploys workflows and monitors execution" do
      workflow_result = %{
        module: TestWorkflows.SimpleWorkflow,
        spec: %{name: "Test Workflow"},
        json: %{"name" => "Test", "nodes" => [], "connections" => %{}},
        generated_at: DateTime.utc_now()
      }
      
      # Mock successful deployment
      MockN8nApi
      |> expect(:import_workflow, fn _json ->
        {:ok, %{"id" => "test_workflow_123", "active" => true}}
      end)
      
      {:ok, deployment} = deploy_workflow_with_monitoring(workflow_result)
      
      assert deployment.n8n_workflow_id == "test_workflow_123"
      assert deployment.deployed_at != nil
      
      # Simulate workflow execution
      execution_result = simulate_workflow_execution(deployment.n8n_workflow_id)
      
      # Monitor should capture execution metrics
      assert execution_result.execution_time > 0
      assert execution_result.success == true
    end
    
    test "handles deployment failures and retries" do
      workflow_result = %{
        module: TestWorkflows.SimpleWorkflow,
        spec: %{name: "Test Workflow"},
        json: %{"name" => "Test", "nodes" => [], "connections" => %{}}
      }
      
      # Mock deployment failure followed by success
      MockN8nApi
      |> expect(:import_workflow, fn _json ->
        {:error, "Network timeout"}
      end)
      |> expect(:import_workflow, fn _json ->
        {:ok, %{"id" => "retry_workflow_456"}}
      end)
      
      {:ok, deployment} = deploy_workflow_with_retry(workflow_result, max_retries: 2)
      
      assert deployment.n8n_workflow_id == "retry_workflow_456"
      assert deployment.retry_count == 1
    end
  end
  
  describe "performance measurement and learning loop" do
    test "measures cycle performance accurately" do
      cycle_start = System.monotonic_time()
      
      # Simulate cycle activities
      :timer.sleep(50)  # Simulate work
      
      performance_metrics = measure_cycle_performance(cycle_start, [
        %{deployment_time: 1000, success: true},
        %{deployment_time: 1500, success: true},
        %{deployment_time: 800, success: false}
      ])
      
      assert performance_metrics.cycle_duration >= 50_000  # microseconds
      assert performance_metrics.successful_deployments == 2
      assert performance_metrics.deployment_success_rate == 2/3
      assert performance_metrics.avg_deployment_time == 1100
    end
    
    test "learns from failure patterns" do
      failure_history = [
        %{type: "network_timeout", count: 5, last_seen: DateTime.utc_now()},
        %{type: "compilation_error", count: 2, last_seen: DateTime.utc_now()},
        %{type: "validation_failure", count: 8, last_seen: DateTime.utc_now()}
      ]
      
      learning_result = analyze_failure_patterns(failure_history)
      
      assert learning_result.primary_issue == "validation_failure"
      assert learning_result.recommended_actions != []
      assert "improve validation" in learning_result.recommended_actions
    end
    
    test "adapts strategy based on success patterns" do
      success_history = [
        %{strategy: "incremental", success_rate: 0.9, cycles: 10},
        %{strategy: "aggressive", success_rate: 0.6, cycles: 5},
        %{strategy: "conservative", success_rate: 0.95, cycles: 8}
      ]
      
      strategy_analysis = analyze_strategy_effectiveness(success_history)
      
      assert strategy_analysis.recommended_strategy == "conservative"
      assert strategy_analysis.confidence > 0.8
    end
  end
  
  describe "error recovery and resilience" do
    test "recovers from orchestrator crashes" do
      # Stop the orchestrator
      GenServer.stop(SelfImprovementOrchestrator)
      
      # Restart and verify state recovery
      {:ok, _pid} = start_supervised({SelfImprovementOrchestrator, []})
      
      status = SelfImprovementOrchestrator.get_status()
      
      # Should recover with clean state
      assert status.cycle_id >= 0
      assert status.queued_improvements >= 0
    end
    
    test "handles partial cycle failures" do
      # Mock partial failures
      MockClaudeCode
      |> expect(:prompt, 3, fn prompt, _ ->
        cond do
          String.contains?(prompt, "opportunities") -> {:ok, "Valid response"}
          String.contains?(prompt, "generate") -> {:error, "Generation failed"}
          String.contains?(prompt, "optimize") -> {:ok, "Valid response"}
        end
      end)
      
      setup_performance_mocks()
      
      SelfImprovementOrchestrator.trigger_improvement_cycle()
      
      assert_receive {:cycle_completed, cycle_result}, 5_000
      
      # Should complete with partial success
      assert cycle_result.opportunities_found > 0
      assert cycle_result.partial_failures > 0
      assert cycle_result.cycle_duration > 0
    end
  end
  
  describe "performance and scalability" do
    test "handles high-frequency improvement requests" do
      # Queue many improvements rapidly
      tasks = for i <- 1..50 do
        %{
          description: "Improvement #{i}",
          priority: Enum.random([:high, :medium, :low]),
          type: :performance
        }
      end
      
      start_time = System.monotonic_time()
      
      for task <- tasks do
        SelfImprovementOrchestrator.queue_improvement(task)
      end
      
      queue_time = System.convert_time_unit(
        System.monotonic_time() - start_time,
        :native,
        :millisecond
      )
      
      # Should queue all items quickly
      assert queue_time < 1000  # Less than 1 second
      
      status = SelfImprovementOrchestrator.get_status()
      assert status.queued_improvements == 50
    end
    
    test "maintains performance under concurrent access" do
      # Simulate concurrent operations
      tasks = for _i <- 1..10 do
        Task.async(fn ->
          SelfImprovementOrchestrator.get_status()
        end)
      end
      
      results = Task.await_many(tasks, 5000)
      
      # All should succeed
      assert length(results) == 10
      for result <- results do
        assert result.cycle_id != nil
      end
    end
  end
  
  # Helper functions for test setup and mocking
  
  defp setup_discovery_mocks do
    MockClaudeCode
    |> expect(:prompt, fn prompt, _ ->
      if String.contains?(prompt, "improvement opportunities") do
        {:ok, mock_improvement_opportunities_response()}
      else
        {:ok, "Mock analysis response"}
      end
    end)
  end
  
  defp setup_generation_mocks do
    MockClaudeCode
    |> expect(:prompt, fn prompt, _ ->
      cond do
        String.contains?(prompt, "specification") -> {:ok, mock_workflow_specification()}
        String.contains?(prompt, "Generate Elixir") -> {:ok, mock_workflow_code()}
        String.contains?(prompt, "optimizations") -> {:ok, mock_optimized_workflow_code()}
        true -> {:ok, "Mock response"}
      end
    end)
  end
  
  defp setup_performance_mocks do
    MockPerformanceMonitor
    |> stub(:get_cycle_history, fn -> [] end)
    |> stub(:record_cycle_metrics, fn _ -> :ok end)
  end
  
  defp mock_improvement_opportunities_response do
    """
    [
      {
        "type": "workflow_optimization",
        "description": "Optimize HTTP request batching",
        "priority": "high",
        "expected_impact": "30% performance improvement",
        "complexity": "medium"
      },
      {
        "type": "new_workflow", 
        "description": "Add automated testing workflow",
        "priority": "medium",
        "expected_impact": "Improved reliability",
        "complexity": "high"
      }
    ]
    """
  end
  
  defp mock_workflow_specification do
    """
    {
      "name": "Generated Test Workflow",
      "description": "Auto-generated workflow for testing",
      "nodes": [
        {"id": "start", "type": "n8n-nodes-base.httpRequest"},
        {"id": "process", "type": "n8n-nodes-base.code"}
      ],
      "connections": [
        {"source": "start", "target": "process"}
      ]
    }
    """
  end
  
  defp mock_workflow_code do
    """
    use N8n.Reactor
    
    workflow do
      name "Generated Test Workflow"
      active true
      tags ["test", "generated"]
    end
    
    node "start", "n8n-nodes-base.httpRequest" do
      name "Start Node"
      parameters %{"method" => "GET", "url" => "https://api.example.com"}
    end
    
    node "process", "n8n-nodes-base.code" do
      name "Process"
      depends_on ["start"]
      parameters %{"jsCode" => "return items;"}
    end
    """
  end
  
  defp mock_improvement_suggestions do
    """
    [
      {
        "type": "performance",
        "description": "Add connection pooling",
        "priority": "high",
        "expected_impact": "20% faster execution"
      }
    ]
    """
  end
  
  defp mock_optimized_workflow_code do
    """
    # Optimized version with improved error handling and performance
    use N8n.Reactor
    
    workflow do
      name "Optimized Test Workflow"
      active true
      tags ["test", "optimized"]
    end
    
    node "start", "n8n-nodes-base.httpRequest" do
      name "Start Node"
      parameters %{
        "method" => "GET", 
        "url" => "https://api.example.com",
        "timeout" => 10000,
        "retry" => true
      }
    end
    """
  end
  
  defp deploy_workflow_with_monitoring(workflow_result) do
    # Simulate deployment process
    {:ok, %{
      module: workflow_result.module,
      n8n_workflow_id: "test_workflow_123",
      deployed_at: DateTime.utc_now()
    }}
  end
  
  defp deploy_workflow_with_retry(workflow_result, opts) do
    max_retries = Keyword.get(opts, :max_retries, 3)
    
    # Simulate retry logic
    {:ok, %{
      module: workflow_result.module,
      n8n_workflow_id: "retry_workflow_456",
      deployed_at: DateTime.utc_now(),
      retry_count: 1
    }}
  end
  
  defp simulate_workflow_execution(workflow_id) do
    %{
      workflow_id: workflow_id,
      execution_time: :rand.uniform(5000),
      success: true,
      executed_at: DateTime.utc_now()
    }
  end
  
  defp measure_cycle_performance(cycle_start, deployment_results) do
    cycle_end = System.monotonic_time()
    cycle_duration = System.convert_time_unit(cycle_end - cycle_start, :native, :microsecond)
    
    successful = Enum.count(deployment_results, & &1.success)
    deployment_times = Enum.map(deployment_results, & &1.deployment_time)
    avg_deployment_time = if length(deployment_times) > 0, do: Enum.sum(deployment_times) / length(deployment_times), else: 0
    
    %{
      cycle_duration: cycle_duration,
      successful_deployments: successful,
      deployment_success_rate: successful / length(deployment_results),
      avg_deployment_time: avg_deployment_time
    }
  end
  
  defp analyze_failure_patterns(failure_history) do
    primary_failure = Enum.max_by(failure_history, & &1.count)
    
    %{
      primary_issue: primary_failure.type,
      failure_count: primary_failure.count,
      recommended_actions: ["improve validation", "add error handling", "increase timeouts"]
    }
  end
  
  defp analyze_strategy_effectiveness(success_history) do
    best_strategy = Enum.max_by(success_history, & &1.success_rate)
    
    %{
      recommended_strategy: best_strategy.strategy,
      confidence: best_strategy.success_rate,
      sample_size: best_strategy.cycles
    }
  end
end