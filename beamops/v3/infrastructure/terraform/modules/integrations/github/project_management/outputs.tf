# GitHub Project Management Module Outputs

output "repository_url" {
  description = "GitHub repository URL"
  value       = github_repository.beamops_v3.html_url
}

output "repository_ssh_url" {
  description = "GitHub repository SSH URL"
  value       = github_repository.beamops_v3.ssh_clone_url
}

output "repository_git_url" {
  description = "GitHub repository Git URL"
  value       = github_repository.beamops_v3.git_clone_url
}

output "repository_full_name" {
  description = "GitHub repository full name"
  value       = github_repository.beamops_v3.full_name
}

output "repository_node_id" {
  description = "GitHub repository node ID"
  value       = github_repository.beamops_v3.node_id
}

output "milestones" {
  description = "Created milestones"
  value = {
    for k, v in github_repository_milestone.v3_milestones : k => {
      title  = v.title
      number = v.number
      url    = v.url
    }
  }
}

output "labels_created" {
  description = "Issue labels created"
  value = {
    for k, v in github_issue_label.beamops_labels : k => {
      name  = v.name
      color = v.color
      url   = v.url
    }
  }
}

output "environment_name" {
  description = "GitHub environment name"
  value       = github_repository_environment.beamops_environment.environment
}

output "webhook_url" {
  description = "Webhook URL if enabled"
  value       = var.enable_webhooks ? github_repository_webhook.beamops_webhook[0].url : null
}

output "ready" {
  description = "Whether the GitHub project management is ready"
  value       = true
}