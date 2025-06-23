# NuxtOps V3: Production-Ready Nuxt 3 Deployment System

**Enterprise-grade infrastructure for deploying and monitoring Nuxt 3 applications with full observability**

## Overview

NuxtOps V3 is the Nuxt/Vue ecosystem equivalent of BeamOps V3, providing a complete production deployment system for Nuxt 3 applications. It includes containerization, monitoring, distributed tracing, and enterprise-ready infrastructure patterns adapted specifically for the JavaScript/TypeScript ecosystem.

## Quick Start

```bash
# Clone and setup
cd /Users/sac/dev/ai-self-sustaining-system/nuxtops/v3

# Initialize infrastructure
./scripts/init-nuxtops-v3.sh

# Launch all services
./scripts/deploy-nuxtops-stack.sh

# Monitor deployment
./scripts/monitor-deployment.sh
```

## Features

### Core Infrastructure
- **Nuxt 3 Application**: Modern Vue 3 framework with server-side rendering
- **PostgreSQL**: Primary database with connection pooling
- **Redis**: High-performance caching and session storage
- **Docker**: Multi-stage builds optimized for production

### Observability Stack
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Beautiful dashboards and visualization
- **Jaeger**: Distributed tracing for performance analysis
- **Loki + Promtail**: Centralized log aggregation

### Development Experience
- **Hot Module Replacement**: Instant updates during development
- **TypeScript**: Full type safety across the stack
- **Tailwind CSS**: Utility-first styling
- **Pinia**: State management for Vue 3
- **Prisma**: Type-safe database ORM

### Production Features
- **Health Checks**: Automated service monitoring
- **Auto-scaling Ready**: Horizontal scaling configuration
- **Secret Management**: Secure credential handling
- **Zero-downtime Deployments**: Rolling update support

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Application   │    │   Data Layer    │    │  Observability  │
│     Layer       │    │                 │    │                 │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ • Nuxt 3 SSR    │    │ • PostgreSQL    │    │ • Prometheus    │
│ • Nitro Server  │    │ • Redis Cache   │    │ • Grafana       │
│ • API Routes    │    │ • Prisma ORM    │    │ • Jaeger        │
│ • Vue Components│    │ • Migrations    │    │ • Loki/Promtail │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Project Structure

```
nuxtops/v3/
├── applications/
│   └── nuxt-app/              # Main Nuxt 3 application
│       ├── server/            # API routes and middleware
│       ├── pages/             # Application pages
│       ├── components/        # Vue components
│       ├── composables/       # Composition API utilities
│       ├── stores/            # Pinia stores
│       └── plugins/           # Nuxt plugins
├── infrastructure/
│   ├── docker/                # Container configurations
│   ├── terraform/             # Infrastructure as Code
│   ├── kubernetes/            # K8s manifests (future)
│   └── ansible/               # Configuration management
├── monitoring/
│   ├── prometheus/            # Metrics configuration
│   ├── grafana/               # Dashboards and alerts
│   ├── loki/                  # Log aggregation config
│   └── jaeger/                # Tracing configuration
├── deployment/
│   ├── development/           # Dev environment
│   ├── staging/               # Staging environment
│   ├── production/            # Production environment
│   └── secrets/               # Encrypted credentials
├── scripts/
│   ├── init-nuxtops-v3.sh    # Project initialization
│   ├── deploy-nuxtops-stack.sh # Stack deployment
│   └── monitor-deployment.sh   # Health monitoring
├── tests/
│   ├── unit/                  # Unit tests
│   ├── integration/           # Integration tests
│   └── e2e/                   # End-to-end tests
├── Dockerfile                 # Multi-stage build
├── compose.yaml               # Docker Compose config
└── README.md                  # This file
```

## Services

### Core Services

| Service | Port | Description |
|---------|------|-------------|
| Nuxt App | 3000 | Main application |
| PostgreSQL | 5436 | Primary database |
| Redis | 6381 | Caching layer |
| Adminer | 8081 | Database UI |

### Monitoring Services

| Service | Port | Description |
|---------|------|-------------|
| Prometheus | 9092 | Metrics collection |
| Grafana | 3002 | Dashboards |
| Jaeger | 16687 | Tracing UI |
| Loki | 3100 | Log aggregation |

### Exporters (Monitoring Profile)

| Service | Port | Description |
|---------|------|-------------|
| Node Exporter | 9100 | System metrics |
| Redis Exporter | 9121 | Redis metrics |
| Postgres Exporter | 9187 | Database metrics |

## Configuration

### Environment Variables

```bash
# Application
NODE_ENV=production
NUXT_PUBLIC_SITE_URL=https://example.com
NUXT_PUBLIC_API_BASE=https://api.example.com

# Database
DATABASE_URL=postgresql://user:pass@host:5432/db

# Redis
REDIS_URL=redis://redis:6379

# Monitoring
OTEL_SERVICE_NAME=nuxtops-app
OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4318
```

### Secrets Management

Secrets are stored in `./deployment/secrets/` and mounted as Docker secrets:

