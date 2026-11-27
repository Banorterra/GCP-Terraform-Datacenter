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
  description = "Log filter for the organization-level audit sink. Defaults to Admin Activity, Data Access, System Event and Policy Denied (VPC Service Controls violations, including dry-run, and org policy denials)."
  type        = string
  default     = <<-EOT
    logName:"logs/cloudaudit.googleapis.com%2Factivity" OR
    logName:"logs/cloudaudit.googleapis.com%2Fdata_access" OR
    logName:"logs/cloudaudit.googleapis.com%2Fsystem_event" OR
    logName:"logs/cloudaudit.googleapis.com%2Fpolicy"
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

variable "extra_billing_accounts" {
  description = <<-EOT
    More billing accounts, besides var.billing_account (key "main"), for the projects of this stage.
    Each free-trial billing account can only have 3 projects with billing, so the team spreads projects
    over several accounts. Key: short alias used in var.project_billing. currency must be the account's
    currency (budgets fail otherwise); budget_total and budget_project are in that currency.
  EOT
  type = map(object({
    id             = string
    currency       = string
    budget_total   = number
    budget_project = number
  }))
  default = {}

  validation {
    condition     = alltrue([for k, a in var.extra_billing_accounts : can(regex("^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$", a.id)) && !contains(["main", "none"], k)])
    error_message = "Each extra billing account needs an id like ABCDEF-123456-7890AB, and the aliases main and none are reserved."
  }
}

variable "project_billing" {
  description = <<-EOT
    Which billing account each project of this stage uses, by project key (c-net-hub, c-logging,
    c-security, c-backup, dev-net-host, qa-net-host, prod-net-host). Value: "main", an alias from
    var.extra_billing_accounts, or "none" for a project without billing (it can only use free APIs).
    Projects not listed use "main".
  EOT
  type        = map(string)
  default     = {}
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

variable "pipeline_sa_project_id" {
  description = "Project ID of stage 0's seed project, where the pipeline service accounts live (sa-terraform-<stage>@<this>.iam.gserviceaccount.com). Used to give later stages access to the projects created here."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.pipeline_sa_project_id))
    error_message = "pipeline_sa_project_id must be a valid project ID (output seed_project_id of stage 0)."
  }
}

variable "folder_viewer_groups" {
  description = "Groups (email, without the group: prefix) with read-only access (roles/viewer) to the common, dev, qa and prod folders and everything in them, and with read access to VPC Service Controls. Spec: humans read, the pipeline changes."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for g in var.folder_viewer_groups : can(regex("^[^@ :]+@[^@ ]+[.][^@ ]+$", g))])
    error_message = "Every folder_viewer_groups entry must be an email address without a prefix."
  }
}

variable "security_reader_groups" {
  description = "Groups (email, without the group: prefix) that list KMS keys and secrets in the security project (never secret values). Same groups as security_reader_groups in 2-security."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for g in var.security_reader_groups : can(regex("^[^@ :]+@[^@ ]+[.][^@ ]+$", g))])
    error_message = "Every security_reader_groups entry must be an email address without a prefix."
  }
}
