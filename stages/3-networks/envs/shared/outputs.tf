# Stage 3 (envs/shared) outputs. Each spoke root (envs/dev|qa|prod) reads these via
# terraform_remote_state (prefix "3-networks/shared").

output "hub_vpc_id" {
  description = "Hub VPC self-link. Spokes peer/NCC-attach to it."
  value       = google_compute_network.hub.id
}

output "hub_vpc_name" {
  description = "Hub VPC name."
  value       = google_compute_network.hub.name
}

output "hub_project_id" {
  description = "Project that hosts the hub VPC (net-hub)."
  value       = local.net_hub_project
}

output "hub_subnet_self_link" {
  description = "Primary-region hub subnet self-link."
  value       = google_compute_subnetwork.hub_primary.self_link
}

output "onprem_project_id" {
  description = "Project that hosts the simulated on-prem VPC."
  value       = local.onprem_sim_project
}

output "onprem_vpc_id" {
  description = "Simulated on-prem VPC self-link."
  value       = google_compute_network.onprem.id
}

output "onprem_host_internal_ip" {
  description = "Internal IP of the on-prem simulation VM. Spokes should ping/HTTP this to prove the HA VPN works."
  value       = google_compute_instance.onprem_host.network_interface[0].network_ip
}

output "cidr_plan" {
  description = "IP plan (same shape as var.cidr_plan). Re-exposed so spokes do not re-declare CIDRs."
  value       = var.cidr_plan
}

output "ncc_hub_id" {
  description = "Network Connectivity Center hub ID. Spokes attach to this."
  value       = google_network_connectivity_hub.main.id
}

output "hub_vpn_tunnel_names" {
  description = "Names of the two HA VPN tunnels on the hub side. Useful for Monitoring dashboards."
  value       = [for t in google_compute_vpn_tunnel.hub : t.name]
}

output "onprem_vpn_tunnel_names" {
  description = "Names of the two HA VPN tunnels on the on-prem side."
  value       = [for t in google_compute_vpn_tunnel.onprem : t.name]
}

output "hub_dns_zone_name" {
  description = "Hub DNS managed-zone short name. Spokes DNS-peer to this."
  value       = google_dns_managed_zone.hub_internal.name
}

output "hub_dns_zone" {
  description = "Hub DNS domain (with trailing dot)."
  value       = var.hub_dns_zone
}

output "onprem_dns_zone" {
  description = "On-prem DNS domain (with trailing dot). Forwarded from the hub."
  value       = var.onprem_dns_zone
}

output "ncc_edge_group" {
  description = "NCC group the environment spokes (dev, qa, prod) join: in STAR they only see the center (hub VPC and VPN)."
  value       = google_network_connectivity_group.edge.id
}
