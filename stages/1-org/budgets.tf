# Billing budgets. Each free-trial billing account has its own credit (300 USD), so:
#   - one budget per billing account (local.billing_accounts), the one that matters: it tracks how much
#     of that account's credit is gone;
#   - one small budget per project with billing, on the account that pays for it.
# Amounts and currency come from each account (budgets must use the account's currency).
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

  # Only projects with billing get a budget, on their own billing account.
  budgeted_projects = { for k, n in local.stage_projects : k => n if local.project_billing_alias[k] != "none" }
}

# One email notification channel per address. count (not for_each) because the list is sensitive;
# only its length is revealed.
# New name on purpose (ADR 0008): the channels move from c-logging to c-security. As a new resource,
# Terraform creates these first, switches the budgets to them and only then deletes the old
# "email" channels. A replacement in place would delete the old ones first.
resource "google_monitoring_notification_channel" "email_security" {
  count = nonsensitive(length(var.alert_emails))

  project      = module.common_projects["security"].project_id
  display_name = "${var.project_prefix}-alerts-${count.index}"
  type         = "email"

  labels = {
    email_address = var.alert_emails[count.index]
  }
}

moved {
  from = google_billing_budget.total
  to   = google_billing_budget.total["main"]
}

resource "google_billing_budget" "total" {
  for_each = local.billing_accounts

  billing_account = each.value.id
  display_name    = "${var.project_prefix}-billing-account-total-${each.key}"

  budget_filter {
    credit_types_treatment = "EXCLUDE_ALL_CREDITS"
  }

  amount {
    specified_amount {
      currency_code = each.value.currency
      units         = tostring(each.value.budget_total)
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
    monitoring_notification_channels = google_monitoring_notification_channel.email_security[*].id
    disable_default_iam_recipients   = false
  }
}

resource "google_billing_budget" "project" {
  for_each = local.budgeted_projects

  billing_account = local.billing_accounts[local.project_billing_alias[each.key]].id
  display_name    = "${var.project_prefix}-${each.key}"

  budget_filter {
    projects               = ["projects/${each.value}"]
    credit_types_treatment = "EXCLUDE_ALL_CREDITS"
  }

  amount {
    specified_amount {
      currency_code = local.billing_accounts[local.project_billing_alias[each.key]].currency
      units         = tostring(local.billing_accounts[local.project_billing_alias[each.key]].budget_project)
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
    monitoring_notification_channels = google_monitoring_notification_channel.email_security[*].id
    disable_default_iam_recipients   = false
  }
}
