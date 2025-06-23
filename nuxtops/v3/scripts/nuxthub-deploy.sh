#!/usr/bin/env bash

# NuxtOps V3 NuxtHub Deployment Script
# Deploy to NuxtHub platform with full observability integration

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
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly DEPLOYMENT_ID="nuxthub_deploy_$(date +%s%N)"
readonly DEPLOYMENT_LOG="${PROJECT_ROOT}/logs/nuxthub-deployments/${DEPLOYMENT_ID}.log"
readonly DEPLOYMENT_STATE="${PROJECT_ROOT}/.nuxthub_deployment_state.json"

# NuxtHub configuration
readonly NUXTHUB_CLI_VERSION="latest"
readonly SUPPORTED_REGIONS=("us-east-1" "eu-west-1" "ap-southeast-1")
readonly SUPPORTED_ENVIRONMENTS=("preview" "production")

# Deployment stages
readonly DEPLOYMENT_STAGES=(
    "prerequisites_check"
    "project_setup"
    "build_optimization"
    "observability_integration"
    "deployment"
    "validation"
    "domain_configuration"
)

# Initialize deployment
init_deployment() {
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║         NuxtOps V3 NuxtHub Deployment                         ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Deployment ID:${NC} ${DEPLOYMENT_ID}"
    echo -e "${CYAN}Target Environment:${NC} ${TARGET_ENVIRONMENT}"
    echo -e "${CYAN}Target Region:${NC} ${TARGET_REGION}"
    echo -e "${CYAN}Timestamp:${NC} $(date +'%Y-%m-%d %H:%M:%S')"
    echo
    
    # Create logging directory
    mkdir -p "$(dirname "$DEPLOYMENT_LOG")"
    exec 1> >(tee -a "$DEPLOYMENT_LOG")
    exec 2>&1
    
    # Initialize deployment state
    echo '{
        "deployment_id": "'"${DEPLOYMENT_ID}"'",
        "start_time": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'",
        "target_environment": "'"${TARGET_ENVIRONMENT}"'",
        "target_region": "'"${TARGET_REGION}"'",
        "stages": [],
        "status": "in_progress"
    }' > "$DEPLOYMENT_STATE"
}

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}━━━ Stage: Prerequisites Check ━━━${NC}"
    
    local stage_result="passed"
    local details=()
    
    # Check Node.js version
    if command -v node &>/dev/null; then
        local node_version=$(node --version)
        local node_major=$(echo "$node_version" | cut -d'.' -f1 | sed 's/v//')
        
        if [[ $node_major -ge 18 ]]; then
            details+=("Node.js version: $node_version (compatible)")
        else
            stage_result="failed"
            details+=("Node.js version: $node_version (incompatible, need >= 18)")
        fi
    else
        stage_result="failed"
        details+=("Node.js: Not installed")
    fi
    
    # Check npm/yarn
    if command -v npm &>/dev/null; then
        local npm_version=$(npm --version)
        details+=("npm version: $npm_version")
    else
        stage_result="failed"
        details+=("npm: Not installed")
    fi
    
    # Check for NuxtHub CLI
    if command -v nuxthub &>/dev/null; then
        local nuxthub_version=$(nuxthub --version 2>/dev/null || echo "unknown")
        details+=("NuxtHub CLI: Installed ($nuxthub_version)")
    else
        echo -e "${YELLOW}Installing NuxtHub CLI...${NC}"
        if npm install -g @nuxthub/cli@$NUXTHUB_CLI_VERSION; then
            details+=("NuxtHub CLI: Installed")
        else
            stage_result="failed"
            details+=("NuxtHub CLI: Installation failed")
        fi
    fi
    
    # Check authentication
    if nuxthub auth whoami &>/dev/null; then
        local user_info=$(nuxthub auth whoami 2>/dev/null || echo "unknown")
        details+=("NuxtHub authentication: Valid ($user_info)")
    else
        stage_result="failed"
        details+=("NuxtHub authentication: Not authenticated (run 'nuxthub auth login')")
    fi
    
    # Check project structure
    if [[ -f "${PROJECT_ROOT}/nuxt.config.ts" || -f "${PROJECT_ROOT}/nuxt.config.js" ]]; then
        details+=("Nuxt configuration: Found")
    else
        stage_result="failed"
        details+=("Nuxt configuration: Not found")
    fi
    
    # Check package.json
    if [[ -f "${PROJECT_ROOT}/package.json" ]]; then
        details+=("package.json: Found")
        
        # Check for required dependencies
        local required_deps=("nuxt" "@nuxthub/core")
        for dep in "${required_deps[@]}"; do
            if jq -e ".dependencies.\"$dep\" // .devDependencies.\"$dep\"" "${PROJECT_ROOT}/package.json" &>/dev/null; then
                details+=("Dependency $dep: Found")
            else
                stage_result="degraded"
                details+=("Dependency $dep: Missing (will be installed)")
            fi
        done
    else
        stage_result="failed"
        details+=("package.json: Not found")
    fi
    
    save_stage_result "prerequisites_check" "$stage_result" "${details[@]}"
    
    [[ "$stage_result" == "passed" ]]
}

