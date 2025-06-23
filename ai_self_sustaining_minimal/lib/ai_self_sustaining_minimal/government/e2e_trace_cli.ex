defmodule AiSelfSustainingMinimal.Government.E2ETraceCli do
  @moduledoc """
  End-to-end OpenTelemetry instrumented government CLI for trace validation.
  
  This module creates real OpenTelemetry spans and validates trace ID propagation
  through government operations.
  """
  
  require OpenTelemetry.Tracer, as: Tracer
  require Logger
  
  @trace_validation_service "government-claude-code-e2e"
  
  def execute_government_operation(operation_type, opts \\ []) do
    # Start the root span for government operation using proper API
    span_name = "government.operation.#{operation_type}"
    
    ctx = :otel_ctx.new()
    span_ctx = :otel_tracer.start_span(ctx, span_name, %{})
    trace_id = get_trace_id_from_span_ctx(span_ctx)
    
    # Set as current span context
    :otel_ctx.attach(ctx)
    
    Logger.info("🔍 E2E Government Operation Started", trace_id: trace_id, operation: operation_type)
    
    try do
      # Set government-specific attributes
      :otel_span.set_attributes(span_ctx, [
        {"government.operation.type", operation_type},
        {"government.security.clearance", opts[:security_clearance] || "unclassified"},
        {"government.data.classification", opts[:data_classification] || "unclassified"},
        {"government.environment", opts[:environment] || "e2e-test"},
        {"government.compliance.frameworks", "fisma,fedramp,soc2,stig"},
        {"government.audit.required", true},
        {"government.trace.validation", true}
      ])
      
      :otel_span.add_event(span_ctx, "government.operation.started", %{
        "operation_type" => operation_type,
        "trace_id" => trace_id
      })
      
      try do
        # Execute security validation
        security_result = execute_security_validation(opts)
        
        case security_result do
          {:granted, context} ->
            Logger.info("🔐 Security Authorized", trace_id: trace_id, context: context)
            
            # Execute compliance validation
            compliance_result = execute_compliance_validation(operation_type)
            
            if compliance_result == :passed do
              Logger.info("✅ Compliance Validated", trace_id: trace_id)
              
              # Execute operation phases based on type
              if opts[:dry_run] do
                result = execute_plan_phase(operation_type, opts)
                Logger.info("📋 Plan Phase Completed", trace_id: trace_id, result: result)
              else
                plan_result = execute_plan_phase(operation_type, opts)
                apply_result = execute_apply_phase(operation_type, opts)
                audit_result = execute_audit_phase(operation_type, opts)
                
                Logger.info("🚀 Full Operation Completed", 
                  trace_id: trace_id, 
                  plan: plan_result, 
                  apply: apply_result, 
                  audit: audit_result
                )
              end
              
              Tracer.add_event("government.operation.completed", %{
                "result" => "success",
                "trace_id" => trace_id
              })
              
              {:success, trace_id}
            else
              Logger.warning("❌ Compliance Failed", trace_id: trace_id)
              Tracer.add_event("government.operation.failed", %{
                "reason" => "compliance_failure",
                "trace_id" => trace_id
              })
              
              {:error, trace_id, "compliance_failure"}
            end
            
          {:denied, reason} ->
            Logger.warning("🚫 Security Denied", trace_id: trace_id, reason: reason)
            Tracer.add_event("government.operation.failed", %{
              "reason" => "security_denied: #{reason}",
              "trace_id" => trace_id
            })
            
            {:error, trace_id, "security_denied"}
        end
      rescue
        error ->
          Logger.error("💥 Operation Failed", trace_id: trace_id, error: inspect(error))
          Tracer.add_event("government.operation.error", %{
            "error" => inspect(error),
            "trace_id" => trace_id
          })
          
          {:error, trace_id, "operation_error"}
      end
    end
  end
  
  defp execute_security_validation(opts) do
    Tracer.with_span "government.security.validation" do
      trace_id = get_current_trace_id()
      
      Tracer.set_attributes([
        {"security.clearance.provided", opts[:security_clearance] || "unclassified"},
        {"security.classification.required", opts[:data_classification] || "unclassified"}
      ])
      
      clearance_level = get_security_level(opts[:security_clearance] || "unclassified")
      required_level = get_security_level(opts[:data_classification] || "unclassified")
      
      if clearance_level >= required_level do
        Tracer.add_event("security.authorization.granted", %{
          "clearance" => opts[:security_clearance],
          "classification" => opts[:data_classification],
          "trace_id" => trace_id
        })
        
        {:granted, %{clearance: opts[:security_clearance], classification: opts[:data_classification]}}
      else
        Tracer.add_event("security.authorization.denied", %{
          "clearance" => opts[:security_clearance],
          "classification" => opts[:data_classification],
          "reason" => "insufficient_clearance",
          "trace_id" => trace_id
        })
        
        {:denied, "insufficient_clearance"}
      end
    end
  end
  
  defp execute_compliance_validation(operation_type) do
    Tracer.with_span "government.compliance.validation" do
      trace_id = get_current_trace_id()
      
      frameworks = ["fisma", "fedramp", "soc2", "stig"]
      
      Tracer.set_attributes([
        {"compliance.frameworks", Enum.join(frameworks, ",")},
        {"compliance.operation_type", operation_type}
      ])
      
      # Validate each framework in child spans
      framework_results = Enum.map(frameworks, fn framework ->
        Tracer.with_span "government.compliance.framework.#{framework}" do
          Tracer.set_attributes([
            {"compliance.framework", framework},
            {"compliance.operation_type", operation_type}
          ])
          
          # Simulate framework validation
          result = if :rand.uniform() > 0.1, do: :passed, else: :failed
          
          Tracer.add_event("compliance.framework.validated", %{
            "framework" => framework,
            "result" => Atom.to_string(result),
            "trace_id" => trace_id
          })
          
          result
        end
      end)
      
      overall_result = if Enum.all?(framework_results, &(&1 == :passed)), do: :passed, else: :failed
      
      Tracer.add_event("compliance.all_frameworks.validated", %{
        "result" => Atom.to_string(overall_result),
        "frameworks_passed" => Enum.count(framework_results, &(&1 == :passed)),
        "frameworks_total" => length(framework_results),
        "trace_id" => trace_id
      })
      
      overall_result
    end
  end
  
  defp execute_plan_phase(operation_type, opts) do
    Tracer.with_span "government.plan.phase" do
      trace_id = get_current_trace_id()
      
      Tracer.set_attributes([
        {"plan.operation_type", operation_type},
        {"plan.environment", opts[:environment] || "e2e-test"}
      ])
      
      # Simulate plan calculations
      Process.sleep(50)
      
      Tracer.add_event("plan.calculations.completed", %{
        "operation_type" => operation_type,
        "trace_id" => trace_id
      })
      
      :plan_completed
    end
  end
  
  defp execute_apply_phase(operation_type, _opts) do
    Tracer.with_span "government.apply.phase" do
      trace_id = get_current_trace_id()
      
      Tracer.set_attributes([
        {"apply.operation_type", operation_type}
      ])
      
      # Create rollback snapshot
      Tracer.with_span "government.rollback.snapshot" do
        Tracer.add_event("rollback.snapshot.created", %{
          "snapshot_id" => "snap_#{System.system_time(:millisecond)}",
          "trace_id" => trace_id
        })
      end
      
      # Apply changes
      Tracer.with_span "government.changes.application" do
        Process.sleep(100)
        
        Tracer.add_event("changes.applied.successfully", %{
          "operation_type" => operation_type,
          "trace_id" => trace_id
        })
      end
      
      Tracer.add_event("apply.phase.completed", %{
        "operation_type" => operation_type,
        "trace_id" => trace_id
      })
      
      :apply_completed
    end
  end
  
  defp execute_audit_phase(operation_type, _opts) do
    Tracer.with_span "government.audit.finalization" do
      trace_id = get_current_trace_id()
      
      Tracer.set_attributes([
        {"audit.operation_type", operation_type}
      ])
      
      # Generate audit trail
      Process.sleep(25)
      
      Tracer.add_event("audit.trail.finalized", %{
        "operation_type" => operation_type,
        "audit_id" => "audit_#{System.system_time(:millisecond)}",
        "trace_id" => trace_id
      })
      
      :audit_completed
    end
  end
  
  defp get_current_trace_id() do
    case :otel_tracer.current_span_ctx() do
      :undefined -> 
        "no_trace"
      span_ctx ->
        span_ctx
        |> :otel_span.trace_id()
        |> Integer.to_string(16)
        |> String.downcase()
        |> String.pad_leading(32, "0")
    end
  end
  
  defp get_security_level(clearance) do
    case clearance do
      "unclassified" -> 1
      "cui" -> 2
      "confidential" -> 3
      "secret" -> 4
      "top-secret" -> 5
      _ -> 1
    end
  end
end
