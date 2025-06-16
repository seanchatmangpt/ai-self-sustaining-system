# BEAMOPS v3 Terraform Infrastructure
# Following Engineering Elixir Applications Chapter 2 patterns

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.41"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    # Configure your S3 backend for state management
    # bucket = "beamops-v3-terraform-state"
    # key    = "infrastructure/terraform.tfstate"
    # region = "us-west-2"
  }
}

# GitHub Repository Management
module "github_project_management" {
  source = "./modules/integrations/github/project_management"
  
  repository_name = var.repository_name
  github_owner    = var.github_owner
  environment     = var.environment
}

# AWS Infrastructure Base
module "aws_base_infrastructure" {
  source = "./modules/cloud/aws/base"
  
  project_name = var.project_name
  environment  = var.environment
  region       = var.aws_region
  
  # Agent coordination requirements
  enable_auto_scaling = var.enable_auto_scaling
  max_agent_count     = var.max_agent_count
  
  tags = {
    Project     = "BEAMOPS-v3"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "AgentCoordination"
  }
}

# Docker Registry Infrastructure
module "container_registry" {
  source = "./modules/cloud/aws/ecr"
  
  repository_names = [
    "beamops-v3-coordination",
    "beamops-v3-monitoring", 
    "beamops-v3-dashboard"
  ]
  
  environment = var.environment
  
  tags = {
    Project = "BEAMOPS-v3"
    Purpose = "ContainerRegistry"
  }
}

# Monitoring Infrastructure
module "monitoring_infrastructure" {
  source = "./modules/monitoring"
  
  project_name = var.project_name
  environment  = var.environment
  
  # Prometheus and Grafana setup
  enable_prometheus = true
  enable_grafana    = true
  enable_alerting   = true
  
  # Agent coordination specific monitoring
  agent_coordination_enabled = true
  max_agents_monitored       = var.max_agent_count
}

# Output important values
output "repository_url" {
  description = "GitHub repository URL"
  value       = module.github_project_management.repository_url
}

output "container_registry_urls" {
  description = "ECR repository URLs"
  value       = module.container_registry.repository_urls
}

output "monitoring_endpoints" {
  description = "Monitoring service endpoints"
  value = {
    prometheus = module.monitoring_infrastructure.prometheus_endpoint
    grafana    = module.monitoring_infrastructure.grafana_endpoint
  }
  sensitive = true
}

output "infrastructure_status" {
  description = "Infrastructure deployment status"
  value = {
    github_ready     = module.github_project_management.ready
    aws_ready        = module.aws_base_infrastructure.ready
    monitoring_ready = module.monitoring_infrastructure.ready
  }
}