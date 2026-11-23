# Stage 2 outputs consumed by stages 3-5 through terraform_remote_state (prefix "2-security").

output "security_project_id" {
  description = "Project that holds the keys and secrets."
  value       = local.security_project_id
}

output "kms_keyring_ids" {
  description = "Key ring ID by region role (primary, dr)."
  value       = { for k, m in module.kms : k => m.keyring_id }
}

output "kms_key_ids" {
  description = "CMEK key IDs by region role and key name, for example kms_key_ids.primary.storage."
  value       = { for k, m in module.kms : k => m.key_ids }
}

output "secret_ids" {
  description = "Secret ID (projects/<project>/secrets/<name>) by short name. Read the value with the google_secret_manager_secret_version data source."
  value       = { for k, s in google_secret_manager_secret.this : k => s.id }
}

output "access_policy_id" {
  description = "Number of the organization access policy."
  value       = local.access_policy_id
}

output "vpc_sc_perimeter_name" {
  description = "Full name of the prod perimeter. Stage 4 adds prod service projects to it."
  value       = google_access_context_manager_service_perimeter.prod.name
}

output "vpc_sc_enforced" {
  description = "false while the perimeter is dry-run only."
  value       = var.vpc_sc_enforce
}
