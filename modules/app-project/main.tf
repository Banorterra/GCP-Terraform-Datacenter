# One application (service) project attached to the Shared VPC of its environment.
#
# AWS analogy: a member account of AWS Organizations that gets a subnet shared with it through RAM. The
# network (VPC, subnet, routes, firewall) stays in the host project of stage 3; this project only places
# resources in that subnet. Here we create the project, attach it to the host, and give each service
# account the access it needs: the stage 5 pipeline, the Google service agents (GKE, Cloud SQL, Storage)
# and the people's groups (read only).

resource "random_id" "suffix" {
  byte_length = 2
}

locals {
  # A random suffix so the stage can be destroyed and created again: GCP keeps a deleted project ID
  # reserved for 30 days, so the same ID cannot be reused right away.
  project_id = "${var.name}-${random_id.suffix.hex}"

  apis = toset(distinct(concat(["compute.googleapis.com"], var.apis)))

  gke_enabled = contains(local.apis, "container.googleapis.com")
  sql_enabled = contains(local.apis, "sqladmin.googleapis.com")

  # projects/<p>/regions/<r>/subnetworks/<name> at the end of the self link.
  subnet_parts = regex("projects/(?P<project>[^/]+)/regions/(?P<region>[^/]+)/subnetworks/(?P<name>[^/]+)$", var.subnet_self_link)
}

resource "google_project" "this" {
  name                = var.name
  project_id          = local.project_id
  folder_id           = var.folder_id
  billing_account     = var.billing_account
  labels              = var.labels
  deletion_policy     = var.deletion_policy
  auto_create_network = false # the network is the Shared VPC; org policy skipDefaultNetworkCreation agrees
}

resource "google_project_service" "this" {
  for_each = local.apis

  project = google_project.this.project_id
  service = each.value

  # The project is deleted as a whole on destroy; turning APIs off one by one first only slows it down.
  disable_on_destroy = false
}

# --- Shared VPC -----------------------------------------------------------------------------------------

resource "google_compute_shared_vpc_service_project" "this" {
  host_project    = var.host_project_id
  service_project = google_project.this.project_id

  depends_on = [google_project_service.this]
}

locals {
  number = google_project.this.number

  # Google-managed service agents of this project. They exist once their API is on.
  agents = {
    cloudservices  = "serviceAccount:${local.number}@cloudservices.gserviceaccount.com"
    gke            = "serviceAccount:service-${local.number}@container-engine-robot.iam.gserviceaccount.com"
    compute_system = "serviceAccount:service-${local.number}@compute-system.iam.gserviceaccount.com"
    storage        = "serviceAccount:${data.google_storage_project_service_account.this.email_address}"
    sql            = local.sql_enabled ? "serviceAccount:${google_project_service_identity.sql[0].email}" : null
  }

  # Who may use the shared subnet: the Google APIs agent (MIG, instance templates) and the GKE agent.
  subnet_users = merge(
    { cloudservices = local.agents.cloudservices },
    local.gke_enabled ? { gke = local.agents.gke } : {},
  )
}

resource "google_compute_subnetwork_iam_member" "network_user" {
  for_each = local.subnet_users

  project    = local.subnet_parts.project
  region     = local.subnet_parts.region
  subnetwork = local.subnet_parts.name
  role       = "roles/compute.networkUser"
  member     = each.value

  depends_on = [google_compute_shared_vpc_service_project.this]
}

# The stage 5 account gets Network User on the whole host project, not only the subnet: Cloud SQL,
# Filestore and Memorystore with private IP attach to the VPC (private services access), not to a subnet.
resource "google_project_iam_member" "workloads_host_network_user" {
  project = var.host_project_id
  role    = "roles/compute.networkUser"
  member  = "serviceAccount:${var.workloads_sa}"

  depends_on = [google_compute_shared_vpc_service_project.this]
}

# GKE in a Shared VPC: the GKE agent of the service project acts in the host project (Google's guide
# "Setting up clusters with Shared VPC").
resource "google_project_iam_member" "gke_host_agent_user" {
  count = local.gke_enabled ? 1 : 0

  project = var.host_project_id
  role    = "roles/container.hostServiceAgentUser"
  member  = local.agents.gke

  depends_on = [google_project_service.this]
}

resource "google_project_iam_member" "gke_host_firewall" {
  count = local.gke_enabled && var.grant_gke_firewall_admin ? 1 : 0

  project = var.host_project_id
  role    = "roles/compute.securityAdmin"
  member  = local.agents.gke

  depends_on = [google_project_service.this]
}

# --- Access inside the project --------------------------------------------------------------------------

resource "google_project_iam_member" "workloads" {
  for_each = toset(var.workloads_roles)

  project = google_project.this.project_id
  role    = each.value
  member  = "serviceAccount:${var.workloads_sa}"
}

resource "google_project_iam_member" "viewer" {
  for_each = toset(var.viewer_groups)

  project = google_project.this.project_id
  role    = "roles/viewer"
  member  = "group:${each.value}"
}

# --- CMEK: service agents may use the keys of stage 2 ---------------------------------------------------

data "google_storage_project_service_account" "this" {
  project = google_project.this.project_id

  depends_on = [google_project_service.this]
}

resource "google_project_service_identity" "sql" {
  provider = google-beta
  count    = local.sql_enabled ? 1 : 0

  project = google_project.this.project_id
  service = "sqladmin.googleapis.com"

  depends_on = [google_project_service.this]
}

locals {
  # Purpose of a key => the agents that encrypt with it. GKE needs the compute agent too (node disks).
  purpose_agents = {
    storage = [local.agents.storage]
    sql     = local.sql_enabled ? [local.agents.sql] : []
    gke     = local.gke_enabled ? [local.agents.gke, local.agents.compute_system] : []
  }

  # "<purpose>/<key index>/<agent index>" => { key, member }. Indexes, not values, so the keys are known at plan.
  cmek_grants = merge([
    for purpose, key_ids in var.cmek_keys : merge([
      for ki, key in key_ids : {
        for ai, member in local.purpose_agents[purpose] : "${purpose}/${ki}/${ai}" => { key = key, member = member }
      }
    ]...)
  ]...)
}

resource "google_kms_crypto_key_iam_member" "cmek" {
  for_each = local.cmek_grants

  crypto_key_id = each.value.key
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = each.value.member
}

# --- VPC Service Controls (prod) ------------------------------------------------------------------------
# The stage 2 perimeter ignores changes to its project list, so each stage adds its own projects.

resource "google_access_context_manager_service_perimeter_dry_run_resource" "this" {
  count = var.vpc_sc_perimeter_name == null ? 0 : 1

  perimeter_name = var.vpc_sc_perimeter_name
  resource       = "projects/${google_project.this.number}"
}

resource "google_access_context_manager_service_perimeter_resource" "this" {
  count = var.vpc_sc_perimeter_name != null && var.vpc_sc_enforced ? 1 : 0

  perimeter_name = var.vpc_sc_perimeter_name
  resource       = "projects/${google_project.this.number}"
}
