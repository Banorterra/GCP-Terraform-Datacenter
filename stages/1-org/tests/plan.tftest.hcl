# Stage 1 plan test with mock providers. Runs with `terraform test` from stages/1-org.
# Verifies that the plan creates the expected folders, projects and org policies without
# touching the real org. Mocks google and google-beta so the module's data sources and
# provider blocks don't fail.

mock_provider "google" {}
mock_provider "google-beta" {}

# imports.tf adopts policies that already exist in the real org. Mock providers can't import,
# so these overrides stand in for the imported objects.
override_resource {
  target = google_org_policy_policy.boolean_enforce["iam.automaticIamGrantsForDefaultServiceAccounts"]
}

override_resource {
  target = google_org_policy_policy.boolean_enforce["iam.disableServiceAccountKeyUpload"]
}

override_resource {
  target = google_org_policy_policy.boolean_enforce["storage.uniformBucketLevelAccess"]
}

override_resource {
  target = google_org_policy_policy.allowed_policy_member_domains
}

variables {
  org_id          = "123456789012"
  billing_account = "ABCDEF-123456-7890AB"
  environment     = "shared"
  project_prefix  = "dc"
  state_bucket    = "mock-state-bucket"
  parent_folder   = ""
  labels = {
    owner       = "iac-team"
    cost_center = "ti-001"
  }
  folder_deletion_protection = false
  project_deletion_policy    = "DELETE"
  pipeline_sa_project_id     = "dc-b-seed-0000"
}

run "folders_and_projects" {
  command = plan

  assert {
    condition     = length(google_folder.env) == 4
    error_message = "Stage 1 must create exactly four folders: common, dev, qa, prod."
  }

  assert {
    condition = alltrue([
      for k in ["common", "dev", "qa", "prod"] : contains(keys(google_folder.env), k)
    ])
    error_message = "Folder names must be common, dev, qa, prod."
  }

  assert {
    condition     = length(module.common_projects) == 4
    error_message = "Common folder must have four projects: net-hub, logging, security, backup."
  }

  assert {
    condition     = length(module.net_host_projects) == 3
    error_message = "Each env folder must have one network host project (3 total)."
  }
}

run "org_policies" {
  command = plan

  assert {
    condition     = contains(keys(google_org_policy_policy.boolean_enforce), "iam.disableServiceAccountKeyCreation")
    error_message = "Org policy must disable SA key creation."
  }

  assert {
    condition     = contains(keys(google_org_policy_policy.boolean_enforce), "iam.disableServiceAccountKeyUpload")
    error_message = "Org policy must disable SA key upload."
  }

  assert {
    condition     = google_org_policy_policy.vm_external_ip.spec[0].rules[0].deny_all == "TRUE"
    error_message = "Org policy must deny all external IPs on VMs."
  }

  assert {
    condition = alltrue([
      for v in google_org_policy_policy.resource_locations.spec[0].rules[0].values[0].allowed_values :
      contains(["in:northamerica-south1-locations", "in:us-south1-locations"], v)
    ])
    error_message = "Resource Locations policy must allow only primary and DR regions."
  }

  assert {
    condition     = contains(keys(google_org_policy_policy.boolean_enforce), "compute.requireShieldedVm")
    error_message = "Org policy must require Shielded VMs."
  }

  assert {
    condition     = length(google_org_policy_policy.allowed_policy_member_domains.spec[0].rules[0].values[0].allowed_values) == 2
    error_message = "Domain restricted sharing must allow only our customer ID and our organization principal set."
  }
}

run "budgets" {
  command = plan

  variables {
    alert_emails = ["equipo@example.com"]
    # Every project on the main account, whatever terraform.auto.tfvars assigns.
    extra_billing_accounts = {}
    project_billing        = {}
  }

  assert {
    condition     = google_billing_budget.total["main"].budget_filter[0].credit_types_treatment == "EXCLUDE_ALL_CREDITS"
    error_message = "The total budget must measure gross cost, or free-trial credits hide every alert."
  }

  assert {
    condition     = length(google_billing_budget.project) == 7
    error_message = "Every project created by stage 1 must have its own budget."
  }

  assert {
    condition     = length(google_monitoring_notification_channel.email) == 1
    error_message = "Each alert email must get a notification channel."
  }
}

run "multiple_billing_accounts" {
  command = plan

  variables {
    extra_billing_accounts = {
      jesus = { id = "111111-222222-333333", currency = "MXN", budget_total = 5500, budget_project = 200 }
    }
    project_billing = {
      "c-logging"   = "jesus"
      "c-backup"    = "none"
      "qa-net-host" = "none"
    }
  }

  assert {
    condition     = local.project_billing_account["c-logging"] == "111111-222222-333333"
    error_message = "A project assigned to an extra billing account must use that account."
  }

  assert {
    condition     = local.project_billing_account["c-backup"] == "" && local.project_billing_account["c-net-hub"] == "ABCDEF-123456-7890AB"
    error_message = "\"none\" must leave the project without billing; unlisted projects use the main account."
  }

  assert {
    condition     = length(google_billing_budget.total) == 2 && google_billing_budget.total["jesus"].amount[0].specified_amount[0].currency_code == "MXN"
    error_message = "Every billing account must get its own total budget in its own currency."
  }

  assert {
    condition     = length(google_billing_budget.project) == 5 && !contains(keys(google_billing_budget.project), "c-backup")
    error_message = "Only projects with billing get a project budget."
  }

  assert {
    condition     = google_billing_budget.project["c-logging"].billing_account == "111111-222222-333333"
    error_message = "A project budget must live on the account that pays for the project."
  }
}

run "sinks_and_notifications" {
  command = plan

  assert {
    condition     = google_logging_organization_sink.audit.include_children == true
    error_message = "Audit sink must include children (org-wide)."
  }

  assert {
    condition     = google_storage_bucket.audit_logs.retention_policy[0].retention_period >= 24 * 3600
    error_message = "Audit bucket must retain at least 1 day."
  }

  assert {
    condition     = google_storage_bucket.audit_logs.retention_policy[0].is_locked == true
    error_message = "Audit bucket retention must be locked by default (spec: locked retention)."
  }

  assert {
    condition     = google_scc_v2_organization_notification_config.all_findings.organization == "123456789012"
    error_message = "SCC notification must target the org."
  }
}

run "stage_access" {
  command = plan

  assert {
    condition = alltrue([
      for r in ["roles/cloudkms.admin", "roles/secretmanager.admin"] :
      google_project_iam_member.stage_access["security/${r}"].member == "serviceAccount:sa-terraform-security@dc-b-seed-0000.iam.gserviceaccount.com"
    ])
    error_message = "The stage 2 SA must get KMS and Secret Manager admin on the security project."
  }

  assert {
    condition     = length(google_project_iam_member.stage_access) == 2
    error_message = "Stage 1 must grant later stages only the roles listed in stage_access.tf."
  }
}
