# CI/CD identity: a dedicated project that holds the Workload Identity pool GitHub Actions uses.
# Keeping it apart from the seed project (state + service accounts) follows the example foundation's
# separation of concerns. No JSON keys anywhere: GitHub's OIDC token is exchanged for a short-lived
# credential of the stage service account.

module "cicd" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 18.0"

  name              = "${var.project_prefix}-b-cicd-wif-gh"
  random_project_id = true
  org_id            = var.org_id
  folder_id         = google_folder.bootstrap.id
  billing_account   = var.billing_account
  labels            = merge(local.base_labels, { app = "cicd-wif" })

  activate_apis = [
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "serviceusage.googleapis.com",
    "billingbudgets.googleapis.com",
  ]

  deletion_policy = var.project_deletion_policy
}

module "gh_oidc" {
  source  = "terraform-google-modules/github-actions-runners/google//modules/gh-oidc"
  version = "~> 5.1"

  project_id  = module.cicd.project_id
  pool_id     = "foundation-pool"
  provider_id = "foundation-gh-provider"

  # Only workflows from this exact repository can obtain credentials.
  attribute_condition = "assertion.repository=='${var.github_owner}/${var.github_repo}'"

  # Each stage service account can be impersonated by this repository only.
  sa_mapping = {
    for k, sa in google_service_account.stage : k => {
      sa_name   = sa.name
      attribute = "attribute.repository/${var.github_owner}/${var.github_repo}"
    }
  }
}