# Setup NuxtHub project
setup_project() {
    echo -e "${BLUE}━━━ Stage: Project Setup ━━━${NC}"
    
    local stage_result="passed"
    local details=()
    
    # Install dependencies if needed
    if [[ ! -d "${PROJECT_ROOT}/node_modules" ]]; then
        echo -e "${YELLOW}Installing dependencies...${NC}"
        cd "$PROJECT_ROOT"
        
        if npm ci || npm install; then
            details+=("Dependencies: Installed")
        else
            stage_result="failed"
            details+=("Dependencies: Installation failed")
            save_stage_result "project_setup" "$stage_result" "${details[@]}"
            return 1
        fi
    else
        details+=("Dependencies: Already installed")
    fi
    
    # Add NuxtHub dependencies if missing
    local missing_deps=()
    
    if ! jq -e '.dependencies."@nuxthub/core" // .devDependencies."@nuxthub/core"' "${PROJECT_ROOT}/package.json" &>/dev/null; then
        missing_deps+=("@nuxthub/core")
    fi
    
    if ! jq -e '.dependencies."@nuxthub/kv" // .devDependencies."@nuxthub/kv"' "${PROJECT_ROOT}/package.json" &>/dev/null; then
        missing_deps+=("@nuxthub/kv")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Installing missing NuxtHub dependencies: ${missing_deps[*]}${NC}"
        cd "$PROJECT_ROOT"
        
        if npm install "${missing_deps[@]}"; then
            details+=("NuxtHub dependencies: Installed (${missing_deps[*]})")
        else
            stage_result="degraded"
            details+=("NuxtHub dependencies: Installation failed")
        fi
    else
        details+=("NuxtHub dependencies: Already present")
    fi
    
    # Create or update nuxt.config for NuxtHub
    local nuxt_config="${PROJECT_ROOT}/nuxt.config.ts"
    if [[ ! -f "$nuxt_config" ]]; then
        nuxt_config="${PROJECT_ROOT}/nuxt.config.js"
    fi
    
    if [[ -f "$nuxt_config" ]]; then
        # Backup existing config
        cp "$nuxt_config" "${nuxt_config}.backup.$(date +%s)"
        details+=("Nuxt config: Backed up")
        
        # Check if NuxtHub is already configured
        if grep -q "@nuxthub/core" "$nuxt_config"; then
            details+=("NuxtHub integration: Already configured")
        else
            echo -e "${YELLOW}Adding NuxtHub integration to Nuxt config...${NC}"
            
            # Add NuxtHub module to configuration
            # This is a simplified approach - in practice, you'd want more sophisticated config merging
            if grep -q "modules:" "$nuxt_config"; then
                # Add to existing modules array
                sed -i "s/modules: \[/modules: [\n    '@nuxthub\/core',/" "$nuxt_config"
            else
                # Add modules array
                cat >> "$nuxt_config" << 'EOF'

// NuxtHub integration
export default defineNuxtConfig({
  modules: ['@nuxthub/core'],
  nitro: {
    experimental: {
      wasm: true
    }
  },
  hub: {
    kv: true,
    database: true,
    blob: true
  }
})
EOF
            fi
            
            details+=("NuxtHub integration: Added to configuration")
        fi
    else
        stage_result="failed"
        details+=("Nuxt config: Not found")
    fi
    
    # Create NuxtHub-specific files
    local nuxthub_dir="${PROJECT_ROOT}/.nuxthub"
    mkdir -p "$nuxthub_dir"
    
    # Create environment-specific configuration
    cat > "${nuxthub_dir}/config.json" << EOF
{
  "environments": {
    "preview": {
      "region": "${TARGET_REGION}",
      "kv": true,
      "database": true,
      "blob": true,
      "opentelemetry": {
        "enabled": true,
        "endpoint": "${OTEL_ENDPOINT:-}",
        "headers": {
          "authorization": "${OTEL_AUTH_HEADER:-}"
        }
      }
    },
    "production": {
      "region": "${TARGET_REGION}",
      "kv": true,
      "database": true,
      "blob": true,
      "opentelemetry": {
        "enabled": true,
        "endpoint": "${OTEL_ENDPOINT:-}",
        "headers": {
          "authorization": "${OTEL_AUTH_HEADER:-}"
        }
      }
    }
  }
}
EOF
    
    details+=("NuxtHub configuration: Created")
    
    save_stage_result "project_setup" "$stage_result" "${details[@]}"
    
    [[ "$stage_result" == "passed" ]]
}

