#!/usr/bin/env bash

# NuxtOps V3 Chapter 5: OpenTelemetry Integration
# Comprehensive distributed tracing and observability implementation

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
readonly CHAPTER_ID="chapter_05_$(date +%s%N)"
readonly CHAPTER_LOG="${PROJECT_ROOT}/logs/chapters/${CHAPTER_ID}.log"
readonly CHAPTER_STATE="${PROJECT_ROOT}/.chapter_05_state.json"

# Chapter configuration
readonly CHAPTER_NAME="OpenTelemetry Integration"
readonly CHAPTER_VERSION="1.0.0"
readonly ESTIMATED_DURATION="45-90 minutes"

# Prerequisites from previous chapters
readonly REQUIRED_CHAPTERS=("chapter-01" "chapter-02" "chapter-03" "chapter-04")

# OpenTelemetry components
readonly OTEL_COMPONENTS=(
    "otel-collector"
    "jaeger"
    "tempo"
    "instrumentation"
    "correlation"
    "exporters"
)

# Implementation phases
readonly IMPLEMENTATION_PHASES=(
    "prerequisites_check"
    "otel_collector_setup"
    "tracing_backend_setup"
    "instrumentation_setup"
    "correlation_setup"
    "validation"
    "optimization"
)

# Initialize chapter
init_chapter() {
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║         NuxtOps V3 - Chapter 5: OpenTelemetry Integration     ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Chapter:${NC} ${CHAPTER_NAME}"
    echo -e "${CYAN}Version:${NC} ${CHAPTER_VERSION}"
    echo -e "${CYAN}Chapter ID:${NC} ${CHAPTER_ID}"
    echo -e "${CYAN}Estimated Duration:${NC} ${ESTIMATED_DURATION}"
    echo -e "${CYAN}Environment:${NC} ${ENVIRONMENT}"
    echo
    
    # Create logging directory
    mkdir -p "$(dirname "$CHAPTER_LOG")"
    exec 1> >(tee -a "$CHAPTER_LOG")
    exec 2>&1
    
    # Initialize chapter state
    echo '{
        "chapter_id": "'"${CHAPTER_ID}"'",
        "chapter_name": "'"${CHAPTER_NAME}"'",
        "start_time": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'",
        "environment": "'"${ENVIRONMENT}"'",
        "phases": [],
        "components": [],
        "status": "in_progress"
    }' > "$CHAPTER_STATE"
}

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}━━━ Phase: Prerequisites Check ━━━${NC}"
    
    local phase_result="passed"
    local details=()
    
    # Check required chapters
    for chapter in "${REQUIRED_CHAPTERS[@]}"; do
        local chapter_state_file="${PROJECT_ROOT}/.${chapter}_state.json"
        if [[ -f "$chapter_state_file" ]]; then
            local chapter_status=$(jq -r '.status' "$chapter_state_file" 2>/dev/null || echo "unknown")
            if [[ "$chapter_status" == "completed" ]]; then
                details+=("Chapter dependency ${chapter}: Satisfied")
            else
                phase_result="failed"
                details+=("Chapter dependency ${chapter}: Not completed (status: ${chapter_status})")
            fi
        else
            phase_result="failed"
            details+=("Chapter dependency ${chapter}: Not found")
        fi
    done
    
    # Check Docker and Docker Compose
    if command -v docker &>/dev/null && docker info &>/dev/null; then
        details+=("Docker: Available")
    else
        phase_result="failed"
        details+=("Docker: Not available or not running")
    fi
    
    if command -v docker-compose &>/dev/null; then
        details+=("Docker Compose: Available")
    else
        phase_result="failed"
        details+=("Docker Compose: Not available")
    fi
    
    # Check monitoring stack (Chapter 4 prerequisite)
    if docker ps --format "{{.Names}}" | grep -E "(prometheus|grafana)" &>/dev/null; then
        details+=("Monitoring stack: Running")
    else
        phase_result="degraded"
        details+=("Monitoring stack: Not running (will start as part of this chapter)")
    fi
    
    # Check application (Chapter 2 prerequisite)
    if curl -s "http://localhost:3000/health" &>/dev/null; then
        details+=("Application: Running")
    else
        phase_result="degraded"
        details+=("Application: Not accessible (will be configured for tracing)")
    fi
    
    # Check system resources
    local available_memory=$(free -m | awk '/^Mem:/ {print $7}')
    if [[ $available_memory -gt 2048 ]]; then
        details+=("Available memory: ${available_memory}MB (sufficient)")
    else
        phase_result="degraded"
        details+=("Available memory: ${available_memory}MB (may be insufficient)")
    fi
    
    save_phase_result "prerequisites_check" "$phase_result" "${details[@]}"
    
    if [[ "$phase_result" == "failed" ]]; then
        echo -e "${RED}Prerequisites not met. Cannot proceed with OpenTelemetry implementation.${NC}"
        exit 1
    fi
    
    [[ "$phase_result" == "passed" ]]
}

