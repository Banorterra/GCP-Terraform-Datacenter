output "keyring_id" {
  description = "Key ring ID: projects/<project>/locations/<location>/keyRings/<name>."
  value       = google_kms_key_ring.this.id
}

output "key_ids" {
  description = "Key ID by key name, in the form CMEK settings take (kms_key_name, encryption.default_kms_key_name)."
  value       = { for k, v in google_kms_crypto_key.this : k => v.id }
}