# Optimize build for NuxtHub
optimize_build() {
    echo -e "${BLUE}━━━ Stage: Build Optimization ━━━${NC}"
    
    local stage_result="passed"
    local details=()
    
    cd "$PROJECT_ROOT"
    
    # Create optimized build configuration
    cat > ".nuxthub/build-config.json" << EOF
{
  "optimization": {
    "minify": true,
    "treeshaking": true,
    "compression": "gzip",
    "splitChunks": true
  },
  "target": {
    "environment": "${TARGET_ENVIRONMENT}",
    "region": "${TARGET_REGION}",
    "edge": true
  },
  "features": {
    "ssr": true,
    "prerendering": true,
    "nitro": {
      "minify": true,
      "sourceMap": false
    }
  }
}
EOF
    
    details+=("Build configuration: Optimized for ${TARGET_ENVIRONMENT}")
    
    # Add build optimization to package.json scripts
    if jq -e '.scripts.build' package.json &>/dev/null; then
        # Update existing build script
        jq '.scripts.build = "nuxt build --preset=nuxthub"' package.json > package.json.tmp && mv package.json.tmp package.json
        details+=("Build script: Updated for NuxtHub")
    else
        # Add build script
        jq '.scripts.build = "nuxt build --preset=nuxthub"' package.json > package.json.tmp && mv package.json.tmp package.json
        details+=("Build script: Added for NuxtHub")
    fi
    
    # Add NuxtHub-specific scripts
    jq '.scripts."deploy:preview" = "nuxthub deploy --env=preview"' package.json > package.json.tmp && mv package.json.tmp package.json
    jq '.scripts."deploy:production" = "nuxthub deploy --env=production"' package.json > package.json.tmp && mv package.json.tmp package.json
    
    details+=("NuxtHub scripts: Added to package.json")
    
    # Run build
    echo -e "${YELLOW}Building application for NuxtHub...${NC}"
    
    if npm run build; then
        details+=("Application build: Success")
        
        # Check build output
        if [[ -d ".output" ]]; then
            local build_size=$(du -sh .output | cut -f1)
            details+=("Build output size: $build_size")
        fi
    else
        stage_result="failed"
        details+=("Application build: Failed")
    fi
    
    save_stage_result "build_optimization" "$stage_result" "${details[@]}"
    
    [[ "$stage_result" == "passed" ]]
}

