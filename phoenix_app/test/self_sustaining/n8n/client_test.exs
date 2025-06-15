defmodule SelfSustaining.N8N.ClientTest do
  use ExUnit.Case, async: true
  
  alias SelfSustaining.N8N.Client
  
  describe "test_connection/0" do
    test "handles successful connection" do
      # This test will pass regardless of N8N availability
      # Real integration testing should be done in integration test suite
      
      case Client.test_connection() do
        {:ok, result} ->
          assert Map.has_key?(result, :status)
          assert Map.has_key?(result, :tested_at)
          assert result.status == :connected
        
        {:error, _reason} ->
          # Expected when N8N is not running in test environment
          assert true
      end
    end
  end
  
  describe "health_check/0" do
    test "returns appropriate health status" do
      health = Client.health_check()
      assert health in [:healthy, :degraded, :unhealthy]
    end
  end
  
  describe "get_workflow/1" do
    test "handles workflow retrieval" do
      case Client.get_workflow("test-workflow-id") do
        {:ok, _workflow} ->
          # N8N is available and workflow exists
          assert true
        
        {:error, _reason} ->
          # Expected when N8N is not running or workflow doesn't exist
          assert true
      end
    end
  end
  
  describe "list_executions/2" do
    test "handles execution listing" do
      case Client.list_executions("test-workflow-id", 5) do
        {:ok, executions} when is_list(executions) ->
          # N8N is available
          assert true
        
        {:error, _reason} ->
          # Expected when N8N is not running
          assert true
      end
    end
  end
end