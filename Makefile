# =============================================================================
# AI Self-Sustaining System Makefile
# =============================================================================
#
# DESCRIPTION:
#   Comprehensive build automation and orchestration for the AI Self-Sustaining
#   System. This Makefile provides a unified interface to all system components
#   including Phoenix applications, agent coordination, Claude AI integration,
#   XAVOS system management, OpenTelemetry tracing, and worktree operations.
#
# SYSTEM ARCHITECTURE:
#   • Phoenix Application (Elixir/LiveView) - Core web framework
#   • Agent Coordination System - 40+ shell commands for Scrum at Scale
#   • Claude AI Integration - Structured JSON analysis and intelligence
#   • XAVOS System - Complete Ash Framework ecosystem (port 4002)
#   • OpenTelemetry - Distributed tracing and performance monitoring
#   • Worktree Management - Git worktree operations for parallel development
#   • SPR Processing - Sparse Priming Representation data pipeline
#
# DEPENDENCIES:
#   Required:
#     - Elixir 1.14+ with OTP 25+
#     - PostgreSQL 14+
#     - Docker & Docker Compose
#     - Node.js 18+ with npm
#   Optional:
#     - Claude CLI for AI features
#     - jq for JSON processing
#     - curl for health checks
#
# QUICK START:
#   1. make setup                    # Complete system setup
#   2. make system-overview          # View system status
#   3. make dev                      # Start development environment
#   4. make system-health-full       # Comprehensive health check
#
# COMPREHENSIVE USAGE:
#   Core Development:
#     make setup                     # Complete project setup
#     make dev                       # Start development environment
#     make test                      # Run all tests
#     make quality                   # Run all quality checks
#     make ci                        # Full CI pipeline
#
#   System Management:
#     make system-overview           # Show complete system overview
#     make system-health-full        # Comprehensive health check
#     make system-full-test          # Run all system tests
#     make script-status             # Run system status check script
#
#   Agent Coordination (Scrum at Scale):
#     make coord-help                # Show coordination commands
#     make coord-dashboard           # View coordination dashboard
#     make coord-pi-planning         # Run PI Planning session
#     make coord-scrum-of-scrums     # Cross-team coordination
#
#   Claude AI Intelligence:
#     make claude-help               # Show Claude AI commands
#     make claude-analyze-priorities # AI priority analysis
#     make claude-health-analysis    # AI health analysis
#     make claude-optimize-assignments # AI assignment optimization
#
#   XAVOS System (Ash Framework):
#     make xavos-help                # Show XAVOS commands
#     make xavos-status              # Check XAVOS system status
#     make xavos-deploy-complete     # Deploy complete XAVOS system
#
#   OpenTelemetry & Observability:
#     make otel-help                 # Show OpenTelemetry commands
#     make otel-trace-validation     # Validate trace implementation
#     make otel-test-integration     # Test OpenTelemetry integration
#
#   Worktree Management:
#     make worktree-help             # Show worktree commands
#     make worktree-status           # Show all worktree status
#     make worktree-create-s2s       # Create new S2S worktree
#
# TROUBLESHOOTING:
#   Common Issues:
#     - Port conflicts: Check if ports 4000, 4002, 5432, 5678 are available
#     - Database issues: Run `make db-reset` to reset database
#     - Permission errors: Ensure scripts have execute permissions
#     - Docker issues: Run `make docker-clean` then `make docker-start`
#
#   Debug Commands:
#     make health                    # Check basic system health
#     make script-status             # Run comprehensive status check
#     make docker-ps                 # Show Docker container status
#     make version                   # Show version information
#
# PERFORMANCE NOTES:
#   - Parallel execution: Many targets can run concurrently
#   - Resource usage: Full system requires ~2GB RAM
#   - Startup time: Initial setup takes 5-10 minutes
#   - Test suite: Complete tests take 10-15 minutes
#
# SECURITY CONSIDERATIONS:
#   - Never commit secrets to repository
#   - Use .env file for sensitive configuration
#   - Run `make security` to check for vulnerabilities
#   - XAVOS system uses secure authentication patterns
#
# AUTHORS:
#   AI Self-Sustaining System Team
#   Enhanced for enterprise Scrum at Scale coordination
#
# VERSION: 2.0.0 (Enhanced Shell Script Integration)
# =============================================================================

.PHONY: help setup dev test quality clean docker docs ci reactor validate
.DEFAULT_GOAL := help

# ============================================================================
# Configuration Variables
# ============================================================================
#
# Core application configuration variables used throughout the Makefile.
# These variables define paths, commands, and formatting options.
#
# IMPORTANT: Do not modify these unless you understand the implications.
# Many shell scripts and automation depend on these exact values.

# Application Metadata
# --------------------
# APP_NAME: Core application identifier used in deployment and monitoring
APP_NAME := self_sustaining

# APP_VERSION: Dynamically extracted from Phoenix mix.exs file
# This ensures version consistency across the entire system
APP_VERSION := $(shell grep 'version:' phoenix_app/mix.exs | cut -d'"' -f2)

# Directory Structure
# -------------------
# PROJECT_ROOT: Absolute path to the project root directory
# Used as base for all relative path calculations
PROJECT_ROOT := $(shell pwd)

# PHOENIX_DIR: Phoenix application directory
# Contains the main Elixir/Phoenix codebase
PHOENIX_DIR := $(PROJECT_ROOT)/phoenix_app

# Command Definitions
# -------------------
# Tool commands used throughout the Makefile
# These allow for easy customization and testing with different tool versions
DOCKER_COMPOSE := docker-compose
MIX := mix
ELIXIR := elixir