# Integrate observability
integrate_observability() {
    echo -e "${BLUE}━━━ Stage: Observability Integration ━━━${NC}"
    
    local stage_result="passed"
    local details=()
    
    # Create NuxtHub-specific OpenTelemetry configuration
    local otel_config_dir="${PROJECT_ROOT}/.nuxthub/observability"
    mkdir -p "$otel_config_dir"
    
    # Create edge-compatible OpenTelemetry configuration
    cat > "${otel_config_dir}/edge-telemetry.js" << 'EOF'
// Edge-compatible OpenTelemetry configuration for NuxtHub
import { trace, metrics } from '@opentelemetry/api'
import { Resource } from '@opentelemetry/resources'
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions'

// Edge-compatible tracer configuration
class EdgeTracer {
  constructor(config = {}) {
    this.config = {
      serviceName: config.serviceName || 'nuxtops-edge',
      serviceVersion: config.serviceVersion || '1.0.0',
      environment: config.environment || 'production',
      endpoint: config.endpoint || process.env.OTEL_EXPORTER_OTLP_ENDPOINT,
      ...config
    }
    
    this.resource = new Resource({
      [SemanticResourceAttributes.SERVICE_NAME]: this.config.serviceName,
      [SemanticResourceAttributes.SERVICE_VERSION]: this.config.serviceVersion,
      [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: this.config.environment,
      [SemanticResourceAttributes.CLOUD_PROVIDER]: 'cloudflare',
      [SemanticResourceAttributes.CLOUD_PLATFORM]: 'cloudflare_workers',
    })
  }
  
  // Create a trace for edge function execution
  async traceEdgeFunction(name, fn, attributes = {}) {
    const tracer = trace.getTracer('nuxtops-edge', '1.0.0')
    
    return tracer.startActiveSpan(name, {
      kind: 1, // SERVER
      attributes: {
        'faas.execution': 'edge',
        'http.route': name,
        ...attributes
      }
    }, async (span) => {
      try {
        const result = await fn(span)
        span.setStatus({ code: 1 }) // OK
        return result
      } catch (error) {
        span.setStatus({
          code: 2, // ERROR
          message: error.message
        })
        span.recordException(error)
        throw error
      } finally {
        span.end()
      }
    })
  }
  
  // Log with trace correlation
  logWithTrace(level, message, meta = {}) {
    const span = trace.getActiveSpan()
    const logEntry = {
      timestamp: new Date().toISOString(),
      level,
      message,
      ...meta
    }
    
    if (span) {
      const spanContext = span.spanContext()
      logEntry.trace_id = spanContext.traceId
      logEntry.span_id = spanContext.spanId
    }
    
    console[level](JSON.stringify(logEntry))
  }
  
  // Record custom metrics
  recordMetric(name, value, attributes = {}) {
    const meter = metrics.getMeter('nuxtops-edge', '1.0.0')
    const counter = meter.createCounter(name)
    counter.add(value, attributes)
  }
}

export default EdgeTracer
export { EdgeTracer }
EOF
    
    details+=("Edge telemetry configuration: Created")
    
    # Create NuxtHub plugin for observability
    local plugins_dir="${PROJECT_ROOT}/plugins"
    mkdir -p "$plugins_dir"
    
    cat > "${plugins_dir}/nuxthub-observability.client.js" << 'EOF'
// NuxtHub client-side observability plugin
import { EdgeTracer } from '~/.nuxthub/observability/edge-telemetry.js'

export default defineNuxtPlugin(() => {
  const config = useRuntimeConfig()
  
  // Initialize edge tracer
  const tracer = new EdgeTracer({
    serviceName: 'nuxtops-client',
    environment: config.public.environment || 'production',
    endpoint: config.public.otelEndpoint
  })
  
  // Add global error tracking
  window.addEventListener('error', (event) => {
    tracer.logWithTrace('error', 'Unhandled error', {
      error: event.error?.message || 'Unknown error',
      filename: event.filename,
      lineno: event.lineno,
      colno: event.colno
    })
  })
  
  // Add performance tracking
  window.addEventListener('load', () => {
    const navigation = performance.getEntriesByType('navigation')[0]
    
    tracer.recordMetric('page_load_time', navigation.loadEventEnd - navigation.fetchStart, {
      page: window.location.pathname
    })
  })
  
  // Provide tracer globally
  return {
    provide: {
      tracer
    }
  }
})
EOF
    
    cat > "${plugins_dir}/nuxthub-observability.server.js" << 'EOF'
// NuxtHub server-side observability plugin
import { EdgeTracer } from '~/.nuxthub/observability/edge-telemetry.js'

export default defineNuxtPlugin(async (nuxtApp) => {
  const config = useRuntimeConfig()
  
  // Initialize edge tracer
  const tracer = new EdgeTracer({
    serviceName: 'nuxtops-server',
    environment: config.environment || 'production',
    endpoint: config.otelEndpoint
  })
  
  // Add request tracing
  nuxtApp.hook('render:route', async (url, result, context) => {
    await tracer.traceEdgeFunction('render:route', async (span) => {
      span.setAttributes({
        'http.url': url,
        'http.method': context.event?.node?.req?.method || 'GET',
        'user_agent': context.event?.node?.req?.headers?.['user-agent'] || 'unknown'
      })
      
      tracer.logWithTrace('info', 'Route rendered', {
        url,
        renderTime: Date.now() - context.event?.node?.req?.timestamp
      })
    })
  })
  
  // Add error tracking
  nuxtApp.hook('app:error', (error) => {
    tracer.logWithTrace('error', 'Application error', {
      error: error.message,
      stack: error.stack
    })
  })
  
  // Provide tracer globally
  return {
    provide: {
      tracer
    }
  }
})
EOF
    
    details+=("NuxtHub observability plugins: Created")
    
    # Update runtime configuration for observability
    local runtime_config="${PROJECT_ROOT}/app.config.ts"
    if [[ ! -f "$runtime_config" ]]; then
        cat > "$runtime_config" << 'EOF'
export default defineAppConfig({
  nuxtIcon: {},
  observability: {
    enabled: true,
    tracing: {
      enabled: true,
      sampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0
    },
    metrics: {
      enabled: true
    },
    logging: {
      level: process.env.NODE_ENV === 'production' ? 'warn' : 'info'
    }
  }
})
EOF
        details+=("App configuration: Created with observability settings")
    else
        details+=("App configuration: Already exists")
    fi
    
    save_stage_result "observability_integration" "$stage_result" "${details[@]}"
    
    [[ "$stage_result" == "passed" ]]
}

# Deploy to NuxtHub
deploy_to_nuxthub() {
    echo -e "${BLUE}━━━ Stage: NuxtHub Deployment ━━━${NC}"
    
    local stage_result="passed"
    local details=()
    
    cd "$PROJECT_ROOT"
    
    # Set deployment environment variables
    export NUXT_PUBLIC_ENVIRONMENT="$TARGET_ENVIRONMENT"
    export NUXT_PUBLIC_REGION="$TARGET_REGION"
    export NUXT_PUBLIC_DEPLOYMENT_ID="$DEPLOYMENT_ID"
    
    # Deploy to NuxtHub
    echo -e "${YELLOW}Deploying to NuxtHub ${TARGET_ENVIRONMENT} environment...${NC}"
    
    local deploy_command="nuxthub deploy"
    
    # Add environment flag
    if [[ "$TARGET_ENVIRONMENT" == "production" ]]; then
        deploy_command="$deploy_command --env=production"
    else
        deploy_command="$deploy_command --env=preview"
    fi
    
    # Add region if specified
    if [[ -n "$TARGET_REGION" ]]; then
        deploy_command="$deploy_command --region=$TARGET_REGION"
    fi
    
    # Add build configuration
    deploy_command="$deploy_command --build-preset=nuxthub"
    
    # Execute deployment
    if $deploy_command; then
        details+=("NuxtHub deployment: Success")
        
        # Get deployment URL
        local deployment_url=$(nuxthub deployments list --env="$TARGET_ENVIRONMENT" --format=json | jq -r '.[0].url' 2>/dev/null || echo "")
        
        if [[ -n "$deployment_url" ]]; then
            details+=("Deployment URL: $deployment_url")
            
            # Save deployment URL to state
            jq --arg url "$deployment_url" '. + {deployment_url: $url}' "$DEPLOYMENT_STATE" > "${DEPLOYMENT_STATE}.tmp" && mv "${DEPLOYMENT_STATE}.tmp" "$DEPLOYMENT_STATE"
        fi
        
        # Get deployment info
        local deployment_info=$(nuxthub deployments list --env="$TARGET_ENVIRONMENT" --format=json | jq -r '.[0]' 2>/dev/null || echo "{}")
        
        if [[ "$deployment_info" != "{}" ]]; then
            local deployment_id_hub=$(echo "$deployment_info" | jq -r '.id' 2>/dev/null || echo "")
            local deployment_size=$(echo "$deployment_info" | jq -r '.size' 2>/dev/null || echo "")
            local deployment_functions=$(echo "$deployment_info" | jq -r '.functions_count' 2>/dev/null || echo "0")
            
            details+=("NuxtHub deployment ID: $deployment_id_hub")
            details+=("Deployment size: $deployment_size")
            details+=("Edge functions: $deployment_functions")
        fi
    else
        stage_result="failed"
        details+=("NuxtHub deployment: Failed")
    fi
    
    save_stage_result "deployment" "$stage_result" "${details[@]}"
    
    [[ "$stage_result" == "passed" ]]
}

# Validate deployment
validate_deployment() {
    echo -e "${BLUE}━━━ Stage: Deployment Validation ━━━${NC}"
    
    local stage_result="passed"
    local details=()
    
    # Get deployment URL from state
    local deployment_url=$(jq -r '.deployment_url // empty' "$DEPLOYMENT_STATE")
    
    if [[ -z "$deployment_url" ]]; then
        # Try to get URL from NuxtHub CLI
        deployment_url=$(nuxthub deployments list --env="$TARGET_ENVIRONMENT" --format=json | jq -r '.[0].url' 2>/dev/null || echo "")
    fi
    
    if [[ -n "$deployment_url" ]]; then
        details+=("Deployment URL: $deployment_url")
        
        # Test basic connectivity
        echo -e "${YELLOW}Testing deployment connectivity...${NC}"
        
        local max_attempts=10
        local attempt=0
        local connected=false
        
        while [ $attempt -lt $max_attempts ]; do
            if curl -s --max-time 10 "$deployment_url" &>/dev/null; then
                connected=true
                break
            fi
            
            sleep 10
            ((attempt++))
        done
        
        if $connected; then
            details+=("Connectivity test: PASSED")
            
            # Test health endpoint
            local health_status=$(curl -s "${deployment_url}/api/health" | jq -r '.status' 2>/dev/null || echo "unknown")
            if [[ "$health_status" == "ok" || "$health_status" == "healthy" ]]; then
                details+=("Health check: PASSED")
            else
                stage_result="degraded"
                details+=("Health check: FAILED (status: $health_status)")
            fi
            
            # Test performance
            local response_time=$(curl -s -o /dev/null -w "%{time_total}" "$deployment_url" 2>/dev/null || echo "0")
            details+=("Response time: ${response_time}s")
            
            if (( $(echo "$response_time < 2.0" | bc -l) )); then
                details+=("Performance test: PASSED")
            else
                stage_result="degraded"
                details+=("Performance test: SLOW (>${response_time}s)")
            fi
            
            # Test OpenTelemetry integration
            if curl -s "${deployment_url}/api/telemetry" &>/dev/null; then
                details+=("OpenTelemetry endpoint: Available")
            else
                details+=("OpenTelemetry endpoint: Not available")
            fi
        else
            stage_result="failed"
            details+=("Connectivity test: FAILED (timeout after ${max_attempts} attempts)")
        fi
    else
        stage_result="failed"
        details+=("Deployment URL: Not found")
    fi
    
    # Validate NuxtHub features
    echo -e "${YELLOW}Validating NuxtHub features...${NC}"
    
    # Check KV store
    if nuxthub kv list --env="$TARGET_ENVIRONMENT" &>/dev/null; then
        details+=("KV store: Available")
    else
        details+=("KV store: Not available or not accessible")
    fi
    
    # Check database
    if nuxthub database list --env="$TARGET_ENVIRONMENT" &>/dev/null; then
        details+=("Database: Available")
    else
        details+=("Database: Not available or not accessible")
    fi
    
    # Check blob storage
    if nuxthub blob list --env="$TARGET_ENVIRONMENT" &>/dev/null; then
        details+=("Blob storage: Available")
    else
        details+=("Blob storage: Not available or not accessible")
    fi
    
    save_stage_result "validation" "$stage_result" "${details[@]}"
    
    [[ "$stage_result" == "passed" || "$stage_result" == "degraded" ]]
}

# Configure custom domain
configure_domain() {
    echo -e "${BLUE}━━━ Stage: Domain Configuration ━━━${NC}"
    
    local stage_result="passed"
    local details=()
    
    if [[ -n "$CUSTOM_DOMAIN" ]]; then
        echo -e "${YELLOW}Configuring custom domain: $CUSTOM_DOMAIN${NC}"
        
        # Add custom domain to NuxtHub
        if nuxthub domains add "$CUSTOM_DOMAIN" --env="$TARGET_ENVIRONMENT"; then
            details+=("Custom domain: Added ($CUSTOM_DOMAIN)")
            
            # Wait for domain verification
            echo -e "${YELLOW}Waiting for domain verification...${NC}"
            
            local max_attempts=30
            local attempt=0
            local verified=false
            
            while [ $attempt -lt $max_attempts ]; do
                local domain_status=$(nuxthub domains list --env="$TARGET_ENVIRONMENT" --format=json | jq -r '.[] | select(.domain == "'"$CUSTOM_DOMAIN"'") | .status' 2>/dev/null || echo "")
                
                if [[ "$domain_status" == "active" ]]; then
                    verified=true
                    break
                elif [[ "$domain_status" == "failed" ]]; then
                    break
                fi
                
                sleep 10
                ((attempt++))
            done
            
            if $verified; then
                details+=("Domain verification: Success")
                details+=("Custom domain URL: https://$CUSTOM_DOMAIN")
            else
                stage_result="degraded"
                details+=("Domain verification: Failed or timeout")
            fi
        else
            stage_result="degraded"
            details+=("Custom domain: Failed to add")
        fi
    else
        details+=("Custom domain: Not specified (using default NuxtHub domain)")
    fi
    
    save_stage_result "domain_configuration" "$stage_result" "${details[@]}"
    
    [[ "$stage_result" == "passed" || "$stage_result" == "degraded" ]]
}

# Save stage result
save_stage_result() {
    local stage_name="$1"
    local result="$2"
    shift 2
    local details=("$@")
    
    # Create stage result entry
    local stage_entry=$(jq -n \
        --arg name "$stage_name" \
        --arg res "$result" \
        --argjson det "$(printf '%s\n' "${details[@]}" | jq -R . | jq -s .)" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            name: $name,
            result: $res,
            details: $det,
            timestamp: $ts
        }')
    
    # Update deployment state
    jq ".stages += [$stage_entry]" "$DEPLOYMENT_STATE" > "${DEPLOYMENT_STATE}.tmp" && mv "${DEPLOYMENT_STATE}.tmp" "$DEPLOYMENT_STATE"
    
    # Display result
    if [[ "$result" == "passed" ]]; then
        echo -e "${GREEN}✓ Stage ${stage_name}: ${result}${NC}"
    elif [[ "$result" == "degraded" ]]; then
        echo -e "${YELLOW}⚠ Stage ${stage_name}: ${result}${NC}"
    else
        echo -e "${RED}✗ Stage ${stage_name}: ${result}${NC}"
    fi
    
    # Display details if verbose
    if [[ "${VERBOSE}" == "true" ]]; then
        for detail in "${details[@]}"; do
            echo "  $detail"
        done
    fi
}

# Generate deployment summary
generate_deployment_summary() {
    local total_stages=$(jq '.stages | length' "$DEPLOYMENT_STATE")
    local passed_stages=$(jq '[.stages[] | select(.result == "passed")] | length' "$DEPLOYMENT_STATE")
    local degraded_stages=$(jq '[.stages[] | select(.result == "degraded")] | length' "$DEPLOYMENT_STATE")
    local failed_stages=$(jq '[.stages[] | select(.result == "failed")] | length' "$DEPLOYMENT_STATE")
    
    # Determine overall result
    local overall_result="success"
    if [[ $failed_stages -gt 0 ]]; then
        overall_result="failed"
    elif [[ $degraded_stages -gt 0 ]]; then
        overall_result="success_with_warnings"
    fi
    
    # Update deployment state
    jq \
        --arg end_time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg status "$overall_result" \
        --argjson total "$total_stages" \
        --argjson passed "$passed_stages" \
        --argjson degraded "$degraded_stages" \
        --argjson failed "$failed_stages" \
        '. + {
            end_time: $end_time,
            status: $status,
            summary: {
                total_stages: $total,
                passed: $passed,
                degraded: $degraded,
                failed: $failed
            }
        }' "$DEPLOYMENT_STATE" > "${DEPLOYMENT_STATE}.tmp" && mv "${DEPLOYMENT_STATE}.tmp" "$DEPLOYMENT_STATE"
    
    # Display summary
    echo
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║         NuxtHub Deployment Summary                            ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Overall Result:${NC} $(format_result "$overall_result")"
    echo -e "${CYAN}Target Environment:${NC} $TARGET_ENVIRONMENT"
    echo -e "${CYAN}Target Region:${NC} $TARGET_REGION"
    echo -e "${CYAN}Deployment ID:${NC} $DEPLOYMENT_ID"
    echo
    echo -e "${CYAN}Stages Summary:${NC}"
    echo -e "  ${CYAN}Total:${NC} $total_stages"
    echo -e "  ${GREEN}Passed:${NC} $passed_stages"
    echo -e "  ${YELLOW}Degraded:${NC} $degraded_stages"
    echo -e "  ${RED}Failed:${NC} $failed_stages"
    echo
    
    # Display deployment URL if available
    local deployment_url=$(jq -r '.deployment_url // empty' "$DEPLOYMENT_STATE")
    if [[ -n "$deployment_url" ]]; then
        echo -e "${CYAN}Deployment URL:${NC} $deployment_url"
    fi
    
    echo -e "${CYAN}Deployment Log:${NC} $DEPLOYMENT_LOG"
    echo -e "${CYAN}Deployment State:${NC} $DEPLOYMENT_STATE"
    
    # Exit with appropriate code
    if [[ "$overall_result" == "failed" ]]; then
        exit 1
    else
        exit 0
    fi
}