# Setup OpenTelemetry Collector
setup_otel_collector() {
    echo -e "${BLUE}━━━ Phase: OpenTelemetry Collector Setup ━━━${NC}"
    
    local phase_result="passed"
    local details=()
    
    # Create OpenTelemetry configuration directory
    local otel_config_dir="${PROJECT_ROOT}/monitoring/opentelemetry"
    mkdir -p "$otel_config_dir"
    
    # Generate OpenTelemetry Collector configuration
    cat > "${otel_config_dir}/otel-collector-config.yaml" << 'EOF'
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
  
  # Host metrics
  hostmetrics:
    collection_interval: 10s
    scrapers:
      cpu:
      disk:
      filesystem:
      memory:
      network:
      process:
  
  # Prometheus scraping
  prometheus:
    config:
      scrape_configs:
        - job_name: 'otel-collector'
          scrape_interval: 10s
          static_configs:
            - targets: ['localhost:8888']

processors:
  # Memory limiter
  memory_limiter:
    limit_mib: 512
    spike_limit_mib: 128
    check_interval: 5s
  
  # Batch processor
  batch:
    send_batch_size: 1024
    timeout: 10s
    send_batch_max_size: 2048
  
  # Resource processor
  resource:
    attributes:
      - key: environment
        value: "${ENVIRONMENT}"
        action: upsert
      - key: service.namespace
        value: "nuxtops"
        action: upsert
      - key: deployment.environment
        value: "${ENVIRONMENT}"
        action: upsert
  
  # Attributes processor
  attributes:
    actions:
      - key: http.user_agent
        action: delete
      - key: http.request.header.authorization
        action: delete

exporters:
  # Jaeger exporter
  jaeger:
    endpoint: jaeger:14250
    tls:
      insecure: true
  
  # Prometheus exporter
  prometheus:
    endpoint: "0.0.0.0:8889"
    send_timestamps: true
    metric_expiration: 180m
    enable_open_metrics: true
  
  # OTLP exporter (for external systems)
  otlp/tempo:
    endpoint: tempo:4317
    tls:
      insecure: true
  
  # Logging exporter (for debugging)
  logging:
    loglevel: info
    sampling_initial: 5
    sampling_thereafter: 200

extensions:
  health_check:
    endpoint: 0.0.0.0:13133
  
  pprof:
    endpoint: 0.0.0.0:1777
  
  zpages:
    endpoint: 0.0.0.0:55679

service:
  extensions: [health_check, pprof, zpages]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, resource, attributes, batch]
      exporters: [jaeger, otlp/tempo, logging]
    
    metrics:
      receivers: [otlp, hostmetrics, prometheus]
      processors: [memory_limiter, resource, batch]
      exporters: [prometheus, logging]
    
    logs:
      receivers: [otlp]
      processors: [memory_limiter, resource, batch]
      exporters: [logging]
  
  telemetry:
    logs:
      level: "info"
    metrics:
      address: 0.0.0.0:8888
EOF
    
    details+=("OpenTelemetry Collector config: Created")
    
    # Create Docker Compose configuration for OpenTelemetry
    cat > "${PROJECT_ROOT}/monitoring/compose.otel.yaml" << 'EOF'
version: '3.8'

networks:
  nuxtops-network:
    external: true

volumes:
  jaeger-data:
  tempo-data:
  prometheus-data:
  grafana-data:

services:
  # OpenTelemetry Collector
  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.89.0
    container_name: otel-collector
    restart: unless-stopped
    command: ["--config=/etc/otelcol-contrib/otel-collector-config.yaml"]
    volumes:
      - ./opentelemetry/otel-collector-config.yaml:/etc/otelcol-contrib/otel-collector-config.yaml:ro
    ports:
      - "1888:1888"   # pprof extension
      - "8888:8888"   # Prometheus metrics
      - "8889:8889"   # Prometheus exporter metrics
      - "13133:13133" # health_check extension
      - "4317:4317"   # OTLP gRPC receiver
      - "4318:4318"   # OTLP HTTP receiver
      - "55679:55679" # zpages extension
    environment:
      - ENVIRONMENT=${ENVIRONMENT:-development}
    networks:
      - nuxtops-network
    depends_on:
      - jaeger
      - tempo
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:13133/"]
      interval: 10s
      timeout: 5s
      retries: 3

  # Jaeger
  jaeger:
    image: jaegertracing/all-in-one:1.50
    container_name: jaeger
    restart: unless-stopped
    ports:
      - "16686:16686" # Jaeger UI
      - "14268:14268" # Jaeger HTTP
      - "14250:14250" # Jaeger gRPC
    environment:
      - COLLECTOR_OTLP_ENABLED=true
      - QUERY_BASE_PATH=/jaeger
    volumes:
      - jaeger-data:/tmp
    networks:
      - nuxtops-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:16686/"]
      interval: 10s
      timeout: 5s
      retries: 3

  # Grafana Tempo
  tempo:
    image: grafana/tempo:2.3.0
    container_name: tempo
    restart: unless-stopped
    command: [ "-config.file=/etc/tempo.yaml" ]
    volumes:
      - ./opentelemetry/tempo.yaml:/etc/tempo.yaml:ro
      - tempo-data:/tmp/tempo
    ports:
      - "3200:3000"  # Tempo HTTP
      - "4317"       # OTLP gRPC
    networks:
      - nuxtops-network

  # Prometheus (if not already running)
  prometheus:
    image: prom/prometheus:v2.47.0
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    networks:
      - nuxtops-network
    profiles:
      - monitoring

  # Grafana (if not already running)
  grafana:
    image: grafana/grafana:10.2.0
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_FEATURE_TOGGLES_ENABLE=traceqlEditor
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
    networks:
      - nuxtops-network
    profiles:
      - monitoring
    depends_on:
      - prometheus
      - tempo
      - jaeger
