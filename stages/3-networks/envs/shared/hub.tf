# Hub VPC in the net-hub project. Custom-mode (no auto subnets); one subnet in the primary region
# for management workloads (e.g. a bastion). Shared VPC designation is set here so stage 4 service
# projects can attach as service projects of the hub if needed.

resource "google_compute_network" "hub" {
  project                 = local.net_hub_project
  name                    = "${var.project_prefix}-c-hub-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  description             = "Hub VPC: HA VPN to on-prem, DNS hub, NCC hub. Managed by stage 3 envs/shared."

  delete_default_routes_on_create = false
}

resource "google_compute_subnetwork" "hub_primary" {
  project                  = local.net_hub_project
  name                     = "${var.project_prefix}-c-hub-subnet-${var.primary_region}"
  network                  = google_compute_network.hub.id
  ip_cidr_range            = var.cidr_plan.hub.subnet_cidr
  region                   = var.primary_region
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = var.flow_logs_sampling
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Mark net-hub as a Shared VPC host project. Stage 4 attaches service projects.
resource "google_compute_shared_vpc_host_project" "hub" {
  project = local.net_hub_project
}
