#!/bin/bash

# AI Self-Sustaining System Startup Script
# Starts n8n AI Starter Kit with appropriate profile for the system

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