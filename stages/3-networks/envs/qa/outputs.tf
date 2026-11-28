# Read by stage 4 (attach app projects to the Shared VPC, grant networkUser on the subnet) and stage 5.

output "host_project_id" {
  description = "Shared VPC host project of this environment."
  value       = module.spoke.host_project_id
}

output "network_self_link" {
  description = "Self link of the VPC of this environment."
  value       = module.spoke.network_self_link
}

output "network_name" {
  description = "Name of the VPC of this environment."
  value       = module.spoke.network_name
}

output "subnet_self_link" {
  description = "Self link of the subnet of this environment."
  value       = module.spoke.subnet_self_link
}

output "subnet_cidr" {
  description = "Primary range of the subnet of this environment."
  value       = module.spoke.subnet_cidr
}

output "secondary_range_names" {
  description = "Names of the subnet's secondary ranges (pods, services)."
  value       = module.spoke.secondary_range_names
}

output "dns_zone_name" {
  description = "Name of the private DNS zone of this environment."
  value       = module.spoke.dns_zone_name
}

output "gate_vm_name" {
  description = "Name of the Sprint 4 gate VM (null when enable_gate_vm is false)."
  value       = module.spoke.gate_vm_name
}

output "psa_range_name" {
  description = "Private services access range of this environment (stage 5: allocated_ip_range of Cloud SQL)."
  value       = module.spoke.psa_range_name
}
