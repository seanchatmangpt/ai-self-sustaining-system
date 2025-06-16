# GitHub Project Management Module
# Following Engineering Elixir Applications Chapter 2 patterns

terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.41"
    }
  }
}

# BEAMOPS v3 Repository Management
resource "github_repository" "beamops_v3" {
  name                   = var.repository_name
  description            = "BEAMOPS v3: Enterprise AI Agent Coordination Infrastructure"
  visibility             = var.repository_visibility
  has_issues             = true
  has_projects           = true
  has_wiki              = true
  auto_init              = false  # Repository already exists
  delete_branch_on_merge = true
  
  # Repository features
  allow_merge_commit     = false
  allow_squash_merge     = true
  allow_rebase_merge     = false
  
  # Security settings
  vulnerability_alerts = true
  
  topics = [
    "elixir",
    "phoenix", 
    "beamops",
    "agent-coordination",
    "engineering-elixir-applications",
    "prometheus",
    "grafana",
    "distributed-systems"
  ]
}

# Branch Protection for Main
resource "github_branch_protection" "main" {
  repository_id = github_repository.beamops_v3.node_id
  pattern       = "main"
  
  required_status_checks {
    strict   = true
    contexts = [
      "continuous-integration/github-actions/build",
      "continuous-integration/github-actions/test",
      "continuous-integration/github-actions/lint"
    ]
  }
  
  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    required_approving_review_count = 1
    require_code_owner_reviews      = true
  }
  
  enforce_admins = false
  
  restrictions {
    users = []
    teams = []
    apps  = []
  }
}

# Issues and Project Management
resource "github_issue_label" "beamops_labels" {
  for_each = var.issue_labels
  
  repository = github_repository.beamops_v3.name
  name       = each.key
  color      = each.value.color
  description = each.value.description
}

# Milestones for BEAMOPS v3 Implementation
resource "github_repository_milestone" "v3_milestones" {
  for_each = var.v3_milestones
  
  owner       = var.github_owner
  repository  = github_repository.beamops_v3.name
  title       = each.value.title
  description = each.value.description
  due_date    = each.value.due_date
  state       = each.value.state
}

# Repository Secrets for CI/CD
resource "github_actions_secret" "ci_secrets" {
  for_each = var.ci_secrets
  
  repository      = github_repository.beamops_v3.name
  secret_name     = each.key
  plaintext_value = each.value
}

# Environment-specific Secrets
resource "github_actions_environment_secret" "env_secrets" {
  for_each = var.environment_secrets
  
  repository    = github_repository.beamops_v3.name
  environment   = var.environment
  secret_name   = each.key
  plaintext_value = each.value
}

# Repository Environment
resource "github_repository_environment" "beamops_environment" {
  repository  = github_repository.beamops_v3.name
  environment = var.environment
  
  # Environment protection rules
  deployment_branch_policy {
    protected_branches     = true
    custom_branch_policies = false
  }
  
  # Require reviewers for production deployments
  dynamic "reviewers" {
    for_each = var.environment == "prod" ? [1] : []
    content {
      users = var.deployment_reviewers
    }
  }
}

# Webhooks for Integration
resource "github_repository_webhook" "beamops_webhook" {
  count = var.enable_webhooks ? 1 : 0
  
  repository = github_repository.beamops_v3.name
  
  configuration {
    url          = var.webhook_url
    content_type = "json"
    insecure_ssl = false
    secret       = var.webhook_secret
  }
  
  active = true
  
  events = [
    "push",
    "pull_request",
    "issues",
    "deployment",
    "deployment_status"
  ]
}