# GitHub Project Management Module Variables

variable "repository_name" {
  description = "Name of the GitHub repository"
  type        = string
}

variable "github_owner" {
  description = "GitHub organization or username"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "repository_visibility" {
  description = "Repository visibility (public, private, internal)"
  type        = string
  default     = "private"
}

# BEAMOPS v3 Issue Labels
variable "issue_labels" {
  description = "Issue labels for BEAMOPS v3 project management"
  type = map(object({
    color       = string
    description = string
  }))
  default = {
    "beamops:chapter-02" = {
      color       = "0E7BB8"
      description = "Chapter 2: Terraform Infrastructure"
    }
    "beamops:chapter-03" = {
      color       = "1F77B4"
      description = "Chapter 3: Docker Containerization"
    }
    "beamops:chapter-04" = {
      color       = "FF7F0E"
      description = "Chapter 4: CI/CD Pipelines"
    }
    "beamops:chapter-05" = {
      color       = "2CA02C"
      description = "Chapter 5: Development Environment"
    }
    "beamops:chapter-06" = {
      color       = "D62728"
      description = "Chapter 6: Production Environment"
    }
    "beamops:chapter-07" = {
      color       = "9467BD"
      description = "Chapter 7: Secrets Management"
    }
    "beamops:chapter-08" = {
      color       = "8C564B"
      description = "Chapter 8: Docker Swarm"
    }
    "beamops:chapter-09" = {
      color       = "E377C2"
      description = "Chapter 9: Distributed Erlang"
    }
    "beamops:chapter-10" = {
      color       = "7F7F7F"
      description = "Chapter 10: Auto Scaling"
    }
    "beamops:chapter-11" = {
      color       = "BCBD22"
      description = "Chapter 11: Instrumentation"
    }
    "beamops:chapter-12" = {
      color       = "17BECF"
      description = "Chapter 12: Custom PromEx"
    }
    "priority:critical" = {
      color       = "B60205"
      description = "Critical priority - blocks deployment"
    }
    "priority:high" = {
      color       = "D93F0B"
      description = "High priority"
    }
    "priority:medium" = {
      color       = "FBCA04"
      description = "Medium priority"
    }
    "priority:low" = {
      color       = "0E8A16"
      description = "Low priority"
    }
    "type:bug" = {
      color       = "D73A4A"
      description = "Something isn't working"
    }
    "type:enhancement" = {
      color       = "A2EEEF"
      description = "New feature or request"
    }
    "type:documentation" = {
      color       = "0075CA"
      description = "Improvements or additions to documentation"
    }
    "agent-coordination" = {
      color       = "7057FF"
      description = "Agent coordination system"
    }
    "claude-integration" = {
      color       = "FF6B35"
      description = "Claude AI integration"
    }
    "monitoring" = {
      color       = "006B75"
      description = "Monitoring and observability"
    }
    "infrastructure" = {
      color       = "5319E7"
      description = "Infrastructure and deployment"
    }
  }
}

# BEAMOPS v3 Milestones  
variable "v3_milestones" {
  description = "Milestones for BEAMOPS v3 implementation"
  type = map(object({
    title       = string
    description = string
    due_date    = string
    state       = string
  }))
  default = {
    "foundation" = {
      title       = "Phase 1: Foundation (Chapters 2-3)"
      description = "Infrastructure foundation with Terraform and Docker containerization"
      due_date    = "2025-07-01"
      state       = "open"
    }
    "automation" = {
      title       = "Phase 2: Automation (Chapters 4-5)"
      description = "CI/CD pipelines and development environment standardization"
      due_date    = "2025-07-15"
      state       = "open"
    }
    "production" = {
      title       = "Phase 3: Production (Chapters 6-8)"
      description = "Production environment, secrets management, and orchestration"
      due_date    = "2025-08-01"
      state       = "open"
    }
    "scaling" = {
      title       = "Phase 4: Scaling (Chapters 9-10)"
      description = "Distributed Erlang clustering and auto scaling for 100+ agents"
      due_date    = "2025-08-15"
      state       = "open"
    }
    "monitoring" = {
      title       = "Phase 5: Monitoring (Chapters 11-12)"
      description = "Comprehensive instrumentation and custom metrics"
      due_date    = "2025-08-30"
      state       = "open"
    }
  }
}

# CI/CD Secrets
variable "ci_secrets" {
  description = "CI/CD secrets for GitHub Actions"
  type        = map(string)
  default     = {}
  sensitive   = true
}

# Environment-specific Secrets
variable "environment_secrets" {
  description = "Environment-specific secrets"
  type        = map(string)
  default     = {}
  sensitive   = true
}

# Deployment Configuration
variable "deployment_reviewers" {
  description = "GitHub usernames required to review deployments"
  type        = list(string)
  default     = []
}

# Webhook Configuration
variable "enable_webhooks" {
  description = "Enable repository webhooks"
  type        = bool
  default     = false
}

variable "webhook_url" {
  description = "Webhook URL for repository events"
  type        = string
  default     = ""
}

variable "webhook_secret" {
  description = "Webhook secret for security"
  type        = string
  default     = ""
  sensitive   = true
}