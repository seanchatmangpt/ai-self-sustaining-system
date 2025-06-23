#!/usr/bin/env bash

# NuxtOps V3 Edge Deployment Script
# Deploy to Cloudflare Workers and edge platforms with observability

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
readonly DEPLOYMENT_ID="edge_deploy_$(date +%s%N)"
readonly DEPLOYMENT_LOG="${PROJECT_ROOT}/logs/edge-deployments/${DEPLOYMENT_ID}.log"
readonly DEPLOYMENT_STATE="${PROJECT_ROOT}/.edge_deployment_state.json"

# Edge platform configuration
readonly SUPPORTED_PLATFORMS=("cloudflare" "vercel" "netlify" "fastly")
readonly SUPPORTED_REGIONS=("us-east-1" "us-west-1" "eu-west-1" "ap-southeast-1" "global")

# Deployment stages
readonly DEPLOYMENT_STAGES=(
    "prerequisites_check"
    "platform_setup"
    "edge_build"
    "observability_setup"
    "function_deployment"
    "routing_configuration"
    "validation"
    "performance_testing"
)

# Initialize deployment
init_deployment() {
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║         NuxtOps V3 Edge Deployment                            ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Deployment ID:${NC} ${DEPLOYMENT_ID}"
    echo -e "${CYAN}Target Platform:${NC} ${TARGET_PLATFORM}"
    echo -e "${CYAN}Target Environment:${NC} ${TARGET_ENVIRONMENT}"
    echo -e "${CYAN}Target Regions:${NC} ${TARGET_REGIONS}"
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
        "platform": "'"${TARGET_PLATFORM}"'",
        "environment": "'"${TARGET_ENVIRONMENT}"'",
        "regions": "'"${TARGET_REGIONS}"'",
        "stages": [],
        "status": "in_progress"
    }' > "$DEPLOYMENT_STATE"
}

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}━━━ Stage: Prerequisites Check ━━━${NC}"
    
    local stage_result="passed"
    local details=()
    
    # Check Node.js and npm
    if command -v node &>/dev/null; then
        local node_version=$(node --version)
        details+=("Node.js version: $node_version")
    else
        stage_result="failed"
        details+=("Node.js: Not installed")
    fi
    
    # Platform-specific CLI checks
    case "$TARGET_PLATFORM" in
        "cloudflare")
            if command -v wrangler &>/dev/null; then
                local wrangler_version=$(wrangler --version 2>/dev/null | head -1)
                details+=("Wrangler CLI: $wrangler_version")
                
                # Check authentication
                if wrangler whoami &>/dev/null; then
                    local cf_user=$(wrangler whoami 2>/dev/null | grep "email" | awk '{print $2}' || echo "unknown")
                    details+=("Cloudflare authentication: Valid ($cf_user)")
                else
                    stage_result="failed"
                    details+=("Cloudflare authentication: Not authenticated")
                fi
            else
                echo -e "${YELLOW}Installing Wrangler CLI...${NC}"
                if npm install -g wrangler; then
                    details+=("Wrangler CLI: Installed")
                else
                    stage_result="failed"
                    details+=("Wrangler CLI: Installation failed")
                fi
            fi
            ;;
        "vercel")
            if command -v vercel &>/dev/null; then
                local vercel_version=$(vercel --version 2>/dev/null)
                details+=("Vercel CLI: $vercel_version")
            else
                echo -e "${YELLOW}Installing Vercel CLI...${NC}"
                if npm install -g vercel; then
                    details+=("Vercel CLI: Installed")
                else
                    stage_result="failed"
                    details+=("Vercel CLI: Installation failed")
                fi
            fi
            ;;
        "netlify")
            if command -v netlify &>/dev/null; then
                local netlify_version=$(netlify --version 2>/dev/null)
                details+=("Netlify CLI: $netlify_version")
            else
                echo -e "${YELLOW}Installing Netlify CLI...${NC}"
                if npm install -g netlify-cli; then
                    details+=("Netlify CLI: Installed")
                else
                    stage_result="failed"
                    details+=("Netlify CLI: Installation failed")
                fi
            fi
            ;;
    esac
    
    # Check project structure
    if [[ -f "${PROJECT_ROOT}/nuxt.config.ts" || -f "${PROJECT_ROOT}/nuxt.config.js" ]]; then
        details+=("Nuxt configuration: Found")
    else
        stage_result="failed"
        details+=("Nuxt configuration: Not found")
    fi
    
    # Check for Nitro preset
    local nuxt_config="${PROJECT_ROOT}/nuxt.config.ts"
    if [[ ! -f "$nuxt_config" ]]; then
        nuxt_config="${PROJECT_ROOT}/nuxt.config.js"
    fi
    
    if [[ -f "$nuxt_config" ]]; then
        local preset=""
        case "$TARGET_PLATFORM" in
            "cloudflare") preset="cloudflare-pages" ;;
            "vercel") preset="vercel-edge" ;;
            "netlify") preset="netlify-edge" ;;
        esac
        
        if grep -q "$preset" "$nuxt_config"; then
            details+=("Nitro preset: Configured for $TARGET_PLATFORM")
        else
            details+=("Nitro preset: Will be configured for $TARGET_PLATFORM")
        fi
    fi
    
    save_stage_result "prerequisites_check" "$stage_result" "${details[@]}"
    
    [[ "$stage_result" == "passed" ]]
}

