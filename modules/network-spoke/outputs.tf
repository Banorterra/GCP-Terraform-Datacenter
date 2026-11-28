output "network_id" {
  description = "ID of the spoke VPC."
  value       = google_compute_network.this.id
}

output "network_self_link" {
  description = "Self link of the spoke VPC."
  value       = google_compute_network.this.self_link
}

output "network_name" {
  description = "Name of the spoke VPC."
  value       = google_compute_network.this.name
}

output "subnet_self_link" {
  description = "Self link of the environment subnet (stage 4 grants compute.networkUser on it)."
  value       = google_compute_subnetwork.primary.self_link
}

output "subnet_cidr" {
  description = "Primary range of the environment subnet."
  value       = google_compute_subnetwork.primary.ip_cidr_range
}

output "secondary_range_names" {
  description = "Names of the subnet's secondary ranges (GKE ip_allocation_policy in stage 5)."
  value       = keys(var.secondary_ranges)
}

output "host_project_id" {
  description = "Shared VPC host project of the environment."
  value       = google_compute_shared_vpc_host_project.this.project
}

output "ncc_spoke_id" {
  description = "ID of the NCC spoke."
  value       = google_network_connectivity_spoke.this.id
}

output "dns_zone_name" {
  description = "Name of the environment's private DNS zone."
  value       = google_dns_managed_zone.env.name
}

output "gate_vm_name" {
  description = "Name of the Sprint 4 gate VM (null when enable_gate_vm is false)."
  value       = one(google_compute_instance.gate[*].name)
}

output "psa_range_name" {
  description = "Name of the private services access range (null without psa_cidr). Stage 5 passes it as allocated_ip_range to Cloud SQL."
  value       = var.psa_cidr == null ? null : google_compute_global_address.psa[0].name
}
