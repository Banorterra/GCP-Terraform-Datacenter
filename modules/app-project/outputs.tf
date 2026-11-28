output "project_id" {
  description = "ID of the project (with its random suffix)."
  value       = google_project.this.project_id
}

output "project_number" {
  description = "Number of the project."
  value       = google_project.this.number
}

output "service_agents" {
  description = "Google service agents of the project (members, serviceAccount:...), by name. sql is null when Cloud SQL is off."
  value       = local.agents
}