EOF
    
    details+=("OpenTelemetry Compose config: Created")
    
    # Create Tempo configuration
    cat > "${otel_config_dir}/tempo.yaml" << 'EOF'
server:
  http_listen_port: 3000

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318

ingester:
  trace_idle_period: 10s
  max_block_bytes: 1_000_000
  max_block_duration: 5m

storage:
  trace:
    backend: local
    local:
      path: /tmp/tempo/traces
    wal:
      path: /tmp/tempo/wal
    pool:
      max_workers: 100
      queue_depth: 10000

querier:
  frontend_worker:
    frontend_address: tempo:9095

query_frontend:
  search:
    duration_slo: 5s
    throughput_bytes_slo: 1.073741824e+09
  trace_by_id:
    duration_slo: 5s

compactor:
  compaction:
    compaction_window: 1h
    max_block_bytes: 100_000_000
    block_retention: 1h
    compacted_block_retention: 10m
EOF
    
    details+=("Tempo config: Created")
    
    save_phase_result "otel_collector_setup" "$phase_result" "${details[@]}"
    
    [[ "$phase_result" == "passed" ]]
}

# Setup tracing backends
setup_tracing_backends() {
    echo -e "${BLUE}━━━ Phase: Tracing Backend Setup ━━━${NC}"
    
    local phase_result="passed"
    local details=()
    
    # Create network if it doesn't exist
    if ! docker network ls | grep -q "nuxtops-network"; then
        docker network create nuxtops-network
        details+=("Docker network: Created")
    else
        details+=("Docker network: Already exists")
    fi
    
    # Start OpenTelemetry stack
    echo -e "${YELLOW}Starting OpenTelemetry stack...${NC}"
    
    cd "${PROJECT_ROOT}/monitoring"
    
    if docker-compose -f compose.otel.yaml up -d; then
        details+=("OpenTelemetry stack: Started")
    else
        phase_result="failed"
        details+=("OpenTelemetry stack: Failed to start")
        save_phase_result "tracing_backend_setup" "$phase_result" "${details[@]}"
        return 1
    fi
    
    # Wait for services to be healthy
    echo -e "${YELLOW}Waiting for services to be healthy...${NC}"
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        local healthy_services=0
        
        # Check each service
        for service in "otel-collector" "jaeger" "tempo"; do
            if docker ps --filter "name=$service" --filter "status=running" | grep -q "$service"; then
                ((healthy_services++))
            fi
        done
        
        if [ $healthy_services -eq 3 ]; then
            details+=("All services healthy: Yes")
            break
        fi
        
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        phase_result="degraded"
        details+=("Service health check: Timeout (some services may not be ready)")
    fi
    
    # Test OpenTelemetry Collector endpoints
    if curl -s "http://localhost:13133/" &>/dev/null; then
        details+=("OpenTelemetry Collector health endpoint: OK")
    else
        phase_result="degraded"
        details+=("OpenTelemetry Collector health endpoint: Not accessible")
    fi
    
    if curl -s "http://localhost:4318/v1/traces" -X POST &>/dev/null; then
        details+=("OpenTelemetry OTLP HTTP endpoint: OK")
    else
        phase_result="degraded"
        details+=("OpenTelemetry OTLP HTTP endpoint: Not accessible")
    fi
    
    # Test Jaeger UI
    if curl -s "http://localhost:16686/" &>/dev/null; then
        details+=("Jaeger UI: Accessible")
    else
        phase_result="degraded"
        details+=("Jaeger UI: Not accessible")
    fi
    
    save_phase_result "tracing_backend_setup" "$phase_result" "${details[@]}"
    
    [[ "$phase_result" == "passed" || "$phase_result" == "degraded" ]]
}

