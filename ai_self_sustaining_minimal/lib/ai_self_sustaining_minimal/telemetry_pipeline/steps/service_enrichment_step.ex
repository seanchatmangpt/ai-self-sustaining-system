defmodule AiSelfSustainingMinimal.TelemetryPipeline.Steps.ServiceEnrichmentStep do
  @moduledoc """
  Enriches telemetry data with service-level metadata.
  Adds service discovery info, deployment details, and operational context.
  """
  
  use Reactor.Step
  require Logger
  
  @impl Reactor.Step
  def run(arguments, context, _options) do
    parsed_data = Map.get(arguments, :parsed_data)
    config = Map.get(arguments, :config, %{})
    
    start_time = System.monotonic_time()
    trace_id = Map.get(parsed_data, :trace_id)
    
    # Emit enrichment start telemetry
    :telemetry.execute([:otlp_pipeline, :service_enrichment, :start], %{
      traces_count: get_in(parsed_data, [:parsing_stats, :traces_count]) || 0,
      timestamp: System.system_time(:microsecond)
    }, %{context: context, trace_id: trace_id})
    
    try do
      # Extract service information from parsed data
      service_info = extract_service_information(parsed_data)
      
      # Enrich with service discovery data
      enriched_services = enrich_with_service_discovery(service_info, config)
      
      # Add deployment metadata
      deployment_info = add_deployment_metadata(enriched_services, config)
      
      # Add operational context
      operational_context = add_operational_context(deployment_info, config)
      
      processing_time = System.monotonic_time() - start_time
      
      result = %{
        service_enrichment: operational_context,
        enrichment_stats: %{
          services_enriched: map_size(operational_context),
          processing_time_ms: System.convert_time_unit(processing_time, :native, :millisecond),
          enrichment_fields_added: count_enrichment_fields(operational_context)
        },
        original_data: parsed_data,
        trace_id: trace_id,
        timestamp: DateTime.utc_now()
      }
      
      # Emit success telemetry
      :telemetry.execute([:otlp_pipeline, :service_enrichment, :success], %{
        services_enriched: result.enrichment_stats.services_enriched,
        processing_time_ms: result.enrichment_stats.processing_time_ms,
        fields_added: result.enrichment_stats.enrichment_fields_added
      }, %{context: context, trace_id: trace_id})
      
      Logger.debug("Service enrichment completed: #{result.enrichment_stats.services_enriched} services enriched")
      
      {:ok, result}
      
    rescue
      error ->
        processing_time = System.monotonic_time() - start_time
        
        error_details = %{
          error: Exception.message(error),
          processing_time_ms: System.convert_time_unit(processing_time, :native, :millisecond),
          stage: "service_enrichment"
        }
        
        # Emit error telemetry
        :telemetry.execute([:otlp_pipeline, :service_enrichment, :error], %{
          processing_time_ms: error_details.processing_time_ms
        }, %{context: context, error: error_details, trace_id: trace_id})
        
        Logger.error("Service enrichment failed: #{inspect(error)}")
        
        {:error, error_details}
    end
  end
  
  @impl Reactor.Step
  def undo(_result, _arguments, _context, _options) do
    # No specific cleanup needed for enrichment
    :ok
  end
  
  # Private enrichment functions
  
  defp extract_service_information(parsed_data) do
    # Extract from traces
    trace_services = 
      parsed_data
      |> Map.get(:traces, %{})
      |> Map.get(:traces, [])
      |> Enum.flat_map(&Map.get(&1, :services, []))
      |> Enum.uniq()
    
    # Extract from metrics
    metric_services = extract_services_from_metrics(parsed_data)
    
    # Extract from logs
    log_services = extract_services_from_logs(parsed_data)
    
    # Combine all discovered services
    all_services = (trace_services ++ metric_services ++ log_services) |> Enum.uniq()
    
    # Build service map
    all_services
    |> Enum.map(&{&1, %{name: &1, discovered_from: determine_discovery_source(&1, parsed_data)}})
    |> Enum.into(%{})
  end
  
  defp extract_services_from_metrics(parsed_data) do
    parsed_data
    |> Map.get(:metrics, %{})
    |> Map.get(:metrics, %{})
    |> Enum.flat_map(fn {_metric_name, metric_list} ->
      metric_list
      |> Enum.map(&extract_service_from_resource(&1))
      |> Enum.reject(&is_nil/1)
    end)
    |> Enum.uniq()
  end
  
  defp extract_services_from_logs(parsed_data) do
    parsed_data
    |> Map.get(:logs, %{})
    |> Map.get(:logs, [])
    |> Enum.map(&extract_service_from_resource(&1))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end
  
  defp extract_service_from_resource(item) do
    item
    |> Map.get("resource", %{})
    |> Map.get("attributes", [])
    |> find_service_name_attribute()
  end
  
  defp find_service_name_attribute(attributes) when is_list(attributes) do
    service_attr = Enum.find(attributes, &(Map.get(&1, "key") == "service.name"))
    case service_attr do
      %{"value" => %{"stringValue" => service_name}} -> service_name
      _ -> nil
    end
  end
  defp find_service_name_attribute(_), do: nil
  
  defp determine_discovery_source(service_name, parsed_data) do
    sources = []
    
    # Check if found in traces
    sources = if service_in_traces?(service_name, parsed_data), do: ["traces" | sources], else: sources
    
    # Check if found in metrics
    sources = if service_in_metrics?(service_name, parsed_data), do: ["metrics" | sources], else: sources
    
    # Check if found in logs
    sources = if service_in_logs?(service_name, parsed_data), do: ["logs" | sources], else: sources
    
    sources
  end
  
  defp service_in_traces?(service_name, parsed_data) do
    parsed_data
    |> Map.get(:traces, %{})
    |> Map.get(:traces, [])
    |> Enum.any?(&(service_name in Map.get(&1, :services, [])))
  end
  
  defp service_in_metrics?(service_name, parsed_data) do
    parsed_data
    |> Map.get(:metrics, %{})
    |> Map.get(:metrics, %{})
    |> Enum.any?(fn {_name, metrics} ->
      Enum.any?(metrics, &(extract_service_from_resource(&1) == service_name))
    end)
  end
  
  defp service_in_logs?(service_name, parsed_data) do
    parsed_data
    |> Map.get(:logs, %{})
    |> Map.get(:logs, [])
    |> Enum.any?(&(extract_service_from_resource(&1) == service_name))
  end
  
  defp enrich_with_service_discovery(service_info, config) do
    service_registry = Map.get(config, :service_registry, %{})
    
    service_info
    |> Enum.map(fn {service_name, service_data} ->
      # Look up service in registry
      registry_data = Map.get(service_registry, service_name, %{})
      
      enriched_data = 
        service_data
        |> Map.merge(registry_data)
        |> Map.put(:endpoints, get_service_endpoints(service_name, config))
        |> Map.put(:health_status, get_service_health(service_name, config))
        |> Map.put(:load_balancer, get_load_balancer_info(service_name, config))
      
      {service_name, enriched_data}
    end)
    |> Enum.into(%{})
  end
  
  defp add_deployment_metadata(enriched_services, config) do
    deployment_info = Map.get(config, :deployment_info, %{})
    
    enriched_services
    |> Enum.map(fn {service_name, service_data} ->
      deployment_data = %{
        environment: Map.get(deployment_info, :environment, "unknown"),
        region: Map.get(deployment_info, :region, "unknown"),
        cluster: Map.get(deployment_info, :cluster, "unknown"),
        namespace: Map.get(deployment_info, :namespace, "default"),
        version: get_service_version(service_name, config),
        deployment_time: get_deployment_time(service_name, config),
        replicas: get_replica_count(service_name, config)
      }
      
      enriched_data = 
        service_data
        |> Map.put(:deployment, deployment_data)
        |> Map.put(:tags, generate_service_tags(service_name, deployment_data))
      
      {service_name, enriched_data}
    end)
    |> Enum.into(%{})
  end
  
  defp add_operational_context(deployment_services, config) do
    current_time = DateTime.utc_now()
    
    deployment_services
    |> Enum.map(fn {service_name, service_data} ->
      operational_data = %{
        sla_tier: determine_sla_tier(service_name, config),
        team_ownership: get_team_ownership(service_name, config),
        cost_center: get_cost_center(service_name, config),
        monitoring: %{
          alerts_enabled: service_has_alerts?(service_name, config),
          dashboard_url: generate_dashboard_url(service_name, config),
          runbook_url: get_runbook_url(service_name, config)
        },
        compliance: %{
          data_classification: get_data_classification(service_name, config),
          retention_policy: get_retention_policy(service_name, config),
          encryption_required: encryption_required?(service_name, config)
        },
        enriched_at: current_time
      }
      
      final_data = 
        service_data
        |> Map.put(:operational, operational_data)
        |> Map.put(:enrichment_complete, true)
      
      {service_name, final_data}
    end)
    |> Enum.into(%{})
  end
  
  # Helper functions for service discovery
  
  defp get_service_endpoints(service_name, config) do
    service_name
    |> lookup_service_discovery(config)
    |> Map.get(:endpoints, [])
  end
  
  defp get_service_health(service_name, config) do
    # Mock health check - in real implementation, would call health endpoints
    health_statuses = ["healthy", "degraded", "unhealthy"]
    Enum.random(health_statuses)
  end
  
  defp get_load_balancer_info(service_name, _config) do
    %{
      type: "application",
      algorithm: "round_robin",
      health_check_enabled: true
    }
  end
  
  defp get_service_version(service_name, config) do
    service_name
    |> lookup_service_discovery(config)
    |> Map.get(:version, "unknown")
  end
  
  defp get_deployment_time(service_name, config) do
    service_name
    |> lookup_service_discovery(config)
    |> Map.get(:deployed_at, DateTime.utc_now())
  end
  
  defp get_replica_count(service_name, config) do
    service_name
    |> lookup_service_discovery(config)
    |> Map.get(:replicas, 1)
  end
  
  defp generate_service_tags(service_name, deployment_data) do
    [
      "service:#{service_name}",
      "env:#{deployment_data.environment}",
      "region:#{deployment_data.region}",
      "cluster:#{deployment_data.cluster}",
      "namespace:#{deployment_data.namespace}"
    ]
  end
  
  defp determine_sla_tier(service_name, config) do
    sla_config = Map.get(config, :sla_tiers, %{})
    Map.get(sla_config, service_name, "standard")
  end
  
  defp get_team_ownership(service_name, config) do
    ownership_config = Map.get(config, :team_ownership, %{})
    Map.get(ownership_config, service_name, "unknown")
  end
  
  defp get_cost_center(service_name, config) do
    cost_config = Map.get(config, :cost_centers, %{})
    Map.get(cost_config, service_name, "shared")
  end
  
  defp service_has_alerts?(service_name, config) do
    alert_config = Map.get(config, :alerts_enabled, %{})
    Map.get(alert_config, service_name, false)
  end
  
  defp generate_dashboard_url(service_name, config) do
    base_url = Map.get(config, :dashboard_base_url, "https://monitoring.example.com")
    "#{base_url}/service/#{service_name}"
  end
  
  defp get_runbook_url(service_name, config) do
    runbook_config = Map.get(config, :runbooks, %{})
    Map.get(runbook_config, service_name, "https://wiki.example.com/runbooks/#{service_name}")
  end
  
  defp get_data_classification(service_name, config) do
    classification_config = Map.get(config, :data_classification, %{})
    Map.get(classification_config, service_name, "internal")
  end
  
  defp get_retention_policy(service_name, config) do
    retention_config = Map.get(config, :retention_policies, %{})
    Map.get(retention_config, service_name, "30_days")
  end
  
  defp encryption_required?(service_name, config) do
    encryption_config = Map.get(config, :encryption_required, %{})
    Map.get(encryption_config, service_name, false)
  end
  
  defp lookup_service_discovery(service_name, config) do
    service_registry = Map.get(config, :service_registry, %{})
    Map.get(service_registry, service_name, %{})
  end
  
  defp count_enrichment_fields(operational_context) do
    operational_context
    |> Enum.map(fn {_service_name, service_data} ->
      Map.keys(service_data) |> length()
    end)
    |> Enum.sum()
  end
end