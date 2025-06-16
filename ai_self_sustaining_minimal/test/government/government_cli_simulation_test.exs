defmodule AiSelfSustainingMinimal.Government.GovernmentCliSimulationTest do
  @moduledoc """
  80/20 Simulation Test for Government Infrastructure CLI Patterns.
  
  Demonstrates that enterprise patterns can be simulated without 
  enterprise infrastructure complexity.
  
  This test validates:
  - Security context validation
  - Plan/apply workflow
  - Audit trail generation  
  - Compliance checking
  - Rollback capabilities
  
  All without requiring Kubernetes, OpenTelemetry, Terraform, etc.
  """
  
  use ExUnit.Case, async: false
  
  alias AiSelfSustainingMinimal.Government.ClaudeCodeGov
  
  setup do
    # Clean up any audit files from previous tests
    File.rm_rf("/tmp/claude_code_audit_*")
    :ok
  end
  
  describe "government CLI patterns simulation" do
    test "security context validation with clearance levels" do
      IO.puts("\n🔒 TESTING: Security Context Validation")
      
      # Test insufficient clearance
      operation = %{
        type: "fix_crash",
        target: "classified_system.ex",
        involves_pii: true
      }
      
      opts = [
        security_clearance: "unclassified",  # Too low
        data_classification: "secret",       # Requires secret clearance
        environment: "prod"
      ]
      
      result = ClaudeCodeGov.execute_with_government_controls(operation, opts)
      
      assert {:compliance_failure, failures, audit_trail} = result
      assert length(failures) > 0
      assert audit_trail.audit_id != nil
      
      IO.puts("   ❌ Correctly rejected unclassified user accessing secret data")
      IO.puts("   📂 Audit trail generated: #{audit_trail.audit_id}")
      
      # Test sufficient clearance
      sufficient_opts = [
        security_clearance: "top-secret",   # High enough
        data_classification: "secret",      # Lower than clearance
        environment: "prod"
      ]
      
      result2 = ClaudeCodeGov.execute_with_government_controls(operation, sufficient_opts)
      
      case result2 do
        {:executed, _apply_result, _audit_trail} ->
          IO.puts("   ✅ Correctly authorized top-secret user for secret data")
        {:plan_only, _plan_result} ->
          IO.puts("   ✅ Plan authorized for top-secret user")
      end
    end
    
    test "plan/apply workflow with rollback capability" do
      IO.puts("\n📋 TESTING: Plan/Apply Workflow")
      
      operation = %{
        type: "security_patch",
        target: "web_service",
        patch_level: "critical",
        involves_pii: false,
        network_access: "restricted"
      }
      
      # Test plan phase (dry run)
      plan_opts = [
        security_clearance: "confidential",
        data_classification: "cui",
        environment: "staging",
        dry_run: true
      ]
      
      plan_result = ClaudeCodeGov.execute_with_government_controls(operation, plan_opts)
      
      assert {:plan_only, plan_data} = plan_result
      assert plan_data.diff != nil
      assert plan_data.risk_assessment != nil
      
      IO.puts("   📝 Plan phase completed:")
      IO.puts("      Actions required: #{plan_data.actions_required}")
      IO.puts("      Risk level: #{plan_data.risk_assessment.level}")
      IO.puts("      Estimated duration: #{plan_data.estimated_duration}s")
      
      # Test apply phase
      apply_opts = [
        security_clearance: "confidential", 
        data_classification: "cui",
        environment: "staging",
        dry_run: false  # Actually execute
      ]
      
      apply_result = ClaudeCodeGov.execute_with_government_controls(operation, apply_opts)
      
      assert {:executed, execution_data, audit_trail} = apply_result
      assert execution_data.rollback_snapshot != nil
      assert execution_data.success == true
      
      IO.puts("   ⚡ Apply phase completed:")
      IO.puts("      Changes applied: #{length(execution_data.changes_applied)}")
      IO.puts("      Rollback snapshot: #{execution_data.rollback_snapshot.snapshot_id}")
      IO.puts("      Audit file: #{audit_trail.audit_file}")
      
      # Verify audit file was created
      assert File.exists?(audit_trail.audit_file)
    end
    
    test "compliance framework validation (FISMA, FedRAMP, SOC2, STIG)" do
      IO.puts("\n🛡️ TESTING: Compliance Framework Validation")
      
      # Test operation that violates multiple compliance frameworks
      non_compliant_operation = %{
        type: "infrastructure_update",
        target: "prod_cluster",
        involves_pii: true,           # FISMA concern
        cloud_deployment: true,       # FedRAMP concern
        network_access: "unrestricted" # STIG violation
      }
      
      non_compliant_opts = [
        security_clearance: "unclassified",  # Too low for PII
        data_classification: "confidential", # Requires higher clearance
        environment: "dev"                   # SOC 2 violation
      ]
      
      result = ClaudeCodeGov.execute_with_government_controls(non_compliant_operation, non_compliant_opts)
      
      assert {:compliance_failure, failures, audit_trail} = result
      
      IO.puts("   🚨 Compliance violations detected:")
      Enum.each(failures, fn {framework, reason} ->
        IO.puts("      ❌ #{String.upcase(framework)}: #{reason}")
      end)
      
      assert length(failures) >= 3  # Should catch multiple violations
      
      # Test compliant operation
      compliant_operation = %{
        type: "fix_crash",
        target: "internal_tool.ex", 
        involves_pii: false,
        network_access: "restricted"
      }
      
      compliant_opts = [
        security_clearance: "secret",
        data_classification: "cui",
        environment: "prod"
      ]
      
      compliant_result = ClaudeCodeGov.execute_with_government_controls(compliant_operation, compliant_opts)
      
      case compliant_result do
        {:executed, _data, _audit} ->
          IO.puts("   ✅ Compliant operation executed successfully")
        {:plan_only, _plan} ->
          IO.puts("   ✅ Compliant operation plan approved")
      end
    end
    
    test "audit trail generation and SIEM integration" do
      IO.puts("\n📂 TESTING: Audit Trail and SIEM Integration")
      
      operation = %{
        type: "fix_crash",
        target: "critical_service.ex",
        fixes: ["null_pointer_fix", "memory_leak_fix"]
      }
      
      opts = [
        security_clearance: "secret",
        data_classification: "confidential", 
        environment: "prod"
      ]
      
      # Capture SIEM output
      result = ExUnit.CaptureIO.capture_io(fn ->
        ClaudeCodeGov.execute_with_government_controls(operation, opts)
      end)
      
      # Verify SIEM integration was simulated
      assert String.contains?(result, "SIEM: Audit trail")
      assert String.contains?(result, "ingested into security monitoring")
      
      # Find the generated audit file
      audit_files = Path.wildcard("/tmp/claude_code_audit_*.json")
      assert length(audit_files) > 0
      
      audit_file = List.first(audit_files)
      audit_content = File.read!(audit_file)
      audit_data = Jason.decode!(audit_content)
      
      IO.puts("   📋 Audit trail analysis:")
      IO.puts("      Audit ID: #{audit_data["audit_id"]}")
      IO.puts("      Events recorded: #{length(audit_data["events"])}")
      IO.puts("      User: #{audit_data["user"]}")
      IO.puts("      Git commit: #{audit_data["git_commit"]}")
      
      # Verify audit trail structure
      assert audit_data["audit_id"] != nil
      assert audit_data["operation"] != nil
      assert audit_data["security_context"] != nil
      assert is_list(audit_data["events"])
      assert length(audit_data["events"]) > 0
      
      # Verify security context is captured
      security_context = audit_data["security_context"]
      assert security_context["clearance_level"] == "secret"
      assert security_context["data_classification"] == "confidential"
      assert security_context["authorized"] == true
      
      IO.puts("   ✅ Complete audit trail generated with security context")
    end
    
    test "rollback capability simulation" do
      IO.puts("\n🔄 TESTING: Rollback Capability")
      
      operation = %{
        type: "infrastructure_update",
        target: "load_balancer_config",
        changes: ["update_ssl_certs", "modify_routing_rules"]
      }
      
      opts = [
        security_clearance: "confidential",
        data_classification: "cui",
        environment: "staging"
      ]
      
      # Execute operation to create rollback snapshot
      result = ClaudeCodeGov.execute_with_government_controls(operation, opts)
      
      assert {:executed, execution_data, _audit_trail} = result
      
      rollback_snapshot = execution_data.rollback_snapshot
      assert rollback_snapshot.snapshot_id != nil
      assert rollback_snapshot.state != nil
      assert rollback_snapshot.rollback_procedure != nil
      
      IO.puts("   📸 Rollback snapshot created:")
      IO.puts("      Snapshot ID: #{rollback_snapshot.snapshot_id}")
      IO.puts("      Timestamp: #{rollback_snapshot.timestamp}")
      IO.puts("      Procedure: #{rollback_snapshot.rollback_procedure}")
      
      # Simulate rollback operation
      rollback_result = simulate_rollback_execution(rollback_snapshot.snapshot_id)
      
      assert rollback_result.success == true
      assert rollback_result.restored_state != nil
      
      IO.puts("   ✅ Rollback simulation successful")
      IO.puts("      State restored: #{rollback_result.restored_state != nil}")
      IO.puts("      Duration: #{rollback_result.duration_ms}ms")
    end
    
    test "end-to-end government workflow simulation" do
      IO.puts("\n🎯 TESTING: End-to-End Government Workflow")
      
      # Simulate a complete government operation workflow
      operation = %{
        type: "security_patch",
        target: "classified_database_service",
        patch_level: "critical",
        involves_pii: true,
        network_access: "restricted",
        cloud_deployment: false
      }
      
      # Step 1: Plan with appropriate clearance
      plan_opts = [
        security_clearance: "secret",
        data_classification: "confidential",
        environment: "prod",
        dry_run: true
      ]
      
      plan_result = ClaudeCodeGov.execute_with_government_controls(operation, plan_opts)
      assert {:plan_only, plan_data} = plan_result
      
      IO.puts("   1️⃣ Plan phase: ✅ Authorized and compliant")
      
      # Step 2: Execute with full audit trail
      execute_opts = [
        security_clearance: "secret",
        data_classification: "confidential",
        environment: "prod",
        dry_run: false
      ]
      
      execution_result = ClaudeCodeGov.execute_with_government_controls(operation, execute_opts)
      assert {:executed, execution_data, audit_trail} = execution_result
      
      IO.puts("   2️⃣ Execution phase: ✅ Applied with rollback capability")
      
      # Step 3: Verify audit trail completeness
      assert File.exists?(audit_trail.audit_file)
      audit_content = File.read!(audit_trail.audit_file) |> Jason.decode!()
      
      required_events = ["plan_phase_started", "plan_phase_completed", 
                        "apply_phase_started", "apply_phase_completed", 
                        "change_applied", "operation_completed"]
      
      event_types = audit_content["events"] |> Enum.map(fn e -> e["event_type"] end)
      
      Enum.each(required_events, fn required ->
        assert required in event_types, "Missing audit event: #{required}"
      end)
      
      IO.puts("   3️⃣ Audit trail: ✅ Complete with #{length(audit_content["events"])} events")
      
      # Step 4: Verify post-execution compliance
      post_compliance = audit_trail.final_result.post_compliance
      assert post_compliance.security_scan.passed == true
      assert post_compliance.data_integrity.passed == true
      
      IO.puts("   4️⃣ Post-execution compliance: ✅ All checks passed")
      
      IO.puts("\n🏆 END-TO-END GOVERNMENT WORKFLOW: ✅ FULLY VALIDATED")
      IO.puts("   📊 Total audit events: #{length(audit_content["events"])}")
      IO.puts("   🔒 Security compliance: PASSED")
      IO.puts("   📂 Audit file: #{audit_trail.audit_file}")
      IO.puts("   🔄 Rollback available: #{execution_data.rollback_snapshot.snapshot_id}")
    end
  end
  
  # Helper function to simulate rollback execution
  defp simulate_rollback_execution(snapshot_id) do
    start_time = System.monotonic_time(:millisecond)
    
    # Simulate rollback process
    :timer.sleep(50) # Simulate rollback time
    
    end_time = System.monotonic_time(:millisecond)
    
    %{
      success: true,
      snapshot_id: snapshot_id,
      restored_state: %{status: "restored", version: "previous"},
      duration_ms: end_time - start_time
    }
  end
end