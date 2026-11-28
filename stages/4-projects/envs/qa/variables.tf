# Stage 4 (envs/<env>) variables. Shared ones (org_id, billing_account, environment, regions, labels, state_bucket)
# come from variables_common.tf.

variable "project_prefix" {
  description = "Short company prefix used in names. Must match stages 0-3."
  type        = string
  default     = "bnt"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,2}$", var.project_prefix))
    error_message = "project_prefix must be 2-3 lowercase letters/digits and start with a letter."
  }
}

variable "pipeline_sa_project_id" {
  description = "Seed project of stage 0 (output seed_project_id), home of the pipeline service accounts."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.pipeline_sa_project_id))
    error_message = "pipeline_sa_project_id must be a valid project ID (output seed_project_id of stage 0)."
  }
}

variable "app_billing_account" {
  description = "Billing account for the application projects of this environment. null = var.billing_account (the main account). Its owner grants sa-terraform-projects Billing Account User on it (ADR 0007)."
  type        = string
  default     = null
}

variable "apps" {
  description = "Application projects of this environment: name => APIs and viewer groups. Adding an application is one entry here and a PR."
  type = map(object({
    apis          = list(string)
    viewer_groups = optional(list(string), [])
  }))

  validation {
    condition     = alltrue([for k in keys(var.apps) : can(regex("^[a-z][a-z0-9-]{1,12}$", k))])
    error_message = "Application names must be 2-13 lowercase letters, digits or '-'."
  }
}

variable "grant_dr_keys" {
  description = "Also let the service agents use the CMEK keys in the DR region (us-south1)."
  type        = bool
  default     = true
}

variable "project_deletion_policy" {
  description = "Deletion policy for the projects (PREVENT or DELETE). DELETE in the sandbox so destroy.yml works."
  type        = string
  default     = "DELETE"
}
