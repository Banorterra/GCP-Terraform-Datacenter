# Network Connectivity Center hub. Each spoke root (envs/dev|qa|prod) adds its VPC as a spoke
# through its own terraform_remote_state of this root. The hub itself has no traffic policy;
# spoke-to-spoke transit is left OFF (spec: "sin conectividad directa entre entornos").

resource "google_network_connectivity_hub" "main" {
  project     = local.net_hub_project
  name        = "${var.project_prefix}-c-ncc-hub"
  description = "Landing-zone hub. Spokes attach from their env roots."
  labels      = merge(local.base_labels, { app = "ncc-hub" })
}

# The hub VPC itself is a VPC spoke on the hub so routes it learns via BGP from on-prem get
# re-advertised to the other spokes. (If we did not add the hub VPC, spoke VPCs would not see
# the on-prem ranges.)
resource "google_network_connectivity_spoke" "hub_self" {
  project  = local.net_hub_project
  name     = "${var.project_prefix}-c-ncc-spoke-hub"
  location = "global"
  hub      = google_network_connectivity_hub.main.id

  linked_vpc_network {
    uri                   = google_compute_network.hub.self_link
    exclude_export_ranges = []
  }

  labels = merge(local.base_labels, { app = "ncc-hub" })
}
