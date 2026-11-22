# Stage 1 variables. Shared ones (org_id, billing_account, environment, regions, labels,
# state_bucket) come from variables_common.tf (copied from stages/_shared/).

variable "project_prefix" {
  description = "Short company prefix used in project IDs (spec naming: <empresa>-<entorno>-<dominio>-<recurso>). Must match stage 0's project_prefix."
  type        = string
  default     = "dc"

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

variable "folder_deletion_protection" {
  description = "Prevent Terraform from destroying the top-level folders (common/dev/qa/prod)."
  type        = bool
  default     = true
}

variable "project_deletion_policy" {
  description = "Deletion policy for projects created here (PREVENT or DELETE)."
  type        = string
  default     = "PREVENT"
}

variable "audit_log_retention_days" {
  description = "Retention, in days, of the audit log bucket."
  type        = number
  default     = 400

  validation {
    condition     = var.audit_log_retention_days >= 30
    error_message = "audit_log_retention_days must be at least 30."
  }
}

variable "audit_log_retention_locked" {
  description = "Lock the retention policy on the audit log bucket. Locking is IRREVERSIBLE. Keep false in sandbox; set true before prod cutover."
  type        = bool
  default     = false
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

variable "org_policy_dry_run" {
  description = "Reserved for a future toggle: stage org policies in dry-run before enforcement. Not wired yet; left here so tfvars stay stable."
  type        = bool
  default     = false
}

variable "budget_currency" {
  description = "ISO 4217 currency code for budgets. Must match the billing account's currency."
  type        = string
  default     = "USD"
}

variable "budget_common_project_monthly_amount" {
  description = "Monthly budget cap, in whole currency units, for each common-folder project (net-hub, logging, security, backup)."
  type        = number
  default     = 100
}

variable "budget_env_monthly_amount" {
  description = "Monthly budget cap per environment folder, in whole currency units."
  type        = map(number)
  default = {
    dev  = 300
    qa   = 500
    prod = 2000
  }
}