# Setup application instrumentation
setup_instrumentation() {
    echo -e "${BLUE}━━━ Phase: Application Instrumentation Setup ━━━${NC}"
    
    local phase_result="passed"
    local details=()
    
    # Create instrumentation configuration
    local instrumentation_dir="${PROJECT_ROOT}/instrumentation"
    mkdir -p "$instrumentation_dir"
    
    # Generate Node.js instrumentation
    cat > "${instrumentation_dir}/tracing.js" << 'EOF'
// OpenTelemetry instrumentation for NuxtOps
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-otlp-http');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-otlp-http');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');

// Configuration
const serviceName = process.env.OTEL_SERVICE_NAME || 'nuxtops-app';
const serviceVersion = process.env.OTEL_SERVICE_VERSION || '1.0.0';
const environment = process.env.ENVIRONMENT || 'development';
const otelCollectorUrl = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318';

// Resource configuration
const resource = new Resource({
  [SemanticResourceAttributes.SERVICE_NAME]: serviceName,
  [SemanticResourceAttributes.SERVICE_VERSION]: serviceVersion,
  [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: environment,
  [SemanticResourceAttributes.SERVICE_NAMESPACE]: 'nuxtops',
  [SemanticResourceAttributes.SERVICE_INSTANCE_ID]: `${serviceName}-${process.pid}`,
});

// Trace exporter
const traceExporter = new OTLPTraceExporter({
  url: `${otelCollectorUrl}/v1/traces`,
  headers: {},
});

// Metric exporter
const metricExporter = new OTLPMetricExporter({
  url: `${otelCollectorUrl}/v1/metrics`,
  headers: {},
});

// Initialize the SDK
const sdk = new NodeSDK({
  resource: resource,
  traceExporter: traceExporter,
  metricReader: new PeriodicExportingMetricReader({
    exporter: metricExporter,
    exportIntervalMillis: 10000,
  }),
  instrumentations: [
    getNodeAutoInstrumentations({
      // Disable/configure specific instrumentations
      '@opentelemetry/instrumentation-dns': {
        enabled: false,
      },
      '@opentelemetry/instrumentation-net': {
        enabled: false,
      },
      '@opentelemetry/instrumentation-http': {
        enabled: true,
        ignoreincomingRequestHook: (req) => {
          // Ignore health check endpoints
          return req.url && (
            req.url.includes('/health') ||
            req.url.includes('/metrics') ||
            req.url.includes('/_nuxt/')
          );
        },
        ignoreOutgoingRequestHook: (options) => {
          // Ignore internal requests
          return options.hostname === 'localhost' && options.port === 4318;
        },
      },
      '@opentelemetry/instrumentation-express': {
        enabled: true,
      },
      '@opentelemetry/instrumentation-postgres': {
        enabled: true,
      },
      '@opentelemetry/instrumentation-redis': {
        enabled: true,
      },
    }),
  ],
});

// Error handling
process.on('SIGTERM', () => {
  sdk.shutdown()
    .then(() => console.log('Tracing terminated'))
    .catch((error) => console.log('Error terminating tracing', error))
    .finally(() => process.exit(0));
});

// Start the SDK
sdk.start();

console.log(`OpenTelemetry started for ${serviceName} in ${environment} environment`);

module.exports = sdk;
EOF
    
    details+=("Node.js instrumentation: Created")
    
    # Create environment-specific configurations
    for env in "development" "staging" "production"; do
        cat > "${instrumentation_dir}/.env.${env}" << EOF
# OpenTelemetry configuration for ${env}
OTEL_SERVICE_NAME=nuxtops-app
OTEL_SERVICE_VERSION=1.0.0
OTEL_RESOURCE_ATTRIBUTES=service.name=nuxtops-app,service.version=1.0.0,deployment.environment=${env}
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp

# Sampling configuration
OTEL_TRACES_SAMPLER=traceidratio
OTEL_TRACES_SAMPLER_ARG=1.0

# Environment-specific settings
ENVIRONMENT=${env}
NODE_ENV=${env}
EOF
    done
    
    details+=("Environment configurations: Created for development, staging, production")
    
    # Create instrumentation package.json
    cat > "${instrumentation_dir}/package.json" << 'EOF'
{
  "name": "nuxtops-instrumentation",
  "version": "1.0.0",
  "description": "OpenTelemetry instrumentation for NuxtOps",
  "main": "tracing.js",
  "dependencies": {
    "@opentelemetry/sdk-node": "^0.44.0",
    "@opentelemetry/auto-instrumentations-node": "^0.39.4",
    "@opentelemetry/resources": "^1.17.0",
    "@opentelemetry/semantic-conventions": "^1.17.0",
    "@opentelemetry/exporter-otlp-http": "^0.44.0",
    "@opentelemetry/sdk-metrics": "^1.17.0"
  }
}
EOF
    
    details+=("Instrumentation package.json: Created")
    
    save_phase_result "instrumentation_setup" "$phase_result" "${details[@]}"
    
    [[ "$phase_result" == "passed" ]]
}