# Format result with color
format_result() {
    local result="$1"
    case "$result" in
        "success")
            echo -e "${GREEN}SUCCESS${NC}"
            ;;
        "success_with_warnings")
            echo -e "${YELLOW}SUCCESS WITH WARNINGS${NC}"
            ;;
        "failed")
            echo -e "${RED}FAILED${NC}"
            ;;
        *)
            echo "$result"
            ;;
    esac
}

# Main function
main() {
    local environment="${1:-preview}"
    local region="${2:-us-east-1}"
    local custom_domain="${3:-}"
    local verbose="${4:-}"
    
    # Validate environment
    if [[ ! " ${SUPPORTED_ENVIRONMENTS[*]} " =~ " ${environment} " ]]; then
        echo -e "${RED}Error: Unsupported environment '$environment'${NC}"
        echo "Supported environments: ${SUPPORTED_ENVIRONMENTS[*]}"
        exit 1
    fi
    
    # Validate region
    if [[ ! " ${SUPPORTED_REGIONS[*]} " =~ " ${region} " ]]; then
        echo -e "${RED}Error: Unsupported region '$region'${NC}"
        echo "Supported regions: ${SUPPORTED_REGIONS[*]}"
        exit 1
    fi
    
    # Set global variables
    TARGET_ENVIRONMENT="$environment"
    TARGET_REGION="$region"
    CUSTOM_DOMAIN="$custom_domain"
    
    # Set verbosity
    VERBOSE="false"
    if [[ "$verbose" == "--verbose" || "$verbose" == "-v" ]]; then
        VERBOSE="true"
    fi
    
    # Initialize deployment
    init_deployment
    
    # Execute deployment stages
    local failed_stages=0
    
    for stage in "${DEPLOYMENT_STAGES[@]}"; do
        case "$stage" in
            "prerequisites_check")
                check_prerequisites || ((failed_stages++))
                ;;
            "project_setup")
                setup_project || ((failed_stages++))
                ;;
            "build_optimization")
                optimize_build || ((failed_stages++))
                ;;
            "observability_integration")
                integrate_observability || ((failed_stages++))
                ;;
            "deployment")
                deploy_to_nuxthub || ((failed_stages++))
                ;;
            "validation")
                validate_deployment || ((failed_stages++))
                ;;
            "domain_configuration")
                configure_domain || ((failed_stages++))
                ;;
        esac
        
        echo  # Add spacing between stages
    done
    
    # Generate deployment summary
    generate_deployment_summary
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [ENVIRONMENT] [REGION] [CUSTOM_DOMAIN] [OPTIONS]

ENVIRONMENT:
    preview     - Deploy to preview environment (default)
    production  - Deploy to production environment

REGION:
    us-east-1      - US East (default)
    eu-west-1      - Europe West
    ap-southeast-1 - Asia Pacific Southeast

CUSTOM_DOMAIN:
    Optional custom domain for the deployment

OPTIONS:
    --verbose, -v  - Show detailed deployment output
    --help         - Show this help message

Examples:
    $0                                    # Deploy to preview in us-east-1
    $0 production                         # Deploy to production in us-east-1
    $0 production eu-west-1               # Deploy to production in eu-west-1
    $0 production us-east-1 example.com   # Deploy with custom domain
    $0 preview us-east-1 "" --verbose     # Verbose preview deployment

Prerequisites:
    - Node.js 18+ installed
    - NuxtHub CLI authenticated (nuxthub auth login)
    - Valid Nuxt.js project
    - @nuxthub/core dependency

This script deploys your NuxtOps application to NuxtHub with:
- Optimized edge-compatible builds
- Integrated OpenTelemetry observability
- KV store, database, and blob storage
- Custom domain configuration
- Performance validation

EOF
}

# Parse arguments
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

# Execute main function
main "$@"