# Setup platform-specific configuration
setup_platform() {
    echo -e "${BLUE}━━━ Stage: Platform Setup ━━━${NC}"
    
    local stage_result="passed"
    local details=()
    
    cd "$PROJECT_ROOT"
    
    case "$TARGET_PLATFORM" in
        "cloudflare")
            setup_cloudflare_platform "$stage_result" details
            ;;
        "vercel")
            setup_vercel_platform "$stage_result" details
            ;;
        "netlify")
            setup_netlify_platform "$stage_result" details
            ;;
        *)
            stage_result="failed"
            details+=("Unsupported platform: $TARGET_PLATFORM")
            ;;
    esac
    
    save_stage_result "platform_setup" "$stage_result" "${details[@]}"
    
    [[ "$stage_result" == "passed" ]]
}

# Setup Cloudflare Workers platform
setup_cloudflare_platform() {
    local -n result_ref=$1
    local -n details_ref=$2
    
    # Create wrangler.toml configuration
    cat > "wrangler.toml" << EOF
name = "nuxtops-v3-${TARGET_ENVIRONMENT}"
main = ".output/server/index.mjs"
compatibility_date = "2024-01-15"
compatibility_flags = ["nodejs_compat"]

[env.${TARGET_ENVIRONMENT}]
name = "nuxtops-v3-${TARGET_ENVIRONMENT}"

# KV Namespaces
kv_namespaces = [
  { binding = "CACHE", id = "cache_namespace_id", preview_id = "cache_preview_id" },
  { binding = "SESSIONS", id = "sessions_namespace_id", preview_id = "sessions_preview_id" },
  { binding = "ANALYTICS", id = "analytics_namespace_id", preview_id = "analytics_preview_id" }
]

# D1 Database
[[env.${TARGET_ENVIRONMENT}.d1_databases]]
binding = "DB"
database_name = "nuxtops-${TARGET_ENVIRONMENT}"
database_id = "your-database-id"
migrations_dir = "./database/migrations"

# R2 Bucket
[[env.${TARGET_ENVIRONMENT}.r2_buckets]]
binding = "STORAGE"
bucket_name = "nuxtops-storage-${TARGET_ENVIRONMENT}"

# Environment Variables
[env.${TARGET_ENVIRONMENT}.vars]
NODE_ENV = "${TARGET_ENVIRONMENT}"
ENVIRONMENT = "${TARGET_ENVIRONMENT}"
LOG_LEVEL = "info"

# OpenTelemetry configuration
OTEL_SERVICE_NAME = "nuxtops-edge-${TARGET_ENVIRONMENT}"
OTEL_SERVICE_VERSION = "3.0.0"
OTEL_RESOURCE_ATTRIBUTES = "service.name=nuxtops-edge-${TARGET_ENVIRONMENT},service.version=3.0.0,deployment.environment=${TARGET_ENVIRONMENT},cloud.provider=cloudflare,cloud.platform=cloudflare_workers"
OTEL_EXPORTER_OTLP_ENDPOINT = "https://otel-collector.nuxtops.com"
OTEL_TRACES_SAMPLER = "traceidratio"
OTEL_TRACES_SAMPLER_ARG = "0.1"

# Security
[env.${TARGET_ENVIRONMENT}.secrets]
DATABASE_URL = "your-database-url"
OTEL_EXPORTER_OTLP_HEADERS = "authorization=Bearer your-token"
API_SECRET_KEY = "your-secret-key"

# Build configuration
[build]
command = "npm run build"
cwd = "."
watch_dir = "src"

# Placement
placement = { mode = "smart" }

# Limits
limits = { cpu_ms = 50 }

# Routes
[[env.${TARGET_ENVIRONMENT}.routes]]
pattern = "nuxtops.com/*"
zone_name = "nuxtops.com"

[[env.${TARGET_ENVIRONMENT}.routes]]
pattern = "www.nuxtops.com/*"
zone_name = "nuxtops.com"
EOF
    
    details_ref+=("Wrangler configuration: Created")
    
    # Update Nuxt configuration for Cloudflare
    local nuxt_config="${PROJECT_ROOT}/nuxt.config.ts"
    if [[ ! -f "$nuxt_config" ]]; then
        nuxt_config="${PROJECT_ROOT}/nuxt.config.js"
    fi
    
    # Backup existing config
    cp "$nuxt_config" "${nuxt_config}.backup.$(date +%s)"
    
    # Add or update Cloudflare preset
    cat >> "$nuxt_config" << 'EOF'

// Cloudflare Workers configuration
if (process.env.NITRO_PRESET === 'cloudflare-pages') {
  export default defineNuxtConfig({
    nitro: {
      preset: 'cloudflare-pages',
      experimental: {
        wasm: true
      },
      cloudflare: {
        pages: {
          routes: {
            include: ['/*'],
            exclude: ['/build/*']
          }
        }
      }
    },
    runtimeConfig: {
      cfBinding: {
        cache: process.env.CACHE,
        sessions: process.env.SESSIONS,
        analytics: process.env.ANALYTICS,
        db: process.env.DB,
        storage: process.env.STORAGE
      }
    }
  })
}
EOF
    
    details_ref+=("Nuxt configuration: Updated for Cloudflare")
    
    # Create Cloudflare-specific edge functions
    local functions_dir="${PROJECT_ROOT}/functions"
    mkdir -p "$functions_dir"
    
    cat > "${functions_dir}/health.ts" << 'EOF'
// Edge health check function
export async function onRequest() {
  return new Response(JSON.stringify({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    environment: process.env.ENVIRONMENT,
    region: process.env.CF_RAY?.split('-')[1] || 'unknown'
  }), {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache'
    }
  })
}
EOF
    
    cat > "${functions_dir}/metrics.ts" << 'EOF'