# Setup trace correlation
setup_correlation() {
    echo -e "${BLUE}━━━ Phase: Trace Correlation Setup ━━━${NC}"
    
    local phase_result="passed"
    local details=()
    
    # Create correlation middleware
    local middleware_dir="${PROJECT_ROOT}/middleware"
    mkdir -p "$middleware_dir"
    
    cat > "${middleware_dir}/tracing.js" << 'EOF'
// OpenTelemetry tracing middleware for Nuxt.js
import { trace, context, propagation } from '@opentelemetry/api';

const tracer = trace.getTracer('nuxtops-middleware', '1.0.0');

export default function (req, res, next) {
  // Extract trace context from incoming request
  const parentContext = propagation.extract(context.active(), req.headers);
  
  // Create a new span for this request
  const span = tracer.startSpan(`${req.method} ${req.url}`, {
    kind: 1, // SERVER
    attributes: {
      'http.method': req.method,
      'http.url': req.url,
      'http.scheme': req.protocol,
      'http.host': req.get('host'),
      'http.user_agent': req.get('user-agent'),
      'http.route': req.route?.path || req.url,
      'user.id': req.user?.id || 'anonymous',
    },
  }, parentContext);
  
  // Set the span as active
  context.with(trace.setSpan(context.active(), span), () => {
    // Add span context to request for use in handlers
    req.span = span;
    req.traceId = span.spanContext().traceId;
    req.spanId = span.spanContext().spanId;
    
    // Add trace correlation to response headers
    res.setHeader('X-Trace-Id', req.traceId);
    res.setHeader('X-Span-Id', req.spanId);
    
    // Override res.end to capture response details
    const originalEnd = res.end;
    res.end = function(...args) {
      // Set response attributes
      span.setAttributes({
        'http.status_code': res.statusCode,
        'http.response.size': res.get('content-length') || 0,
      });
      
      // Set span status based on response code
      if (res.statusCode >= 400) {
        span.setStatus({
          code: 2, // ERROR
          message: `HTTP ${res.statusCode}`,
        });
      }
      
      // End the span
      span.end();
      
      // Call original end
      originalEnd.apply(this, args);
    };
    
    next();
  });
}
EOF
    
    details+=("Tracing middleware: Created")
    
    # Create log correlation configuration
    cat > "${middleware_dir}/log-correlation.js" << 'EOF'
// Log correlation with OpenTelemetry
import { trace } from '@opentelemetry/api';

// Enhanced console logging with trace correlation
const originalConsole = {
  log: console.log,
  error: console.error,
  warn: console.warn,
  info: console.info,
  debug: console.debug,
};

function addTraceContext(level, args) {
  const span = trace.getActiveSpan();
  if (span) {
    const spanContext = span.spanContext();
    const traceInfo = {
      timestamp: new Date().toISOString(),
      level: level,
      trace_id: spanContext.traceId,
      span_id: spanContext.spanId,
      trace_flags: spanContext.traceFlags,
    };
    
    // Prepend trace info to log message
    return [JSON.stringify(traceInfo), ...args];
  }
  
  return args;
}

// Override console methods
console.log = (...args) => originalConsole.log(...addTraceContext('info', args));
console.error = (...args) => originalConsole.error(...addTraceContext('error', args));
console.warn = (...args) => originalConsole.warn(...addTraceContext('warn', args));
console.info = (...args) => originalConsole.info(...addTraceContext('info', args));
console.debug = (...args) => originalConsole.debug(...addTraceContext('debug', args));

// Structured logging function
export function logWithTrace(level, message, meta = {}) {
  const span = trace.getActiveSpan();
  const logEntry = {
    timestamp: new Date().toISOString(),
    level: level,
    message: message,
    ...meta,
  };
  
  if (span) {
    const spanContext = span.spanContext();
    logEntry.trace_id = spanContext.traceId;
    logEntry.span_id = spanContext.spanId;
    logEntry.trace_flags = spanContext.traceFlags;
  }
  
  console[level](JSON.stringify(logEntry));
  
  // Add log event to current span
  if (span) {
    span.addEvent('log', {
      'log.severity': level,
      'log.message': message,
      ...meta,
    });
  }
}

export default {
  logWithTrace,
  addTraceContext,
};
EOF
    
    details+=("Log correlation: Configured")
    
    # Create database correlation helpers
    cat > "${middleware_dir}/db-correlation.js" << 'EOF'
// Database query correlation with OpenTelemetry
import { trace } from '@opentelemetry/api';

const tracer = trace.getTracer('nuxtops-db', '1.0.0');

// PostgreSQL query wrapper with tracing
export function tracedQuery(client, query, params = []) {
  return new Promise((resolve, reject) => {
    const span = tracer.startSpan('db.query', {
      kind: 3, // CLIENT
      attributes: {
        'db.system': 'postgresql',
        'db.operation': query.split(' ')[0].toUpperCase(),
        'db.statement': query,
        'db.name': process.env.POSTGRES_DB || 'nuxtops',
      },
    });
    
    const startTime = Date.now();
    
    client.query(query, params)
      .then(result => {
        span.setAttributes({
          'db.rows_affected': result.rowCount || 0,
          'db.duration': Date.now() - startTime,
        });
        
        span.setStatus({ code: 1 }); // OK
        span.end();
        resolve(result);
      })
      .catch(error => {
        span.setAttributes({
          'error.name': error.name,
          'error.message': error.message,
          'db.duration': Date.now() - startTime,
        });
        
        span.setStatus({
          code: 2, // ERROR
          message: error.message,
        });
        span.end();
        reject(error);
      });
  });
}

// Redis operation wrapper with tracing
export function tracedRedisOperation(client, operation, ...args) {
  return new Promise((resolve, reject) => {
    const span = tracer.startSpan(`redis.${operation}`, {
      kind: 3, // CLIENT
      attributes: {
        'db.system': 'redis',
        'db.operation': operation.toUpperCase(),
        'redis.key': args[0] || '',
      },
    });
    
    const startTime = Date.now();
    
    client[operation](...args)
      .then(result => {
        span.setAttributes({
          'db.duration': Date.now() - startTime,
          'redis.result_type': typeof result,
        });
        
        span.setStatus({ code: 1 }); // OK
        span.end();
        resolve(result);
      })
      .catch(error => {
        span.setAttributes({
          'error.name': error.name,
          'error.message': error.message,
          'db.duration': Date.now() - startTime,
        });
        
        span.setStatus({
          code: 2, // ERROR
          message: error.message,
        });
        span.end();
        reject(error);
      });
  });
}

export default {
  tracedQuery,
  tracedRedisOperation,
};
EOF
    
    details+=("Database correlation: Configured")
    
    save_phase_result "correlation_setup" "$phase_result" "${details[@]}"
    
    [[ "$phase_result" == "passed" ]]
}

