# Stage 2 plan test with mock providers: `terraform test` from stages/2-security.
# The stage 1 outputs are faked with override_data, so nothing touches GCP or the state bucket.

mock_provider "google" {}
mock_provider "google-beta" {}

override_data {
  target = data.terraform_remote_state.org
  values = {
    outputs = {
      common_project_ids       = { security = "dc-c-security", logging = "dc-c-logging", net-hub = "dc-c-net-hub", backup = "dc-c-backup" }
      net_host_project_numbers = { dev = "111", qa = "222", prod = "333" }
    }
  }
}

variables {
  org_id                 = "123456789012"
  billing_account        = "ABCDEF-123456-7890AB"
  environment            = "shared"
  state_bucket           = "mock-state-bucket"
  project_prefix         = "dc"
  pipeline_sa_project_id = "dc-b-seed-0000"
  security_reader_groups = ["grp-seguridad@example.com"]
  labels = {
    owner       = "iac-team"
    cost_center = "ti-001"
  }
}

run "kms_in_both_regions" {
  command = plan

  assert {
    condition     = length(module.kms) == 2
    error_message = "There must be one key ring in the primary region and one in the DR region."
  }

  assert {
    condition     = alltrue([for m in module.kms : length(m.key_ids) == 3])
    error_message = "Each ring must hold the storage, sql and gke keys."
  }
}

run "secrets_never_in_plain_text" {
  command = plan

  assert {
    condition     = alltrue([for v in google_secret_manager_secret_version.this : v.secret_data == null])
    error_message = "Secret values must go through secret_data_wo (write-only), never secret_data."
  }

  assert {
    condition     = google_secret_manager_secret_iam_member.accessor["vpn-psk-onprem/networks"].member == "serviceAccount:sa-terraform-networks@dc-b-seed-0000.iam.gserviceaccount.com"
    error_message = "Only the networks pipeline SA may read the VPN pre-shared key."
  }

  assert {
    condition     = length(google_secret_manager_secret_iam_member.accessor) == 2
    error_message = "Each secret must have exactly one reader stage by default."
  }

  assert {
    condition     = alltrue([for m in google_secret_manager_secret_iam_member.viewer : m.role == "roles/secretmanager.viewer"])
    error_message = "Groups may see secret metadata only, never the value."
  }
}

run "perimeter_dry_run_by_default" {
  command = plan

  assert {
    condition     = length(google_access_context_manager_service_perimeter.prod.status) == 0
    error_message = "The perimeter must not be enforced by default."
  }

  assert {
    condition     = google_access_context_manager_service_perimeter_dry_run_resource.prod["prod-net-host"].resource == "projects/333"
    error_message = "The prod network host project must be in the dry-run perimeter."
  }

  assert {
    condition     = length(google_access_context_manager_service_perimeter_resource.prod) == 0
    error_message = "No project may be in the enforced perimeter while dry-run."
  }

  assert {
    condition     = length(google_access_context_manager_access_policy.org) == 1
    error_message = "With no access_policy_id the stage creates the org access policy."
  }
}

run "perimeter_enforced" {
  command = plan

  variables {
    vpc_sc_enforce   = true
    access_policy_id = "987654321"
  }

  assert {
    condition     = length(google_access_context_manager_service_perimeter.prod.status) == 1
    error_message = "vpc_sc_enforce = true must set the enforced config."
  }

  assert {
    condition     = length(google_access_context_manager_access_policy.org) == 0
    error_message = "An existing access policy must be reused, not created."
  }
}
