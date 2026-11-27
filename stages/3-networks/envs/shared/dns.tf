# Private DNS: two authoritative zones + hub -> onprem forwarding.
#
# - Hub VPC owns var.hub_dns_zone ("gcp.banorterra.internal."), which the spokes join by DNS peering
#   from their own roots.
# - Onprem VPC owns var.onprem_dns_zone ("banorterra.local."), served by dnsmasq on the onprem VM.
# - Hub creates a forwarding zone for the onprem domain pointing at the onprem VM's static IP so
#   anything in the hub (and the spokes, via DNS peering) can resolve host.banorterra.local across
#   the HA VPN.

resource "google_dns_managed_zone" "hub_internal" {
  project     = local.net_hub_project
  name        = replace("${var.project_prefix}-c-hub-${trimsuffix(var.hub_dns_zone, ".")}", ".", "-")
  dns_name    = var.hub_dns_zone
  description = "GCP-internal authoritative zone. Spokes peer to this zone."
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.hub.id
    }
  }

  labels = merge(local.base_labels, { app = "dns-hub" })
}

resource "google_dns_managed_zone" "onprem_authoritative" {
  project     = local.onprem_sim_project
  name        = replace("${var.project_prefix}-c-onprem-${trimsuffix(var.onprem_dns_zone, ".")}", ".", "-")
  dns_name    = var.onprem_dns_zone
  description = "On-prem authoritative zone (shadowed by dnsmasq on the VM; this is only for records visible inside the on-prem VPC itself)."
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.onprem.id
    }
  }

  labels = merge(local.base_labels, { app = "dns-onprem" })
}

resource "google_dns_record_set" "onprem_host" {
  project      = local.onprem_sim_project
  managed_zone = google_dns_managed_zone.onprem_authoritative.name
  name         = "host.${var.onprem_dns_zone}"
  type         = "A"
  ttl          = 60
  rrdatas      = [google_compute_address.onprem_host.address]
}

# Hub forwards banorterra.local to the on-prem dnsmasq. Routes to the onprem subnet come via BGP
# over the HA VPN, so this resolves once both tunnels are up.
resource "google_dns_managed_zone" "hub_forward_onprem" {
  project     = local.net_hub_project
  name        = "${var.project_prefix}-c-hub-fwd-onprem"
  dns_name    = var.onprem_dns_zone
  description = "Forwarding zone: hub VPC -> on-prem dnsmasq."
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.hub.id
    }
  }

  forwarding_config {
    target_name_servers {
      ipv4_address    = google_compute_address.onprem_host.address
      forwarding_path = "private"
    }
  }

  labels = merge(local.base_labels, { app = "dns-forward" })
}
