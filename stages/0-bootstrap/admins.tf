# Read-only visibility for the human admins on the two bootstrap projects.
# Whoever runs stage 0 becomes Owner of these projects because they created them; everyone else in
# gcp-organization-admins only had access to the state bucket itself and could not list buckets or
# browse the projects in the console. Granting Viewer to the group gives every admin the same view
# without personal grants. Write access stays with the stage service accounts.

locals {
  bootstrap_projects = {
    seed = module.seed_bootstrap.seed_project_id
    cicd = module.cicd.project_id
  }
}

resource "google_project_iam_member" "org_admins_viewer" {
  for_each = local.bootstrap_projects

  project = each.value
  role    = "roles/viewer"
  member  = "group:${var.group_org_admins}"
}
