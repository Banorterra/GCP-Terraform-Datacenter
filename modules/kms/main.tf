# Cloud KMS key ring with symmetric keys that rotate on their own. Used for CMEK (customer-managed keys) on
# Cloud Storage, Cloud SQL, GKE and Persistent Disk. Like an AWS KMS customer managed key with automatic
# rotation, except that GCP groups keys in a regional key ring.
#
# Destroy: GCP never deletes key rings or keys. terraform destroy schedules every key version for
# destruction (destroy_scheduled_duration) and drops the ring and keys from the state; their names stay
# taken. That is why callers should add a random suffix to keyring_name.

resource "google_kms_key_ring" "this" {
  project  = var.project_id
  name     = var.keyring_name
  location = var.location
}

resource "google_kms_crypto_key" "this" {
  for_each = var.keys

  name                       = each.key
  key_ring                   = google_kms_key_ring.this.id
  purpose                    = "ENCRYPT_DECRYPT"
  rotation_period            = coalesce(each.value.rotation_period, var.rotation_period)
  destroy_scheduled_duration = var.destroy_scheduled_duration
  labels                     = var.labels

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = var.protection_level
  }
}

locals {
  encrypter_pairs = merge([
    for key, members in var.encrypters_decrypters : {
      for m in members : "${key}/${m}" => { key = key, member = m }
    }
  ]...)
}

resource "google_kms_crypto_key_iam_member" "encrypter_decrypter" {
  for_each = local.encrypter_pairs

  crypto_key_id = google_kms_crypto_key.this[each.value.key].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = each.value.member
}

resource "google_kms_key_ring_iam_member" "viewer" {
  for_each = toset(var.keyring_viewers)

  key_ring_id = google_kms_key_ring.this.id
  role        = "roles/cloudkms.viewer"
  member      = each.value
}