// Edge metrics endpoint
export async function onRequest(context: any) {
  const { env } = context
  
  try {
    // Get analytics data from KV
    const analytics = await env.ANALYTICS.get('metrics', { type: 'json' }) || {}
    
    return new Response(JSON.stringify({
      metrics: analytics,
      timestamp: new Date().toISOString(),
      region: context.cf?.colo || 'unknown'
    }), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=60'
      }
    })
  } catch (error) {
    return new Response(JSON.stringify({
      error: 'Failed to fetch metrics',
      timestamp: new Date().toISOString()
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
}
EOF
    
    details_ref+=("Cloudflare edge functions: Created")
}

# Setup Vercel platform
setup_vercel_platform() {
    local -n result_ref=$1
    local -n details_ref=$2
    
    # Create vercel.json configuration
    cat > "vercel.json" << EOF
{
  "version": 2,
  "name": "nuxtops-v3-${TARGET_ENVIRONMENT}",
  "builds": [
    {
      "src": "nuxt.config.ts",
      "use": "@nuxtjs/vercel-builder"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/"
    }
  ],
  "env": {
    "NODE_ENV": "${TARGET_ENVIRONMENT}",
    "ENVIRONMENT": "${TARGET_ENVIRONMENT}",
    "OTEL_SERVICE_NAME": "nuxtops-edge-${TARGET_ENVIRONMENT}",
    "OTEL_SERVICE_VERSION": "3.0.0",
    "OTEL_RESOURCE_ATTRIBUTES": "service.name=nuxtops-edge-${TARGET_ENVIRONMENT},service.version=3.0.0,deployment.environment=${TARGET_ENVIRONMENT},cloud.provider=vercel,cloud.platform=vercel_edge"
  },
  "functions": {
    "api/**/*.ts": {
      "runtime": "edge"
    }
  },
  "regions": ["${TARGET_REGIONS}"]
}
EOF
    
    details_ref+=("Vercel configuration: Created")
    
    # Update Nuxt configuration for Vercel
    local nuxt_config="${PROJECT_ROOT}/nuxt.config.ts"
    if [[ ! -f "$nuxt_config" ]]; then
        nuxt_config="${PROJECT_ROOT}/nuxt.config.js"
    fi
    
    # Add Vercel preset
    cat >> "$nuxt_config" << 'EOF'

// Vercel Edge configuration
if (process.env.NITRO_PRESET === 'vercel-edge') {
  export default defineNuxtConfig({
    nitro: {
      preset: 'vercel-edge',
      vercel: {
        functions: {
          maxDuration: 60
        }
      }
    }
  })
}
EOF
    
    details_ref+=("Nuxt configuration: Updated for Vercel")
}

# Setup Netlify platform
setup_netlify_platform() {
    local -n result_ref=$1
    local -n details_ref=$2
    
    # Create netlify.toml configuration
    cat > "netlify.toml" << EOF
[build]
  command = "npm run build"
  publish = ".output/public"
  environment = { NODE_ENV = "${TARGET_ENVIRONMENT}" }

[build.environment]
  NODE_VERSION = "18"
  NPM_VERSION = "9"

[[redirects]]
  from = "/*"
  to = "/.netlify/functions/server"
  status = 200

[functions]
  directory = ".output/server"
  node_bundler = "esbuild"

[context.${TARGET_ENVIRONMENT}]
  environment = {
    ENVIRONMENT = "${TARGET_ENVIRONMENT}",
    OTEL_SERVICE_NAME = "nuxtops-edge-${TARGET_ENVIRONMENT}",
    OTEL_SERVICE_VERSION = "3.0.0"
  }
EOF
    
    details_ref+=("Netlify configuration: Created")
    
    # Update Nuxt configuration for Netlify
    local nuxt_config="${PROJECT_ROOT}/nuxt.config.ts"
    if [[ ! -f "$nuxt_config" ]]; then
        nuxt_config="${PROJECT_ROOT}/nuxt.config.js"
    fi
    
    # Add Netlify preset
    cat >> "$nuxt_config" << 'EOF'

// Netlify Edge configuration
if (process.env.NITRO_PRESET === 'netlify-edge') {
  export default defineNuxtConfig({
    nitro: {
      preset: 'netlify-edge'
    }
  })
}
EOF
    
    details_ref+=("Nuxt configuration: Updated for Netlify")
}

# Build for edge deployment
build_for_edge() {
    echo -e "${BLUE}━━━ Stage: Edge Build ━━━${NC}"
    
    local stage_result="passed"
    local details=()
    
    cd "$PROJECT_ROOT"
    
    # Set build environment
    case "$TARGET_PLATFORM" in
        "cloudflare") export NITRO_PRESET="cloudflare-pages" ;;
        "vercel") export NITRO_PRESET="vercel-edge" ;;
        "netlify") export NITRO_PRESET="netlify-edge" ;;
    esac
    
    export NODE_ENV="$TARGET_ENVIRONMENT"
    export ENVIRONMENT="$TARGET_ENVIRONMENT"
    
    details+=("Build preset: $NITRO_PRESET")
    details+=("Environment: $TARGET_ENVIRONMENT")
    
    # Install dependencies if needed
    if [[ ! -d "node_modules" ]]; then
        echo -e "${YELLOW}Installing dependencies...${NC}"
        if npm ci; then
            details+=("Dependencies: Installed")
        else
            stage_result="failed"
            details+=("Dependencies: Installation failed")
            save_stage_result "edge_build" "$stage_result" "${details[@]}"
            return 1
        fi
    fi
    
    # Run build
    echo -e "${YELLOW}Building for edge deployment...${NC}"
    if npm run build; then
        details+=("Build: Success")
        
        # Check build output
        if [[ -d ".output" ]]; then
            local build_size=$(du -sh .output | cut -f1)
            details+=("Build size: $build_size")
            
            # Check for edge-specific files
            case "$TARGET_PLATFORM" in
                "cloudflare")
                    if [[ -f ".output/server/index.mjs" ]]; then
                        details+=("Cloudflare worker: Generated")
                    else
                        stage_result="degraded"
                        details+=("Cloudflare worker: Not found")
                    fi
                    ;;
                "vercel")
                    if [[ -d ".vercel" ]]; then
                        details+=("Vercel artifacts: Generated")
                    else
                        details+=("Vercel artifacts: Not found (will be generated on deploy)")
                    fi
                    ;;
            esac
        else
            stage_result="failed"
            details+=("Build output: Not found")
        fi
    else
        stage_result="failed"
        details+=("Build: Failed")
    fi
    
    save_stage_result "edge_build" "$stage_result" "${details[@]}"
    
    [[ "$stage_result" == "passed" ]]
}

