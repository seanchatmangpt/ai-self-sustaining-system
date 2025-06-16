# BEAMOPS v3 Terraform Variables
# Following Engineering Elixir Applications patterns

variable "project_name" {
  description = "Name of the BEAMOPS v3 project"
  type        = string
  default     = "beamops-v3"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "repository_name" {
  description = "GitHub repository name"
  type        = string
  default     = "ai-self-sustaining-system"
}

variable "github_owner" {
  description = "GitHub organization or username"
  type        = string
  # Set via environment variable: TF_VAR_github_owner
}

variable "aws_region" {
  description = "AWS region for infrastructure"
  type        = string
  default     = "us-west-2"
}

# Agent Coordination Specific Variables
variable "max_agent_count" {
  description = "Maximum number of agents to support"
  type        = number
  default     = 100
  
  validation {
    condition     = var.max_agent_count >= 1 && var.max_agent_count <= 1000
    error_message = "Max agent count must be between 1 and 1000."
  }
}

variable "enable_auto_scaling" {
  description = "Enable auto scaling for agent coordination"
  type        = bool
  default     = true
}

variable "coordination_instance_type" {
  description = "Instance type for coordination nodes"
  type        = string
  default     = "t3.medium"
}

variable "monitoring_instance_type" {
  description = "Instance type for monitoring infrastructure"
  type        = string
  default     = "t3.small"
}

# Networking Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

# Security Configuration
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access infrastructure"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production
}

variable "enable_encryption" {
  description = "Enable encryption for all resources"
  type        = bool
  default     = true
}

# Resource Limits and Performance
variable "coordination_memory_limit" {
  description = "Memory limit for coordination containers (MB)"
  type        = number
  default     = 2048
}

variable "coordination_cpu_limit" {
  description = "CPU limit for coordination containers (millicores)"
  type        = number
  default     = 1000
}

variable "prometheus_retention_days" {
  description = "Prometheus metrics retention period"
  type        = number
  default     = 30
}

variable "log_retention_days" {
  description = "Log retention period"
  type        = number
  default     = 14
}

# Feature Flags
variable "enable_distributed_erlang" {
  description = "Enable distributed Erlang clustering"
  type        = bool
  default     = true
}

variable "enable_live_dashboard" {
  description = "Enable Phoenix LiveDashboard"
  type        = bool
  default     = true
}

variable "enable_telemetry_ui" {
  description = "Enable telemetry UI components"
  type        = bool
  default     = true
}

# Tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "BEAMOPS-v3"
    Source      = "Terraform"
    Repository  = "ai-self-sustaining-system"
    Pattern     = "EngineeringElixirApplications"
  }
}