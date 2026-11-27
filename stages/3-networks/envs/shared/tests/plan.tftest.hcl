# Stage 3 (envs/shared) plan test. Mocks google/google-beta, stubs the two remote states.

mock_provider "google" {}
mock_provider "google-beta" {}

override_data {
  target = data.terraform_remote_state.org
  values = {
    outputs = {
      common_project_ids = {
        "net-hub"  = "bnt-c-net-hub"
        "logging"  = "bnt-c-logging"
        "security" = "bnt-c-security"
        "backup"   = "bnt-c-backup"
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

  assert {
    condition     = google_compute_network.onprem.project == "bnt-c-net-hub" && google_compute_instance.onprem_host.project == "bnt-c-net-hub"
    error_message = "The simulated on-prem VPC and VM live in net-hub (no project of their own)."
  }

  assert {
    condition     = google_compute_router_nat.onprem.router == google_compute_router.onprem.name
    error_message = "On-prem needs Cloud NAT so the VM's startup script can install dnsmasq."
  }

  assert {
    condition     = contains(google_compute_firewall.onprem_allow_dns_from_gcp.source_ranges, "35.199.192.0/19")
    error_message = "On-prem DNS must accept the Cloud DNS forwarding range."
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

  assert {
    condition = alltrue([
      for r in ["10.10.0.0/16", "10.20.0.0/16", "10.30.0.0/16", "35.199.192.0/19"] :
      contains([for a in google_compute_router.hub.bgp[0].advertised_ip_ranges : a.range], r)
    ])
    error_message = "The hub router must advertise the spoke blocks and the Cloud DNS forwarding range to on-prem."
  }
}

run "ncc_and_dns" {
  command = plan

  assert {
    condition     = google_network_connectivity_hub.main.name == "bnt-c-ncc-hub"
    error_message = "NCC hub name must follow the prefix convention."
  }

  assert {
    condition     = google_network_connectivity_hub.main.preset_topology == "STAR"
    error_message = "NCC hub must be STAR so dev, qa and prod don't see each other."
  }

  assert {
    condition     = length(google_network_connectivity_spoke.onprem_vpn.linked_vpn_tunnels[0].uris) == 2 && google_network_connectivity_spoke.onprem_vpn.linked_vpn_tunnels[0].site_to_site_data_transfer == false
    error_message = "Both hub VPN tunnels must be a hybrid spoke, without site-to-site data transfer."
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
