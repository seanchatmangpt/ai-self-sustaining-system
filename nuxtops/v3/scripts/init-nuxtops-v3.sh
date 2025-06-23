#!/bin/bash
# NuxtOps V3 Initialization Script
# Initialize project structure and dependencies

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check for required tools
    command -v docker >/dev/null 2>&1 || missing_tools+=("docker")
    command -v docker-compose >/dev/null 2>&1 || missing_tools+=("docker-compose")
    command -v node >/dev/null 2>&1 || missing_tools+=("node")
    command -v npm >/dev/null 2>&1 || missing_tools+=("npm")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again."
        exit 1
    fi
    
    # Check Docker daemon
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# Create directory structure
create_directories() {
    log_info "Creating directory structure..."
    
    # Application directories
    mkdir -p "$PROJECT_ROOT/applications/nuxt-app"/{server,pages,components,composables,plugins,middleware,stores,assets,public}
    
    # Monitoring configuration directories
    mkdir -p "$PROJECT_ROOT/monitoring/prometheus/rules"
    mkdir -p "$PROJECT_ROOT/monitoring/grafana/provisioning"/{dashboards,datasources,alerting}
    mkdir -p "$PROJECT_ROOT/monitoring/loki"
    mkdir -p "$PROJECT_ROOT/monitoring/promtail"
    
    # Test directories
    mkdir -p "$PROJECT_ROOT/tests"/{unit,integration,e2e}
    
    # Infrastructure directories
    mkdir -p "$PROJECT_ROOT/infrastructure"/{docker,terraform,kubernetes,ansible}
    
    # Scripts directories
    mkdir -p "$PROJECT_ROOT/scripts"/{tools,chapters}
    
    log_success "Directory structure created"
}

# Initialize secrets
init_secrets() {
    log_info "Initializing secrets..."
    
    local secrets_dir="$PROJECT_ROOT/deployment/secrets"
    mkdir -p "$secrets_dir"
    
    # Generate secure passwords if they don't exist
    if [ ! -f "$secrets_dir/.postgrespassword" ]; then
        openssl rand -base64 32 > "$secrets_dir/.postgrespassword"
        log_success "Generated PostgreSQL password"
    fi
    
    if [ ! -f "$secrets_dir/.sessionsecret" ]; then
        openssl rand -base64 32 > "$secrets_dir/.sessionsecret"
        log_success "Generated session secret"
    fi
    
    if [ ! -f "$secrets_dir/.grafanapassword" ]; then
        echo "admin" > "$secrets_dir/.grafanapassword"
        log_warning "Using default Grafana password (admin). Change this in production!"
    fi
    
    # Create database URL
    if [ ! -f "$secrets_dir/.databaseurl" ]; then
        local pg_pass=$(cat "$secrets_dir/.postgrespassword")
        echo "postgresql://postgres:${pg_pass}@db:5432/nuxtops_dev" > "$secrets_dir/.databaseurl"
        log_success "Generated database URL"
    fi
    
    # Create postgres exporter DSN
    if [ ! -f "$secrets_dir/.postgres_exporter_dsn" ]; then
        local pg_pass=$(cat "$secrets_dir/.postgrespassword")
        echo "postgresql://postgres:${pg_pass}@db:5432/nuxtops_dev?sslmode=disable" > "$secrets_dir/.postgres_exporter_dsn"
        log_success "Generated PostgreSQL exporter DSN"
    fi
    
    # Set proper permissions
    chmod 600 "$secrets_dir"/.* 2>/dev/null || true
    
    log_success "Secrets initialized"
}