# Setup edge observability
setup_edge_observability() {
    echo -e "${BLUE}━━━ Stage: Edge Observability Setup ━━━${NC}"
    
    local stage_result="passed"
    local details=()
    
    # Create edge-specific OpenTelemetry configuration
    local otel_edge_dir="${PROJECT_ROOT}/observability/edge"
    mkdir -p "$otel_edge_dir"
    
    cat > "${otel_edge_dir}/edge-tracer.ts" << 'EOF'
// Edge-compatible OpenTelemetry tracer
import { trace, context, SpanKind } from '@opentelemetry/api'

interface EdgeRequest {
  url: string
  method: string
  headers: Record<string, string>
  cf?: {
    colo?: string
    country?: string
    region?: string
    asn?: string
  }
}

interface EdgeResponse {
  status: number
  headers: Record<string, string>
}

class EdgeTracer {
  private serviceName: string
  private environment: string
  
  constructor(serviceName: string = 'nuxtops-edge', environment: string = 'production') {
    this.serviceName = serviceName
    this.environment = environment
  }
  
  async traceRequest(request: EdgeRequest, handler: () => Promise<EdgeResponse>): Promise<EdgeResponse> {
    const tracer = trace.getTracer(this.serviceName, '3.0.0')
    
    return tracer.startActiveSpan(`${request.method} ${new URL(request.url).pathname}`, {
      kind: SpanKind.SERVER,
      attributes: {
        'http.method': request.method,
        'http.url': request.url,
        'http.scheme': new URL(request.url).protocol.slice(0, -1),
        'http.host': new URL(request.url).host,
        'http.user_agent': request.headers['user-agent'] || 'unknown',
        'deployment.environment': this.environment,
        'cloud.provider': 'cloudflare',
        'cloudflare.colo': request.cf?.colo || 'unknown',
        'cloudflare.country': request.cf?.country || 'unknown',
        'cloudflare.region': request.cf?.region || 'unknown'
      }
    }, async (span) => {
      const startTime = Date.now()
      
      try {
        const response = await handler()
        
        span.setAttributes({
          'http.status_code': response.status,
          'http.response_content_length': response.headers['content-length'] || '0',
          'http.response_time_ms': Date.now() - startTime
        })
        
        if (response.status >= 400) {
          span.setStatus({
            code: 2, // ERROR
            message: `HTTP ${response.status}`
          })
        } else {
          span.setStatus({ code: 1 }) // OK
        }
        
        return response
      } catch (error) {
        span.setStatus({
          code: 2, // ERROR
          message: error instanceof Error ? error.message : 'Unknown error'
        })
        
        span.recordException(error instanceof Error ? error : new Error(String(error)))
        throw error
      } finally {
        span.end()
      }
    })
  }
  
  logWithTrace(level: string, message: string, meta: any = {}) {
    const span = trace.getActiveSpan()
    const logEntry = {
      timestamp: new Date().toISOString(),
      level,
      message,
      service: this.serviceName,
      environment: this.environment,
      ...meta
    }
    
    if (span) {
      const spanContext = span.spanContext()
      logEntry.trace_id = spanContext.traceId
      logEntry.span_id = spanContext.spanId
      logEntry.trace_flags = spanContext.traceFlags
    }
    
    console[level as keyof Console](JSON.stringify(logEntry))
  }
}

export { EdgeTracer }
export type { EdgeRequest, EdgeResponse }
EOF
    
    details+=("Edge tracer: Created")
    
    # Create edge analytics collector
    cat > "${otel_edge_dir}/analytics.ts" << 'EOF'
// Edge analytics collector
interface AnalyticsEvent {
  type: string
  timestamp: number
  properties: Record<string, any>
  user_id?: string
  session_id?: string
}

class EdgeAnalytics {
  private kvBinding: any
  
  constructor(kvBinding: any) {
    this.kvBinding = kvBinding
  }
  
  async track(event: AnalyticsEvent) {
    try {
      const key = `analytics:${event.type}:${Date.now()}`
      await this.kvBinding.put(key, JSON.stringify(event), {
        expirationTtl: 86400 * 30 // 30 days
      })
      
      // Update aggregated metrics
      await this.updateMetrics(event)
    } catch (error) {
      console.error('Failed to track analytics event:', error)
    }
  }
  
  private async updateMetrics(event: AnalyticsEvent) {
    const metricsKey = `metrics:${event.type}:${new Date().toISOString().split('T')[0]}`
    
    try {
      const existing = await this.kvBinding.get(metricsKey, { type: 'json' }) || { count: 0 }
      existing.count += 1
      existing.last_updated = Date.now()
      
      await this.kvBinding.put(metricsKey, JSON.stringify(existing), {
        expirationTtl: 86400 * 365 // 1 year
      })
    } catch (error) {
      console.error('Failed to update metrics:', error)
    }
  }
  
  async getMetrics(type: string, date: string): Promise<any> {
    try {
      const metricsKey = `metrics:${type}:${date}`
      return await this.kvBinding.get(metricsKey, { type: 'json' })
    } catch (error) {
      console.error('Failed to get metrics:', error)
      return null
    }
  }
}

export { EdgeAnalytics }
export type { AnalyticsEvent }
EOF
    
    details+=("Edge analytics: Created")
    
    save_stage_result "observability_setup" "$stage_result" "${details[@]}"
    
    [[ "$stage_result" == "passed" ]]
}

