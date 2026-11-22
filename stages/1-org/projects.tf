# Common-folder projects and per-environment network host projects.
# Uses the same project-factory module stage 0 uses for the CICD project (~> 18.0).
# `name` becomes the project ID; we keep random_project_id = false here because the IDs must be
# predictable (stage 2-5 reference them by ID). If a sandbox collides on a project ID, change
# var.project_prefix in terraform.tfvars.

module "common_projects" {
  for_each = local.common_projects

  source  = "terraform-google-modules/project-factory/google"
  version = "~> 18.0"

  name              = "${var.project_prefix}-c-${each.key}"
  random_project_id = false
  org_id            = var.org_id
  folder_id         = google_folder.env["common"].id
  billing_account   = var.billing_account
  labels            = merge(local.base_labels, { app = each.value.app })

  # Minimal API set. Each stage that owns the project turns on what it needs.
  activate_apis = [
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "storage.googleapis.com",
  ]

  deletion_policy = var.project_deletion_policy
}

# One network host project per environment. Stage 3 enables Shared VPC and the networking APIs
# on these; here we just create the project in the right folder with the right labels.
module "net_host_projects" {
  for_each = local.env_folders

  source  = "terraform-google-modules/project-factory/google"
  version = "~> 18.0"

  name              = "${var.project_prefix}-${each.value}-net-host"
  random_project_id = false
  org_id            = var.org_id
  folder_id         = google_folder.env[each.value].id
  billing_account   = var.billing_account

  labels = merge(var.labels, {
    env        = each.value
    managed_by = "terraform"
    app        = "net-host"
  })

  activate_apis = [
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
    "compute.googleapis.com",
  ]

  deletion_policy = var.project_deletion_policy
}
