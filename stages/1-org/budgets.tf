# Billing budgets with alert thresholds. One Pub/Sub topic in the logging project receives every
# budget alert (50 / 90 / 100%); subscribe monitoring or an incident bot to it.
#
# Two budget groups:
#   - per common-folder project (small, fixed per-project amount)
#   - per environment folder (dev/qa/prod, larger per-env amount)
# Amounts come from variables with conservative sandbox defaults.

resource "google_pubsub_topic" "budget_alerts" {
  project = module.common_projects["logging"].project_id
  name    = "${var.project_prefix}-budget-alerts"
  labels  = merge(local.base_labels, { app = "budgets" })
}

locals {
  budget_thresholds = [0.5, 0.9, 1.0]
}

# One budget per common project.
resource "google_billing_budget" "common_project" {
  for_each = module.common_projects

  billing_account = var.billing_account
  display_name    = "${var.project_prefix}-c-${each.key}"

  budget_filter {
    projects = ["projects/${each.value.project_number}"]
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency
      units         = tostring(var.budget_common_project_monthly_amount)
    }
  }

  dynamic "threshold_rules" {
    for_each = local.budget_thresholds
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  all_updates_rule {
    pubsub_topic                   = google_pubsub_topic.budget_alerts.id
    schema_version                 = "1.0"
    disable_default_iam_recipients = false
  }
}

# One budget per environment folder (dev/qa/prod). Covers every project that stage 4 will create
# in that folder plus the network host project created above.
resource "google_billing_budget" "env_folder" {
  for_each = local.env_folders

  billing_account = var.billing_account
  display_name    = "${var.project_prefix}-${each.value}-folder"

  budget_filter {
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
    labels = {
      env = each.value
    }
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency
      units         = tostring(lookup(var.budget_env_monthly_amount, each.value, 1000))
    }
  }

  dynamic "threshold_rules" {
    for_each = local.budget_thresholds
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  all_updates_rule {
    pubsub_topic                   = google_pubsub_topic.budget_alerts.id
    schema_version                 = "1.0"
    disable_default_iam_recipients = false
  }
}
