defmodule AiSelfSustainingMinimal.TelemetryPipeline.OtlpDataPipelineReactor do
  @moduledoc """
  High-throughput OpenTelemetry data processing pipeline using Reactor.
  
  Processes telemetry data through configurable stages:
  1. Ingestion from multiple sources (OTLP, HTTP, file)
  2. Validation and parsing
  3. Enrichment with metadata
  4. Sampling and filtering
  5. Transformation to target formats
  6. Routing to multiple backends
  7. Error handling and recovery
  
  Features:
  - Parallel processing with configurable concurrency
  - Fault-tolerant with compensation logic
  - Batch processing for efficiency
  - Comprehensive monitoring and metrics
  - Dead letter queue for failed records
  """
  
  use Reactor, extensions: [Reactor.Extension.Telemetry]
  
  require Logger
  
  # Pipeline configuration
  input :telemetry_data
  input :pipeline_config
  input :processing_context
  
  # Stage 1: Ingestion and Initial Validation
  step :ingest_telemetry_data, AiSelfSustainingMinimal.TelemetryPipeline.Steps.IngestionStep do
    argument :raw_data, input(:telemetry_data)
    argument :config, input(:pipeline_config)
    argument :context, input(:processing_context)
  end
  
  # Stage 2: Parse and Validate OTLP Data
  step :parse_otlp_data, AiSelfSustainingMinimal.TelemetryPipeline.Steps.OtlpParsingStep do
    argument :ingested_data, result(:ingest_telemetry_data)
    argument :config, input(:pipeline_config)
  end
  
  # Stage 3: Enrich with Metadata (parallel processing)
  step :enrich_with_service_metadata, AiSelfSustainingMinimal.TelemetryPipeline.Steps.ServiceEnrichmentStep do
    argument :parsed_data, result(:parse_otlp_data)
    argument :config, input(:pipeline_config)
  end
  
  step :enrich_with_resource_metadata, AiSelfSustainingMinimal.TelemetryPipeline.Steps.ResourceEnrichmentStep do
    argument :parsed_data, result(:parse_otlp_data)
    argument :config, input(:pipeline_config)
  end
  
  step :enrich_with_environment_metadata, AiSelfSustainingMinimal.TelemetryPipeline.Steps.EnvironmentEnrichmentStep do
    argument :parsed_data, result(:parse_otlp_data)
    argument :config, input(:pipeline_config)
  end
  
  # Stage 4: Merge Enrichment Results
  step :merge_enriched_data, AiSelfSustainingMinimal.TelemetryPipeline.Steps.EnrichmentMergeStep do
    argument :service_data, result(:enrich_with_service_metadata)
    argument :resource_data, result(:enrich_with_resource_metadata)
    argument :environment_data, result(:enrich_with_environment_metadata)
    argument :config, input(:pipeline_config)
  end
  
  # Stage 5: Apply Sampling and Filtering
  step :apply_sampling_strategy, AiSelfSustainingMinimal.TelemetryPipeline.Steps.SamplingStep do
    argument :enriched_data, result(:merge_enriched_data)
    argument :config, input(:pipeline_config)
  end
  
  # Stage 6: Transform to Target Formats (parallel)
  step :transform_to_jaeger, AiSelfSustainingMinimal.TelemetryPipeline.Steps.JaegerTransformStep do
    argument :sampled_data, result(:apply_sampling_strategy)
    argument :config, input(:pipeline_config)
  end
  
  step :transform_to_prometheus, AiSelfSustainingMinimal.TelemetryPipeline.Steps.PrometheusTransformStep do
    argument :sampled_data, result(:apply_sampling_strategy)
    argument :config, input(:pipeline_config)
  end
  
  step :transform_to_elasticsearch, AiSelfSustainingMinimal.TelemetryPipeline.Steps.ElasticsearchTransformStep do
    argument :sampled_data, result(:apply_sampling_strategy)
    argument :config, input(:pipeline_config)
  end
  
  # Stage 7: Batch and Route to Backends
  step :batch_for_backends, AiSelfSustainingMinimal.TelemetryPipeline.Steps.BatchingStep do
    argument :jaeger_data, result(:transform_to_jaeger)
    argument :prometheus_data, result(:transform_to_prometheus)
    argument :elasticsearch_data, result(:transform_to_elasticsearch)
    argument :config, input(:pipeline_config)
  end
  
  # Stage 8: Send to Backends (parallel)
  step :send_to_jaeger, AiSelfSustainingMinimal.TelemetryPipeline.Steps.JaegerSinkStep do
    argument :batched_data, result(:batch_for_backends)
    argument :config, input(:pipeline_config)
  end
  
  step :send_to_prometheus, AiSelfSustainingMinimal.TelemetryPipeline.Steps.PrometheusSinkStep do
    argument :batched_data, result(:batch_for_backends)
    argument :config, input(:pipeline_config)
  end
  
  step :send_to_elasticsearch, AiSelfSustainingMinimal.TelemetryPipeline.Steps.ElasticsearchSinkStep do
    argument :batched_data, result(:batch_for_backends)
    argument :config, input(:pipeline_config)
  end
  
  # Stage 9: Collect Results and Generate Report
  step :collect_processing_results, AiSelfSustainingMinimal.TelemetryPipeline.Steps.ResultCollectionStep do
    argument :jaeger_result, result(:send_to_jaeger)
    argument :prometheus_result, result(:send_to_prometheus)
    argument :elasticsearch_result, result(:send_to_elasticsearch)
    argument :original_data, result(:ingest_telemetry_data)
    argument :config, input(:pipeline_config)
  end
  
  # Final output
  return :collect_processing_results
end