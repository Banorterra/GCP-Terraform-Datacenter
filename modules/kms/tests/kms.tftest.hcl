# Unit tests for modules/kms with a mock provider: `terraform test` from modules/kms.

mock_provider "google" {}

variables {
  project_id   = "test-project"
  location     = "northamerica-south1"
  keyring_name = "test-keyring"
  keys = {
    storage = {}
    sql     = { rotation_period = "2592000s" }
  }
  labels = { app = "kms" }
  encrypters_decrypters = {
    storage = ["serviceAccount:service-123@gs-project-accounts.iam.gserviceaccount.com"]
  }
  keyring_viewers = ["group:grp-seguridad@example.com"]
}

run "keys_rotate_within_90_days" {
  command = plan

  assert {
    condition     = google_kms_crypto_key.this["storage"].rotation_period == "7776000s"
    error_message = "Keys without an override must rotate every 90 days."
  }

  assert {
    condition     = google_kms_crypto_key.this["sql"].rotation_period == "2592000s"
    error_message = "A per-key rotation_period must win over the default."
  }

  assert {
    condition     = google_kms_crypto_key.this["storage"].version_template[0].protection_level == "SOFTWARE"
    error_message = "Default protection level must be SOFTWARE (the cheap one)."
  }

  assert {
    condition     = google_kms_crypto_key.this["storage"].destroy_scheduled_duration == "86400s"
    error_message = "Default destroy delay must be 1 day so a sandbox destroy stops billing quickly."
  }
}

run "iam_is_per_key_and_ring" {
  command = plan

  assert {
    condition     = length(google_kms_crypto_key_iam_member.encrypter_decrypter) == 1
    error_message = "Only the storage key gets an encrypter/decrypter."
  }

  assert {
    condition     = google_kms_key_ring_iam_member.viewer["group:grp-seguridad@example.com"].role == "roles/cloudkms.viewer"
    error_message = "Key ring viewers must get roles/cloudkms.viewer."
  }
}

run "rejects_rotation_over_90_days" {
  command = plan

  variables {
    rotation_period = "31536000s"
  }

  expect_failures = [var.rotation_period]
}

run "rejects_individual_users" {
  command = plan

  variables {
    keyring_viewers = ["user:alguien@example.com"]
  }

  expect_failures = [var.keyring_viewers]
}