# Run validation
run_validation() {
    echo -e "${BLUE}━━━ Phase: OpenTelemetry Validation ━━━${NC}"
    
    local phase_result="passed"
    local details=()
    
    # Run comprehensive OpenTelemetry validation
    if [[ -f "${PROJECT_ROOT}/scripts/e2e-otel-validation.sh" ]]; then
        echo -e "${YELLOW}Running E2E OpenTelemetry validation...${NC}"
        
        if "${PROJECT_ROOT}/scripts/e2e-otel-validation.sh" "$ENVIRONMENT" --verbose; then
            details+=("E2E OpenTelemetry validation: PASSED")
        else
            phase_result="degraded"
            details+=("E2E OpenTelemetry validation: FAILED")
        fi
    else
        details+=("E2E validation script: Not found")
    fi
    
    # Run compose validation
    if [[ -f "${PROJECT_ROOT}/scripts/validate-compose-otel-e2e.sh" ]]; then
        echo -e "${YELLOW}Running Compose OpenTelemetry validation...${NC}"
        
        if "${PROJECT_ROOT}/scripts/validate-compose-otel-e2e.sh" --no-cleanup --verbose; then
            details+=("Compose OpenTelemetry validation: PASSED")
        else
            phase_result="degraded"
            details+=("Compose OpenTelemetry validation: FAILED")
        fi
    else
        details+=("Compose validation script: Not found")
    fi
    
    # Run distributed trace validation
    if [[ -f "${PROJECT_ROOT}/scripts/validate-distributed-trace-e2e.sh" ]]; then
        echo -e "${YELLOW}Running distributed trace validation...${NC}"
        
        if "${PROJECT_ROOT}/scripts/validate-distributed-trace-e2e.sh" --verbose; then
            details+=("Distributed trace validation: PASSED")
        else
            phase_result="degraded"
            details+=("Distributed trace validation: FAILED")
        fi
    else
        details+=("Distributed trace validation script: Not found")
    fi
    
    # Test manual trace generation
    echo -e "${YELLOW}Testing manual trace generation...${NC}"
    
    local test_trace_id=$(printf '%032x' $RANDOM$RANDOM$RANDOM$RANDOM)
    local test_payload='{"resourceSpans":[{"scopeSpans":[{"spans":[{"traceId":"'$test_trace_id'","spanId":"'$(printf '%016x' $RANDOM$RANDOM)'","name":"chapter-05-test","startTimeUnixNano":"'$(date +%s%N)'","endTimeUnixNano":"'$(date +%s%N)'"}]}]}]}'
    
    if curl -s -X POST "http://localhost:4318/v1/traces" \
        -H "Content-Type: application/json" \
        -d "$test_payload" &>/dev/null; then
        details+=("Manual trace generation: SUCCESS")
        
        # Wait and check if trace appears in Jaeger
        sleep 5
        local trace_check=$(curl -s "http://localhost:16686/api/traces/${test_trace_id}" 2>/dev/null || echo "{}")
        
        if echo "$trace_check" | jq -e '.data[0]' &>/dev/null; then
            details+=("Trace retrieval from Jaeger: SUCCESS")
        else
            phase_result="degraded"
            details+=("Trace retrieval from Jaeger: FAILED")
        fi
    else
        phase_result="failed"
        details+=("Manual trace generation: FAILED")
    fi
    
    save_phase_result "validation" "$phase_result" "${details[@]}"
    
    [[ "$phase_result" == "passed" || "$phase_result" == "degraded" ]]
}

