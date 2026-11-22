# Stage 1 plan test with mock providers. Runs with `terraform test` from stages/1-org.
# Verifies that the plan creates the expected folders, projects and org policies without
# touching the real org. Mocks google and google-beta so the module's data sources and
# provider blocks don't fail.

mock_provider "google" {}
mock_provider "google-beta" {}

# Mock the data source that reads stage 0 state. The outputs we read here must exist, but
# their values don't matter for the plan graph.
override_data {
  target = data.terraform_remote_state.bootstrap
  values = {
    outputs = {
      seed_project_id = "mock-seed"
      state_bucket    = "mock-state-bucket"
    }
  }
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
  audit_log_retention_locked = false
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
}

run "sinks_and_notifications" {
  command = plan

  assert {
    condition     = google_logging_organization_sink.audit.include_children == true
    error_message = "Audit sink must include children (org-wide)."
  }

  assert {
    condition     = google_storage_bucket.audit_logs.retention_policy[0].retention_period >= 30 * 24 * 3600
    error_message = "Audit bucket must retain at least 30 days."
  }

  assert {
    condition     = google_scc_notification_config.all_findings.organization == "123456789012"
    error_message = "SCC notification must target the org."
  }
}
