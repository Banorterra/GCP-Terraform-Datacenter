# Stage 1 variables. Shared ones (org_id, billing_account, environment, regions, labels,
# state_bucket) come from variables_common.tf (copied from stages/_shared/).

variable "project_prefix" {
  description = "Short company prefix used in project IDs (spec naming: <empresa>-<entorno>-<dominio>-<recurso>). Must match stage 0's project_prefix."
  type        = string
  default     = "bnt"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,2}$", var.project_prefix))
    error_message = "project_prefix must be 2-3 lowercase letters/digits and start with a letter."
  }
}

variable "parent_folder" {
  description = "Optional numeric folder ID. Must match stage 0's parent_folder: when non-empty the folders created here hang off that folder, otherwise off the organization root."
  type        = string
  default     = ""
}

# Sandbox defaults: the team must be able to run terraform destroy. Flip both for a real production org.
variable "folder_deletion_protection" {
  description = "Prevent Terraform from destroying the top-level folders (common/dev/qa/prod). false in the sandbox so terraform destroy works."
  type        = bool
  default     = false
}

variable "project_deletion_policy" {
  description = "Deletion policy for projects created here (PREVENT or DELETE). DELETE in the sandbox so terraform destroy works."
  type        = string
  default     = "DELETE"

  validation {
    condition     = contains(["PREVENT", "DELETE", "ABANDON"], var.project_deletion_policy)
    error_message = "project_deletion_policy must be PREVENT, DELETE or ABANDON."
  }
}

variable "audit_log_retention_days" {
  description = "Retention, in days, of the audit log bucket. 1 in the sandbox: the lock is real but objects can be deleted a day later. A production org would use 365 or more."
  type        = number
  default     = 1

  validation {
    condition     = var.audit_log_retention_days >= 1
    error_message = "audit_log_retention_days must be at least 1."
  }
}

variable "audit_log_retention_locked" {
  description = "Lock the retention policy on the audit log bucket (spec: locked retention). Locking is IRREVERSIBLE: the period can never be shortened, and GCS puts a lien on the logging project until the bucket is deleted."
  type        = bool
  default     = true
}

variable "audit_log_filter" {
  description = "Log filter for the organization-level audit sink. Defaults to Admin Activity and Data Access, plus System Event."
  type        = string
  default     = <<-EOT
    logName:"logs/cloudaudit.googleapis.com%2Factivity" OR
    logName:"logs/cloudaudit.googleapis.com%2Fdata_access" OR
    logName:"logs/cloudaudit.googleapis.com%2Fsystem_event"
  EOT
}

variable "scc_notification_filter" {
  description = "SCC findings filter. Default: all ACTIVE findings on create."
  type        = string
  default     = "state = \"ACTIVE\""
}

variable "budget_currency" {
  description = "ISO 4217 currency code for budgets. Must match the billing account's currency."
  type        = string
  default     = "USD"
}

variable "budget_total_amount" {
  description = "Budget for the whole billing account, in whole currency units. Matches the team's free-trial credit."
  type        = number
  default     = 300
}

variable "budget_project_monthly_amount" {
  description = "Monthly budget, in whole currency units, for each project this stage creates."
  type        = number
  default     = 10
}

variable "alert_emails" {
  description = "Emails that receive budget alerts and Google's essential notifications. Pass it from the ALERT_EMAILS GitHub secret (JSON list); it is sensitive so it never shows in plans or PR comments."
  type        = list(string)
  default     = []
  sensitive   = true

  validation {
    condition     = alltrue([for e in var.alert_emails : can(regex("^[^@ ]+@[^@ ]+[.][^@ ]+$", e))])
    error_message = "Every alert_emails entry must be an email address."
  }
}