- `.postgrespassword` - PostgreSQL password
- `.sessionsecret` - Session encryption key
- `.grafanapassword` - Grafana admin password
- `.databaseurl` - Full database connection string

## Development Workflow

### Local Development

```bash
# Start development environment
docker-compose up -d

# Watch logs
docker-compose logs -f app

# Run tests
docker-compose exec app npm test

# Access services
open http://localhost:3000  # Application
open http://localhost:3002  # Grafana
open http://localhost:16687 # Jaeger
```

### Building for Production

```bash
# Build production image
docker build -t nuxtops-app:latest .

# Run production container
docker run -p 3000:3000 \
  -e DATABASE_URL=$DATABASE_URL \
  -e REDIS_URL=$REDIS_URL \
  nuxtops-app:latest
```

## Monitoring

### Grafana Dashboards

Pre-configured dashboards include:
- **NuxtOps Overview**: System health and performance metrics
- **Application Metrics**: Request rates, response times, errors
- **Infrastructure**: CPU, memory, disk, network usage
- **Database Performance**: Query times, connections, locks

### Prometheus Alerts

Example alert rules:
- High error rate (>5% of requests)
- Slow response times (>500ms p95)
- Database connection pool exhaustion
- Memory usage >80%

### Distributed Tracing

Jaeger integration provides:
- Request flow visualization
- Performance bottleneck identification
- Error tracking across services
- Dependency mapping

## Security

### Best Practices Implemented

1. **Non-root Container**: Application runs as unprivileged user
2. **Secret Management**: Credentials stored as Docker secrets
3. **Network Isolation**: Services communicate on internal network
4. **Health Checks**: Automated monitoring of service status
5. **Minimal Images**: Alpine-based containers for smaller attack surface

### Production Hardening

```bash
# Generate secure secrets
openssl rand -base64 32 > deployment/secrets/.sessionsecret
openssl rand -base64 32 > deployment/secrets/.postgrespassword

# Set proper permissions
chmod 600 deployment/secrets/.*

# Enable firewall rules
ufw allow 3000/tcp  # Application only
```

## Performance Optimization

### Image Optimization
- Multi-stage builds reduce final image size by ~70%
- Node modules cached in separate layer
- Production dependencies only in final stage

### Runtime Optimization
- Redis caching for session and API responses
- PostgreSQL connection pooling
- Nuxt static asset optimization
- CDN-ready asset serving

### Monitoring Performance
```bash
# Check resource usage
docker stats

# View application metrics
curl http://localhost:3000/api/metrics

# Analyze traces in Jaeger
open http://localhost:16687
```

## Troubleshooting

### Common Issues

**Application won't start**
```bash
# Check logs
docker-compose logs app

# Verify database connection
docker-compose exec app npm run db:check

# Test Redis connection
docker-compose exec redis redis-cli ping
```

**High memory usage**
```bash
# Check Node.js heap
docker-compose exec app node -e "console.log(process.memoryUsage())"

# Analyze memory leaks
docker-compose exec app npm run analyze:memory
```

**Slow performance**
- Check Jaeger traces for bottlenecks
- Review Grafana dashboards for resource constraints
- Analyze database query performance in Adminer

### Debug Commands

```bash
# Enter application container
docker-compose exec app sh

# Check environment variables
docker-compose exec app env | grep NUXT

# Test database connection
docker-compose exec db psql -U postgres -d nuxtops_dev

# Flush Redis cache
docker-compose exec redis redis-cli FLUSHALL
```

## Scaling

### Horizontal Scaling

```yaml
# docker-compose.override.yml
services:
  app:
    deploy:
      replicas: 3
    environment:
      - PM2_INSTANCES=max
```

### Load Balancing

```nginx
upstream nuxtops {
    server app1:3000;
    server app2:3000;
    server app3:3000;
}
```

### Caching Strategy

1. **Static Assets**: Served with long cache headers
2. **API Responses**: Redis cache with TTL
3. **SSR Pages**: Configurable caching per route
4. **CDN Integration**: CloudFlare/AWS CloudFront ready

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy NuxtOps

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build and push
        run: |
          docker build -t nuxtops:${{ github.sha }} .
          docker push nuxtops:${{ github.sha }}
      
      - name: Deploy
        run: |
          docker stack deploy -c compose.yaml nuxtops
```

## Roadmap

### Phase 1: Foundation (Current)
- [x] Docker containerization
- [x] Basic monitoring stack
- [x] Development environment
- [x] Health checks

### Phase 2: Enhancement
- [ ] Kubernetes manifests
- [ ] Auto-scaling configuration
- [ ] Advanced monitoring dashboards
- [ ] Performance testing suite

### Phase 3: Enterprise
- [ ] Multi-region deployment
- [ ] Disaster recovery
- [ ] Compliance automation
- [ ] Cost optimization

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `npm test`
5. Submit a pull request

## License

This project follows the same licensing as the parent AI Self-Sustaining System project.

## Support

- **Documentation**: See `/docs` directory
- **Issues**: GitHub Issues
- **Community**: Discord/Slack channels

---

**Built with inspiration from BeamOps V3, adapted for the modern JavaScript ecosystem**