# Stage 0: bootstrap.
# Adapted from terraform-google-modules/terraform-example-foundation (0-bootstrap):
# same CFT bootstrap module for the seed project and state bucket, but
#   - GitHub Actions + Workload Identity Federation instead of Cloud Build / Cloud Source Repositories
#     (CSR is closed to new customers),
#   - one service account per stage of THIS spec (org, security, networks, projects, workloads),
#   - state-bucket access limited to each stage's own prefix (see sa.tf).

locals {
  parent      = var.parent_folder != "" ? "folders/${var.parent_folder}" : "organizations/${var.org_id}"
  parent_type = var.parent_folder == "" ? "organization" : "folder"
  parent_id   = var.parent_folder == "" ? var.org_id : var.parent_folder

  base_labels = merge(var.labels, {
    env        = "bootstrap"
    managed_by = "terraform"
  })

  # Identities that may hold Project Creator. The bootstrap module removes it from everyone else.
  # Projects are created by 1-org (common + environment host projects) and 4-projects (service projects).
  project_creator_stages = ["bootstrap", "org", "projects"]
}

resource "google_folder" "bootstrap" {
  display_name        = "bootstrap"
  parent              = local.parent
  deletion_protection = var.folder_deletion_protection
}

module "seed_bootstrap" {
  source  = "terraform-google-modules/bootstrap/google"
  version = "~> 13.0"

  org_id                         = var.org_id
  folder_id                      = google_folder.bootstrap.id
  project_id                     = "${var.project_prefix}-b-seed"
  state_bucket_name              = "${var.project_prefix}-b-seed-tfstate"
  force_destroy                  = var.bucket_force_destroy
  billing_account                = var.billing_account
  group_org_admins               = var.group_org_admins
  group_billing_admins           = var.group_billing_admins
  default_region                 = var.primary_region
  org_project_creators           = [for s in local.project_creator_stages : "serviceAccount:${google_service_account.stage[s].email}"]
  sa_enable_impersonation        = true
  create_terraform_sa            = false
  parent_folder                  = var.parent_folder == "" ? "" : local.parent
  org_admins_org_iam_permissions = ["roles/resourcemanager.organizationAdmin", "roles/billing.user"]
  project_prefix                 = var.project_prefix
  encrypt_gcs_bucket_tfstate     = true
  key_rotation_period            = "7776000s" # 90 days, per spec
  kms_prevent_destroy            = !var.bucket_tfstate_kms_force_destroy
  project_deletion_policy        = var.project_deletion_policy

  project_labels = merge(local.base_labels, { app = "seed-bootstrap" })

  activate_apis = [
    "serviceusage.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudkms.googleapis.com",
    "compute.googleapis.com",
    "logging.googleapis.com",
    "bigquery.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "iam.googleapis.com",
    "storage.googleapis.com",
    "admin.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "securitycenter.googleapis.com",
    "accesscontextmanager.googleapis.com",
    "billingbudgets.googleapis.com",
    "essentialcontacts.googleapis.com",
    "cloudasset.googleapis.com",
  ]

  sa_org_iam_permissions = []
}

data "google_project" "seed_project" {
  project_id = module.seed_bootstrap.seed_project_id
}
