variable "org_id" {
  description = "Numeric ID of the GCP organization."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{6,15}$", var.org_id))
    error_message = "org_id must be the numeric organization ID (digits only)."
  }
}

variable "billing_account" {
  description = "Billing account ID, format XXXXXX-XXXXXX-XXXXXX."
  type        = string

  validation {
    condition     = can(regex("^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$", var.billing_account))
    error_message = "billing_account must look like ABCDEF-123456-7890AB."
  }
}

variable "parent_folder" {
  description = "Optional numeric folder ID. When set, everything is created under that folder instead of the organization root (useful for a sandbox inside an existing org)."
  type        = string
  default     = ""
}

variable "project_prefix" {
  description = "Short company prefix used in project IDs (spec naming: <empresa>-<entorno>-<dominio>-<recurso>). The example foundation limits it to 3 characters because project IDs max out at 30."
  type        = string
  default     = "dc"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,2}$", var.project_prefix))
    error_message = "project_prefix must be 2-3 lowercase letters/digits and start with a letter."
  }
}

variable "primary_region" {
  description = "Primary region (spec: us-central1). Hosts the state bucket and its KMS key."
  type        = string
  default     = "us-central1"
}

variable "dr_region" {
  description = "Disaster-recovery region (spec: us-east4). Not used by stage 0 itself; kept here so every stage shares the same names."
  type        = string
  default     = "us-east4"

  validation {
    condition     = var.dr_region != var.primary_region
    error_message = "dr_region must differ from primary_region."
  }
}

variable "group_org_admins" {
  description = "Email of the existing Cloud Identity / Workspace group for organization admins."
  type        = string
}

variable "group_billing_admins" {
  description = "Email of the existing group for billing admins."
  type        = string
}

variable "github_owner" {
  description = "GitHub organization or user that owns the repository."
  type        = string
}

variable "github_repo" {
  description = "Repository that holds this code (the spec uses a single repo for all stages). Must match the name on GitHub exactly: Workload Identity trusts only this owner/repo."
  type        = string
  default     = "GCP-Terraform-Datacenter"
}

variable "labels" {
  description = "Common labels. Must include owner and cost_center; env, app and managed_by are set by the code. GCP label values must be lowercase letters, digits, '_' or '-'."
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["owner", "cost_center"] : contains(keys(var.labels), k)])
    error_message = "labels must include owner and cost_center."
  }

  validation {
    condition     = alltrue([for v in values(var.labels) : can(regex("^[a-z0-9_-]{0,63}$", v))])
    error_message = "Label values must match ^[a-z0-9_-]{0,63}$ (lowercase only: use ti-001, not TI-001)."
  }
}

variable "bucket_force_destroy" {
  description = "Allow Terraform to delete the state bucket even if it has objects. Keep false outside a throwaway sandbox."
  type        = bool
  default     = false
}

variable "bucket_tfstate_kms_force_destroy" {
  description = "Allow Terraform to destroy the KMS key that encrypts the state bucket. Keep false outside a throwaway sandbox."
  type        = bool
  default     = false
}

variable "folder_deletion_protection" {
  description = "Prevent Terraform from destroying the bootstrap folder."
  type        = bool
  default     = true
}

variable "project_deletion_policy" {
  description = "Deletion policy for the bootstrap projects (PREVENT or DELETE)."
  type        = string
  default     = "PREVENT"
}