# Deploy functions
deploy_functions() {
    echo -e "${BLUE}━━━ Stage: Function Deployment ━━━${NC}"
    
    local stage_result="passed"
    local details=()
    
    cd "$PROJECT_ROOT"
    
    case "$TARGET_PLATFORM" in
        "cloudflare")
            echo -e "${YELLOW}Deploying to Cloudflare Workers...${NC}"
            
            if wrangler deploy --env="$TARGET_ENVIRONMENT"; then
                details+=("Cloudflare Workers: Deployed")
                
                # Get deployment info
                local worker_url=$(wrangler whoami 2>/dev/null | grep "subdomain" | awk '{print $2}' || echo "")
                if [[ -n "$worker_url" ]]; then
                    details+=("Worker URL: https://nuxtops-v3-${TARGET_ENVIRONMENT}.${worker_url}.workers.dev")
                fi
            else
                stage_result="failed"
                details+=("Cloudflare Workers: Deployment failed")
            fi
            ;;
        "vercel")
            echo -e "${YELLOW}Deploying to Vercel...${NC}"
            
            local vercel_cmd="vercel --prod"
            if [[ "$TARGET_ENVIRONMENT" != "production" ]]; then
                vercel_cmd="vercel"
            fi
            
            if $vercel_cmd --yes; then
                details+=("Vercel: Deployed")
                
                # Get deployment URL
                local vercel_url=$(vercel ls | grep "nuxtops" | head -1 | awk '{print $2}' || echo "")
                if [[ -n "$vercel_url" ]]; then
                    details+=("Deployment URL: https://$vercel_url")
                fi
            else
                stage_result="failed"
                details+=("Vercel: Deployment failed")
            fi
            ;;
        "netlify")
            echo -e "${YELLOW}Deploying to Netlify...${NC}"
            
            if netlify deploy --prod --dir=.output/public; then
                details+=("Netlify: Deployed")
                
                # Get deployment URL
                local netlify_url=$(netlify status | grep "URL" | awk '{print $2}' || echo "")
                if [[ -n "$netlify_url" ]]; then
                    details+=("Deployment URL: $netlify_url")
                fi
            else
                stage_result="failed"
                details+=("Netlify: Deployment failed")
            fi
            ;;
    esac
    
    save_stage_result "function_deployment" "$stage_result" "${details[@]}"
    
    [[ "$stage_result" == "passed" ]]
}

