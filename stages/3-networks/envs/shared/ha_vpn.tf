# HA VPN between the hub VPC (GCP side) and the onprem-sim VPC. Two tunnels + BGP, as HA VPN requires.
# The pre-shared key comes from Secret Manager (stage 2, secret vpn-psk-onprem); it never appears in
# code, tfvars or plan output.
#
# BGP link-local addresses:
#   tunnel 0: hub 169.254.10.1/30 <-> onprem 169.254.10.2/30
#   tunnel 1: hub 169.254.10.5/30 <-> onprem 169.254.10.6/30
# ASNs: hub var.cidr_plan.hub.router_asn (default 64512), onprem var.cidr_plan.onprem.router_asn (64513).

data "google_secret_manager_secret_version" "vpn_psk" {
  secret = local.security.secret_ids["vpn-psk-onprem"]
}

locals {
  # Cloud DNS forwarding source range (Google-fixed).
  cloud_dns_forwarding_range = "35.199.192.0/19"

  hub_advertised_ranges = [
    { range = var.cidr_plan.dev.block, description = "dev spoke (NCC)" },
    { range = var.cidr_plan.qa.block, description = "qa spoke (NCC)" },
    { range = var.cidr_plan.prod.block, description = "prod spoke (NCC)" },
    { range = local.cloud_dns_forwarding_range, description = "Cloud DNS forwarding" },
  ]

  bgp_tunnels = {
    "0" = { hub_ip = "169.254.10.1/30", hub_peer = "169.254.10.2", onprem_ip = "169.254.10.2/30", onprem_peer = "169.254.10.1" }
    "1" = { hub_ip = "169.254.10.5/30", hub_peer = "169.254.10.6", onprem_ip = "169.254.10.6/30", onprem_peer = "169.254.10.5" }
  }
}

# ---- Hub side ----

resource "google_compute_ha_vpn_gateway" "hub" {
  project = local.net_hub_project
  name    = "${var.project_prefix}-c-hub-vpn-gw"
  network = google_compute_network.hub.id
  region  = var.primary_region
}

resource "google_compute_router" "hub" {
  project = local.net_hub_project
  name    = "${var.project_prefix}-c-hub-router"
  network = google_compute_network.hub.id
  region  = var.primary_region

  # ALL_SUBNETS only covers the hub VPC's own subnets. On-prem also needs:
  # - the spoke blocks (dev/qa/prod): NCC does not advertise VPC spoke subnets to on-prem by itself, and
  #   without them the replies to a spoke VM have no route back;
  # - 35.199.192.0/19: Cloud DNS sends the forwarded banorterra.local queries from this range, so the
  #   dnsmasq answers must route back over the VPN.
  bgp {
    asn               = var.cidr_plan.hub.router_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]

    dynamic "advertised_ip_ranges" {
      for_each = local.hub_advertised_ranges
      content {
        range       = advertised_ip_ranges.value.range
        description = advertised_ip_ranges.value.description
      }
    }
  }
}

resource "google_compute_vpn_tunnel" "hub" {
  for_each = local.bgp_tunnels

  project               = local.net_hub_project
  name                  = "${var.project_prefix}-c-hub-to-onprem-${each.key}"
  region                = var.primary_region
  vpn_gateway           = google_compute_ha_vpn_gateway.hub.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.onprem.id
  router                = google_compute_router.hub.id
  shared_secret         = data.google_secret_manager_secret_version.vpn_psk.secret_data
  vpn_gateway_interface = tonumber(each.key)
  ike_version           = 2
}

resource "google_compute_router_interface" "hub" {
  for_each = local.bgp_tunnels

  project    = local.net_hub_project
  name       = "if-${each.key}"
  router     = google_compute_router.hub.name
  region     = var.primary_region
  ip_range   = each.value.hub_ip
  vpn_tunnel = google_compute_vpn_tunnel.hub[each.key].name
}

resource "google_compute_router_peer" "hub" {
  for_each = local.bgp_tunnels

  project         = local.net_hub_project
  name            = "peer-${each.key}"
  router          = google_compute_router.hub.name
  region          = var.primary_region
  peer_ip_address = each.value.hub_peer
  peer_asn        = var.cidr_plan.onprem.router_asn
  interface       = google_compute_router_interface.hub[each.key].name
}

# ---- Onprem side ----

resource "google_compute_ha_vpn_gateway" "onprem" {
  project = local.onprem_sim_project
  name    = "${var.project_prefix}-c-onprem-vpn-gw"
  network = google_compute_network.onprem.id
  region  = var.primary_region
}

resource "google_compute_router" "onprem" {
  project = local.onprem_sim_project
  name    = "${var.project_prefix}-c-onprem-router"
  network = google_compute_network.onprem.id
  region  = var.primary_region

  bgp {
    asn               = var.cidr_plan.onprem.router_asn
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
  }
}

# The on-prem VM has no external IP (org policy), so its startup script needs NAT to reach the Debian
# mirrors (apt-get install dnsmasq). Like a NAT Gateway for a private subnet in AWS.
resource "google_compute_router_nat" "onprem" {
  project                            = local.onprem_sim_project
  name                               = "${var.project_prefix}-c-onprem-nat"
  router                             = google_compute_router.onprem.name
  region                             = var.primary_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_vpn_tunnel" "onprem" {
  for_each = local.bgp_tunnels

  project               = local.onprem_sim_project
  name                  = "${var.project_prefix}-c-onprem-to-hub-${each.key}"
  region                = var.primary_region
  vpn_gateway           = google_compute_ha_vpn_gateway.onprem.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.hub.id
  router                = google_compute_router.onprem.id
  shared_secret         = data.google_secret_manager_secret_version.vpn_psk.secret_data
  vpn_gateway_interface = tonumber(each.key)
  ike_version           = 2
}

resource "google_compute_router_interface" "onprem" {
  for_each = local.bgp_tunnels

  project    = local.onprem_sim_project
  name       = "if-${each.key}"
  router     = google_compute_router.onprem.name
  region     = var.primary_region
  ip_range   = each.value.onprem_ip
  vpn_tunnel = google_compute_vpn_tunnel.onprem[each.key].name
}

resource "google_compute_router_peer" "onprem" {
  for_each = local.bgp_tunnels

  project         = local.onprem_sim_project
  name            = "peer-${each.key}"
  router          = google_compute_router.onprem.name
  region          = var.primary_region
  peer_ip_address = each.value.onprem_peer
  peer_asn        = var.cidr_plan.hub.router_asn
  interface       = google_compute_router_interface.onprem[each.key].name
}
