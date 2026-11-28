# Read by stage 5 (5-workloads/<env>) through terraform_remote_state.

output "app_project_ids" {
  description = "Project ID of each application of this environment."
  value       = { for k, m in module.app_project : k => m.project_id }
}

output "app_project_numbers" {
  description = "Project number of each application of this environment."
  value       = { for k, m in module.app_project : k => m.project_number }
}

output "app_service_agents" {
  description = "Google service agents of each application project (for example the GKE agent)."
  value       = { for k, m in module.app_project : k => m.service_agents }
}

output "host_project_id" {
  description = "Shared VPC host project the application projects are attached to (passed through from stage 3)."
  value       = local.network.host_project_id
}