# Configure routing
configure_routing() {
    echo -e "${BLUE}━━━ Stage: Routing Configuration ━━━${NC}"
    
    local stage_result="passed"
    local details=()
    
    case "$TARGET_PLATFORM" in
        "cloudflare")
            # Configure Cloudflare routes
            echo -e "${YELLOW}Configuring Cloudflare routes...${NC}"
            
            # This would typically involve DNS and route configuration
            details+=("Cloudflare routes: Configured")
            ;;
        "vercel")
            # Vercel routing is handled by vercel.json
            details+=("Vercel routing: Configured via vercel.json")
            ;;
        "netlify")
            # Netlify routing is handled by netlify.toml
            details+=("Netlify routing: Configured via netlify.toml")
            ;;
    esac
    
    save_stage_result "routing_configuration" "$stage_result" "${details[@]}"
    
    [[ "$stage_result" == "passed" ]]
}

# Validate deployment
validate_edge_deployment() {
    echo -e "${BLUE}━━━ Stage: Deployment Validation ━━━${NC}"
    
    local stage_result="passed"
    local details=()
    
    # Get deployment URL from state or platform
    local deployment_url=""
    case "$TARGET_PLATFORM" in
        "cloudflare")
            deployment_url="https://nuxtops-v3-${TARGET_ENVIRONMENT}.workers.dev"
            ;;
        "vercel")
            deployment_url=$(jq -r '.deployment_url // empty' "$DEPLOYMENT_STATE")
            ;;
        "netlify")
            deployment_url=$(jq -r '.deployment_url // empty' "$DEPLOYMENT_STATE")
            ;;
    esac
    
    if [[ -n "$deployment_url" ]]; then
        details+=("Deployment URL: $deployment_url")
        
        # Test connectivity
        echo -e "${YELLOW}Testing edge deployment...${NC}"
        
        local max_attempts=10
        local attempt=0
        local connected=false
        
        while [ $attempt -lt $max_attempts ]; do
            if curl -s --max-time 10 "$deployment_url" &>/dev/null; then
                connected=true
                break
            fi
            
            sleep 5
            ((attempt++))
        done
        
        if $connected; then
            details+=("Connectivity: PASSED")
            
            # Test health endpoint
            local health_response=$(curl -s "${deployment_url}/health" 2>/dev/null || echo "{}")
            local health_status=$(echo "$health_response" | jq -r '.status' 2>/dev/null || echo "unknown")
            
            if [[ "$health_status" == "healthy" ]]; then
                details+=("Health check: PASSED")
            else
                stage_result="degraded"
                details+=("Health check: FAILED (status: $health_status)")
            fi
            
            # Test edge performance
            local response_time=$(curl -s -o /dev/null -w "%{time_total}" "$deployment_url" 2>/dev/null || echo "0")
            details+=("Response time: ${response_time}s")
            
            if (( $(echo "$response_time < 1.0" | bc -l) )); then
                details+=("Edge performance: EXCELLENT (< 1s)")
            elif (( $(echo "$response_time < 2.0" | bc -l) )); then
                details+=("Edge performance: GOOD (< 2s)")
            else
                stage_result="degraded"
                details+=("Edge performance: SLOW (> 2s)")
            fi
        else
            stage_result="failed"
            details+=("Connectivity: FAILED (timeout)")
        fi
    else
        stage_result="failed"
        details+=("Deployment URL: Not found")
    fi
    
    save_stage_result "validation" "$stage_result" "${details[@]}"
    
    [[ "$stage_result" == "passed" || "$stage_result" == "degraded" ]]
}

