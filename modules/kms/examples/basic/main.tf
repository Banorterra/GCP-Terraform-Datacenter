# Minimal use of modules/kms: one key ring in Querétaro with a key for Cloud Storage, and a group that can
# see it. Run from this folder with `terraform init && terraform plan -var project_id=<security project>`.

terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

variable "project_id" {
  description = "Project that holds the key ring."
  type        = string
}

module "kms" {
  source = "../.."

  project_id   = var.project_id
  location     = "northamerica-south1"
  keyring_name = "example-keyring"
  keys = {
    storage = {}
  }
  labels          = { app = "kms-example" }
  keyring_viewers = ["group:grp-seguridad@example.com"]
}

output "storage_key_id" {
  description = "ID of the storage key, to use as a bucket's default_kms_key_name."
  value       = module.kms.key_ids["storage"]
}
