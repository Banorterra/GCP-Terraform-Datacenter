# One environment's network: a Shared VPC host VPC with one subnet, Cloud NAT for outbound traffic, an NCC spoke
# on the landing-zone hub, DNS (own private zone + peering to the hub) and the base firewall.
#
# AWS analogy: a VPC shared with RAM to the account's workloads, attached to a Transit Gateway, with a NAT gateway.

locals {
  name = "${var.prefix}-${var.env}"
}

# ---- VPC and subnet ----

resource "google_compute_network" "this" {
  project                         = var.project_id
  name                            = "${local.name}-spoke-vpc"
  auto_create_subnetworks         = false
  routing_mode                    = "GLOBAL"
  delete_default_routes_on_create = false
  description                     = "Spoke VPC of ${var.env}. Shared VPC host; attached to the NCC hub."
}

resource "google_compute_subnetwork" "primary" {
  project                  = var.project_id
  name                     = "${local.name}-subnet-${var.region}"
  network                  = google_compute_network.this.id
  region                   = var.region
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true

  dynamic "secondary_ip_range" {
    for_each = var.secondary_ranges
    content {
      range_name    = secondary_ip_range.key
      ip_cidr_range = secondary_ip_range.value
    }
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = var.flow_logs_sampling
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Stage 4 attaches the environment's app projects as service projects of this host.
resource "google_compute_shared_vpc_host_project" "this" {
  project = var.project_id
}

# ---- Private services access (needed by stages 4 and 5) ----
# Cloud SQL, Filestore and Memorystore run in a Google-managed VPC that is peered to this one. Google takes their
# private IPs from this reserved range. Without it stage 5 cannot create Cloud SQL: public IP is blocked by the org
# policy sql.restrictPublicIp (stage 1). The app projects of stage 4 use it through the Shared VPC.
# AWS analogy: the subnet group of RDS, except that the database lives in Google's VPC, not in a subnet of ours.

resource "google_compute_global_address" "psa" {
  count = var.psa_cidr == null ? 0 : 1

  project       = var.project_id
  name          = "${local.name}-psa-range"
  network       = google_compute_network.this.id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = split("/", var.psa_cidr)[0]
  prefix_length = tonumber(split("/", var.psa_cidr)[1])
  description   = "Private services access range of ${var.env} (Cloud SQL, Filestore, Memorystore)."
}

resource "google_service_networking_connection" "psa" {
  count = var.psa_cidr == null ? 0 : 1

  network                 = google_compute_network.this.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa[0].name]
}

# ---- Outbound Internet (VMs have no external IPs: org policy) ----

resource "google_compute_router" "nat" {
  project = var.project_id
  name    = "${local.name}-nat-router"
  network = google_compute_network.this.id
  region  = var.region
}

resource "google_compute_router_nat" "this" {
  project                            = var.project_id
  name                               = "${local.name}-nat"
  router                             = google_compute_router.nat.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ---- Network Connectivity Center ----

# The spoke lives in this VPC's project and joins the hub in net-hub, as NCC documents for a VPC in another
# project: it is a proposal that the hub's edge group auto-accepts for the net-host projects (3-networks/shared).
# Like attaching a VPC from a member account to a Transit Gateway shared with RAM.
resource "google_network_connectivity_spoke" "this" {
  project  = var.project_id
  name     = "${local.name}-ncc-spoke"
  location = "global"
  hub      = var.ncc_hub_id
  group    = var.ncc_spoke_group

  linked_vpc_network {
    uri = google_compute_network.this.self_link
  }

  labels = merge(var.labels, { app = "ncc-spoke" })
}

# ---- DNS ----

resource "google_dns_managed_zone" "env" {
  project     = var.project_id
  name        = "${local.name}-private"
  dns_name    = var.dns_zone
  description = "Private zone of ${var.env}."
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.this.id
    }
  }

  labels = merge(var.labels, { app = "dns" })
}

# Names the hub resolves (its zone, and the on-prem domain it forwards over the VPN) are resolved here by peering.
resource "google_dns_managed_zone" "peering" {
  for_each = toset(var.peered_dns_zones)

  project     = var.project_id
  name        = "${local.name}-peer-${replace(trimsuffix(each.value, "."), ".", "-")}"
  dns_name    = each.value
  description = "Peering to the hub VPC for ${each.value}"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.this.id
    }
  }

  peering_config {
    target_network {
      network_url = var.hub_network_id
    }
  }

  labels = merge(var.labels, { app = "dns" })
}

# ---- Firewall (ingress is denied unless a rule below allows it) ----

resource "google_compute_firewall" "allow_internal" {
  project   = var.project_id
  network   = google_compute_network.this.name
  name      = "${local.name}-allow-internal"
  direction = "INGRESS"
  priority  = 1000

  source_ranges = concat([var.subnet_cidr], values(var.secondary_ranges))

  allow { protocol = "all" }
}

resource "google_compute_firewall" "allow_iap_ssh" {
  project   = var.project_id
  network   = google_compute_network.this.name
  name      = "${local.name}-allow-iap-ssh"
  direction = "INGRESS"
  priority  = 1000

  source_ranges = [var.iap_source_range]
  target_tags   = ["ssh"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow_from_onprem" {
  count = length(var.onprem_cidrs) > 0 ? 1 : 0

  project   = var.project_id
  network   = google_compute_network.this.name
  name      = "${local.name}-allow-from-onprem"
  direction = "INGRESS"
  priority  = 1100

  source_ranges = var.onprem_cidrs
  target_tags   = ["allow-onprem"]

  allow { protocol = "icmp" }
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

# Load balancer health checks (needed by stages 4 and 5). The load balancer of stage 5 checks the MIG VMs and the
# GKE nodes from these Google ranges, and the external load balancer's proxies connect from them too. Without this
# rule deny_all drops them: every backend looks down, users get 502 and the MIG autohealing keeps recreating VMs.
# AWS analogy: the security group rule that lets the ALB reach the instances for its health checks.
resource "google_compute_firewall" "allow_health_checks" {
  project   = var.project_id
  network   = google_compute_network.this.name
  name      = "${local.name}-allow-health-checks"
  direction = "INGRESS"
  priority  = 1000

  source_ranges = var.health_check_ranges

  allow { protocol = "tcp" }
}

resource "google_compute_firewall" "deny_all" {
  project   = var.project_id
  network   = google_compute_network.this.name
  name      = "${local.name}-deny-all"
  direction = "INGRESS"
  priority  = 65534

  source_ranges = ["0.0.0.0/0"]

  deny { protocol = "all" }
}