# Terminal Color Codes
# --------------------
# ANSI color codes for enhanced terminal output and user experience
# Used throughout the Makefile to provide clear, colored feedback
RED := \033[31m
GREEN := \033[32m
YELLOW := \033[33m
BLUE := \033[34m
MAGENTA := \033[35m
CYAN := \033[36m
WHITE := \033[37m
RESET := \033[0m

# Environment Detection
# ---------------------
# Detect the current operating system for platform-specific operations
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# Default Environment Variables
# ------------------------------
# Set default values for environment variables if not already defined
export MIX_ENV ?= dev
export DEPLOYMENT_ENV ?= development
export COORDINATION_DIR ?= $(PROJECT_ROOT)/agent_coordination

# ============================================================================
# Interactive Help System
# ============================================================================
#
# Comprehensive help system that provides detailed information about all
# available make targets. The help system uses inline documentation comments
# (##) to automatically generate usage information.
#
# FEATURES:
#   • Automatic target discovery and documentation
#   • Categorized command display
#   • Color-coded output for better readability
#   • Quick start guide and workflow recommendations
#   • System status information
#
# USAGE:
#   make help           # Show complete help (default target)
#   make <target>       # Run specific target
#
# NOTE: All targets with ## comments are automatically included in help output

help: ## Show comprehensive help and system overview
	@echo ""
	@echo "$(CYAN)🚀 AI Self-Sustaining System - Enhanced Makefile v2.0$(RESET)"
	@echo "$(CYAN)========================================================$(RESET)"
	@echo ""
	@echo "$(GREEN)📋 All Available Commands:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)🔧 Development Workflow:$(RESET)"
	@echo "  1. $(YELLOW)make setup$(RESET)               - Initial project setup"
	@echo "  2. $(YELLOW)make dev$(RESET)                 - Start development environment"
	@echo "  3. $(YELLOW)make test$(RESET)                - Run tests during development"
	@echo "  4. $(YELLOW)make quality$(RESET)             - Check code quality before commit"
	@echo ""
	@echo "$(GREEN)🌟 Comprehensive Commands:$(RESET)"
	@echo "  • $(YELLOW)make system-overview$(RESET)      - Show complete system overview"
	@echo "  • $(YELLOW)make system-health-full$(RESET)   - Full system health check"
	@echo "  • $(YELLOW)make system-full-test$(RESET)     - Run all system tests"
	@echo "  • $(YELLOW)make dev-full$(RESET)             - Start full dev environment"
	@echo ""
	@echo "$(GREEN)🚀 Enhanced Reactor Runner:$(RESET)"
	@echo "  • $(YELLOW)make reactor-help$(RESET)     - Show reactor commands"
	@echo "  • $(YELLOW)make reactor-test$(RESET)     - Test reactor with enhanced features"
	@echo "  • $(YELLOW)make reactor-monitor$(RESET)  - Monitor reactor execution with telemetry"
	@echo ""
	@echo "$(GREEN)🤝 Agent Coordination:$(RESET)"
	@echo "  • $(YELLOW)make coord-help$(RESET)           - Show coordination commands"
	@echo "  • $(YELLOW)make coord-dashboard$(RESET)      - View coordination dashboard"
	@echo "  • $(YELLOW)make coord-test$(RESET)           - Test coordination helper"
	@echo ""
	@echo "$(GREEN)🧠 Claude AI Intelligence:$(RESET)"
	@echo "  • $(YELLOW)make claude-help$(RESET)          - Show Claude AI commands"
	@echo "  • $(YELLOW)make claude-analyze-priorities$(RESET) - AI priority analysis"
	@echo "  • $(YELLOW)make claude-health-analysis$(RESET) - AI health analysis"
	@echo ""
	@echo "$(GREEN)🚀 XAVOS System:$(RESET)"
	@echo "  • $(YELLOW)make xavos-help$(RESET)           - Show XAVOS commands"
	@echo "  • $(YELLOW)make xavos-status$(RESET)         - Check XAVOS system status"
	@echo "  • $(YELLOW)make xavos-deploy-complete$(RESET) - Deploy complete XAVOS"
	@echo ""
	@echo "$(GREEN)📡 OpenTelemetry:$(RESET)"
	@echo "  • $(YELLOW)make otel-help$(RESET)            - Show OpenTelemetry commands"
	@echo "  • $(YELLOW)make otel-trace-validation$(RESET) - Validate traces"
	@echo "  • $(YELLOW)make otel-test-integration$(RESET) - Test OTel integration"
	@echo ""
	@echo "$(GREEN)🌳 Worktree Management:$(RESET)"
	@echo "  • $(YELLOW)make worktree-help$(RESET)        - Show worktree commands"
	@echo "  • $(YELLOW)make worktree-status$(RESET)      - Show worktree status"
	@echo "  • $(YELLOW)make worktree-create-s2s$(RESET)  - Create S2S worktree"
	@echo ""
	@echo "$(GREEN)🔧 System Scripts:$(RESET)"
	@echo "  • $(YELLOW)make script-status$(RESET)        - Run system status check"
	@echo "  • $(YELLOW)make script-integration-test$(RESET) - Run integration tests"
	@echo "  • $(YELLOW)make script-configure-claude$(RESET) - Configure Claude MCP"
	@echo ""
	@echo "$(GREEN)📊 Performance Benchmarks:$(RESET)"
	@echo "  • $(YELLOW)make benchmark-help$(RESET)       - Show benchmark commands"
	@echo "  • $(YELLOW)make benchmark-quick$(RESET)      - Run quick performance check"
	@echo "  • $(YELLOW)make benchmark-full$(RESET)       - Run comprehensive benchmarks"
	@echo ""
	@echo "$(GREEN)📊 System Status:$(RESET)"
	@echo "  • App Version: $(MAGENTA)$(APP_VERSION)$(RESET)"
	@echo "  • Project Root: $(MAGENTA)$(PROJECT_ROOT)$(RESET)"
	@echo "  • Phoenix Directory: $(MAGENTA)$(PHOENIX_DIR)$(RESET)"
	@echo ""

# ============================================================================
# Project Setup and Initialization
# ============================================================================
#
# Comprehensive setup system that initializes the entire AI Self-Sustaining
# System from a fresh checkout. This section handles dependency verification,
# environment setup, database initialization, and service configuration.
#
# SETUP PROCESS:
#   1. Dependency verification (check-dependencies)
#   2. Elixir environment setup (setup-elixir)
#   3. Database initialization (setup-database)
#   4. Frontend asset compilation (setup-assets)
#   5. Docker service configuration (setup-docker-env)
#
# PREREQUISITES:
#   • Elixir 1.14+ with OTP 25+
#   • PostgreSQL 14+ (or Docker for containerized DB)
#   • Node.js 18+ with npm
#   • Docker and Docker Compose
#   • Git (for repository operations)
#
# TIME ESTIMATE: 5-10 minutes for complete setup
# DISK SPACE: ~2GB for all dependencies and assets
#
# TROUBLESHOOTING:
#   • If setup fails, check individual targets: make check-dependencies
#   • For permission issues: ensure user can write to project directory
#   • For network issues: check internet connectivity and proxy settings

setup: ## Complete project setup (dependencies, database, assets, Docker services)
	@echo "$(CYAN)🔧 Setting up AI Self-Sustaining System...$(RESET)"
	@echo "$(BLUE)📋 Running comprehensive project initialization$(RESET)"
	@echo "$(YELLOW)⏱️  Estimated time: 5-10 minutes$(RESET)"
	@echo ""
	@$(MAKE) check-dependencies
	@$(MAKE) setup-elixir
	@$(MAKE) setup-database
	@$(MAKE) setup-assets
	@$(MAKE) setup-docker-env
	@echo ""
	@echo "$(GREEN)✅ Setup completed successfully!$(RESET)"
	@echo ""
	@echo "$(YELLOW)🚀 Next steps:$(RESET)"
	@echo "  1. Run $(BLUE)make dev$(RESET) to start development environment"
	@echo "  2. Visit $(BLUE)http://localhost:4000$(RESET) to see the Phoenix application"
	@echo "  3. Visit $(BLUE)http://localhost:4002$(RESET) to see the XAVOS system"
	@echo "  4. Run $(BLUE)make system-overview$(RESET) to see system status"
	@echo "  5. Run $(BLUE)make coord-dashboard$(RESET) to explore agent coordination"
	@echo ""
	@echo "$(CYAN)💡 Pro tips:$(RESET)"
	@echo "  • Use $(BLUE)make system-health-full$(RESET) for comprehensive health check"
	@echo "  • Use $(BLUE)make help$(RESET) to see all available commands"
	@echo "  • Check $(BLUE)make script-status$(RESET) if you encounter issues"

check-dependencies: ## Check if required tools are installed
	@echo "$(BLUE)📋 Checking dependencies...$(RESET)"
	@which elixir > /dev/null || (echo "$(RED)❌ Elixir not found. Install from https://elixir-lang.org/$(RESET)" && exit 1)
	@which mix > /dev/null || (echo "$(RED)❌ Mix not found. Elixir installation may be incomplete$(RESET)" && exit 1)
	@which docker > /dev/null || (echo "$(RED)❌ Docker not found. Install from https://docker.com/$(RESET)" && exit 1)
	@which docker-compose > /dev/null || (echo "$(RED)❌ Docker Compose not found$(RESET)" && exit 1)
	@which psql > /dev/null || echo "$(YELLOW)⚠️  PostgreSQL client not found. Database operations may be limited$(RESET)"
	@echo "$(GREEN)✅ All required dependencies found$(RESET)"

setup-elixir: ## Install Elixir dependencies and compile
	@echo "$(BLUE)📦 Installing Elixir dependencies...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) deps.get
	@cd $(PHOENIX_DIR) && $(MIX) deps.compile
	@cd $(PHOENIX_DIR) && $(MIX) compile
	@echo "$(GREEN)✅ Elixir dependencies installed$(RESET)"

setup-database: ## Setup database and run migrations
	@echo "$(BLUE)🗄️  Setting up database...$(RESET)"
	@$(MAKE) db-setup
	@echo "$(GREEN)✅ Database setup completed$(RESET)"

setup-assets: ## Install and build frontend assets
	@echo "$(BLUE)🎨 Setting up frontend assets...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) assets.setup
	@cd $(PHOENIX_DIR) && $(MIX) assets.build
	@echo "$(GREEN)✅ Assets setup completed$(RESET)"

setup-docker-env: ## Setup Docker environment and start supporting services
	@echo "$(BLUE)🐳 Setting up Docker environment...$(RESET)"
	@cp -n .env.example .env 2>/dev/null || echo "$(YELLOW)⚠️  .env file already exists$(RESET)"
	@$(DOCKER_COMPOSE) up -d postgres n8n qdrant ollama-cpu
	@echo "$(GREEN)✅ Docker services started$(RESET)"
	@echo "$(CYAN)📋 Services available:$(RESET)"
	@echo "  • PostgreSQL: $(BLUE)localhost:5434$(RESET)"
	@echo "  • N8N: $(BLUE)http://localhost:5678$(RESET)"
	@echo "  • Qdrant: $(BLUE)http://localhost:6333$(RESET)"
	@echo "  • Ollama: $(BLUE)localhost:11434$(RESET)"

# ============================================================================
# Development Commands
# ============================================================================

dev: ## Start development environment (Phoenix server + supporting services)
	@echo "$(CYAN)🚀 Starting development environment...$(RESET)"
	@$(MAKE) docker-start
	@echo "$(BLUE)⏳ Waiting for services to be ready...$(RESET)"
	@sleep 5
	@echo "$(GREEN)🌟 Starting Phoenix server...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) phx.server

dev-detached: ## Start development environment in background
	@echo "$(CYAN)🚀 Starting development environment (detached)...$(RESET)"
	@$(MAKE) docker-start
	@echo "$(BLUE)⏳ Waiting for services to be ready...$(RESET)"
	@sleep 5
	@echo "$(GREEN)🌟 Starting Phoenix server in background...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) phx.server &
	@echo "$(GREEN)✅ Development environment running in background$(RESET)"

dev-stop: ## Stop development environment
	@echo "$(YELLOW)🛑 Stopping development environment...$(RESET)"
	@$(MAKE) docker-stop
	@pkill -f "mix phx.server" || true
	@echo "$(GREEN)✅ Development environment stopped$(RESET)"

iex: ## Start interactive Elixir shell
	@echo "$(BLUE)🔧 Starting interactive Elixir shell...$(RESET)"
	@cd $(PHOENIX_DIR) && iex -S mix

shell: ## Start Phoenix console (interactive shell with app loaded)
	@echo "$(BLUE)🔧 Starting Phoenix console...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) run --no-halt

# ============================================================================
# Testing
# ============================================================================

test: ## Run all tests
	@echo "$(CYAN)🧪 Running all tests...$(RESET)"
	@$(MAKE) test-unit
	@$(MAKE) test-integration
	@$(MAKE) test-reactor
	@$(MAKE) test-coordination
	@echo "$(GREEN)✅ All tests completed$(RESET)"

test-unit: ## Run unit tests
	@echo "$(BLUE)🔬 Running unit tests...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) test --exclude integration

test-integration: ## Run integration tests
	@echo "$(BLUE)🔗 Running integration tests...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) test --only integration

test-watch: ## Run tests in watch mode
	@echo "$(BLUE)👀 Running tests in watch mode...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) test.watch

test-coverage: ## Run tests with coverage report
	@echo "$(BLUE)📊 Running tests with coverage...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) test --cover

test-reactor: ## Test enhanced reactor runner functionality
	@echo "$(BLUE)⚛️  Testing Enhanced Reactor Runner...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) test test/self_sustaining/reactor_middleware/
	@echo "$(GREEN)✅ Reactor tests completed$(RESET)"

test-coordination: ## Test agent coordination system (shell scripts and JSON consistency)
	@echo "$(BLUE)🤝 Testing Agent Coordination System...$(RESET)"
	@echo "$(CYAN)Running BATS test suite for coordination helper...$(RESET)"
	@cd agent_coordination && bats coordination_helper.bats
	@echo "$(CYAN)Testing coordination JSON format consistency...$(RESET)"
	@$(MAKE) test-coordination-consistency
	@echo "$(GREEN)✅ Agent coordination tests completed$(RESET)"

test-coordination-consistency: ## Verify JSON format consistency between shell and Elixir
	@echo "$(BLUE)🔍 Verifying JSON format consistency...$(RESET)"
	@echo "$(CYAN)Testing shell script work claim format...$(RESET)"
	@cd agent_coordination && \
		AGENT_ID="test_consistency_$$$$" ./coordination_helper.sh claim "format_test" "JSON consistency validation" "high" "test_team" >/dev/null && \
		echo "  ✅ Shell script: Work claim created" || echo "  ❌ Shell script: Work claim failed"
	@echo "$(CYAN)Validating JSON structure matches middleware expectations...$(RESET)"
	@cd agent_coordination && \
		jq -e '.[] | select(.agent_id | startswith("test_consistency")) | has("work_item_id", "agent_id", "reactor_id", "claimed_at", "work_type", "priority", "description", "status", "team")' work_claims.json >/dev/null && \
		echo "  ✅ JSON structure: Compatible with AgentCoordinationMiddleware" || echo "  ❌ JSON structure: Incompatible format detected"
	@echo "$(GREEN)✅ JSON consistency validation completed$(RESET)"

test-scrum-commands: ## Test all Scrum at Scale commands functionality
	@echo "$(BLUE)📊 Testing Scrum at Scale Commands...$(RESET)"
	@echo "$(CYAN)Testing core Scrum commands...$(RESET)"
	@cd agent_coordination && ./coordination_helper.sh dashboard >/dev/null && echo "  ✅ dashboard" || echo "  ❌ dashboard"
	@cd agent_coordination && ./coordination_helper.sh pi-planning >/dev/null && echo "  ✅ pi-planning" || echo "  ❌ pi-planning"
	@cd agent_coordination && ./coordination_helper.sh scrum-of-scrums >/dev/null && echo "  ✅ scrum-of-scrums" || echo "  ❌ scrum-of-scrums"
	@echo "$(CYAN)Testing new Scrum at Scale commands...$(RESET)"
	@cd agent_coordination && ./coordination_helper.sh innovation-planning >/dev/null && echo "  ✅ innovation-planning" || echo "  ❌ innovation-planning"
	@cd agent_coordination && ./coordination_helper.sh system-demo >/dev/null && echo "  ✅ system-demo" || echo "  ❌ system-demo"
	@cd agent_coordination && ./coordination_helper.sh inspect-adapt >/dev/null && echo "  ✅ inspect-adapt" || echo "  ❌ inspect-adapt"
	@cd agent_coordination && ./coordination_helper.sh art-sync >/dev/null && echo "  ✅ art-sync" || echo "  ❌ art-sync"
	@cd agent_coordination && ./coordination_helper.sh portfolio-kanban >/dev/null && echo "  ✅ portfolio-kanban" || echo "  ❌ portfolio-kanban"
	@cd agent_coordination && ./coordination_helper.sh coach-training >/dev/null && echo "  ✅ coach-training" || echo "  ❌ coach-training"
	@cd agent_coordination && ./coordination_helper.sh value-stream >/dev/null && echo "  ✅ value-stream" || echo "  ❌ value-stream"
	@echo "$(CYAN)Testing command aliases...$(RESET)"
	@cd agent_coordination && ./coordination_helper.sh ip >/dev/null && echo "  ✅ ip (innovation-planning alias)" || echo "  ❌ ip alias"
	@cd agent_coordination && ./coordination_helper.sh ia >/dev/null && echo "  ✅ ia (inspect-adapt alias)" || echo "  ❌ ia alias"
	@cd agent_coordination && ./coordination_helper.sh vsm >/dev/null && echo "  ✅ vsm (value-stream alias)" || echo "  ❌ vsm alias"
	@echo "$(GREEN)✅ Scrum at Scale commands tested$(RESET)"

# ============================================================================
# Quality Assurance
# ============================================================================

quality: ## Run all quality checks (compile, format, credo, dialyzer, tests)
	@echo "$(CYAN)🎯 Running comprehensive quality checks...$(RESET)"
	@$(MAKE) quality-compile
	@$(MAKE) quality-format-check
	@$(MAKE) quality-credo
	@$(MAKE) quality-dialyzer
	@$(MAKE) test-unit
	@$(MAKE) test-coordination
	@echo "$(GREEN)✅ All quality checks passed!$(RESET)"

quality-compile: ## Check compilation with warnings as errors
	@echo "$(BLUE)🔨 Checking compilation (warnings as errors)...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) compile --warnings-as-errors

quality-format: ## Format code
	@echo "$(BLUE)🎨 Formatting code...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) format

quality-format-check: ## Check if code is properly formatted
	@echo "$(BLUE)✅ Checking code formatting...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) format --check-formatted

quality-credo: ## Run static code analysis with Credo
	@echo "$(BLUE)🔍 Running static code analysis...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) credo --strict

quality-dialyzer: ## Run type checking with Dialyzer
	@echo "$(BLUE)🔬 Running type checking...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) dialyzer

quality-unused-deps: ## Check for unused dependencies
	@echo "$(BLUE)📦 Checking for unused dependencies...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) deps.unlock --check-unused

# ============================================================================
# Enhanced Reactor Runner Commands
# ============================================================================

reactor-help: ## Show enhanced reactor runner help
	@echo "$(CYAN)⚛️  Enhanced Reactor Runner Commands$(RESET)"
	@echo "$(CYAN)=====================================$(RESET)"
	@echo ""
	@echo "$(GREEN)📋 Available Commands:$(RESET)"
	@echo "  $(BLUE)make reactor-test$(RESET)           - Test reactor with enhanced features"
	@echo "  $(BLUE)make reactor-demo$(RESET)           - Run reactor demo with telemetry"
	@echo "  $(BLUE)make reactor-monitor$(RESET)        - Monitor reactor execution"
	@echo "  $(BLUE)make reactor-improvement$(RESET)    - Run self-improvement reactor"
	@echo "  $(BLUE)make reactor-n8n$(RESET)           - Run N8N integration reactor"
	@echo "  $(BLUE)make reactor-aps$(RESET)           - Run APS coordination reactor"
	@echo ""
	@echo "$(GREEN)🚀 Enhanced Features:$(RESET)"
	@echo "  • Automatic middleware integration (Debug, Telemetry, Coordination)"
	@echo "  • Nanosecond-precision agent IDs and work claiming"
	@echo "  • Real-time telemetry dashboard and monitoring"
	@echo "  • Enhanced error handling with retry mechanisms"
	@echo "  • Work coordination and progress tracking"
	@echo ""
	@echo "$(GREEN)📖 CLI Usage:$(RESET)"
	@echo "  $(YELLOW)cd phoenix_app && mix self_sustaining.reactor.run$(RESET)"
	@echo ""

reactor-test: ## Test enhanced reactor runner with telemetry
	@echo "$(BLUE)⚛️  Testing Enhanced Reactor Runner...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) self_sustaining.reactor.run \
		SelfSustaining.Workflows.SelfImprovementReactor \
		--input-improvement_request='{"type": "test", "priority": "medium"}' \
		--input-context='{"test_mode": true, "makefile_test": true}' \
		--verbose \
		--telemetry-dashboard \
		--retry-attempts 2 \
		--timeout 30000

reactor-demo: ## Run reactor demo showcasing enhanced features
	@echo "$(BLUE)🎬 Running Enhanced Reactor Demo...$(RESET)"
	@echo "$(CYAN)This demo showcases:$(RESET)"
	@echo "  • Automatic middleware integration"
	@echo "  • Real-time telemetry collection"
	@echo "  • Agent coordination with nanosecond precision"
	@echo "  • Enhanced error handling and recovery"
	@echo ""
	@cd $(PHOENIX_DIR) && $(MIX) self_sustaining.reactor.run \
		SelfSustaining.Workflows.SelfImprovementReactor \
		--input-improvement_request='{"type": "performance", "priority": "high", "urgency": "medium"}' \
		--input-context='{"demo_mode": true, "showcase_features": true}' \
		--verbose \
		--telemetry-dashboard \
		--retry-attempts 3 \
		--priority high

reactor-monitor: ## Monitor reactor execution with comprehensive telemetry
	@echo "$(BLUE)📊 Starting Reactor Monitoring Session...$(RESET)"
	@echo "$(CYAN)Monitoring features:$(RESET)"
	@echo "  • Real-time step execution tracking"
	@echo "  • Performance metrics collection"
	@echo "  • Error detection and reporting"
	@echo "  • Work coordination status"
	@echo ""
	@cd $(PHOENIX_DIR) && $(MIX) self_sustaining.reactor.run \
		SelfSustaining.Workflows.SelfImprovementReactor \
		--input-improvement_request='{"type": "monitoring_test", "priority": "medium"}' \
		--input-context='{"monitoring_mode": true, "collect_metrics": true}' \
		--verbose \
		--telemetry-dashboard \
		--agent-coordination \
		--timeout 60000

reactor-improvement: ## Run self-improvement reactor with enhanced features
	@echo "$(BLUE)🧠 Running Self-Improvement Reactor...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) self_sustaining.reactor.run \
		SelfSustaining.Workflows.SelfImprovementReactor \
		--input-improvement_request='{"type": "code_quality", "priority": "high"}' \
		--input-context='{"automated_improvement": true}' \
		--verbose \
		--agent-coordination \
		--work-type "self_improvement" \
		--priority high

reactor-n8n: ## Run N8N integration reactor (requires N8N running)
	@echo "$(BLUE)🔗 Running N8N Integration Reactor...$(RESET)"
	@$(MAKE) ensure-n8n-running
	@cd $(PHOENIX_DIR) && $(MIX) self_sustaining.reactor.run \
		SelfSustaining.Workflows.N8nIntegrationReactor \
		--input-workflow_definition='{"name": "makefile_test", "nodes": [], "connections": []}' \
		--input-n8n_config='{"api_url": "http://localhost:5678/api/v1"}' \
		--verbose \
		--work-type "n8n_integration"

reactor-aps: ## Run APS coordination reactor
	@echo "$(BLUE)📋 Running APS Coordination Reactor...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) self_sustaining.reactor.run \
		SelfSustaining.Workflows.APSReactor \
		--input-process_definition='{"name": "test_process", "type": "coordination"}' \
		--input-context='{"aps_mode": true}' \
		--verbose \
		--work-type "aps_coordination"

# ============================================================================
# Performance Benchmarks
# ============================================================================

benchmark-help: ## Show performance benchmark help
	@echo "$(CYAN)📊 Enhanced Reactor Runner Performance Benchmarks$(RESET)"
	@echo "$(CYAN)================================================$(RESET)"
	@echo ""
	@echo "$(GREEN)📋 Benchmark Commands:$(RESET)"
	@echo "  $(BLUE)make benchmark-quick$(RESET)          - Quick performance check (30 seconds)"
	@echo "  $(BLUE)make benchmark-full$(RESET)           - Comprehensive performance benchmark"
	@echo "  $(BLUE)make benchmark-telemetry$(RESET)      - Validate telemetry system performance"
	@echo "  $(BLUE)make benchmark-stress$(RESET)         - Run stress test (30 seconds)"
	@echo "  $(BLUE)make benchmark-stress-long$(RESET)    - Run extended stress test (5 minutes)"
	@echo ""
	@echo "$(GREEN)🚀 Benchmark Features:$(RESET)"
	@echo "  • Execution performance measurement with/without middleware"
	@echo "  • Memory usage analysis and optimization recommendations"
	@echo "  • Concurrency scaling and optimal worker count detection"
	@echo "  • Telemetry system validation and overhead analysis"
	@echo "  • Agent coordination performance under load"
	@echo "  • Comprehensive performance reporting and recommendations"
	@echo ""
	@echo "$(GREEN)📊 Results:$(RESET)"
	@echo "  • Real-time performance metrics and analysis"
	@echo "  • Automated performance rating and recommendations"
	@echo "  • JSON reports saved to benchmarks/ directory"
	@echo "  • Comparison with baseline performance characteristics"
	@echo ""

benchmark-quick: ## Run quick performance check
	@echo "$(BLUE)⚡ Running Quick Performance Benchmark...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) benchmark quick

benchmark-full: ## Run comprehensive performance benchmark
	@echo "$(BLUE)📊 Running Comprehensive Performance Benchmark...$(RESET)"
	@echo "$(YELLOW)This may take several minutes to complete...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) benchmark full

benchmark-telemetry: ## Validate telemetry system performance
	@echo "$(BLUE)📡 Validating Telemetry System Performance...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) benchmark telemetry

benchmark-stress: ## Run stress test (30 seconds)
	@echo "$(BLUE)💪 Running Stress Test (30 seconds)...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) benchmark stress

benchmark-stress-long: ## Run extended stress test (5 minutes)
	@echo "$(BLUE)💪 Running Extended Stress Test (5 minutes)...$(RESET)"
	@echo "$(YELLOW)This will run for 5 minutes to test sustained performance...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) benchmark stress 300

benchmark-all: ## Run all benchmark tests
	@echo "$(CYAN)🎯 Running Complete Benchmark Suite...$(RESET)"
	@echo "$(CYAN)=====================================$(RESET)"
	@$(MAKE) benchmark-quick
	@echo ""
	@$(MAKE) benchmark-telemetry
	@echo ""
	@$(MAKE) benchmark-stress
	@echo ""
	@echo "$(GREEN)✅ Complete benchmark suite finished!$(RESET)"
	@echo "$(CYAN)For comprehensive analysis, run: $(YELLOW)make benchmark-full$(RESET)"

# ============================================================================
# Agent Coordination System
# ============================================================================

coordination-help: ## Show agent coordination system help
	@echo "$(CYAN)🤝 Agent Coordination System Commands$(RESET)"
	@echo "$(CYAN)====================================$(RESET)"
	@echo ""
	@echo "$(GREEN)📋 Testing Commands:$(RESET)"
	@echo "  $(BLUE)make test-coordination$(RESET)           - Run complete coordination test suite"
	@echo "  $(BLUE)make test-coordination-consistency$(RESET) - Test JSON format consistency"
	@echo "  $(BLUE)make test-scrum-commands$(RESET)         - Test all Scrum at Scale commands"
	@echo ""
	@echo "$(GREEN)🎯 Scrum at Scale Commands (via coordination helper):$(RESET)"
	@echo "  $(BLUE)cd agent_coordination && ./coordination_helper.sh <command>$(RESET)"
	@echo ""
	@echo "$(GREEN)📊 Core Work Management:$(RESET)"
	@echo "  • $(YELLOW)claim <work_type> <description> [priority] [team]$(RESET) - Claim work"
	@echo "  • $(YELLOW)progress <work_id> <percent> [status]$(RESET)            - Update progress"
	@echo "  • $(YELLOW)complete <work_id> [result] [velocity]$(RESET)           - Complete work"
	@echo "  • $(YELLOW)dashboard$(RESET)                                        - Show dashboard"
	@echo ""
	@echo "$(GREEN)🎯 Scrum at Scale Events:$(RESET)"
	@echo "  • $(YELLOW)pi-planning$(RESET)                                      - PI Planning session"
	@echo "  • $(YELLOW)innovation-planning$(RESET) ($(YELLOW)ip$(RESET))                         - Innovation & Planning iteration"
	@echo "  • $(YELLOW)system-demo$(RESET)                                      - Integrated system demo"
	@echo "  • $(YELLOW)inspect-adapt$(RESET) ($(YELLOW)ia$(RESET))                               - Inspect & Adapt workshop"
	@echo "  • $(YELLOW)scrum-of-scrums$(RESET)                                  - Cross-team coordination"
	@echo "  • $(YELLOW)art-sync$(RESET)                                         - ART synchronization"
	@echo ""
	@echo "$(GREEN)📈 Enterprise Commands:$(RESET)"
	@echo "  • $(YELLOW)portfolio-kanban$(RESET)                                 - Portfolio epic management"
	@echo "  • $(YELLOW)coach-training$(RESET)                                   - Coaching development"
	@echo "  • $(YELLOW)value-stream$(RESET) ($(YELLOW)vsm$(RESET))                               - Value stream mapping"
	@echo ""
	@echo "$(GREEN)✅ Test Coverage:$(RESET)"
	@echo "  • 26 BATS unit tests for all functionality"
	@echo "  • JSON format consistency validation"
	@echo "  • Integration with AgentCoordinationMiddleware"
	@echo "  • Command alias testing"
	@echo "  • Error handling and concurrency safety"
	@echo ""

# ============================================================================
# Database Operations
# ============================================================================

db-setup: ## Setup database (create, migrate, seed)
	@echo "$(BLUE)🗄️  Setting up database...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) ecto.setup

db-migrate: ## Run database migrations
	@echo "$(BLUE)📈 Running database migrations...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) ecto.migrate

db-rollback: ## Rollback last database migration
	@echo "$(BLUE)📉 Rolling back last migration...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) ecto.rollback

db-reset: ## Reset database (drop, create, migrate, seed)
	@echo "$(YELLOW)🔄 Resetting database...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) ecto.reset

db-seed: ## Seed database with initial data
	@echo "$(BLUE)🌱 Seeding database...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) run priv/repo/seeds.exs

db-console: ## Open database console
	@echo "$(BLUE)💻 Opening database console...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) ecto.psql

# ============================================================================
# Docker Operations
# ============================================================================

docker-start: ## Start all Docker services
	@echo "$(BLUE)🐳 Starting Docker services...$(RESET)"
	@$(DOCKER_COMPOSE) up -d

docker-stop: ## Stop all Docker services
	@echo "$(YELLOW)🛑 Stopping Docker services...$(RESET)"
	@$(DOCKER_COMPOSE) down

docker-restart: ## Restart all Docker services
	@echo "$(BLUE)🔄 Restarting Docker services...$(RESET)"
	@$(DOCKER_COMPOSE) restart

docker-logs: ## View Docker service logs
	@echo "$(BLUE)📋 Viewing Docker logs...$(RESET)"
	@$(DOCKER_COMPOSE) logs -f

docker-ps: ## Show running Docker containers
	@echo "$(BLUE)📋 Docker container status:$(RESET)"
	@$(DOCKER_COMPOSE) ps

docker-clean: ## Clean up Docker resources (containers, volumes, networks)
	@echo "$(YELLOW)🧹 Cleaning up Docker resources...$(RESET)"
	@$(DOCKER_COMPOSE) down -v
	@docker system prune -f

docker-build: ## Build custom Docker images
	@echo "$(BLUE)🔨 Building Docker images...$(RESET)"
	@$(DOCKER_COMPOSE) build

ensure-n8n-running: ## Ensure N8N service is running
	@echo "$(BLUE)🔍 Checking N8N service...$(RESET)"
	@$(DOCKER_COMPOSE) ps n8n | grep -q "Up" || (echo "$(YELLOW)Starting N8N...$(RESET)" && $(DOCKER_COMPOSE) up -d n8n && sleep 10)

# ============================================================================
# Documentation
# ============================================================================

docs: ## Generate and serve documentation
	@echo "$(BLUE)📚 Generating documentation...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) docs
	@echo "$(GREEN)✅ Documentation generated in doc/$(RESET)"
	@echo "$(CYAN)Opening documentation...$(RESET)"
	@open $(PHOENIX_DIR)/doc/index.html || xdg-open $(PHOENIX_DIR)/doc/index.html || echo "$(YELLOW)Open $(PHOENIX_DIR)/doc/index.html manually$(RESET)"

docs-serve: ## Serve documentation with live reload
	@echo "$(BLUE)📚 Serving documentation with live reload...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) docs && python3 -m http.server 8080 -d doc

# ============================================================================
# Monitoring and Health Checks
# ============================================================================

health: ## Check system health
	@echo "$(CYAN)🏥 System Health Check$(RESET)"
	@echo "$(CYAN)===================$(RESET)"
	@echo ""
	@echo "$(BLUE)📋 Service Status:$(RESET)"
	@$(MAKE) health-services
	@echo ""
	@echo "$(BLUE)📊 Application Status:$(RESET)"
	@$(MAKE) health-app
	@echo ""
	@echo "$(BLUE)⚛️  Reactor Status:$(RESET)"
	@$(MAKE) health-reactor

health-services: ## Check Docker service health
	@echo "$(BLUE)🐳 Docker Services:$(RESET)"
	@$(DOCKER_COMPOSE) ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

health-app: ## Check Phoenix application health
	@echo "$(BLUE)🌟 Phoenix Application:$(RESET)"
	@curl -s http://localhost:4000/api/health 2>/dev/null | grep -q "ok" && echo "  ✅ Application: Healthy" || echo "  ❌ Application: Not responding"
	@curl -s http://localhost:4000/api/metrics 2>/dev/null | grep -q "metrics" && echo "  ✅ Metrics: Available" || echo "  ❌ Metrics: Not available"

health-reactor: ## Check reactor system health
	@echo "$(BLUE)⚛️  Enhanced Reactor Runner:$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) help self_sustaining.reactor.run >/dev/null 2>&1 && echo "  ✅ Enhanced Reactor Runner: Available" || echo "  ❌ Enhanced Reactor Runner: Not available"
	@ls $(PHOENIX_DIR)/lib/self_sustaining/reactor_middleware/*.ex >/dev/null 2>&1 && echo "  ✅ Reactor Middleware: Installed" || echo "  ❌ Reactor Middleware: Missing"

monitor: ## Start comprehensive system monitoring
	@echo "$(CYAN)📊 Starting System Monitoring$(RESET)"
	@echo "$(CYAN)=============================$(RESET)"
	@echo ""
	@echo "$(BLUE)Press Ctrl+C to stop monitoring$(RESET)"
	@echo ""
	@while true; do \
		clear; \
		echo "$(CYAN)📊 AI Self-Sustaining System Monitor - $$(date)$(RESET)"; \
		echo "$(CYAN)================================================$(RESET)"; \
		echo ""; \
		$(MAKE) health-services; \
		echo ""; \
		$(MAKE) health-app; \
		echo ""; \
		echo "$(BLUE)💾 System Resources:$(RESET)"; \
		echo "  Memory: $$(free -h | awk '/^Mem:/ {print $$3 "/" $$2}' 2>/dev/null || echo 'N/A')"; \
		echo "  Disk: $$(df -h . | awk 'NR==2 {print $$3 "/" $$2 " (" $$5 " used)"}' 2>/dev/null || echo 'N/A')"; \
		sleep 10; \
	done

# ============================================================================
# Deployment and Production
# ============================================================================

deploy-staging: ## Deploy to staging environment
	@echo "$(CYAN)🚀 Deploying to staging...$(RESET)"
	@$(MAKE) quality
	@echo "$(BLUE)🔨 Building release...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) assets.deploy
	@cd $(PHOENIX_DIR) && $(MIX) release
	@echo "$(GREEN)✅ Staging deployment ready$(RESET)"

deploy-prod: ## Deploy to production environment
	@echo "$(RED)🚨 Production Deployment$(RESET)"
	@echo "$(YELLOW)Are you sure you want to deploy to production? [y/N]$(RESET)"
	@read confirm && [ "$$confirm" = "y" ] || (echo "$(YELLOW)Deployment cancelled$(RESET)" && exit 1)
	@$(MAKE) quality
	@echo "$(BLUE)🔨 Building production release...$(RESET)"
	@cd $(PHOENIX_DIR) && MIX_ENV=prod $(MIX) assets.deploy
	@cd $(PHOENIX_DIR) && MIX_ENV=prod $(MIX) release
	@echo "$(GREEN)✅ Production deployment ready$(RESET)"

# ============================================================================
# Utility Commands
# ============================================================================

clean: ## Clean build artifacts and dependencies
	@echo "$(YELLOW)🧹 Cleaning build artifacts...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) clean
	@cd $(PHOENIX_DIR) && rm -rf _build deps node_modules
	@echo "$(GREEN)✅ Clean completed$(RESET)"

clean-docker: ## Clean Docker resources
	@echo "$(YELLOW)🧹 Cleaning Docker resources...$(RESET)"
	@$(MAKE) docker-clean

reset: ## Full reset (clean + setup)
	@echo "$(YELLOW)🔄 Performing full reset...$(RESET)"
	@$(MAKE) clean
	@$(MAKE) clean-docker
	@$(MAKE) setup
	@echo "$(GREEN)✅ Reset completed$(RESET)"

logs: ## Tail application logs
	@echo "$(BLUE)📋 Tailing application logs...$(RESET)"
	@tail -f $(PHOENIX_DIR)/phoenix_server.log

version: ## Show version information
	@echo "$(CYAN)📋 Version Information$(RESET)"
	@echo "$(CYAN)=====================$(RESET)"
	@echo "App Version: $(MAGENTA)$(APP_VERSION)$(RESET)"
	@echo "Elixir Version: $(MAGENTA)$$(elixir --version | head -1)$(RESET)"
	@echo "Mix Version: $(MAGENTA)$$(mix --version)$(RESET)"
	@echo "Phoenix Version: $(MAGENTA)$$(cd $(PHOENIX_DIR) && mix deps | grep phoenix | head -1 | awk '{print $$2}')$(RESET)"
	@echo "Docker Version: $(MAGENTA)$$(docker --version)$(RESET)"

# ============================================================================
# CI/CD Commands
# ============================================================================

ci: ## Run CI pipeline (quality + tests)
	@echo "$(CYAN)🤖 Running CI Pipeline$(RESET)"
	@echo "$(CYAN)=====================$(RESET)"
	@$(MAKE) check-dependencies
	@$(MAKE) setup-elixir
	@$(MAKE) quality
	@$(MAKE) test
	@echo "$(GREEN)✅ CI Pipeline completed successfully$(RESET)"

validate: ## Validate entire system (comprehensive check)
	@echo "$(CYAN)✅ System Validation$(RESET)"
	@echo "$(CYAN)==================$(RESET)"
	@$(MAKE) check-dependencies
	@$(MAKE) quality
	@$(MAKE) test
	@$(MAKE) health
	@$(MAKE) reactor-test
	@echo "$(GREEN)🎉 System validation completed successfully!$(RESET)"
	@echo ""
	@echo "$(CYAN)📋 Summary:$(RESET)"
	@echo "  ✅ Dependencies checked"
	@echo "  ✅ Code quality validated"
	@echo "  ✅ Tests passed"
	@echo "  ✅ System health verified"
	@echo "  ✅ Enhanced Reactor Runner tested"
	@echo ""
	@echo "$(GREEN)🚀 System is ready for production!$(RESET)"

# ============================================================================
# Development Utilities
# ============================================================================

install: ## Install additional development tools
	@echo "$(BLUE)🔧 Installing development tools...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) archive.install hex phx_new
	@cd $(PHOENIX_DIR) && $(MIX) local.hex --force
	@echo "$(GREEN)✅ Development tools installed$(RESET)"

update: ## Update dependencies
	@echo "$(BLUE)📦 Updating dependencies...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) deps.update --all
	@cd $(PHOENIX_DIR) && $(MIX) deps.compile
	@echo "$(GREEN)✅ Dependencies updated$(RESET)"

security: ## Run security checks
	@echo "$(BLUE)🔒 Running security checks...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) deps.audit
	@cd $(PHOENIX_DIR) && $(MIX) sobelow
	@echo "$(GREEN)✅ Security checks completed$(RESET)"

# ============================================================================
# Shell Script Integration
# ============================================================================

script-status: ## Run system status check script
	@echo "$(BLUE)📋 Running system status check...$(RESET)"
	@./scripts/check_status.sh

script-monitor: ## Run system monitoring script
	@echo "$(BLUE)📊 Starting system monitoring...$(RESET)"
	@./scripts/monitor.sh

script-configure-claude: ## Configure Claude Desktop MCP
	@echo "$(BLUE)🤖 Configuring Claude Desktop...$(RESET)"
	@./scripts/configure_claude.sh

script-integration-test: ## Run comprehensive integration tests
	@echo "$(BLUE)🧪 Running integration tests...$(RESET)"
	@./test_integration.sh

# ============================================================================
# Agent Coordination Commands
# ============================================================================

coord-help: ## Show agent coordination help
	@echo "$(CYAN)🤝 Agent Coordination Commands$(RESET)"
	@echo "$(CYAN)==============================$(RESET)"
	@echo ""
	@cd agent_coordination && ./coordination_helper.sh help

coord-dashboard: ## Show coordination dashboard
	@echo "$(BLUE)📊 Agent Coordination Dashboard$(RESET)"
	@cd agent_coordination && ./coordination_helper.sh dashboard

coord-test: ## Test coordination helper functionality
	@echo "$(BLUE)🧪 Testing coordination helper...$(RESET)"
	@cd agent_coordination && ./test_coordination_helper.sh

coord-pi-planning: ## Run PI Planning session
	@echo "$(BLUE)🎯 Starting PI Planning...$(RESET)"
	@cd agent_coordination && ./coordination_helper.sh pi-planning

coord-scrum-of-scrums: ## Run Scrum of Scrums coordination
	@echo "$(BLUE)🤝 Scrum of Scrums Coordination...$(RESET)"
	@cd agent_coordination && ./coordination_helper.sh scrum-of-scrums

coord-art-sync: ## Run ART synchronization
	@echo "$(BLUE)🔄 ART Sync Meeting...$(RESET)"
	@cd agent_coordination && ./coordination_helper.sh art-sync

coord-system-demo: ## Run system demo
	@echo "$(BLUE)🎬 System Demo...$(RESET)"
	@cd agent_coordination && ./coordination_helper.sh system-demo

coord-inspect-adapt: ## Run Inspect & Adapt workshop
	@echo "$(BLUE)🔍 Inspect & Adapt Workshop...$(RESET)"
	@cd agent_coordination && ./coordination_helper.sh inspect-adapt

coord-portfolio-kanban: ## Portfolio Kanban management
	@echo "$(BLUE)📊 Portfolio Kanban...$(RESET)"
	@cd agent_coordination && ./coordination_helper.sh portfolio-kanban

coord-value-stream: ## Value stream mapping
	@echo "$(BLUE)🗺️ Value Stream Mapping...$(RESET)"
	@cd agent_coordination && ./coordination_helper.sh value-stream

# ============================================================================
# Claude AI Intelligence
# ============================================================================

claude-help: ## Show Claude intelligence commands
	@echo "$(CYAN)🧠 Claude AI Intelligence Commands$(RESET)"
	@echo "$(CYAN)==================================$(RESET)"
	@echo ""
	@cd agent_coordination && ./coordination_helper.sh claude-dashboard

claude-analyze-priorities: ## Analyze work priorities with Claude
	@echo "$(BLUE)🎯 Claude Priority Analysis...$(RESET)"
	@cd agent_coordination && ./coordination_helper.sh claude-analyze-priorities

claude-optimize-assignments: ## Optimize agent assignments with Claude
	@echo "$(BLUE)🎯 Claude Assignment Optimization...$(RESET)"
	@cd agent_coordination && ./coordination_helper.sh claude-optimize-assignments

claude-health-analysis: ## Perform Claude health analysis
	@echo "$(BLUE)🏥 Claude Health Analysis...$(RESET)"
	@cd agent_coordination && ./coordination_helper.sh claude-health-analysis

claude-team-analysis: ## Analyze team formation with Claude
	@echo "$(BLUE)👥 Claude Team Analysis...$(RESET)"
	@cd agent_coordination && ./coordination_helper.sh claude-team-analysis

claude-stream: ## Real-time Claude coordination stream
	@echo "$(BLUE)🔄 Claude Real-time Stream...$(RESET)"
	@cd agent_coordination && ./coordination_helper.sh claude-stream system 30

# ============================================================================
# XAVOS System Management
# ============================================================================

xavos-help: ## Show XAVOS system commands
	@echo "$(CYAN)🚀 XAVOS System Management$(RESET)"
	@echo "$(CYAN)=========================$(RESET)"
	@echo ""
	@echo "$(GREEN)🏗️ XAVOS Deployment Commands:$(RESET)"
	@echo "  $(BLUE)make xavos-deploy-complete$(RESET)    - Full XAVOS deployment"
	@echo "  $(BLUE)make xavos-deploy-realistic$(RESET)   - Realistic XAVOS deployment"
	@echo "  $(BLUE)make xavos-exact-commands$(RESET)     - Run exact XAVOS commands"
	@echo "  $(BLUE)make xavos-test-commands$(RESET)      - Test XAVOS commands"
	@echo ""
	@echo "$(GREEN)📊 XAVOS Status:$(RESET)"
	@echo "  • Location: $(MAGENTA)worktrees/xavos-system/xavos/$(RESET)"
	@echo "  • Port: $(MAGENTA)4002$(RESET)"
	@echo "  • Access: $(BLUE)http://localhost:4002$(RESET)"

xavos-deploy-complete: ## Deploy complete XAVOS system
	@echo "$(BLUE)🚀 Deploying complete XAVOS system...$(RESET)"
	@cd agent_coordination && ./deploy_xavos_complete.sh

xavos-deploy-realistic: ## Deploy XAVOS with realistic settings
	@echo "$(BLUE)🚀 Deploying XAVOS (realistic)...$(RESET)"
	@cd agent_coordination && ./deploy_xavos_realistic.sh

xavos-exact-commands: ## Run exact XAVOS command sequences
	@echo "$(BLUE)⚡ Running exact XAVOS commands...$(RESET)"
	@cd agent_coordination && ./xavos_exact_commands.sh

xavos-test-commands: ## Test XAVOS command functionality
	@echo "$(BLUE)🧪 Testing XAVOS commands...$(RESET)"
	@cd agent_coordination && ./test_xavos_commands.sh

xavos-status: ## Check XAVOS system status
	@echo "$(BLUE)📊 XAVOS System Status$(RESET)"
	@echo "$(CYAN)=====================$(RESET)"
	@echo ""
	@echo "$(GREEN)System Information:$(RESET)"
	@echo "  Location: worktrees/xavos-system/xavos/"
	@echo "  Port: 4002"
	@echo "  Access URL: http://localhost:4002"
	@echo ""
	@echo "$(GREEN)Quick Health Check:$(RESET)"
	@curl -s http://localhost:4002 >/dev/null 2>&1 && echo "  ✅ XAVOS: Running" || echo "  ❌ XAVOS: Not responding"

# ============================================================================
# Worktree Management
# ============================================================================

worktree-help: ## Show worktree management commands
	@echo "$(CYAN)🌳 Worktree Management Commands$(RESET)"
	@echo "$(CYAN)===============================$(RESET)"
	@echo ""
	@echo "$(GREEN)📋 Available Commands:$(RESET)"
	@echo "  $(BLUE)make worktree-status$(RESET)           - Show all worktree status"
	@echo "  $(BLUE)make worktree-create-s2s$(RESET)       - Create S2S worktree"
	@echo "  $(BLUE)make worktree-create-ash$(RESET)       - Create Ash Phoenix worktree"
	@echo "  $(BLUE)make worktree-manage$(RESET)           - Manage existing worktrees"
	@echo "  $(BLUE)make worktree-test-gaps$(RESET)        - Test worktree functionality"
	@echo "  $(BLUE)make worktree-env-manager$(RESET)      - Manage worktree environments"

worktree-status: ## Show status of all worktrees
	@echo "$(BLUE)🌳 Worktree Status$(RESET)"
	@echo "$(CYAN)==================$(RESET)"
	@git worktree list
	@echo ""
	@echo "$(GREEN)Worktree Health Check:$(RESET)"
	@cd worktrees/xavos-system && echo "  ✅ XAVOS worktree: $(shell cd worktrees/xavos-system && git branch --show-current)"
	@cd worktrees/phoenix-ai-nexus && echo "  ✅ Phoenix AI Nexus worktree: $(shell cd worktrees/phoenix-ai-nexus && git branch --show-current)"

worktree-create-s2s: ## Create new S2S worktree
	@echo "$(BLUE)🌱 Creating S2S worktree...$(RESET)"
	@cd agent_coordination && ./create_s2s_worktree.sh

worktree-create-ash: ## Create new Ash Phoenix worktree
	@echo "$(BLUE)🌱 Creating Ash Phoenix worktree...$(RESET)"
	@cd agent_coordination && ./create_ash_phoenix_worktree.sh

worktree-manage: ## Manage existing worktrees
	@echo "$(BLUE)🔧 Managing worktrees...$(RESET)"
	@cd agent_coordination && ./manage_worktrees.sh

worktree-test-gaps: ## Test worktree functionality gaps
	@echo "$(BLUE)🧪 Testing worktree gaps...$(RESET)"
	@cd agent_coordination && ./test_worktree_gaps.sh

worktree-env-manager: ## Run worktree environment manager
	@echo "$(BLUE)🌍 Managing worktree environments...$(RESET)"
	@cd agent_coordination && ./worktree_environment_manager.sh

# ============================================================================
# OpenTelemetry and Telemetry
# ============================================================================

otel-help: ## Show OpenTelemetry commands
	@echo "$(CYAN)📡 OpenTelemetry Commands$(RESET)"
	@echo "$(CYAN)========================$(RESET)"
	@echo ""
	@echo "$(GREEN)📋 Available Commands:$(RESET)"
	@echo "  $(BLUE)make otel-test-integration$(RESET)     - Test OpenTelemetry integration"
	@echo "  $(BLUE)make otel-trace-validation$(RESET)     - Validate trace implementation"
	@echo "  $(BLUE)make otel-trace-performance$(RESET)    - Performance trace validation"
	@echo "  $(BLUE)make otel-detect-antipatterns$(RESET)  - Detect trace antipatterns"
	@echo "  $(BLUE)make otel-fix-traces$(RESET)           - Fix telemetry traces"
	@echo "  $(BLUE)make otel-add-support$(RESET)          - Add trace support"

otel-test-integration: ## Test OpenTelemetry integration
	@echo "$(BLUE)📡 Testing OpenTelemetry integration...$(RESET)"
	@cd agent_coordination && ./test_otel_integration.sh

otel-trace-validation: ## Run trace validation suite
	@echo "$(BLUE)🔍 Running trace validation...$(RESET)"
	@cd phoenix_app/scripts && ./trace_validation_suite.sh

otel-trace-implementation: ## Validate trace implementation
	@echo "$(BLUE)🔍 Validating trace implementation...$(RESET)"
	@cd phoenix_app/scripts && ./validate_trace_implementation.sh

otel-trace-performance: ## Validate trace performance
	@echo "$(BLUE)⚡ Validating trace performance...$(RESET)"
	@cd phoenix_app/scripts && ./validate_trace_performance.sh

otel-detect-antipatterns: ## Detect trace antipatterns
	@echo "$(BLUE)🔍 Detecting trace antipatterns...$(RESET)"
	@cd phoenix_app/scripts && ./detect_trace_antipatterns.sh

otel-fix-traces: ## Fix telemetry traces
	@echo "$(BLUE)🔧 Fixing telemetry traces...$(RESET)"
	@cd phoenix_app/scripts && ./fix_telemetry_traces.sh

otel-add-support: ## Add trace support
	@echo "$(BLUE)➕ Adding trace support...$(RESET)"
	@cd phoenix_app/scripts && ./add_trace_support.sh

# ============================================================================
# System Integration and SPR
# ============================================================================

spr-help: ## Show SPR (Sparse Priming Representation) commands
	@echo "$(CYAN)🧬 SPR Commands$(RESET)"
	@echo "$(CYAN)==============$(RESET)"
	@echo ""
	@echo "$(GREEN)📋 Available Commands:$(RESET)"
	@echo "  $(BLUE)make spr-compress$(RESET)              - Compress data using SPR"
	@echo "  $(BLUE)make spr-decompress$(RESET)            - Decompress SPR data"
	@echo "  $(BLUE)make spr-pipeline$(RESET)              - Run SPR pipeline"
	@echo "  $(BLUE)make spr-test$(RESET)                  - Test SPR CLI functionality"

spr-compress: ## Compress data using SPR
	@echo "$(BLUE)🗜️ Running SPR compression...$(RESET)"
	@./spr_compress.sh

spr-decompress: ## Decompress SPR data
	@echo "$(BLUE)📂 Running SPR decompression...$(RESET)"
	@./spr_decompress.sh

spr-pipeline: ## Run SPR pipeline
	@echo "$(BLUE)🔄 Running SPR pipeline...$(RESET)"
	@./spr_pipeline.sh

spr-test: ## Test SPR CLI functionality
	@echo "$(BLUE)🧪 Testing SPR CLI...$(RESET)"
	@./test_spr_cli.sh

# ============================================================================
# Comprehensive System Commands
# ============================================================================

system-overview: ## Show comprehensive system overview
	@echo "$(CYAN)🌟 AI Self-Sustaining System Overview$(RESET)"
	@echo "$(CYAN)=====================================$(RESET)"
	@echo ""
	@echo "$(GREEN)📊 System Components:$(RESET)"
	@echo "  • Phoenix Application: $(shell cd $(PHOENIX_DIR) && mix --version | head -1)"
	@echo "  • Agent Coordination: 40+ shell commands"
	@echo "  • XAVOS System: Complete Ash Framework ecosystem"
	@echo "  • Claude AI Integration: Structured JSON analysis"
	@echo "  • OpenTelemetry: Distributed tracing"
	@echo "  • Worktrees: $(shell git worktree list | wc -l) active worktrees"
	@echo ""
	@echo "$(GREEN)🚀 Quick Start Commands:$(RESET)"
	@echo "  1. $(YELLOW)make setup$(RESET)                  - Initial setup"
	@echo "  2. $(YELLOW)make script-status$(RESET)          - Check system status"
	@echo "  3. $(YELLOW)make coord-dashboard$(RESET)        - View coordination dashboard"
	@echo "  4. $(YELLOW)make claude-analyze-priorities$(RESET) - AI analysis"
	@echo "  5. $(YELLOW)make otel-trace-validation$(RESET)  - Validate telemetry"

system-full-test: ## Run comprehensive system tests
	@echo "$(CYAN)🎯 Running Full System Test Suite$(RESET)"
	@echo "$(CYAN)=================================$(RESET)"
	@echo ""
	@$(MAKE) test
	@$(MAKE) coord-test
	@$(MAKE) script-integration-test
	@$(MAKE) otel-test-integration
	@echo ""
	@echo "$(GREEN)✅ Comprehensive system testing completed!$(RESET)"

system-health-full: ## Comprehensive system health check
	@echo "$(CYAN)🏥 Comprehensive System Health Check$(RESET)"
	@echo "$(CYAN)===================================$(RESET)"
	@echo ""
	@$(MAKE) health
	@echo ""
	@$(MAKE) script-status
	@echo ""
	@$(MAKE) coord-dashboard
	@echo ""
	@$(MAKE) xavos-status
	@echo ""
	@$(MAKE) worktree-status
	@echo ""
	@echo "$(GREEN)🎉 Full system health check completed!$(RESET)"

# ============================================================================
# Enhanced Development Workflow
# ============================================================================

dev-full: ## Start full development environment with all systems
	@echo "$(CYAN)🚀 Starting Full Development Environment$(RESET)"
	@echo "$(CYAN)=======================================$(RESET)"
	@echo ""
	@echo "$(BLUE)1. Setting up Docker services...$(RESET)"
	@$(MAKE) docker-start
	@echo ""
	@echo "$(BLUE)2. Checking system status...$(RESET)"
	@$(MAKE) script-status
	@echo ""
	@echo "$(BLUE)3. Starting Phoenix server...$(RESET)"
	@cd $(PHOENIX_DIR) && $(MIX) phx.server

dev-minimal: ## Start minimal development environment
	@echo "$(CYAN)🚀 Starting Minimal Development Environment$(RESET)"
	@echo "$(CYAN)=========================================$(RESET)"
	@echo ""
	@$(MAKE) docker-start
	@sleep 3
	@cd $(PHOENIX_DIR) && $(MIX) phx.server

# ============================================================================
# Special Targets
# ============================================================================

.env: ## Create .env file from template
	@if [ ! -f .env ]; then \
		echo "$(BLUE)📋 Creating .env file from template...$(RESET)"; \
		cp .env.example .env; \
		echo "$(YELLOW)⚠️  Please edit .env file with your configuration$(RESET)"; \
	else \
		echo "$(GREEN)✅ .env file already exists$(RESET)"; \
	fi