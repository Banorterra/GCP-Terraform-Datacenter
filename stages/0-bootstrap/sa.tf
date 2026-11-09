# One service account per stage, with least-privilege starting roles.
# Role sets are adapted from the example foundation's 0-bootstrap/sa.tf. They are a STARTING POINT:
# tighten them in the sandbox org by removing roles until a stage's apply fails, then adding back
# only what is needed.

locals {
  stages = {
    bootstrap = "Stage 0 bootstrap. Managed by Terraform."
    org       = "Stage 1 organization (folders, org policies, logging, SCC). Managed by Terraform."
    security  = "Stage 2 security (KMS, Secret Manager, VPC-SC). Managed by Terraform."
    networks  = "Stage 3 networks (hub, spokes, DNS, VPN, firewall). Managed by Terraform."
    projects  = "Stage 4 service projects. Managed by Terraform."
    workloads = "Stage 5 workloads (GKE, MIG, Cloud SQL, storage, LB, backup). Managed by Terraform."
  }

  # State prefix each stage may read/write. Stages 3-5 keep one state per env under their prefix.
  state_prefix = {
    bootstrap = "0-bootstrap"
    org       = "1-org"
    security  = "2-security"
    networks  = "3-networks"
    projects  = "4-projects"
    workloads = "5-workloads"
  }

  org_level_roles = {
    bootstrap = [
      "roles/resourcemanager.organizationAdmin",
      "roles/accesscontextmanager.policyAdmin",
      "roles/serviceusage.serviceUsageConsumer",
    ]
    org = [
      "roles/orgpolicy.policyAdmin",
      "roles/logging.configWriter",
      "roles/resourcemanager.organizationAdmin",
      "roles/securitycenter.notificationConfigEditor",
      "roles/resourcemanager.organizationViewer",
      "roles/accesscontextmanager.policyAdmin",
      "roles/essentialcontacts.admin",
      "roles/resourcemanager.tagAdmin",
      "roles/resourcemanager.tagUser",
      "roles/cloudasset.owner",
      "roles/securitycenter.sourcesEditor",
      "roles/serviceusage.serviceUsageConsumer",
    ]
    security = [
      "roles/accesscontextmanager.policyAdmin",
      "roles/resourcemanager.tagUser",
      "roles/serviceusage.serviceUsageConsumer",
    ]
    networks = [
      "roles/accesscontextmanager.policyAdmin",
      "roles/compute.xpnAdmin",
      "roles/serviceusage.serviceUsageConsumer",
    ]
    projects = [
      "roles/accesscontextmanager.policyAdmin",
      "roles/resourcemanager.organizationAdmin",
      "roles/serviceusage.serviceUsageConsumer",
      "roles/cloudkms.admin",
    ]
    # Workloads get permissions on each service project from stage 4 (project-factory), not here.
    workloads = [
      "roles/serviceusage.serviceUsageConsumer",
    ]
  }

  # Granted on the parent (organization root, or the parent folder when var.parent_folder is set).
  parent_level_roles = {
    bootstrap = ["roles/resourcemanager.folderAdmin"]
    org       = ["roles/resourcemanager.folderAdmin"]
    security  = ["roles/resourcemanager.folderViewer"]
    networks = [
      "roles/resourcemanager.folderViewer",
      "roles/compute.networkAdmin",
      "roles/compute.securityAdmin",
      "roles/compute.orgSecurityPolicyAdmin",
      "roles/compute.orgSecurityResourceAdmin",
      "roles/dns.admin",
      "roles/networkconnectivity.hubAdmin",
    ]
    projects = [
      "roles/resourcemanager.folderAdmin",
      "roles/artifactregistry.admin",
      "roles/compute.networkAdmin",
      "roles/compute.xpnAdmin",
      "roles/iam.serviceAccountAdmin",
      "roles/networkconnectivity.hubUser",
      "roles/networkconnectivity.groupUser",
    ]
    workloads = ["roles/resourcemanager.folderViewer"]
  }

  # Only the bootstrap SA manages things inside the two bootstrap projects.
  seed_project_roles = [
    "roles/storage.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/resourcemanager.projectDeleter",
    "roles/cloudkms.admin",
  ]
  cicd_project_roles = [
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/resourcemanager.projectDeleter",
  ]

  # Stages that create projects need to attach them to the billing account.
  billing_user_stages = ["bootstrap", "org", "projects"]

  org_level_pairs = merge([
    for sa, roles in local.org_level_roles : {
      for r in roles : "${sa}/${r}" => { sa = sa, role = r }
    }
  ]...)

  parent_level_pairs = merge([
    for sa, roles in local.parent_level_roles : {
      for r in roles : "${sa}/${r}" => { sa = sa, role = r }
    }
  ]...)
}

