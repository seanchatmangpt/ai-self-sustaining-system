# AI Self-Sustaining System Makefile
# Enhanced with Reactor Runner Integration and Enterprise Toolchain
#
# Usage:
#   make help                    # Show this help message
#   make setup                   # Complete project setup
#   make dev                     # Start development environment
#   make test                    # Run all tests
#   make quality                 # Run all quality checks
#   make reactor                 # Enhanced reactor operations
#   make deploy                  # Deploy to production

.PHONY: help setup dev test quality clean docker docs ci reactor validate
.DEFAULT_GOAL := help

# ============================================================================
# Configuration
# ============================================================================

APP_NAME := self_sustaining
APP_VERSION := $(shell grep 'version:' phoenix_app/mix.exs | cut -d'"' -f2)
PROJECT_ROOT := $(shell pwd)
PHOENIX_DIR := $(PROJECT_ROOT)/phoenix_app
DOCKER_COMPOSE := docker-compose
MIX := mix
ELIXIR := elixir

# Colors for output
RED := \033[31m
GREEN := \033[32m
YELLOW := \033[33m
BLUE := \033[34m
MAGENTA := \033[35m
CYAN := \033[36m
WHITE := \033[37m
RESET := \033[0m

# ============================================================================
# Help System
# ============================================================================

help: ## Show this help message
	@echo ""
	@echo "$(CYAN)🚀 AI Self-Sustaining System - Enhanced Makefile$(RESET)"
	@echo "$(CYAN)================================================$(RESET)"
	@echo ""
	@echo "$(GREEN)📋 Main Commands:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)🔧 Development Workflow:$(RESET)"
	@echo "  1. $(YELLOW)make setup$(RESET)     - Initial project setup"
	@echo "  2. $(YELLOW)make dev$(RESET)       - Start development environment"
	@echo "  3. $(YELLOW)make test$(RESET)      - Run tests during development"
	@echo "  4. $(YELLOW)make quality$(RESET)   - Check code quality before commit"
	@echo ""
	@echo "$(GREEN)🚀 Enhanced Reactor Runner:$(RESET)"
	@echo "  • $(YELLOW)make reactor-help$(RESET)     - Show reactor commands"
	@echo "  • $(YELLOW)make reactor-test$(RESET)     - Test reactor with enhanced features"
	@echo "  • $(YELLOW)make reactor-monitor$(RESET)  - Monitor reactor execution with telemetry"
	@echo ""
	@echo "$(GREEN)📊 System Status:$(RESET)"
	@echo "  • App Version: $(MAGENTA)$(APP_VERSION)$(RESET)"
	@echo "  • Project Root: $(MAGENTA)$(PROJECT_ROOT)$(RESET)"
	@echo "  • Phoenix Directory: $(MAGENTA)$(PHOENIX_DIR)$(RESET)"
	@echo ""

# ============================================================================
# Project Setup
# ============================================================================

setup: ## Complete project setup (dependencies, database, assets)
	@echo "$(CYAN)🔧 Setting up AI Self-Sustaining System...$(RESET)"
	@$(MAKE) check-dependencies
	@$(MAKE) setup-elixir
	@$(MAKE) setup-database
	@$(MAKE) setup-assets
	@$(MAKE) setup-docker-env
	@echo "$(GREEN)✅ Setup completed successfully!$(RESET)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(RESET)"
	@echo "  1. Run $(BLUE)make dev$(RESET) to start development environment"
	@echo "  2. Visit $(BLUE)http://localhost:4000$(RESET) to see the application"
	@echo "  3. Run $(BLUE)make reactor-help$(RESET) to explore enhanced reactor features"

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