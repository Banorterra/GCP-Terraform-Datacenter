# Unit tests for modules/network-spoke with a mock provider: `terraform test` from modules/network-spoke.

mock_provider "google" {}

variables {
  project_id      = "bnt-dev-net-host"
  env             = "dev"
  prefix          = "bnt"
  region          = "northamerica-south1"
  subnet_cidr     = "10.10.0.0/24"
  ncc_hub_id      = "projects/bnt-c-net-hub/locations/global/hubs/bnt-c-ncc-hub"
  hub_network_id  = "projects/bnt-c-net-hub/global/networks/bnt-c-hub-vpc"
  dns_zone        = "dev.gcp.banorterra.internal."
  ncc_spoke_group = "projects/bnt-c-net-hub/locations/global/hubs/bnt-c-ncc-hub/groups/edge"
  secondary_ranges = {
    pods     = "10.10.64.0/18"
    services = "10.10.128.0/20"
  }
  peered_dns_zones = ["gcp.banorterra.internal.", "banorterra.local."]
  onprem_cidrs     = ["172.16.0.0/16"]
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

run "gate_vm_is_off_by_default" {
  command = plan

  assert {
    condition     = length(google_compute_instance.gate) == 0
    error_message = "The gate VM must not exist unless enable_gate_vm is true."
  }
}

run "gate_vm_is_private_and_shielded" {
  command = plan

  variables {
    enable_gate_vm   = true
    gate_target_host = "host.banorterra.local"
  }

  assert {
    condition     = length(google_compute_instance.gate[0].network_interface[0].access_config) == 0
    error_message = "The gate VM must not have an external IP."
  }

  assert {
    condition     = google_compute_instance.gate[0].shielded_instance_config[0].enable_secure_boot == true
    error_message = "The gate VM must be a Shielded VM."
  }
}

run "spoke_in_its_own_project" {
  command = plan

  assert {
    condition     = google_network_connectivity_spoke.this.project == "bnt-dev-net-host" && endswith(google_network_connectivity_spoke.this.group, "/groups/edge")
    error_message = "The NCC spoke is created in the VPC's own project and joins the hub's edge group."
  }
}

run "private_services_access_for_cloud_sql" {
  command = plan

  variables {
    psa_cidr = "10.10.160.0/20"
  }

  assert {
    condition     = google_compute_global_address.psa[0].address == "10.10.160.0" && google_compute_global_address.psa[0].prefix_length == 20
    error_message = "The private services access range must be the one in psa_cidr."
  }

  assert {
    condition     = google_compute_global_address.psa[0].purpose == "VPC_PEERING"
    error_message = "The range must be reserved for VPC peering (private services access)."
  }

  assert {
    condition     = length(google_service_networking_connection.psa) == 1
    error_message = "The service networking connection must be created."
  }
}

run "no_private_services_access_by_default" {
  command = plan

  assert {
    condition     = length(google_compute_global_address.psa) == 0 && length(google_service_networking_connection.psa) == 0
    error_message = "Without psa_cidr nothing is reserved."
  }
}

run "health_checks_pass_the_firewall" {
  command = plan

  assert {
    condition     = toset(google_compute_firewall.allow_health_checks.source_ranges) == toset(["35.191.0.0/16", "130.211.0.0/22"])
    error_message = "The Google health check ranges must be allowed."
  }

  assert {
    condition     = google_compute_firewall.allow_health_checks.priority < google_compute_firewall.deny_all.priority
    error_message = "The health check rule must win over deny_all."
  }
}
