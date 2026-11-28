# Stage 1 outputs consumed by stages 2, 3 and 4 through terraform_remote_state (prefix "1-org").

output "folder_ids" {
  description = "Folder ID per name (common, dev, qa, prod)."
  value       = { for k, f in google_folder.env : k => f.id }
}

output "common_project_ids" {
  description = "Project ID per common-folder project (net-hub, security; logging until it is retired, ADR 0008)."
  value       = { for k, p in module.common_projects : k => p.project_id }
}

output "common_project_numbers" {
  description = "Project number per common-folder project. Useful for IAM principals that only accept numbers."
  value       = { for k, p in module.common_projects : k => p.project_number }
}

output "net_host_project_ids" {
  description = "Network host project ID per environment (dev, qa, prod). Stage 3 enables Shared VPC on these."
  value       = { for k, p in module.net_host_projects : k => p.project_id }
}

output "net_host_project_numbers" {
  description = "Network host project number per environment. Stage 2 puts the prod one in the VPC-SC perimeter (perimeters take project numbers)."
  value       = { for k, p in module.net_host_projects : k => p.project_number }
}

output "audit_log_bucket" {
  description = "GCS bucket that receives the organization-level audit log sink."
  value       = google_storage_bucket.audit.name
}

output "audit_log_sink_writer" {
  description = "Writer identity of the organization audit sink. Grant it extra access in stages that create their own destinations."
  value       = google_logging_organization_sink.audit.writer_identity
}

output "scc_findings_topic" {
  description = "Pub/Sub topic (ID form) that receives every SCC finding for the org."
  value       = google_pubsub_topic.scc_findings.id
}

output "org_policy_names" {
  description = "Names of the organization policies managed by this stage. Useful for drift inspection."
  value = concat(
    [for p in google_org_policy_policy.boolean_enforce : p.name],
    [
      google_org_policy_policy.resource_locations.name,
      google_org_policy_policy.vm_external_ip.name,
      google_org_policy_policy.allowed_policy_member_domains.name,
    ],
  )
}
