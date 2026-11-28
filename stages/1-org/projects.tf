# Common-folder projects and per-environment network host projects.
# Uses the same project-factory module stage 0 uses for the CICD project (~> 18.0).
# The project ID is <prefix>-c-<key>; `name` is only the display name (local.common_project_display_names,
# or the ID). We keep random_project_id = false here because the IDs must be predictable (stage 2-5 reference
# them by ID). Changing a display name updates the project in place. If a sandbox collides on a project ID, change
# var.project_prefix in terraform.tfvars.

module "common_projects" {
  for_each = local.common_projects

  source  = "terraform-google-modules/project-factory/google"
  version = "~> 18.0"

  name              = lookup(local.common_project_display_names, each.key, "${var.project_prefix}-c-${each.key}")
  project_id        = "${var.project_prefix}-c-${each.key}"
  random_project_id = false
  org_id            = var.org_id
  folder_id         = google_folder.env["common"].id
  billing_account   = local.project_billing_account["c-${each.key}"]
  labels            = merge(local.base_labels, { app = each.value.app })

  # Minimal API set. Each stage that owns the project turns on what it needs. A project without
  # billing can only enable free APIs. Billed projects also get their extra APIs (local.common_projects):
  # stage SAs have no serviceusage admin on these projects, so the APIs a later stage needs are turned on here.
  activate_apis = local.project_billing_alias["c-${each.key}"] == "none" ? local.free_apis : concat(local.free_apis, [
    "storage.googleapis.com",
  ], each.value.extra_apis)

  # No per-project service account: nothing uses it and the spec doesn't ask for one.
  create_project_sa = false

  deletion_policy = var.project_deletion_policy
}

# One network host project per environment: the "spoke" network project the spec asks for in each
# env folder ("un proyecto de red spoke"), which hosts that env's Shared VPC (diagram 2). Stage 3 enables
# Shared VPC and the networking APIs on these; here we just create the project in the right folder.
module "net_host_projects" {
  for_each = local.env_folders

  source  = "terraform-google-modules/project-factory/google"
  version = "~> 18.0"

  name              = "${var.project_prefix}-${each.value}-net-host"
  random_project_id = false
  org_id            = var.org_id
  folder_id         = google_folder.env[each.value].id
  billing_account   = local.project_billing_account["${each.value}-net-host"]

  labels = merge(var.labels, {
    env        = each.value
    managed_by = "terraform"
    app        = "net-host"
  })

  activate_apis = local.project_billing_alias["${each.value}-net-host"] == "none" ? local.free_apis : concat(local.free_apis, [
    "compute.googleapis.com",
  ])

  # No per-project service account: nothing uses it and the spec doesn't ask for one.
  create_project_sa = false

  deletion_policy = var.project_deletion_policy
}
