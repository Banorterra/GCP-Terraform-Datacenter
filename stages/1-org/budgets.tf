# Billing budgets. The team has a single free-trial credit (300 USD) for the whole project, so:
#   - one budget for the whole billing account, the one that matters: it tracks how much of the credit is gone;
#   - one small budget per project created here (the team's design: every project has a spending alert).
#
# credit_types_treatment = EXCLUDE_ALL_CREDITS: budgets measure gross cost. With INCLUDE_ALL_CREDITS (the
# default) the free-trial credit cancels the cost, the net stays at 0 and no alert would ever fire.
#
# Alerts go by email to var.alert_emails (Cloud Monitoring email channels) and to the billing account
# admins and users (default IAM recipients). Budgets only alert; they never stop resources. Billing data
# arrives a few hours late.

locals {
  # Every project this stage creates, by short name.
  stage_projects = merge(
    { for k, p in module.common_projects : "c-${k}" => p.project_number },
    { for k, p in module.net_host_projects : "${k}-net-host" => p.project_number },
  )
}

# One email notification channel per address. count (not for_each) because the list is sensitive;
# only its length is revealed.
resource "google_monitoring_notification_channel" "email" {
  count = nonsensitive(length(var.alert_emails))

  project      = module.common_projects["logging"].project_id
  display_name = "${var.project_prefix}-alerts-${count.index}"
  type         = "email"

  labels = {
    email_address = var.alert_emails[count.index]
  }
}

resource "google_billing_budget" "total" {
  billing_account = var.billing_account
  display_name    = "${var.project_prefix}-billing-account-total"

  budget_filter {
    credit_types_treatment = "EXCLUDE_ALL_CREDITS"
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency
      units         = tostring(var.budget_total_amount)
    }
  }

  dynamic "threshold_rules" {
    for_each = [0.1, 0.25, 0.5, 0.75, 0.9, 1.0]
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  all_updates_rule {
    monitoring_notification_channels = google_monitoring_notification_channel.email[*].id
    disable_default_iam_recipients   = false
  }
}

resource "google_billing_budget" "project" {
  for_each = local.stage_projects

  billing_account = var.billing_account
  display_name    = "${var.project_prefix}-${each.key}"

  budget_filter {
    projects               = ["projects/${each.value}"]
    credit_types_treatment = "EXCLUDE_ALL_CREDITS"
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency
      units         = tostring(var.budget_project_monthly_amount)
    }
  }

  dynamic "threshold_rules" {
    for_each = [0.5, 0.9, 1.0]
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  all_updates_rule {
    monitoring_notification_channels = google_monitoring_notification_channel.email[*].id
    disable_default_iam_recipients   = false
  }
}