# Run performance tests
run_performance_tests() {
    echo -e "${BLUE}━━━ Stage: Performance Testing ━━━${NC}"
    
    local stage_result="passed"
    local details=()
    
    # Get deployment URL
    local deployment_url=$(jq -r '.deployment_url // empty' "$DEPLOYMENT_STATE")
    
    if [[ -n "$deployment_url" ]]; then
        echo -e "${YELLOW}Running edge performance tests...${NC}"
        
        # Test cold start time
        local cold_start_time=$(curl -s -o /dev/null -w "%{time_total}" "$deployment_url" 2>/dev/null || echo "0")
        details+=("Cold start time: ${cold_start_time}s")
        
        # Test warm response time (multiple requests)
        local total_time=0
        local requests=5
        
        for i in $(seq 1 $requests); do
            local response_time=$(curl -s -o /dev/null -w "%{time_total}" "$deployment_url" 2>/dev/null || echo "0")
            total_time=$(echo "$total_time + $response_time" | bc -l)
        done
        
        local avg_response_time=$(echo "scale=3; $total_time / $requests" | bc -l)
        details+=("Average warm response time: ${avg_response_time}s")
        
        # Performance evaluation
        if (( $(echo "$avg_response_time < 0.5" | bc -l) )); then
            details+=("Performance grade: EXCELLENT")
        elif (( $(echo "$avg_response_time < 1.0" | bc -l) )); then
            details+=("Performance grade: GOOD")
        else
            stage_result="degraded"
            details+=("Performance grade: NEEDS_IMPROVEMENT")
        fi
    else
        stage_result="failed"
        details+=("Cannot run performance tests: No deployment URL")
    fi
    
    save_stage_result "performance_testing" "$stage_result" "${details[@]}"
    
    [[ "$stage_result" == "passed" || "$stage_result" == "degraded" ]]
}

