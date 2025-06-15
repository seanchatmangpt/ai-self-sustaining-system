# n8n AI Starter Kit Integration

## Overview

The n8n AI Starter Kit has been integrated into the AI Self-Sustaining System, providing a comprehensive local AI environment with the following components:

- **n8n**: Low-code workflow automation platform
- **Ollama**: Local LLM platform for running language models
- **Qdrant**: Vector database for AI embeddings and semantic search
- **PostgreSQL**: Database for data persistence

## Quick Start

### 1. Start the AI System

```bash
./start-ai-system.sh
```

This script automatically detects your system capabilities and starts the appropriate services:
- **GPU (NVIDIA)**: Uses GPU acceleration for Ollama
- **GPU (AMD)**: Uses AMD GPU acceleration on Linux
- **CPU**: Falls back to CPU-only execution

### 2. Access Services

Once started, the following services will be available:

- **n8n Web Interface**: http://localhost:5678
- **Ollama API**: http://localhost:11434
- **Qdrant Vector DB**: http://localhost:6333
- **PostgreSQL**: localhost:5432

### 3. Initial Setup

1. Open http://localhost:5678 in your browser
2. Create your n8n user account
3. The system includes a demo workflow to get started
4. Ollama will automatically download Llama 3.2 on first run

## Integration with Existing System

### Environment Configuration

The starter kit is integrated with your existing Phoenix application through shared environment variables in `.env`:

```bash
# AI Services
OLLAMA_HOST=localhost:11434
QDRANT_HOST=localhost:6333

# n8n Configuration  
N8N_ENCRYPTION_KEY=super-secret-key-change-in-production
N8N_USER_MANAGEMENT_JWT_SECRET=even-more-secret-change-in-production
N8N_METRICS_ENABLE=true

# Self-Improvement System
AUTO_ENHANCEMENT_ENABLED=true
MAX_CONCURRENT_AGENTS=5
```

### Shared Directories

- **`./shared/`**: Files accessible by both n8n and Phoenix
- **`./n8n_workflows/`**: Workflow exports and backups
- **`./n8n/demo-data/`**: Demo workflows and credentials

### Phoenix Integration Points

The AI services can be integrated with your Phoenix application through:

1. **HTTP APIs**: Direct API calls to Ollama and Qdrant
2. **Shared File System**: Exchange data through the `./shared/` directory
3. **Database**: Shared PostgreSQL instance for coordination
4. **n8n Webhooks**: Phoenix can trigger n8n workflows via webhooks

## Available AI Models

The system comes pre-configured with Llama 3.2, but you can add additional models:

```bash
# Connect to Ollama container
docker exec -it ollama ollama pull mistral
docker exec -it ollama ollama pull codellama
```

## Workflow Development

### Creating Workflows

1. Access n8n at http://localhost:5678
2. Create new workflows using the visual editor
3. Use AI nodes for LLM interactions
4. Connect to Qdrant for vector operations
5. Export workflows to `./n8n_workflows/` for version control

### Integration with Self-Sustaining System

Workflows can interact with your Phoenix application through:

- **HTTP Request nodes** pointing to Phoenix endpoints
- **Webhook triggers** called from Phoenix
- **File operations** in the shared directory
- **Database operations** on shared PostgreSQL

## Management Commands

```bash
# Start the system
./start-ai-system.sh

# Stop all services
docker compose down

# View service logs
docker compose logs -f

# Check service status
docker compose ps

# Restart specific service
docker compose restart n8n

# Pull latest images
docker compose pull
```

## System Profiles

The startup script supports different execution profiles:

### CPU Profile
```bash
docker compose --profile cpu up -d
```
- No GPU acceleration
- Works on all systems
- Slower AI model inference

### NVIDIA GPU Profile
```bash
docker compose --profile gpu-nvidia up -d
```
- NVIDIA GPU acceleration
- Requires NVIDIA Docker runtime
- Faster AI model inference

### AMD GPU Profile (Linux only)
```bash
docker compose --profile gpu-amd up -d
```
- AMD GPU acceleration
- Linux only
- Uses ROCm-based Ollama image

## Security Considerations

⚠️ **Important**: The default configuration uses development credentials:

1. **Change default passwords** in production:
   - PostgreSQL: `POSTGRES_PASSWORD`
   - n8n encryption: `N8N_ENCRYPTION_KEY`
   - JWT secret: `N8N_USER_MANAGEMENT_JWT_SECRET`

2. **Network security**: Services are exposed on localhost only
3. **File permissions**: Secure the `./shared/` directory appropriately

## Troubleshooting

### Common Issues

1. **Docker not running**:
   ```bash
   # Start Docker Desktop or daemon
   sudo systemctl start docker  # Linux
   ```

2. **Port conflicts**:
   - n8n (5678), Ollama (11434), Qdrant (6333), PostgreSQL (5432)
   - Stop conflicting services or change ports in docker-compose.yml

3. **GPU not detected**:
   - Install NVIDIA Docker runtime for GPU support
   - Verify with `nvidia-smi` command

4. **Model download fails**:
   - Check internet connection
   - Manually pull models: `docker exec -it ollama ollama pull llama3.2`

### Health Checks

Use the existing Claude commands to monitor the system:

```bash
# Check overall system health
./.claude/system-status

# Check n8n workflows specifically  
./.claude/workflow-health

# Optimize workflows
./.claude/optimize-workflows
```

## Next Steps

1. **Explore Demo Workflow**: Start with the included demo at http://localhost:5678/workflow/srOnR8PAY3u4RSwb
2. **Create Custom Workflows**: Build workflows for your specific use cases
3. **Integrate with Phoenix**: Connect workflows to your Phoenix application
4. **Scale AI Capabilities**: Add more models and vector collections as needed

The AI Starter Kit provides a solid foundation for building sophisticated AI-powered workflows that enhance your self-sustaining system.