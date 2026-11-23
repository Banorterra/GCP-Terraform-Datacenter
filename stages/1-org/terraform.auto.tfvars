# Non-secret values for stage 1, committed so GitHub Actions uses them (terraform.tfvars is git-ignored).
# org_id, billing_account, state_bucket and environment come from the pipeline (TF_VAR_*), and the alert
# emails from the ALERT_EMAILS secret. Never put secrets or personal data here: the repository is public.

project_prefix = "bnt"

# Spec: every resource carries env, app, owner, cost_center and managed_by. env and managed_by are added by
# the provider, app by each resource. Values: lowercase letters, digits, '_' or '-'.
labels = {
  owner       = "equipo6"
  cost_center = "ti-001"
}

# Sandbox: Terraform can destroy folders and projects, and the audit bucket keeps logs for 1 day (locked).
folder_deletion_protection = false
project_deletion_policy    = "DELETE"
audit_log_retention_days   = 1
audit_log_retention_locked = true

# Budgets for the main billing account (USD): its free-trial credit, and a small one per project.
budget_total_amount           = 300
budget_project_monthly_amount = 10

# Free-trial billing accounts link at most 3 projects each (ADR 0007). Extra accounts from the team,
# with budgets in each account's currency, and which account pays for each project ("none" = no billing).
# extra_billing_accounts = {
#   jesus = { id = "012B54-FF8A43-91674F", currency = "MXN", budget_total = 5500, budget_project = 200 }
# }
# project_billing = {
#   "c-logging"  = "jesus"
#   "c-security" = "jesus"
#   "c-backup"   = "none"
# }
