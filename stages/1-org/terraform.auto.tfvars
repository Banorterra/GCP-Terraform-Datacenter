# Non-secret values for stage 1, committed so GitHub Actions uses them (terraform.tfvars is git-ignored).
# org_id, billing_account, state_bucket and environment come from the pipeline (TF_VAR_*), and the alert
# emails from the ALERT_EMAILS secret. Never put secrets or personal data here: the repository is public.

project_prefix = "bnt"

# Seed project of stage 0 (output seed_project_id), home of the pipeline service accounts.
pipeline_sa_project_id = "bnt-b-seed-5d99"

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

# Budgets (USD): the free-trial credit for the whole billing account, and a small one per project.
budget_total_amount           = 300
budget_project_monthly_amount = 10
