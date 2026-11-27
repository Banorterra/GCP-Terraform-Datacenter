# VPC firewall rules. Deny-all is the implicit default; we only add the allows.
# Hierarchical firewall policies that cover the spokes live in their own roots (envs/{dev,qa,prod}).

# ---- Hub VPC ----

# Allow IAP SSH to anything in the hub (for debugging). IAP's TCP range is Google-fixed.
resource "google_compute_firewall" "hub_allow_iap_ssh" {
  project   = local.net_hub_project
  network   = google_compute_network.hub.name
  name      = "${var.project_prefix}-c-hub-allow-iap-ssh"
  direction = "INGRESS"
  priority  = 1000

  source_ranges = [var.iap_source_range]
  target_tags   = ["ssh"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Allow from the on-prem subnet (so hub-side probes can reach VMs reachable via BGP).
resource "google_compute_firewall" "hub_allow_from_onprem" {
  project   = local.net_hub_project
  network   = google_compute_network.hub.name
  name      = "${var.project_prefix}-c-hub-allow-from-onprem"
  direction = "INGRESS"
  priority  = 1100

  source_ranges = [var.cidr_plan.onprem.block]

  allow { protocol = "icmp" }
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

# Explicit deny-all at the lowest priority for clarity (the implicit default also denies).
resource "google_compute_firewall" "hub_deny_all" {
  project   = local.net_hub_project
  network   = google_compute_network.hub.name
  name      = "${var.project_prefix}-c-hub-deny-all"
  direction = "INGRESS"
  priority  = 65534

  source_ranges = ["0.0.0.0/0"]
  deny { protocol = "all" }
}

# ---- Onprem-sim VPC ----

# Allow IAP SSH to the on-prem host for interactive debugging.
resource "google_compute_firewall" "onprem_allow_iap_ssh" {
  project   = local.onprem_sim_project
  network   = google_compute_network.onprem.name
  name      = "${var.project_prefix}-c-onprem-allow-iap-ssh"
  direction = "INGRESS"
  priority  = 1000

  source_ranges = [var.iap_source_range]
  target_tags   = ["onprem-host"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Allow ICMP + HTTP from the GCP side (hub + every spoke block) so the Sprint 4 gate test works:
# "a prod VM reaches an on-prem host by private IP and resolves its DNS".
resource "google_compute_firewall" "onprem_allow_from_gcp" {
  project   = local.onprem_sim_project
  network   = google_compute_network.onprem.name
  name      = "${var.project_prefix}-c-onprem-allow-from-gcp"
  direction = "INGRESS"
  priority  = 1100

  source_ranges = [
    var.cidr_plan.hub.block,
    var.cidr_plan.dev.block,
    var.cidr_plan.qa.block,
    var.cidr_plan.prod.block,
  ]

  allow { protocol = "icmp" }
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

resource "google_compute_firewall" "onprem_deny_all" {
  project   = local.onprem_sim_project
  network   = google_compute_network.onprem.name
  name      = "${var.project_prefix}-c-onprem-deny-all"
  direction = "INGRESS"
  priority  = 65534

  source_ranges = ["0.0.0.0/0"]
  deny { protocol = "all" }
}