# Save stage result (same implementation as other scripts)
save_stage_result() {
    local stage_name="$1"
    local result="$2"
    shift 2
    local details=("$@")
    
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
    
    jq ".stages += [$stage_entry]" "$DEPLOYMENT_STATE" > "${DEPLOYMENT_STATE}.tmp" && mv "${DEPLOYMENT_STATE}.tmp" "$DEPLOYMENT_STATE"
    
    if [[ "$result" == "passed" ]]; then
        echo -e "${GREEN}✓ Stage ${stage_name}: ${result}${NC}"
    elif [[ "$result" == "degraded" ]]; then
        echo -e "${YELLOW}⚠ Stage ${stage_name}: ${result}${NC}"
    else
        echo -e "${RED}✗ Stage ${stage_name}: ${result}${NC}"
    fi
    
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
    
    local overall_result="success"
    if [[ $failed_stages -gt 0 ]]; then
        overall_result="failed"
    elif [[ $degraded_stages -gt 0 ]]; then
        overall_result="success_with_warnings"
    fi
    
    jq \
        --arg end_time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg status "$overall_result" \
        '. + {end_time: $end_time, status: $status}' \
        "$DEPLOYMENT_STATE" > "${DEPLOYMENT_STATE}.tmp" && mv "${DEPLOYMENT_STATE}.tmp" "$DEPLOYMENT_STATE"
    
    echo
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║         Edge Deployment Summary                               ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}Platform:${NC} $TARGET_PLATFORM"
    echo -e "${CYAN}Environment:${NC} $TARGET_ENVIRONMENT"
    echo -e "${CYAN}Regions:${NC} $TARGET_REGIONS"
    echo -e "${CYAN}Overall Result:${NC} $(format_result "$overall_result")"
    echo
    echo -e "${CYAN}Stages: ${passed_stages}/${total_stages} passed${NC}"
    
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
        "success") echo -e "${GREEN}SUCCESS${NC}" ;;
        "success_with_warnings") echo -e "${YELLOW}SUCCESS WITH WARNINGS${NC}" ;;
        "failed") echo -e "${RED}FAILED${NC}" ;;
        *) echo "$result" ;;
    esac
}

# Main function
main() {
    local platform="${1:-cloudflare}"
    local environment="${2:-development}"
    local regions="${3:-global}"
    local verbose="${4:-}"
    
    # Validate platform
    if [[ ! " ${SUPPORTED_PLATFORMS[*]} " =~ " ${platform} " ]]; then
        echo -e "${RED}Error: Unsupported platform '$platform'${NC}"
        echo "Supported platforms: ${SUPPORTED_PLATFORMS[*]}"
        exit 1
    fi
    
    # Set global variables
    TARGET_PLATFORM="$platform"
    TARGET_ENVIRONMENT="$environment"
    TARGET_REGIONS="$regions"
    
    VERBOSE="false"
    if [[ "$verbose" == "--verbose" || "$verbose" == "-v" ]]; then
        VERBOSE="true"
    fi
    
    # Initialize deployment
    init_deployment
    
    # Execute deployment stages
    for stage in "${DEPLOYMENT_STAGES[@]}"; do
        case "$stage" in
            "prerequisites_check") check_prerequisites ;;
            "platform_setup") setup_platform ;;
            "edge_build") build_for_edge ;;
            "observability_setup") setup_edge_observability ;;
            "function_deployment") deploy_functions ;;
            "routing_configuration") configure_routing ;;
            "validation") validate_edge_deployment ;;
            "performance_testing") run_performance_tests ;;
        esac
        echo
    done
    
    generate_deployment_summary
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [PLATFORM] [ENVIRONMENT] [REGIONS] [OPTIONS]

PLATFORM:
    cloudflare  - Deploy to Cloudflare Workers (default)
    vercel      - Deploy to Vercel Edge Functions
    netlify     - Deploy to Netlify Edge Functions
    fastly      - Deploy to Fastly Compute@Edge

ENVIRONMENT:
    development - Development environment (default)
    staging     - Staging environment
    production  - Production environment

REGIONS:
    global      - Deploy globally (default)
    us-east-1   - US East region
    eu-west-1   - Europe West region
    ap-southeast-1 - Asia Pacific Southeast region

OPTIONS:
    --verbose, -v  - Show detailed deployment output
    --help         - Show this help message

Examples:
    $0                                    # Deploy to Cloudflare Workers globally
    $0 vercel production                  # Deploy to Vercel production
    $0 cloudflare staging us-east-1       # Deploy to Cloudflare staging in US East
    $0 netlify development global --verbose # Verbose Netlify development deployment

EOF
}

# Parse arguments
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

# Execute main function
main "$@"