# Network Connectivity Center hub: the GCP equivalent of an AWS Transit Gateway. Each spoke root
# (envs/dev|qa|prod) attaches its VPC through its own terraform_remote_state of this root.
#
# STAR topology (spec: "sin conectividad directa entre entornos"):
# - center group: the hub VPC and the HA VPN tunnels to on-prem.
# - edge group: the dev, qa and prod VPCs (ncc_spoke_group in the spoke roots).
# Edge spokes only exchange routes with the center, never with each other. Like a TGW route table for
# the environments that only propagates the VPN and the central VPC attachments.
# The topology can only be chosen when the hub is created.

locals {
  ncc_center_group = "${google_network_connectivity_hub.main.id}/groups/center"
}

resource "google_network_connectivity_hub" "main" {
  project         = local.net_hub_project
  name            = "${var.project_prefix}-c-ncc-hub"
  description     = "Landing-zone hub (STAR). Spokes attach from their env roots."
  preset_topology = "STAR"
  labels          = merge(local.base_labels, { app = "ncc-hub" })
}

# The edge group exists as soon as the STAR hub does; this resource manages it to auto-accept spokes from the
# three net-host projects. Each environment root (#19) creates its spoke in its own net-host project, as NCC
# documents for a VPC in another project than the hub: the spoke is a proposal the hub must accept. Like an AWS
# Transit Gateway shared with RAM that auto-accepts attachments from the accounts it trusts, and only those.
resource "google_network_connectivity_group" "edge" {
  project     = local.net_hub_project
  hub         = google_network_connectivity_hub.main.id
  name        = "edge"
  description = "Environment spokes (dev, qa, prod): they only reach the center group."

  auto_accept {
    auto_accept_projects = sort(values(local.org.net_host_project_ids))
  }

  labels = merge(local.base_labels, { app = "ncc-hub" })
}

# The hub VPC as a VPC spoke of the center group, so the environments reach its subnets (and the DNS
# peering target) through NCC.
resource "google_network_connectivity_spoke" "hub_self" {
  project  = local.net_hub_project
  name     = "${var.project_prefix}-c-ncc-spoke-hub"
  location = "global"
  hub      = google_network_connectivity_hub.main.id
  group    = local.ncc_center_group

  linked_vpc_network {
    uri                   = google_compute_network.hub.self_link
    exclude_export_ranges = []
  }

  labels = merge(local.base_labels, { app = "ncc-hub" })
}

# The two HA VPN tunnels of the hub as a hybrid spoke. Without it, the on-prem routes the hub's Cloud
# Router learns by BGP stay in the hub VPC: VPC spokes only import dynamic routes that a hybrid spoke
# exports to the hub. No site-to-site data transfer (that is for on-prem to on-prem through Google),
# so it can sit in the center group. The tunnels and their router are in the hub's project, as NCC
# requires.
resource "google_network_connectivity_spoke" "onprem_vpn" {
  project  = local.net_hub_project
  name     = "${var.project_prefix}-c-ncc-spoke-onprem-vpn"
  location = var.primary_region
  hub      = google_network_connectivity_hub.main.id
  group    = local.ncc_center_group

  linked_vpn_tunnels {
    uris                       = [for t in google_compute_vpn_tunnel.hub : t.self_link]
    site_to_site_data_transfer = false
    include_import_ranges      = ["ALL_IPV4_RANGES"]
  }

  labels = merge(local.base_labels, { app = "ncc-hub" })
}
