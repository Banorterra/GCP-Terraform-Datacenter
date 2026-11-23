# Simulated on-premise datacenter. Its VPC is NOT attached to the NCC hub; it only reaches GCP
# through the HA VPN (ha_vpn.tf). A single Linux VM with an internal IP answers pings and resolves
# the private zone from the hub side; that is the gate the spec requires to start Sprint 4.

resource "google_compute_network" "onprem" {
  project                 = local.onprem_sim_project
  name                    = "${var.project_prefix}-c-onprem-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "Simulated on-prem VPC. Reached from GCP only via HA VPN."
}

resource "google_compute_subnetwork" "onprem_primary" {
  project                  = local.onprem_sim_project
  name                     = "${var.project_prefix}-c-onprem-subnet-${var.primary_region}"
  network                  = google_compute_network.onprem.id
  ip_cidr_range            = var.cidr_plan.onprem.subnet_cidr
  region                   = var.primary_region
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = var.flow_logs_sampling
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Linux VM that acts as the on-prem host. Internal IP only (org policy forbids external IPs on VMs).
# Shielded VM on by default (org policy). Startup script turns on a tiny HTTP responder on :80 for
# connectivity tests from the spokes.
resource "google_compute_instance" "onprem_host" {
  project      = local.onprem_sim_project
  name         = "${var.project_prefix}-c-onprem-host"
  machine_type = var.onprem_vm_machine_type
  zone         = "${var.primary_region}-a"

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-12"
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.onprem_primary.id
    # No access_config: no external IP.
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -eu
    apt-get update -y
    apt-get install -y python3
    cat >/etc/systemd/system/onprem-sim.service <<SVC
    [Unit]
    Description=onprem-sim HTTP responder
    After=network-online.target
    [Service]
    ExecStart=/usr/bin/python3 -m http.server 80
    Restart=always
    [Install]
    WantedBy=multi-user.target
    SVC
    systemctl daemon-reload
    systemctl enable --now onprem-sim.service
  EOT

  labels = merge(local.base_labels, { app = "onprem-sim" })

  tags = ["onprem-host"]
}
