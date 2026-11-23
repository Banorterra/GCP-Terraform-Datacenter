# One key ring per region (Querétaro primary, Dallas DR), with one key per kind of data. CMEK keys must live
# in the same region as the data, so the DR copies (Cloud SQL replica, backups) use the Dallas ring.
#
# GCP never deletes key rings or keys: after a destroy their names stay taken. The random suffix gives a
# new name on the next apply instead of failing with "already exists".

resource "random_id" "kms_suffix" {
  byte_length = 2
}

module "kms" {
  source = "../../modules/kms"

  for_each = {
    primary = var.primary_region
    dr      = var.dr_region
  }

  project_id   = local.security_project_id
  location     = each.value
  keyring_name = "${var.project_prefix}-c-sec-kr-${each.value}-${random_id.kms_suffix.hex}"
  keys         = { for k in var.kms_keys : k => {} }

  rotation_period            = var.kms_rotation_period
  protection_level           = var.kms_protection_level
  destroy_scheduled_duration = var.kms_destroy_scheduled_duration
  labels                     = merge(local.base_labels, { app = "kms" })

  keyring_viewers = [for g in var.security_reader_groups : "group:${g}"]
}

# Stage 4 creates the service projects and grants their service agents (Storage, Cloud SQL, GKE)
# cryptoKeyEncrypterDecrypter on these keys. It holds roles/cloudkms.admin at the organization (stage 0).
