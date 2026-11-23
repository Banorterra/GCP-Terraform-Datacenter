# Which billing account each project uses.
#
# Free-trial billing accounts can only link 3 projects each, so the team spreads the projects over the
# members' accounts (var.extra_billing_accounts) and leaves the ones that only need free APIs without
# billing (var.project_billing = "none"). See ADR 0007.

locals {
  # Every billing account this stage can use, by alias. "main" is the pipeline's TF_VAR_billing_account.
  billing_accounts = merge(
    {
      main = {
        id             = var.billing_account
        currency       = var.budget_currency
        budget_total   = var.budget_total_amount
        budget_project = var.budget_project_monthly_amount
      }
    },
    var.extra_billing_accounts,
  )

  project_keys = concat(
    [for k in keys(local.common_projects) : "c-${k}"],
    [for e in local.env_folders : "${e}-net-host"],
  )

  # Alias per project ("none" = no billing).
  project_billing_alias = { for k in local.project_keys : k => lookup(var.project_billing, k, "main") }

  # Billing account ID per project; "" leaves the project without billing.
  project_billing_account = {
    for k, alias in local.project_billing_alias : k => alias == "none" ? "" : local.billing_accounts[alias].id
  }

  # APIs Google lets a project enable without billing.
  free_apis = [
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "iam.googleapis.com",
    "serviceusage.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ]
}

check "project_billing_aliases" {
  assert {
    condition = alltrue([
      for k, alias in var.project_billing : contains(local.project_keys, k) && (alias == "none" || contains(keys(local.billing_accounts), alias))
    ])
    error_message = "var.project_billing has an unknown project key or billing alias."
  }
}