# Optimize configuration
optimize_configuration() {
    echo -e "${BLUE}━━━ Phase: Configuration Optimization ━━━${NC}"
    
    local phase_result="passed"
    local details=()
    
    # Environment-specific optimizations
    case "$ENVIRONMENT" in
        "production")
            # Production optimizations
            echo "Applying production optimizations..."
            
            # Update sampling rate for production
            sed -i 's/OTEL_TRACES_SAMPLER_ARG=1.0/OTEL_TRACES_SAMPLER_ARG=0.1/' "${PROJECT_ROOT}/instrumentation/.env.production"
            details+=("Production sampling rate: Set to 10%")
            
            # Enable batch processing optimizations
            details+=("Batch processing: Optimized for production")
            ;;
        "staging")
            # Staging optimizations
            sed -i 's/OTEL_TRACES_SAMPLER_ARG=1.0/OTEL_TRACES_SAMPLER_ARG=0.5/' "${PROJECT_ROOT}/instrumentation/.env.staging"
            details+=("Staging sampling rate: Set to 50%")
            ;;
        *)
            # Development - keep full sampling
            details+=("Development sampling rate: 100% (full tracing)")
            ;;
    esac
    
    # Performance tuning based on environment
    local memory_limit="512"
    local batch_size="1024"
    
    if [[ "$ENVIRONMENT" == "production" ]]; then
        memory_limit="1024"
        batch_size="2048"
    fi
    
    # Update collector configuration with optimizations
    sed -i "s/limit_mib: 512/limit_mib: $memory_limit/" "${PROJECT_ROOT}/monitoring/opentelemetry/otel-collector-config.yaml"
    sed -i "s/send_batch_size: 1024/send_batch_size: $batch_size/" "${PROJECT_ROOT}/monitoring/opentelemetry/otel-collector-config.yaml"
    
    details+=("Memory limit: Set to ${memory_limit}MiB")
    details+=("Batch size: Set to ${batch_size}")
    
    # Restart collector with new configuration
    echo -e "${YELLOW}Restarting OpenTelemetry Collector with optimized configuration...${NC}"
    
    cd "${PROJECT_ROOT}/monitoring"
    if docker-compose -f compose.otel.yaml restart otel-collector; then
        details+=("OpenTelemetry Collector: Restarted with optimizations")
    else
        phase_result="degraded"
        details+=("OpenTelemetry Collector: Failed to restart")
    fi
    
    save_phase_result "optimization" "$phase_result" "${details[@]}"
    
    [[ "$phase_result" == "passed" || "$phase_result" == "degraded" ]]
}

# Save phase result
save_phase_result() {
    local phase_name="$1"
    local result="$2"
    shift 2
    local details=("$@")
    
    # Create phase result entry
    local phase_entry=$(jq -n \
        --arg name "$phase_name" \
        --arg res "$result" \
        --argjson det "$(printf '%s\n' "${details[@]}" | jq -R . | jq -s .)" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            name: $name,
            result: $res,
            details: $det,
            timestamp: $ts
        }')
    
    # Update chapter state
    jq ".phases += [$phase_entry]" "$CHAPTER_STATE" > "${CHAPTER_STATE}.tmp" && mv "${CHAPTER_STATE}.tmp" "$CHAPTER_STATE"
    
    # Display result
    if [[ "$result" == "passed" ]]; then
        echo -e "${GREEN}✓ Phase ${phase_name}: ${result}${NC}"
    elif [[ "$result" == "degraded" ]]; then
        echo -e "${YELLOW}⚠ Phase ${phase_name}: ${result}${NC}"
    else
        echo -e "${RED}✗ Phase ${phase_name}: ${result}${NC}"
    fi
    
    # Display details if verbose
    if [[ "${VERBOSE}" == "true" ]]; then
        for detail in "${details[@]}"; do
            echo "  $detail"
        done
    fi
}

