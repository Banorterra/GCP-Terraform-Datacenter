# Read by stage 4 (attach app projects to the Shared VPC, grant networkUser on the subnet) and stage 5.

output "host_project_id" {
  description = "Shared VPC host project of dev."
  value       = module.spoke.host_project_id
}

output "network_self_link" {
  description = "Self link of the dev VPC."
  value       = module.spoke.network_self_link
}

output "network_name" {
  description = "Name of the dev VPC."
  value       = module.spoke.network_name
}

output "subnet_self_link" {
  description = "Self link of the dev subnet."
  value       = module.spoke.subnet_self_link
}

output "subnet_cidr" {
  description = "Primary range of the dev subnet."
  value       = module.spoke.subnet_cidr
}

output "secondary_range_names" {
  description = "Names of the subnet's secondary ranges (pods, services)."
  value       = module.spoke.secondary_range_names
}

output "dns_zone_name" {
  description = "Name of the dev private DNS zone."
  value       = module.spoke.dns_zone_name
}
