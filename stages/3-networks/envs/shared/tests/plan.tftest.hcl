# Stage 3 (envs/shared) plan test. Mocks google/google-beta, stubs the two remote states.

mock_provider "google" {}
mock_provider "google-beta" {}

override_data {
  target = data.terraform_remote_state.org
  values = {
    outputs = {
      common_project_ids = {
        "net-hub"    = "bnt-c-net-hub"
        "logging"    = "bnt-c-logging"
        "security"   = "bnt-c-security"
        "backup"     = "bnt-c-backup"
        "onprem-sim" = "bnt-c-onprem-sim"
      }
      net_host_project_ids = { dev = "bnt-dev-net-host", qa = "bnt-qa-net-host", prod = "bnt-prod-net-host" }
      folder_ids           = { common = "folders/111", dev = "folders/222", qa = "folders/333", prod = "folders/444" }
    }
  }
}

override_data {
  target = data.terraform_remote_state.security
  values = {
    outputs = {
      secret_ids = {
        "vpn-psk-onprem" = "projects/bnt-c-security/secrets/bnt-c-sec-vpn-psk-onprem"
      }
    }
  }
}

override_data {
  target = data.google_secret_manager_secret_version.vpn_psk
  values = {
    secret_data = "mock-psk-value-at-least-32-characters-long"
  }
}

variables {
  org_id                 = "123456789012"
  billing_account        = "ABCDEF-123456-7890AB"
  environment            = "shared"
  project_prefix         = "bnt"
  state_bucket           = "mock-state-bucket"
  pipeline_sa_project_id = "bnt-b-seed-xxxx"
  labels = {
    owner       = "equipo6"
    cost_center = "ti-001"
  }
}

run "hub_and_onprem" {
  command = plan

  assert {
    condition     = google_compute_network.hub.auto_create_subnetworks == false
    error_message = "Hub VPC must be custom-mode."
  }

  assert {
    condition     = google_compute_subnetwork.hub_primary.log_config[0].flow_sampling == 0.5
    error_message = "Hub subnet must sample flow logs at 50%."
  }

  assert {
    condition     = google_compute_instance.onprem_host.machine_type == "e2-micro"
    error_message = "On-prem VM must be e2-micro (sandbox free tier)."
  }

  assert {
    condition     = length(google_compute_instance.onprem_host.network_interface[0].access_config) == 0
    error_message = "On-prem VM must not have an external IP."
  }
}

run "ha_vpn_topology" {
  command = plan

  assert {
    condition     = length(google_compute_vpn_tunnel.hub) == 2 && length(google_compute_vpn_tunnel.onprem) == 2
    error_message = "HA VPN needs two tunnels on each side."
  }

  assert {
    condition     = google_compute_router.hub.bgp[0].asn == 64512 && google_compute_router.onprem.bgp[0].asn == 64513
    error_message = "BGP ASNs must match the cidr_plan defaults."
  }

  assert {
    condition     = length(google_compute_router_peer.hub) == 2 && length(google_compute_router_peer.onprem) == 2
    error_message = "Two BGP peers on each side."
  }
}

run "ncc_and_dns" {
  command = plan

  assert {
    condition     = google_network_connectivity_hub.main.name == "bnt-c-ncc-hub"
    error_message = "NCC hub name must follow the prefix convention."
  }

  assert {
    condition     = google_dns_managed_zone.hub_internal.dns_name == "gcp.banorterra.internal."
    error_message = "Hub DNS zone must be gcp.banorterra.internal."
  }

  assert {
    condition     = alltrue([for s in google_dns_managed_zone.hub_forward_onprem.forwarding_config[0].target_name_servers : s.forwarding_path == "private"])
    error_message = "Hub -> onprem DNS forwarding must use the private path (via the VPN)."
  }
}
