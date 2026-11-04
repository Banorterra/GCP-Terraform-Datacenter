# Variables every stage root shares (names match the spec's variable table).
# Do not edit the copies in stages/*: edit this file and run scripts/sync-boilerplate.sh.

variable "org_id" {
  description = "Numeric ID of the GCP organization."
  type        = string
}

variable "billing_account" {
  description = "Billing account ID, format XXXXXX-XXXXXX-XXXXXX."
  type        = string
}

variable "environment" {
  description = "Environment: dev, qa or prod; use shared for single-instance stages (1-org, 2-security)."
  type        = string

  validation {
    condition     = contains(["shared", "dev", "qa", "prod"], var.environment)
    error_message = "environment must be one of: shared, dev, qa, prod."
  }
}

variable "primary_region" {
  description = "Primary region."
  type        = string
  default     = "us-central1"
}

variable "dr_region" {
  description = "Disaster-recovery region."
  type        = string
  default     = "us-east4"
}

variable "state_bucket" {
  description = "Terraform state bucket (output state_bucket of 0-bootstrap), used by terraform_remote_state."
  type        = string
}

variable "labels" {
  description = "Common labels. Values must be lowercase letters, digits, '_' or '-' (GCP rule): ti-001, not TI-001."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for v in values(var.labels) : can(regex("^[a-z0-9_-]{0,63}$", v))])
    error_message = "Label values must match ^[a-z0-9_-]{0,63}$."
  }
}
