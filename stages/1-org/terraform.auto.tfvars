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

# Budgets for the main billing account (Adrián's free trial, in MXN): its credit (300 USD is about
# 5,500 MXN), and a small one per project (10 USD is about 200 MXN). The currency must match the account.
budget_currency               = "MXN"
budget_total_amount           = 5500
budget_project_monthly_amount = 200

# Free-trial billing accounts link at most 3 projects each (ADR 0007). Extra accounts from the team,
# with budgets in each account's currency, and which account pays for each project ("none" = no billing).
extra_billing_accounts = {
  # Jesús's free trial (personal account, MXN). 300 USD is about 5,500 MXN; 10 USD about 200 MXN.
  jesus = { id = "012B54-FF8A43-91674F", currency = "MXN", budget_total = 5500, budget_project = 200 }
}

# main (Adrián's account) already pays for seed, cicd and c-net-hub: it has no free slot left.
# qa and prod network hosts stay without billing until Hervey's account is added. There is no backup
# project: backups go to c-security, and c-logging is retired once its audit bucket can be deleted, which
# frees one slot (ADR 0008).
project_billing = {
  "c-logging"     = "jesus"
  "c-security"    = "jesus"
  "dev-net-host"  = "jesus"
  "qa-net-host"   = "none"
  "prod-net-host" = "none"
}

# Read-only access for people (spec: groups only, humans read and the pipeline changes).
folder_viewer_groups   = ["gcp-organization-admins@banorterra.com"]
security_reader_groups = ["grp-seguridad@banorterra.com"]
