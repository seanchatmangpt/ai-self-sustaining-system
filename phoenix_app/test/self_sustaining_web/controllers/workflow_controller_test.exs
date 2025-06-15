defmodule SelfSustainingWeb.WorkflowControllerTest do
  @moduledoc """
  Tests for the workflow management API controller.
  """
  
  use SelfSustainingWeb.ConnCase, async: true
  
  describe "GET /api/workflows" do
    test "lists all workflows", %{conn: conn} do
      conn = get(conn, ~p"/api/workflows")
      
      assert %{
        "workflows" => workflows,
        "total_count" => total_count,
        "timestamp" => timestamp
      } = json_response(conn, 200)
      
      assert is_list(workflows)
      assert is_integer(total_count)
      assert is_binary(timestamp)
      assert total_count == length(workflows)
      
      # Each workflow should have required fields
      for workflow <- workflows do
        assert Map.has_key?(workflow, "name")
        assert Map.has_key?(workflow, "module")
        assert Map.has_key?(workflow, "active")
        assert Map.has_key?(workflow, "node_count")
        assert Map.has_key?(workflow, "tags")
      end
    end
  end
  
  describe "GET /api/workflows/stats" do
    test "returns workflow statistics", %{conn: conn} do
      conn = get(conn, ~p"/api/workflows/stats")
      
      assert %{
        "total_workflows" => total,
        "active_workflows" => active,
        "inactive_workflows" => inactive,
        "total_nodes" => nodes,
        "workflows_by_tag" => by_tag,
        "last_updated" => updated
      } = json_response(conn, 200)
      
      assert is_integer(total)
      assert is_integer(active)
      assert is_integer(inactive)
      assert is_integer(nodes)
      assert is_map(by_tag)
      assert is_binary(updated)
      
      # Sanity checks
      assert total == active + inactive
      assert total >= 0
      assert nodes >= 0
    end
  end
  
  describe "GET /api/workflows/:id" do
    test "returns workflow details for valid workflow", %{conn: conn} do
      workflow_id = "simple_workflow"
      conn = get(conn, ~p"/api/workflows/#{workflow_id}")
      
      assert %{"workflow" => workflow} = json_response(conn, 200)
      
      assert Map.has_key?(workflow, "name")
      assert Map.has_key?(workflow, "module")
      assert Map.has_key?(workflow, "active")
      assert Map.has_key?(workflow, "tags")
      assert Map.has_key?(workflow, "node_count")
      assert Map.has_key?(workflow, "nodes")
      assert Map.has_key?(workflow, "json_size")
      assert Map.has_key?(workflow, "compiled_at")
    end
    
    test "returns 404 for unknown workflow", %{conn: conn} do
      workflow_id = "nonexistent_workflow"
      conn = get(conn, ~p"/api/workflows/#{workflow_id}")
      
      assert %{"error" => error} = json_response(conn, 404)
      assert is_binary(error)
    end
  end
  
  describe "POST /api/workflows/:id/compile" do
    test "compiles workflow successfully", %{conn: conn} do
      workflow_id = "simple_workflow"
      conn = post(conn, ~p"/api/workflows/#{workflow_id}/compile")
      
      response = json_response(conn, 200)
      
      # Should return n8n workflow JSON
      assert Map.has_key?(response, "name")
      assert Map.has_key?(response, "nodes")
      assert Map.has_key?(response, "connections")
      assert Map.has_key?(response, "active")
      
      # Should be valid JSON structure
      assert is_list(response["nodes"])
      assert is_map(response["connections"])
    end
    
    test "returns error for invalid workflow", %{conn: conn} do
      workflow_id = "invalid_workflow"
      conn = post(conn, ~p"/api/workflows/#{workflow_id}/compile")
      
      assert %{
        "error" => "Compilation failed",
        "reason" => reason
      } = json_response(conn, 422)
      
      assert is_binary(reason)
    end
    
    test "returns 404 for unknown workflow", %{conn: conn} do
      workflow_id = "nonexistent_workflow"
      conn = post(conn, ~p"/api/workflows/#{workflow_id}/compile")
      
      assert %{"error" => error} = json_response(conn, 404)
      assert is_binary(error)
    end
  end
  
  describe "POST /api/workflows/:id/validate" do
    test "validates workflow successfully", %{conn: conn} do
      workflow_id = "simple_workflow"
      conn = post(conn, ~p"/api/workflows/#{workflow_id}/validate")
      
      assert %{
        "valid" => true,
        "workflow_id" => ^workflow_id,
        "message" => message
      } = json_response(conn, 200)
      
      assert is_binary(message)
    end
    
    test "returns validation errors for invalid workflow", %{conn: conn} do
      workflow_id = "meaningful_error_workflow"
      conn = post(conn, ~p"/api/workflows/#{workflow_id}/validate")
      
      assert %{
        "valid" => false,
        "workflow_id" => ^workflow_id,
        "error" => error
      } = json_response(conn, 422)
      
      assert is_binary(error)
    end
  end
  
  describe "POST /api/workflows/:id/export" do
    test "exports workflow successfully", %{conn: conn} do
      workflow_id = "export_test_workflow"
      conn = post(conn, ~p"/api/workflows/#{workflow_id}/export")
      
      assert %{
        "exported" => true,
        "workflow_id" => ^workflow_id,
        "file_path" => file_path,
        "message" => message
      } = json_response(conn, 200)
      
      assert is_binary(file_path)
      assert is_binary(message)
      assert String.ends_with?(file_path, ".json")
    end
    
    test "returns error for invalid workflow", %{conn: conn} do
      workflow_id = "invalid_workflow"
      conn = post(conn, ~p"/api/workflows/#{workflow_id}/export")
      
      assert %{
        "error" => "Export failed",
        "reason" => reason
      } = json_response(conn, 422)
      
      assert is_binary(reason)
    end
  end
  
  describe "POST /api/workflows/:id/import_to_n8n" do
    test "handles n8n import request", %{conn: conn} do
      workflow_id = "simple_workflow"
      
      # Mock n8n configuration
      conn = post(conn, ~p"/api/workflows/#{workflow_id}/import_to_n8n", %{
        "n8n_endpoint" => "http://localhost:5678",
        "n8n_api_key" => "test_key",
        "timeout" => "30000"
      })
      
      # Should attempt the import (may fail due to no actual n8n server)
      response = json_response(conn, 422)
      
      assert %{
        "error" => "Import to n8n failed",
        "reason" => reason
      } = response
      
      assert is_binary(reason)
      # Should mention network/connection issue since n8n isn't running
      assert reason =~ ~r/connection|network|request/i
    end
    
    test "handles missing n8n configuration", %{conn: conn} do
      workflow_id = "simple_workflow"
      conn = post(conn, ~p"/api/workflows/#{workflow_id}/import_to_n8n")
      
      # Should still attempt import with default config
      response = json_response(conn, 422)
      
      assert %{
        "error" => "Import to n8n failed",
        "reason" => _reason
      } = response
    end
  end
  
  describe "POST /api/workflows/compile_all" do
    test "compiles all workflows", %{conn: conn} do
      conn = post(conn, ~p"/api/workflows/compile_all")
      
      assert %{
        "compiled" => true,
        "total_workflows" => total,
        "successful" => successful,
        "failed" => failed,
        "results" => results,
        "message" => message
      } = json_response(conn, 200)
      
      assert is_integer(total)
      assert is_integer(successful)
      assert is_integer(failed)
      assert is_list(results)
      assert is_binary(message)
      
      assert total == successful + failed
      assert length(results) == total
      
      # Each result should have proper structure
      for result <- results do
        assert Map.has_key?(result, "status")
        assert Map.has_key?(result, "module")
        
        case result["status"] do
          "success" ->
            assert Map.has_key?(result, "file_path")
            assert is_binary(result["file_path"])
          
          "error" ->
            assert Map.has_key?(result, "reason")
            assert is_binary(result["reason"])
        end
      end
    end
  end
  
  describe "POST /api/workflows/validate_all" do
    test "validates all workflows", %{conn: conn} do
      conn = post(conn, ~p"/api/workflows/validate_all")
      
      response = json_response(conn, :ok)
      
      case response do
        %{"valid" => true, "message" => message} ->
          assert is_binary(message)
          assert message =~ "valid"
        
        %{"valid" => false, "message" => message} ->
          assert is_binary(message)
          assert message =~ "error"
      end
    end
  end
  
  describe "parameter validation" do
    test "handles invalid workflow IDs gracefully", %{conn: conn} do
      invalid_ids = ["", "  ", "invalid/id", "id with spaces", "very-very-long-workflow-id-that-should-not-exist"]
      
      for invalid_id <- invalid_ids do
        conn = get(conn, ~p"/api/workflows/#{invalid_id}")
        
        assert %{"error" => error} = json_response(conn, 404)
        assert is_binary(error)
      end
    end
    
    test "validates timeout parameter for n8n import", %{conn: conn} do
      workflow_id = "simple_workflow"
      
      # Valid timeout
      conn = post(conn, ~p"/api/workflows/#{workflow_id}/import_to_n8n", %{
        "timeout" => "60000"
      })
      
      # Should process the request (may fail due to no n8n server)
      response = json_response(conn, 422)
      assert Map.has_key?(response, "error")
      
      # Invalid timeout should be ignored
      conn = post(conn, ~p"/api/workflows/#{workflow_id}/import_to_n8n", %{
        "timeout" => "invalid"
      })
      
      # Should still process with default timeout
      response = json_response(conn, 422)
      assert Map.has_key?(response, "error")
    end
  end
  
  describe "error handling" do
    test "returns proper HTTP status codes", %{conn: conn} do
      # 404 for not found
      conn = get(conn, ~p"/api/workflows/nonexistent")
      assert response(conn, 404)
      
      # 422 for validation errors
      conn = post(conn, ~p"/api/workflows/invalid_workflow/compile")
      assert response(conn, 422)
    end
    
    test "returns consistent error response format", %{conn: conn} do
      # Test various error scenarios
      error_requests = [
        {"/api/workflows/nonexistent", :get},
        {"/api/workflows/invalid_workflow/compile", :post},
        {"/api/workflows/meaningful_error_workflow/validate", :post}
      ]
      
      for {path, method} <- error_requests do
        conn = 
          case method do
            :get -> get(conn, path)
            :post -> post(conn, path)
          end
        
        response_body = json_response(conn, :unprocessable_entity)
        
        # Should have error field
        assert Map.has_key?(response_body, "error")
        assert is_binary(response_body["error"])
        
        # May have additional context
        if Map.has_key?(response_body, "reason") do
          assert is_binary(response_body["reason"])
        end
      end
    end
  end
  
  describe "response headers" do
    test "sets correct content type for JSON responses", %{conn: conn} do
      conn = get(conn, ~p"/api/workflows")
      
      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    end
    
    test "sets content disposition for workflow compilation", %{conn: conn} do
      workflow_id = "simple_workflow"
      conn = post(conn, ~p"/api/workflows/#{workflow_id}/compile")
      
      content_disposition = get_resp_header(conn, "content-disposition")
      
      if content_disposition != [] do
        assert List.first(content_disposition) =~ "attachment"
        assert List.first(content_disposition) =~ "#{workflow_id}.json"
      end
    end
  end
end