resource "google_service_account" "stage" {
  for_each = local.stages

  project                      = module.seed_bootstrap.seed_project_id
  account_id                   = "sa-terraform-${each.key}"
  display_name                 = each.value
  create_ignore_already_exists = true
}

resource "google_organization_iam_member" "org_level" {
  for_each = local.org_level_pairs

  org_id = var.org_id
  role   = each.value.role
  member = "serviceAccount:${google_service_account.stage[each.value.sa].email}"
}

resource "google_organization_iam_member" "parent_level_org" {
  for_each = local.parent_type == "organization" ? local.parent_level_pairs : {}

  org_id = var.org_id
  role   = each.value.role
  member = "serviceAccount:${google_service_account.stage[each.value.sa].email}"
}

resource "google_folder_iam_member" "parent_level_folder" {
  for_each = local.parent_type == "folder" ? local.parent_level_pairs : {}

  folder = "folders/${var.parent_folder}"
  role   = each.value.role
  member = "serviceAccount:${google_service_account.stage[each.value.sa].email}"
}

resource "google_project_iam_member" "seed_bootstrap_sa" {
  for_each = toset(local.seed_project_roles)

  project = module.seed_bootstrap.seed_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.stage["bootstrap"].email}"
}

resource "google_project_iam_member" "cicd_bootstrap_sa" {
  for_each = toset(local.cicd_project_roles)

  project = module.cicd.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.stage["bootstrap"].email}"
}

resource "google_billing_account_iam_member" "billing_user" {
  for_each = toset(local.billing_user_stages)

  billing_account_id = var.billing_account
  role               = "roles/billing.user"
  member             = "serviceAccount:${google_service_account.stage[each.value].email}"
}

# Budgets with alerts (spec: cost-control risk mitigation) are created by the org stage.
resource "google_billing_account_iam_member" "org_costs_manager" {
  billing_account_id = var.billing_account
  role               = "roles/billing.costsManager"
  member             = "serviceAccount:${google_service_account.stage["org"].email}"
}

# Billing-account log sink is created by the org stage.
resource "google_billing_account_iam_member" "org_billing_sink" {
  billing_account_id = var.billing_account
  role               = "roles/logging.configWriter"
  member             = "serviceAccount:${google_service_account.stage["org"].email}"
}

# Spec: "Solo la cuenta de servicio de cada etapa puede leer y escribir su prefijo."
# Object-level access limited to the stage's own prefix with an IAM condition (needs uniform
# bucket-level access, which the bootstrap module enables). The second clause lets `list`
# requests for that prefix through, because list requests carry no object name.
resource "google_storage_bucket_iam_member" "stage_state" {
  for_each = local.state_prefix

  bucket = module.seed_bootstrap.gcs_bucket_tfstate
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.stage[each.key].email}"

  condition {
    title       = "state-prefix-${each.value}"
    description = "Read/write only the ${each.value}/ prefix of the Terraform state bucket."
    expression = join(" || ", [
      "resource.name.startsWith(\"projects/_/buckets/${module.seed_bootstrap.gcs_bucket_tfstate}/objects/${each.value}/\")",
      "api.getAttribute(\"storage.googleapis.com/objectListPrefix\", \"\").startsWith(\"${each.value}/\")",
    ])
  }
}

# Lets the pipeline use the stage SA as the provider identity (impersonation), as in the example foundation.
resource "google_service_account_iam_member" "self_impersonate" {
  for_each = google_service_account.stage

  service_account_id = each.value.id
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${each.value.email}"
}
