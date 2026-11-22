# Read-only "plan" service accounts, one per stage (1-org .. 5-workloads).
#
# Why: PR plans run code nobody has reviewed yet. Anything in a PR (a provider, a data source, a
# local-exec) runs with the identity the plan job uses. So PR plans get a read-only identity, and the
# stage service accounts that can change things are usable only from commits already on main
# (see the sa_mapping in cicd.tf).
#
# What a plan SA can do: read resources across the organization, read billing, and read (not write or
# lock) its own stage's state prefix. PR plans therefore run with -lock=false.

locals {
  plan_stages = toset(["org", "security", "networks", "projects", "workloads"])

  plan_org_roles = [
    "roles/viewer",
    "roles/iam.securityReviewer",
    "roles/orgpolicy.policyViewer",
    "roles/resourcemanager.folderViewer",
    "roles/accesscontextmanager.policyReader",
  ]

  plan_org_pairs = {
    for pair in setproduct(local.plan_stages, local.plan_org_roles) :
    "${pair[0]}/${pair[1]}" => { stage = pair[0], role = pair[1] }
  }
}

resource "google_service_account" "plan" {
  for_each = local.plan_stages

  project                      = module.seed_bootstrap.seed_project_id
  account_id                   = "sa-terraform-plan-${each.key}"
  display_name                 = "Read-only plan identity for stage ${local.state_prefix[each.key]} (PR checks). Managed by Terraform."
  create_ignore_already_exists = true
}

resource "google_organization_iam_member" "plan_org" {
  for_each = local.plan_org_pairs

  org_id = var.org_id
  role   = each.value.role
  member = "serviceAccount:${google_service_account.plan[each.value.stage].email}"
}

resource "google_billing_account_iam_member" "plan_billing_viewer" {
  for_each = local.plan_stages

  billing_account_id = var.billing_account
  role               = "roles/billing.viewer"
  member             = "serviceAccount:${google_service_account.plan[each.key].email}"
}

# Same prefix condition as the stage SA (sa.tf), but object read only.
resource "google_storage_bucket_iam_member" "plan_state_read" {
  for_each = local.plan_stages

  bucket = module.seed_bootstrap.gcs_bucket_tfstate
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.plan[each.key].email}"

  condition {
    title       = "plan-state-read-${local.state_prefix[each.key]}"
    description = "Read only the ${local.state_prefix[each.key]}/ prefix of the Terraform state bucket."
    expression = join(" || ", [
      "resource.name.startsWith(\"projects/_/buckets/${module.seed_bootstrap.gcs_bucket_tfstate}/objects/${local.state_prefix[each.key]}/\")",
      "api.getAttribute(\"storage.googleapis.com/objectListPrefix\", \"\").startsWith(\"${local.state_prefix[each.key]}/\")",
    ])
  }
}
