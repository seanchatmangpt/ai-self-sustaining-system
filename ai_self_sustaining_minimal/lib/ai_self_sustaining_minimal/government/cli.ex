defmodule AiSelfSustainingMinimal.Government.CLI do
  @moduledoc """
  Government-grade CLI interface for Claude Code operations.
  
  Simulates enterprise CLI patterns:
  - Security context flags
  - Plan/apply workflow
  - Audit trail generation
  - Compliance validation
  - Rollback capabilities
  """
  
  alias AiSelfSustainingMinimal.Government.ClaudeCodeGov
  
  def main(args) do
    case parse_args(args) do
      {:ok, command, opts} ->
        execute_command(command, opts)
      {:error, reason} ->
        print_usage()
        IO.puts("Error: #{reason}")
        System.halt(1)
    end
  end
  
  defp parse_args(args) do
    {parsed, remaining, _invalid} = OptionParser.parse(args,
      strict: [
        security_clearance: :string,
        data_classification: :string,
        environment: :string,
        dry_run: :boolean,
        audit_trail: :boolean,
        compliance_check: :boolean,
        force: :boolean,
        rollback_to: :string,
        help: :boolean
      ],
      aliases: [
        s: :security_clearance,
        c: :data_classification,
        e: :environment,
        d: :dry_run,
        h: :help
      ]
    )
    
    if parsed[:help] do
      print_usage()
      System.halt(0)
    end
    
    case remaining do
      [command | _] -> {:ok, command, parsed}
      [] -> {:error, "No command specified"}
    end
  end
  
  defp execute_command("fix-crash", opts) do
    IO.puts("🚀 Claude Code Government: Fix Crash Operation")
    
    operation = %{
      type: "fix_crash",
      target: opts[:file] || "crashed_file.ex",
      fixes: ["add_guard_clause", "handle_nil_case"],
      involves_pii: false,
      network_access: "restricted"
    }
    
    execute_with_government_controls(operation, opts)
  end
  
  defp execute_command("security-patch", opts) do
    IO.puts("🔒 Claude Code Government: Security Patch Operation")
    
    operation = %{
      type: "security_patch", 
      target: opts[:service] || "web_service",
      patch_level: "critical",
      involves_pii: true,
      network_access: "restricted",
      cloud_deployment: false
    }
    
    execute_with_government_controls(operation, opts)
  end
  
  defp execute_command("infrastructure-update", opts) do
    IO.puts("🏗️ Claude Code Government: Infrastructure Update")
    
    operation = %{
      type: "infrastructure_update",
      target: opts[:cluster] || "prod-cluster-east",
      changes: ["scale_replicas", "update_security_policies"],
      involves_pii: true,
      network_access: "restricted",
      cloud_deployment: true
    }
    
    execute_with_government_controls(operation, opts)
  end
  
  defp execute_command("rollback", opts) do
    if snapshot_id = opts[:rollback_to] do
      IO.puts("🔄 Claude Code Government: Rollback to #{snapshot_id}")
      simulate_rollback(snapshot_id, opts)
    else
      IO.puts("❌ Error: --rollback-to <snapshot_id> required")
      System.halt(1)
    end
  end
  
  defp execute_command(unknown, _opts) do
    IO.puts("❌ Unknown command: #{unknown}")
    print_usage()
    System.halt(1)
  end
  
  defp execute_with_government_controls(operation, opts) do
    # Add default government settings
    gov_opts = opts
    |> Keyword.put_new(:security_clearance, "confidential")
    |> Keyword.put_new(:data_classification, "cui") 
    |> Keyword.put_new(:environment, "prod")
    |> Keyword.put_new(:audit_trail, true)
    |> Keyword.put_new(:compliance_check, true)
    
    start_time = System.monotonic_time(:millisecond)
    
    # Execute with government controls
    result = ClaudeCodeGov.execute_with_government_controls(operation, gov_opts)
    
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time
    
    # Display results
    display_results(result, duration, gov_opts)
  end
  
  defp display_results({:plan_only, plan_result}, duration, opts) do
    IO.puts("\n📋 PLAN PHASE RESULTS (DRY RUN)")
    IO.puts("   Duration: #{duration}ms")
    IO.puts("   Security: #{opts[:security_clearance]} clearance, #{opts[:data_classification]} data")
    IO.puts("   Environment: #{opts[:environment]}")
    
    IO.puts("\n📊 PLANNED CHANGES:")
    if length(plan_result.diff) == 0 do
      IO.puts("   ✅ No changes required - system already in desired state")
    else
      Enum.each(plan_result.diff, fn change ->
        IO.puts("   📝 #{change.type}: #{change.from} → #{change.to}")
      end)
    end
    
    IO.puts("\n⚡ IMPACT ASSESSMENT:")
    IO.puts("   Actions Required: #{plan_result.actions_required}")
    IO.puts("   Estimated Duration: #{plan_result.estimated_duration}s")
    IO.puts("   Risk Level: #{plan_result.risk_assessment.level}")
    
    IO.puts("\n🔥 TO EXECUTE: Remove --dry-run flag and run again")
  end
  
  defp display_results({:executed, apply_result, audit_trail}, duration, opts) do
    IO.puts("\n✅ EXECUTION COMPLETED")
    IO.puts("   Duration: #{duration}ms")
    IO.puts("   Security: #{opts[:security_clearance]} clearance")
    IO.puts("   Environment: #{opts[:environment]}")
    
    IO.puts("\n📊 APPLIED CHANGES:")
    Enum.each(apply_result.changes_applied, fn change ->
      status = if change.success, do: "✅", else: "❌"
      IO.puts("   #{status} #{change.change.type} (#{change.duration_ms}ms)")
    end)
    
    if apply_result.success do
      IO.puts("\n🔒 ROLLBACK CAPABILITY:")
      IO.puts("   Snapshot ID: #{apply_result.rollback_snapshot.snapshot_id}")
      IO.puts("   Rollback Command: claude-code-gov rollback --rollback-to=#{apply_result.rollback_snapshot.snapshot_id}")
    end
    
    IO.puts("\n📂 AUDIT TRAIL:")
    IO.puts("   Audit ID: #{audit_trail.audit_id}")
    IO.puts("   Audit File: #{audit_trail.audit_file}")
    IO.puts("   Total Events: #{length(audit_trail.events)}")
    
    IO.puts("\n🔍 COMPLIANCE STATUS:")
    post_compliance = audit_trail.final_result.post_compliance
    IO.puts("   Security Scan: #{if post_compliance.security_scan.passed, do: "✅ PASSED", else: "❌ FAILED"}")
    IO.puts("   Performance Check: #{if post_compliance.performance_check.passed, do: "✅ PASSED", else: "❌ FAILED"}")
    IO.puts("   Data Integrity: #{if post_compliance.data_integrity.passed, do: "✅ PASSED", else: "❌ FAILED"}")
  end
  
  defp display_results({:compliance_failure, failures, audit_trail}, duration, opts) do
    IO.puts("\n❌ COMPLIANCE FAILURE - OPERATION ABORTED")
    IO.puts("   Duration: #{duration}ms")
    IO.puts("   Security: #{opts[:security_clearance]} clearance")
    IO.puts("   Environment: #{opts[:environment]}")
    
    IO.puts("\n🚨 COMPLIANCE VIOLATIONS:")
    Enum.each(failures, fn {framework, reason} ->
      IO.puts("   ❌ #{String.upcase(framework)}: #{reason}")
    end)
    
    IO.puts("\n📂 AUDIT TRAIL (Failure Recorded):")
    IO.puts("   Audit ID: #{audit_trail.audit_id}")
    IO.puts("   Audit File: #{audit_trail.audit_file}")
    
    IO.puts("\n🔧 RESOLUTION:")
    IO.puts("   1. Review compliance requirements")
    IO.puts("   2. Adjust security clearance or data classification")
    IO.puts("   3. Modify operation parameters")
    IO.puts("   4. Retry with --force flag (if authorized)")
    
    System.halt(1)
  end
  
  defp simulate_rollback(snapshot_id, opts) do
    IO.puts("🔄 INITIATING ROLLBACK OPERATION")
    IO.puts("   Snapshot: #{snapshot_id}")
    IO.puts("   Environment: #{opts[:environment] || "prod"}")
    
    # Simulate rollback process
    IO.puts("\n📋 ROLLBACK PLAN:")
    IO.puts("   1. Validate snapshot integrity")
    IO.puts("   2. Stop current services")  
    IO.puts("   3. Restore files from snapshot")
    IO.puts("   4. Restart services")
    IO.puts("   5. Validate system health")
    
    if opts[:dry_run] do
      IO.puts("\n🔥 DRY RUN: Add --apply to execute rollback")
    else
      IO.puts("\n⚡ EXECUTING ROLLBACK...")
      :timer.sleep(2000) # Simulate rollback time
      IO.puts("   ✅ Rollback completed successfully")
      IO.puts("   ✅ System restored to previous state")
      IO.puts("   ✅ All compliance checks passed")
    end
  end
  
  defp print_usage do
    IO.puts("""
    Claude Code Government CLI - Enterprise Operations

    USAGE:
      claude-code-gov <command> [options]

    COMMANDS:
      fix-crash              Fix application crash with audit trail
      security-patch         Apply security patches with compliance validation  
      infrastructure-update  Update infrastructure with rollback capability
      rollback              Rollback to previous snapshot

    OPTIONS:
      -s, --security-clearance <level>    Security clearance (unclassified|cui|confidential|secret|top-secret)
      -c, --data-classification <level>   Data classification level
      -e, --environment <env>             Target environment (dev|staging|prod)
      -d, --dry-run                       Plan only, do not execute
          --audit-trail                   Enable audit trail (default: true)
          --compliance-check              Enable compliance validation (default: true)
          --force                         Override compliance failures (requires authorization)
          --rollback-to <snapshot_id>     Rollback to specific snapshot
      -h, --help                          Show this help

    EXAMPLES:
      # Plan a crash fix in production
      claude-code-gov fix-crash --environment=prod --dry-run

      # Execute security patch with secret clearance
      claude-code-gov security-patch --security-clearance=secret --data-classification=confidential

      # Rollback infrastructure update
      claude-code-gov rollback --rollback-to=rollback_1750047123456789000

    COMPLIANCE:
      All operations are validated against FISMA, FedRAMP, SOC 2, and STIG requirements.
      Complete audit trails are generated for all operations.
      Rollback snapshots are automatically created before any changes.
    """)
  end
end