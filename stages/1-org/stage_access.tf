# Access for later stages to the projects created here.
#
# Stage 0 gives each stage SA roles at the organization (sa.tf), but the projects of stage 1 did not exist
# then. The org SA created them, so it grants the next stages what they need INSIDE each project, and
# nothing more: in AWS terms, a role in the member account that only that stage's pipeline can assume.
#
# Stage 2 (sa-terraform-security) owns the security project: Cloud KMS and Secret Manager. Both admin roles
# include setIamPolicy on keys and secrets, so stage 2 grants access to them resource by resource
# (for example the VPN pre-shared key only to the networks SA). The APIs are enabled in projects.tf.

locals {
  pipeline_sa = {
    for s in ["security", "networks", "projects", "workloads"] :
    s => "sa-terraform-${s}@${var.pipeline_sa_project_id}.iam.gserviceaccount.com"
  }

  # project key in module.common_projects => { stage = SA key, roles = [...] }
  stage_project_roles = {
    security = {
      stage = "security"
      roles = ["roles/cloudkms.admin", "roles/secretmanager.admin"]
    }
  }

  stage_project_pairs = merge([
    for project, cfg in local.stage_project_roles : {
      for role in cfg.roles : "${project}/${role}" => { project = project, stage = cfg.stage, role = role }
    }
  ]...)
}

resource "google_project_iam_member" "stage_access" {
  for_each = local.stage_project_pairs

  project = module.common_projects[each.value.project].project_id
  role    = each.value.role
  member  = "serviceAccount:${local.pipeline_sa[each.value.stage]}"
}
