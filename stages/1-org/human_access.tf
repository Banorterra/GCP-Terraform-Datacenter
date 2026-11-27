# Read-only access for people. The stage service accounts change everything through the pipeline; people need to
# see it in the console. Spec: access through groups only, read-only roles for humans.
#
# Stage 0 already gives the org admins group Viewer on the two bootstrap projects (admins.tf). This does the same
# for the folders stage 1 creates, so every project in them (and the ones later stages add) is visible.

locals {
  folder_viewer_pairs = {
    for pair in setproduct(keys(google_folder.env), var.folder_viewer_groups) :
    "${pair[0]}/${pair[1]}" => { folder = pair[0], group = pair[1] }
  }

  security_reader_roles = ["roles/cloudkms.viewer", "roles/secretmanager.viewer"]

  security_reader_pairs = {
    for pair in setproduct(local.security_reader_roles, var.security_reader_groups) :
    "${pair[0]}/${pair[1]}" => { role = pair[0], group = pair[1] }
  }
}

# Viewer on each folder: browse every project below it, read resources and logs (including the VPC-SC dry-run
# violations in the prod projects). It never includes secret values.
resource "google_folder_iam_member" "viewer" {
  for_each = local.folder_viewer_pairs

  folder = google_folder.env[each.value.folder].name
  role   = "roles/viewer"
  member = "group:${each.value.group}"
}

# VPC Service Controls lives at the organization (2-security). Without this nobody can open the perimeter or the
# access level in the console.
resource "google_organization_iam_member" "vpc_sc_reader" {
  for_each = toset(var.folder_viewer_groups)

  org_id = var.org_id
  role   = "roles/accesscontextmanager.policyReader"
  member = "group:${each.value}"
}

# 2-security grants these groups viewer on each key ring and each secret, which does not let the console list them.
# Project-level viewer roles make the KMS and Secret Manager pages work. secretmanager.viewer never reads values.
resource "google_project_iam_member" "security_reader" {
  for_each = local.security_reader_pairs

  project = module.common_projects["security"].project_id
  role    = each.value.role
  member  = "group:${each.value.group}"
}
