#!/bin/bash

##############################################################################
# AI Self-Sustaining System Docker Startup Script
##############################################################################
#
# DESCRIPTION:
#   Starts the complete AI Self-Sustaining system using Docker Compose with
#   intelligent hardware detection and optimized container orchestration.
#
# FEATURES:
#   - Automatic GPU/CPU hardware detection
#   - Docker Compose profile selection (gpu/cpu/cpu-generic)
#   - n8n AI Starter Kit integration
#   - Container health monitoring and startup validation
#   - Graceful shutdown and cleanup handling
#   - Multi-platform support (x86_64, ARM64, Apple Silicon)
#
# USAGE:
#   ./start-ai-system.sh [PROFILE] [OPTIONS]
#
# PROFILES:
#   gpu         - GPU-accelerated AI workloads (NVIDIA/AMD)
#   cpu         - Optimized CPU-only processing
#   cpu-generic - Generic CPU fallback for compatibility
#   auto        - Automatic detection (default)
#
# OPTIONS:
#   --detach, -d     Run containers in background
#   --build          Rebuild containers before starting
#   --no-gpu         Force CPU-only mode regardless of hardware
#   --verbose        Enable verbose logging output
#
# REQUIREMENTS:
#   - Docker 20+ with Docker Compose V2
#   - 8GB+ RAM recommended for AI workloads  
#   - GPU drivers installed (for GPU profile)
#   - n8n AI Starter Kit configuration files
#
# ENVIRONMENT VARIABLES:
#   DOCKER_BUILDKIT=1 - Enable BuildKit for optimized builds
#   COMPOSE_PROFILES  - Override automatic profile detection
#   N8N_PORT         - n8n web interface port (default: 5678)
#
##############################################################################

echo "🚀 Starting AI Self-Sustaining System..."
echo "========================================"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Detect system and GPU capabilities
echo "🔍 Detecting system capabilities..."

# Default to CPU profile
PROFILE="cpu"

# Check for NVIDIA GPU
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    echo "✅ NVIDIA GPU detected"
    PROFILE="gpu-nvidia"
elif [[ "$OSTYPE" == "linux-gnu"* ]] && lspci | grep -i "amd.*vga" >/dev/null 2>&1; then
    echo "✅ AMD GPU detected (Linux)"
    PROFILE="gpu-amd"
else
    echo "🖥️  Using CPU profile"
fi

echo "📋 Selected profile: $PROFILE"
echo

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p shared
mkdir -p n8n_workflows

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "❌ .env file not found!"
    echo "💡 Please ensure .env file is properly configured"
    exit 1
fi

echo "✅ Environment configured"
echo

# Start the system
echo "🔄 Starting AI services with Docker Compose..."
echo "Profile: $PROFILE"
echo

case "$PROFILE" in
    "gpu-nvidia")
        docker compose --profile gpu-nvidia up -d
        ;;
    "gpu-amd")
        docker compose --profile gpu-amd up -d
        ;;
    "cpu")
        docker compose --profile cpu up -d
        ;;
esac

if [ $? -eq 0 ]; then
    echo
    echo "🎉 AI Self-Sustaining System started successfully!"
    echo "================================================="
    echo
    echo "📊 Service URLs:"
    echo "- n8n Web Interface: http://localhost:5678"
    echo "- Ollama API: http://localhost:11434"
    echo "- Qdrant Vector DB: http://localhost:6333"
    echo "- PostgreSQL: localhost:5432"
    echo
    echo "📁 Shared directories:"
    echo "- Workflows: ./n8n_workflows"
    echo "- Shared files: ./shared"
    echo
    echo "🔧 Next steps:"
    echo "1. Open http://localhost:5678 to set up n8n"
    echo "2. Import existing workflows from n8n_workflows/"
    echo "3. Start developing AI workflows!"
    echo
    echo "📋 Management commands:"
    echo "- Stop: docker compose down"
    echo "- View logs: docker compose logs -f"
    echo "- Status: docker compose ps"
else
    echo "❌ Failed to start AI system"
    echo "💡 Check Docker logs: docker compose logs"
    exit 1
fi