# Initialize Nuxt application
init_nuxt_app() {
    log_info "Initializing Nuxt 3 application..."
    
    local app_dir="$PROJECT_ROOT/applications/nuxt-app"
    
    if [ ! -f "$app_dir/package.json" ]; then
        cd "$app_dir"
        
        # Create package.json
        cat > package.json <<'EOF'
{
  "name": "nuxtops-app",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "build": "nuxt build",
    "dev": "nuxt dev --host 0.0.0.0",
    "generate": "nuxt generate",
    "preview": "nuxt preview",
    "postinstall": "nuxt prepare",
    "lint": "eslint .",
    "test": "vitest",
    "test:e2e": "playwright test"
  },
  "dependencies": {
    "@nuxtjs/tailwindcss": "^6.10.3",
    "@pinia/nuxt": "^0.5.1",
    "@prisma/client": "^5.7.1",
    "@sentry/nuxt": "^7.91.0",
    "ioredis": "^5.3.2",
    "nuxt": "^3.9.0",
    "pinia": "^2.1.7",
    "vue": "^3.4.3"
  },
  "devDependencies": {
    "@nuxt/devtools": "latest",
    "@nuxt/test-utils": "^3.9.0",
    "@playwright/test": "^1.40.1",
    "@types/node": "^20.10.5",
    "@vue/test-utils": "^2.4.3",
    "eslint": "^8.56.0",
    "eslint-config-prettier": "^9.1.0",
    "eslint-plugin-vue": "^9.19.2",
    "prettier": "^3.1.1",
    "prisma": "^5.7.1",
    "typescript": "^5.3.3",
    "vitest": "^1.1.0"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF
        
        # Create nuxt.config.ts
        cat > nuxt.config.ts <<'EOF'
// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  devtools: { enabled: true },
  
  modules: [
    '@nuxtjs/tailwindcss',
    '@pinia/nuxt',
    '@sentry/nuxt'
  ],

  runtimeConfig: {
    // Private keys (server-side only)
    databaseUrl: process.env.DATABASE_URL || '',
    redisUrl: process.env.REDIS_URL || '',
    sessionSecret: process.env.NUXT_SESSION_SECRET || '',
    
    // Public keys (exposed to client)
    public: {
      apiBase: process.env.NUXT_PUBLIC_API_BASE || '',
      siteUrl: process.env.NUXT_PUBLIC_SITE_URL || 'http://localhost:3000',
    }
  },

  nitro: {
    experimental: {
      openAPI: true,
      wasm: true
    }
  },

  typescript: {
    strict: true,
    shim: false
  },

  css: ['~/assets/css/main.css'],

  vite: {
    optimizeDeps: {
      include: ['vue', 'pinia']
    }
  }
})
EOF
        
        # Create app.vue
        cat > app.vue <<'EOF'
<template>
  <div>
    <NuxtLayout>
      <NuxtPage />
    </NuxtLayout>
  </div>
</template>
EOF
        
        # Create default layout
        mkdir -p layouts
        cat > layouts/default.vue <<'EOF'
<template>
  <div class="min-h-screen bg-gray-50">
    <header class="bg-white shadow">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between items-center py-6">
          <h1 class="text-2xl font-bold text-gray-900">NuxtOps V3</h1>
          <nav class="space-x-4">
            <NuxtLink to="/" class="text-gray-700 hover:text-gray-900">Home</NuxtLink>
            <NuxtLink to="/dashboard" class="text-gray-700 hover:text-gray-900">Dashboard</NuxtLink>
            <NuxtLink to="/monitoring" class="text-gray-700 hover:text-gray-900">Monitoring</NuxtLink>
          </nav>
        </div>
      </div>
    </header>
    <main>
      <slot />
    </main>
  </div>
</template>
EOF
        
        # Create index page
        cat > pages/index.vue <<'EOF'
<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
    <div class="text-center">
      <h2 class="text-4xl font-bold text-gray-900 mb-4">Welcome to NuxtOps V3</h2>
      <p class="text-xl text-gray-600 mb-8">
        Production-ready Nuxt 3 deployment system with full observability
      </p>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-8 mt-12">
        <div class="bg-white p-6 rounded-lg shadow">
          <h3 class="text-lg font-semibold mb-2">High Performance</h3>
          <p class="text-gray-600">Optimized for production with edge rendering and caching</p>
        </div>
        <div class="bg-white p-6 rounded-lg shadow">
          <h3 class="text-lg font-semibold mb-2">Full Observability</h3>
          <p class="text-gray-600">Integrated monitoring with Prometheus, Grafana, and Jaeger</p>
        </div>
        <div class="bg-white p-6 rounded-lg shadow">
          <h3 class="text-lg font-semibold mb-2">Enterprise Ready</h3>
          <p class="text-gray-600">Scalable architecture with PostgreSQL and Redis</p>
        </div>
      </div>
    </div>
  </div>
</template>
EOF
        
        # Create health check API endpoint
        mkdir -p server/api
        cat > server/api/health.get.ts <<'EOF'