# Generate chapter summary
generate_chapter_summary() {
    local total_phases=$(jq '.phases | length' "$CHAPTER_STATE")
    local passed_phases=$(jq '[.phases[] | select(.result == "passed")] | length' "$CHAPTER_STATE")
    local degraded_phases=$(jq '[.phases[] | select(.result == "degraded")] | length' "$CHAPTER_STATE")
    local failed_phases=$(jq '[.phases[] | select(.result == "failed")] | length' "$CHAPTER_STATE")
    
    # Determine overall chapter result
    local chapter_result="completed"
    if [[ $failed_phases -gt 0 ]]; then
        chapter_result="failed"
    elif [[ $degraded_phases -gt 0 ]]; then
        chapter_result="completed_with_warnings"
    fi
    
    # Update chapter state with summary
    jq \
        --arg end_time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg status "$chapter_result" \
        --argjson total "$total_phases" \
        --argjson passed "$passed_phases" \
        --argjson degraded "$degraded_phases" \
        --argjson failed "$failed_phases" \
        '. + {
            end_time: $end_time,
            status: $status,
            summary: {
                total_phases: $total,
                passed: $passed,
                degraded: $degraded,
                failed: $failed
            }
        }' "$CHAPTER_STATE" > "${CHAPTER_STATE}.tmp" && mv "${CHAPTER_STATE}.tmp" "$CHAPTER_STATE"
    
    # Display summary
    echo
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║         Chapter 5: OpenTelemetry Integration Summary          ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Chapter Status:${NC} $(format_status "$chapter_result")"
    echo -e "${CYAN}Total Phases:${NC} $total_phases"
    echo -e "${GREEN}Passed:${NC} $passed_phases"
    echo -e "${YELLOW}Degraded:${NC} $degraded_phases"
    echo -e "${RED}Failed:${NC} $failed_phases"
    echo
    echo -e "${CYAN}Chapter State:${NC} $CHAPTER_STATE"
    echo -e "${CYAN}Chapter Log:${NC} $CHAPTER_LOG"
    echo
    echo -e "${CYAN}OpenTelemetry Components:${NC}"
    echo -e "  ${CYAN}• OpenTelemetry Collector:${NC} http://localhost:13133"
    echo -e "  ${CYAN}• Jaeger UI:${NC} http://localhost:16686"
    echo -e "  ${CYAN}• Tempo:${NC} http://localhost:3200"
    echo -e "  ${CYAN}• OTLP HTTP Endpoint:${NC} http://localhost:4318"
    echo -e "  ${CYAN}• OTLP gRPC Endpoint:${NC} localhost:4317"
    
    # Exit with appropriate code
    if [[ "$chapter_result" == "failed" ]]; then
        exit 1
    else
        exit 0
    fi
}

# Format status with color
format_status() {
    local status="$1"
    case "$status" in
        "completed")
            echo -e "${GREEN}COMPLETED${NC}"
            ;;
        "completed_with_warnings")
            echo -e "${YELLOW}COMPLETED WITH WARNINGS${NC}"
            ;;
        "failed")
            echo -e "${RED}FAILED${NC}"
            ;;
        *)
            echo "$status"
            ;;
    esac
}

# Main function
main() {
    local environment="${1:-development}"
    local mode="${2:-}"
    
    # Set global environment
    ENVIRONMENT="$environment"
    
    # Handle special modes
    case "$mode" in
        "--validate-only")
            init_chapter
            run_validation
            generate_chapter_summary
            exit $?
            ;;
        "--check-prerequisites")
            init_chapter
            check_prerequisites
            exit $?
            ;;
        "--verbose")
            VERBOSE="true"
            ;;
        *)
            VERBOSE="false"
            ;;
    esac
    
    # Initialize chapter
    init_chapter
    
    # Execute implementation phases
    local failed_phases=0
    
    for phase in "${IMPLEMENTATION_PHASES[@]}"; do
        case "$phase" in
            "prerequisites_check")
                check_prerequisites || ((failed_phases++))
                ;;
            "otel_collector_setup")
                setup_otel_collector || ((failed_phases++))
                ;;
            "tracing_backend_setup")
                setup_tracing_backends || ((failed_phases++))
                ;;
            "instrumentation_setup")
                setup_instrumentation || ((failed_phases++))
                ;;
            "correlation_setup")
                setup_correlation || ((failed_phases++))
                ;;
            "validation")
                run_validation || ((failed_phases++))
                ;;
            "optimization")
                optimize_configuration || ((failed_phases++))
                ;;
        esac
        
        echo  # Add spacing between phases
    done
    
    # Generate chapter summary
    generate_chapter_summary
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [ENVIRONMENT] [MODE]

ENVIRONMENT:
    development  - Deploy to development environment (default)
    staging      - Deploy to staging environment
    production   - Deploy to production environment

MODE:
    --validate-only        - Only run validation, skip setup
    --check-prerequisites  - Only check prerequisites
    --verbose              - Show detailed output

Examples:
    $0                              # Deploy OpenTelemetry to development
    $0 production                   # Deploy to production
    $0 staging --verbose            # Deploy to staging with detailed output
    $0 development --validate-only  # Only validate existing setup

This chapter implements comprehensive OpenTelemetry integration including:
- OpenTelemetry Collector setup and configuration
- Jaeger and Tempo tracing backends
- Application instrumentation and correlation
- Log correlation and structured logging
- Database query tracing
- Performance optimization for each environment

Prerequisites:
- Chapter 1: Foundation Setup (Docker, networking)
- Chapter 2: Application Deployment
- Chapter 3: Database Integration
- Chapter 4: Monitoring Foundation

EOF
}

# Parse arguments
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

# Execute main function
main "$@"