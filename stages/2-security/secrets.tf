# Secret Manager: secrets that later stages read instead of keeping them in code or tfvars (spec).
#
# The value is generated here with an EPHEMERAL random_password and written through the write-only attribute
# secret_data_wo: it never appears in the plan, in the state or in the PR comments. To rotate a secret, bump
# its `version` in var.secrets; the next apply writes a new version with a new value.
#
# Each secret is replicated in the two allowed regions (the org policy only allows those) and only the stage
# that uses it may read the value (secretAccessor). Groups in var.security_reader_groups see the metadata,
# never the value (secretmanager.viewer).

resource "google_secret_manager_secret" "this" {
  for_each = var.secrets

  project   = local.security_project_id
  secret_id = "${var.project_prefix}-c-sec-${each.key}"

  replication {
    user_managed {
      replicas {
        location = var.primary_region
      }
      replicas {
        location = var.dr_region
      }
    }
  }

  labels = merge(local.base_labels, { app = each.value.app })
}

ephemeral "random_password" "secret" {
  for_each = var.secrets

  length  = each.value.length
  special = each.value.special
}

resource "google_secret_manager_secret_version" "this" {
  for_each = var.secrets

  secret                 = google_secret_manager_secret.this[each.key].id
  secret_data_wo         = ephemeral.random_password.secret[each.key].result
  secret_data_wo_version = each.value.version
}

locals {
  secret_accessor_pairs = merge([
    for name, s in var.secrets : {
      for stage in s.accessors : "${name}/${stage}" => { secret = name, stage = stage }
    }
  ]...)

  secret_viewer_pairs = {
    for pair in setproduct(keys(var.secrets), var.security_reader_groups) :
    "${pair[0]}/${pair[1]}" => { secret = pair[0], group = pair[1] }
  }
}

resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = local.secret_accessor_pairs

  project   = local.security_project_id
  secret_id = google_secret_manager_secret.this[each.value.secret].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.pipeline_sa[each.value.stage]}"
}

resource "google_secret_manager_secret_iam_member" "viewer" {
  for_each = local.secret_viewer_pairs

  project   = local.security_project_id
  secret_id = google_secret_manager_secret.this[each.value.secret].secret_id
  role      = "roles/secretmanager.viewer"
  member    = "group:${each.value.group}"
}