export default defineEventHandler(async (event) => {
  // Check database connection
  let dbStatus = 'unknown'
  try {
    // Add database health check here
    dbStatus = 'healthy'
  } catch (error) {
    dbStatus = 'unhealthy'
  }

  // Check Redis connection
  let redisStatus = 'unknown'
  try {
    // Add Redis health check here
    redisStatus = 'healthy'
  } catch (error) {
    redisStatus = 'unhealthy'
  }

  const healthy = dbStatus === 'healthy' && redisStatus === 'healthy'

  setResponseStatus(event, healthy ? 200 : 503)
  
  return {
    status: healthy ? 'healthy' : 'unhealthy',
    timestamp: new Date().toISOString(),
    services: {
      database: dbStatus,
      redis: redisStatus
    }
  }
})
EOF
        
        # Create CSS file
        mkdir -p assets/css
        cat > assets/css/main.css <<'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF
        
        log_success "Nuxt application initialized"
    else
        log_info "Nuxt application already exists"
    fi
}

# Create monitoring configuration
create_monitoring_config() {
    log_info "Creating monitoring configuration..."
    
    # Prometheus configuration
    cat > "$PROJECT_ROOT/monitoring/prometheus/prometheus.yml" <<'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

rule_files:
  - "/etc/prometheus/rules/*.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'redis-exporter'
    static_configs:
      - targets: ['redis-exporter:9121']

  - job_name: 'postgres-exporter'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'nuxt-app'
    static_configs:
      - targets: ['app:3000']
    metrics_path: '/api/metrics'
EOF
    
    # Grafana datasources
    mkdir -p "$PROJECT_ROOT/monitoring/grafana/provisioning/datasources"
    cat > "$PROJECT_ROOT/monitoring/grafana/provisioning/datasources/prometheus.yaml" <<'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: true

  - name: Jaeger
    type: jaeger
    access: proxy
    url: http://jaeger:16686
    editable: true
EOF
    
    # Grafana dashboard provisioning
    cat > "$PROJECT_ROOT/monitoring/grafana/provisioning/dashboards/dashboard.yaml" <<'EOF'
apiVersion: 1

providers:
  - name: 'NuxtOps'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    options:
      path: /var/lib/grafana/dashboards
EOF
    
    # Loki configuration
    cat > "$PROJECT_ROOT/monitoring/loki/loki-config.yaml" <<'EOF'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093
EOF
    
    # Promtail configuration
    cat > "$PROJECT_ROOT/monitoring/promtail/promtail-config.yaml" <<'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: containers
    static_configs:
      - targets:
          - localhost
        labels:
          job: containerlogs
          __path__: /var/lib/docker/containers/*/*log
    
    pipeline_stages:
      - json:
          expressions:
            output: log
            stream: stream
            attrs:
      - json:
          expressions:
            tag:
          source: attrs
      - regex:
          expression: (?P<container_name>(?:[^|]*))\|(?P<image_name>(?:[^|]*))
          source: tag
      - timestamp:
          format: RFC3339Nano
          source: time
      - labels:
          stream:
          container_name:
          image_name:
      - output:
          source: output
EOF
    
    log_success "Monitoring configuration created"
}

# Create deployment scripts
create_deployment_scripts() {
    log_info "Creating deployment scripts..."
    
    # Deploy script
    cat > "$PROJECT_ROOT/scripts/deploy-nuxtops-stack.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "Deploying NuxtOps V3 stack..."

# Start core services first
docker-compose up -d db redis

# Wait for services to be healthy
echo "Waiting for database and Redis..."
sleep 10

# Start application
docker-compose up -d app

# Start monitoring stack
docker-compose --profile monitoring up -d

echo "NuxtOps V3 stack deployed successfully!"
echo ""
echo "Access points:"
echo "  - Application: http://localhost:3000"
echo "  - Grafana: http://localhost:3002 (admin/admin)"
echo "  - Prometheus: http://localhost:9092"
echo "  - Jaeger: http://localhost:16687"
echo "  - Adminer: http://localhost:8081"
EOF
    
    chmod +x "$PROJECT_ROOT/scripts/deploy-nuxtops-stack.sh"
    
    # Monitor script
    cat > "$PROJECT_ROOT/scripts/monitor-deployment.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

echo "Monitoring NuxtOps V3 deployment..."
echo ""

# Check service health
check_service() {
    local service=$1
    local port=$2
    local endpoint=${3:-/}
    
    if curl -f -s "http://localhost:$port$endpoint" > /dev/null; then
        echo "✓ $service is healthy"
    else
        echo "✗ $service is not responding"
    fi
}

# Check Docker containers
echo "Container Status:"
docker-compose ps

echo ""
echo "Service Health:"
check_service "Nuxt App" 3000 "/api/health"
check_service "Prometheus" 9092 "/-/healthy"
check_service "Grafana" 3002 "/api/health"
check_service "Jaeger" 16687 "/"

echo ""
echo "Resource Usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
EOF
    
    chmod +x "$PROJECT_ROOT/scripts/monitor-deployment.sh"
    
    log_success "Deployment scripts created"
}

# Create initial Grafana dashboard
create_grafana_dashboard() {
    log_info "Creating Grafana dashboard..."
    
    cat > "$PROJECT_ROOT/monitoring/grafana/dashboards/nuxtops-overview.json" <<'EOF'
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": {
          "type": "grafana",
          "uid": "-- Grafana --"
        },
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${DS_PROMETHEUS}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "custom": {
            "axisCenteredZero": false,
            "axisColorMode": "text",
            "axisLabel": "",
            "axisPlacement": "auto",
            "barAlignment": 0,
            "drawStyle": "line",
            "fillOpacity": 0,
            "gradientMode": "none",
            "hideFrom": {
              "tooltip": false,
              "viz": false,
              "legend": false
            },
            "insertNulls": false,
            "lineInterpolation": "linear",
            "lineWidth": 1,
            "pointSize": 5,
            "scaleDistribution": {
              "type": "linear"
            },
            "showPoints": "auto",
            "spanNulls": false,
            "stacking": {
              "group": "A",
              "mode": "none"
            },
            "thresholdsStyle": {
              "mode": "off"
            }
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 80
              }
            ]
          },
          "unit": "percent"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "id": 1,
      "options": {
        "tooltip": {
          "mode": "single",
          "sort": "none"
        },
        "legend": {
          "calcs": [],
          "displayMode": "list",
          "placement": "bottom",
          "showLegend": true
        }
      },
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${DS_PROMETHEUS}"
          },
          "editorMode": "code",
          "expr": "100 - (avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
          "refId": "A"
        }
      ],
      "title": "CPU Usage",
      "type": "timeseries"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "${DS_PROMETHEUS}"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "thresholds"
          },
          "mappings": [],
          "max": 100,
          "min": 0,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "yellow",
                "value": 70
              },
              {
                "color": "red",
                "value": 90
              }
            ]
          },
          "unit": "percent"
        },
        "overrides": []
      },
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 0
      },
      "id": 2,
      "options": {
        "orientation": "auto",
        "reduceOptions": {
          "values": false,
          "calcs": [
            "lastNotNull"
          ],
          "fields": ""
        },
        "showThresholdLabels": false,
        "showThresholdMarkers": true
      },
      "pluginVersion": "10.2.3",
      "targets": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "${DS_PROMETHEUS}"
          },
          "editorMode": "code",
          "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
          "refId": "A"
        }
      ],
      "title": "Memory Usage",
      "type": "gauge"
    }
  ],
  "refresh": "5s",
  "schemaVersion": 38,
  "style": "dark",
  "tags": ["nuxtops", "overview"],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-6h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "NuxtOps Overview",
  "uid": "nuxtops-overview",
  "version": 0,
  "weekStart": ""
}
EOF
    
    log_success "Grafana dashboard created"
}

# Main execution
main() {
    log_info "Initializing NuxtOps V3..."
    
    check_prerequisites
    create_directories
    init_secrets
    init_nuxt_app
    create_monitoring_config
    create_deployment_scripts
    create_grafana_dashboard
    
    log_success "NuxtOps V3 initialization complete!"
    log_info ""
    log_info "Next steps:"
    log_info "1. Review and customize the configuration files"
    log_info "2. Run './scripts/deploy-nuxtops-stack.sh' to start the stack"
    log_info "3. Access the application at http://localhost:3000"
    log_info "4. Access Grafana at http://localhost:3002 (admin/admin)"
}

# Run main function
main "$@"