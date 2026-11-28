# Unit tests for modules/app-project with mock providers: `terraform test` from modules/app-project.

mock_provider "google" {
  mock_resource "google_project" {
    defaults = {
      number = "123456789012"
    }
  }

  mock_data "google_storage_project_service_account" {
    defaults = {
      email_address = "service-123456789012@gs-project-accounts.iam.gserviceaccount.com"
    }
  }
}

mock_provider "google-beta" {
  mock_resource "google_project_service_identity" {
    defaults = {
      email = "service-123456789012@gcp-sa-cloud-sql.iam.gserviceaccount.com"
    }
  }
}

mock_provider "random" {
  mock_resource "random_id" {
    defaults = {
      hex = "a1b2"
    }
  }
}

variables {
  name             = "bnt-dev-app"
  folder_id        = "folders/727313186302"
  billing_account  = "012B54-FF8A43-91674F"
  host_project_id  = "bnt-dev-net-host"
  subnet_self_link = "https://www.googleapis.com/compute/v1/projects/bnt-dev-net-host/regions/northamerica-south1/subnetworks/bnt-dev-subnet"
  workloads_sa     = "sa-terraform-workloads@bnt-b-seed-5d99.iam.gserviceaccount.com"
  apis             = ["container.googleapis.com", "sqladmin.googleapis.com", "storage.googleapis.com"]
  viewer_groups    = ["grp-devops@banorterra.com"]
  cmek_keys = {
    storage = ["projects/bnt-c-security/locations/northamerica-south1/keyRings/kr/cryptoKeys/storage"]
    sql     = ["projects/bnt-c-security/locations/northamerica-south1/keyRings/kr/cryptoKeys/sql"]
    gke     = ["projects/bnt-c-security/locations/northamerica-south1/keyRings/kr/cryptoKeys/gke"]
  }
}

run "project_is_a_shared_vpc_service_project" {
  assert {
    condition     = google_project.this.project_id == "bnt-dev-app-a1b2"
    error_message = "The project ID must be the name plus the random suffix."
  }

  assert {
    condition     = google_compute_shared_vpc_service_project.this.host_project == "bnt-dev-net-host"
    error_message = "The project must be attached to the host project of its environment."
  }

  assert {
    condition     = google_project.this.auto_create_network == false
    error_message = "The project must not get a default network."
  }

  assert {
    condition     = contains(keys(google_project_service.this), "compute.googleapis.com")
    error_message = "Compute must always be on (Shared VPC needs it)."
  }
}

run "subnet_access_for_agents" {
  assert {
    condition     = google_compute_subnetwork_iam_member.network_user["gke"].subnetwork == "bnt-dev-subnet"
    error_message = "The subnet name must come from the self link."
  }

  assert {
    condition     = google_compute_subnetwork_iam_member.network_user["gke"].member == "serviceAccount:service-123456789012@container-engine-robot.iam.gserviceaccount.com"
    error_message = "The GKE agent must be Network User on the subnet."
  }

  assert {
    condition     = google_compute_subnetwork_iam_member.network_user["cloudservices"].region == "northamerica-south1"
    error_message = "The region must come from the self link."
  }

  assert {
    condition     = length(google_project_iam_member.gke_host_agent_user) == 1
    error_message = "With GKE on, its agent needs Host Service Agent User in the host project."
  }
}

run "cmek_grants_per_purpose" {
  assert {
    condition     = length(google_kms_crypto_key_iam_member.cmek) == 4
    error_message = "storage (1), sql (1) and gke (GKE + compute agents = 2) must give 4 grants."
  }

  assert {
    condition     = google_kms_crypto_key_iam_member.cmek["sql/0/0"].member == "serviceAccount:service-123456789012@gcp-sa-cloud-sql.iam.gserviceaccount.com"
    error_message = "The sql key must go to the Cloud SQL agent."
  }
}

run "no_perimeter_outside_prod" {
  assert {
    condition     = length(google_access_context_manager_service_perimeter_dry_run_resource.this) == 0
    error_message = "Without a perimeter name nothing is added to VPC-SC."
  }
}

run "prod_joins_the_dry_run_perimeter" {
  variables {
    vpc_sc_perimeter_name = "accessPolicies/689560098061/servicePerimeters/bnt_prod_perimeter"
  }

  assert {
    condition     = google_access_context_manager_service_perimeter_dry_run_resource.this[0].resource == "projects/123456789012"
    error_message = "The prod project must join the dry-run perimeter by number."
  }

  assert {
    condition     = length(google_access_context_manager_service_perimeter_resource.this) == 0
    error_message = "While the perimeter is dry-run, the project must not be in the enforced config."
  }
}

run "without_gke_or_sql" {
  variables {
    apis = ["storage.googleapis.com"]
  }

  assert {
    condition     = !contains(keys(google_compute_subnetwork_iam_member.network_user), "gke")
    error_message = "Without GKE its agent must not get the subnet."
  }

  assert {
    condition     = length(google_kms_crypto_key_iam_member.cmek) == 1
    error_message = "Without GKE or Cloud SQL only the storage key is granted."
  }
}

run "bad_billing_account_is_rejected" {
  command = plan

  variables {
    billing_account = "none"
  }

  expect_failures = [var.billing_account]
}
