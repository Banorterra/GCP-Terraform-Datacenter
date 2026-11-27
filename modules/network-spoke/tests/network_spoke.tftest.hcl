# Unit tests for modules/network-spoke with a mock provider: `terraform test` from modules/network-spoke.

mock_provider "google" {}

variables {
  project_id     = "bnt-dev-net-host"
  env            = "dev"
  prefix         = "bnt"
  region         = "northamerica-south1"
  subnet_cidr    = "10.10.0.0/24"
  hub_project_id = "bnt-c-net-hub"
  ncc_hub_id     = "projects/bnt-c-net-hub/locations/global/hubs/bnt-c-ncc-hub"
  hub_network_id = "projects/bnt-c-net-hub/global/networks/bnt-c-hub-vpc"
  dns_zone       = "dev.gcp.banorterra.internal."
  secondary_ranges = {
    pods     = "10.10.64.0/18"
    services = "10.10.128.0/20"
  }
  peered_dns_zones = ["gcp.banorterra.internal.", "banorterra.local."]
  onprem_cidrs     = ["10.200.0.0/16"]
}

run "subnet_follows_the_spec" {
  command = plan

  assert {
    condition     = google_compute_subnetwork.primary.private_ip_google_access == true
    error_message = "The subnet must have Private Google Access."
  }

  assert {
    condition     = google_compute_subnetwork.primary.log_config[0].flow_sampling == 0.5
    error_message = "Flow logs must sample 50% by default (spec)."
  }

  assert {
    condition     = length(google_compute_subnetwork.primary.secondary_ip_range) == 2
    error_message = "Both secondary ranges must be created."
  }
}

run "dns_peers_every_hub_zone" {
  command = plan

  assert {
    condition     = length(google_dns_managed_zone.peering) == 2
    error_message = "There must be one peering zone per hub domain."
  }

  assert {
    condition     = google_dns_managed_zone.peering["banorterra.local."].peering_config[0].target_network[0].network_url == var.hub_network_id
    error_message = "Peering zones must target the hub VPC."
  }
}

run "firewall_allows_onprem_only_when_given" {
  command = plan

  variables {
    onprem_cidrs = []
  }

  assert {
    condition     = length(google_compute_firewall.allow_from_onprem) == 0
    error_message = "Without on-prem ranges there must be no on-prem allow rule."
  }
}

run "rejects_unknown_env" {
  command = plan

  variables {
    env = "staging"
  }

  expect_failures = [var.env]
}
