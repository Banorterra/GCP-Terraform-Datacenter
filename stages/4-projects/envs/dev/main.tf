# Stage 4 (envs/<env>): the application projects of one environment, as Shared VPC service projects. The dev,
# qa and prod roots are identical; the environment comes from TF_VAR_environment, set by the pipeline from the
# folder name.
#
# Runs as sa-terraform-projects. Reads stage 1 (the folder of this environment), stage 2 (CMEK keys, VPC-SC
# perimeter) and 3-networks/<env> (host project and subnet) via terraform_remote_state. Apply the stage 3 root of
# the same environment first: without its state this root cannot plan.
#
# AWS analogy: stage 1 made the OUs, stage 3 made the VPC in the network account and shared its subnet. This
# stage creates the workload accounts, puts them in the OU and gives them the shared subnet, ready for stage 5.

data "terraform_remote_state" "org" {
  backend = "gcs"

  config = {
    bucket = var.state_bucket
    prefix = "1-org"
  }
}

data "terraform_remote_state" "security" {
  backend = "gcs"

  config = {
    bucket = var.state_bucket
    prefix = "2-security"
  }
}

data "terraform_remote_state" "network" {
  backend = "gcs"

  config = {
    bucket = var.state_bucket
    prefix = "3-networks/${var.environment}"
  }
}

locals {
  org      = data.terraform_remote_state.org.outputs
  security = data.terraform_remote_state.security.outputs
  network  = data.terraform_remote_state.network.outputs

  env          = var.environment
  workloads_sa = "sa-terraform-workloads@${var.pipeline_sa_project_id}.iam.gserviceaccount.com"

  # Primary-region keys always; the DR-region keys too, for the Cloud SQL replica and backups in us-south1.
  cmek_keys = {
    for purpose in ["storage", "sql", "gke"] : purpose => compact([
      local.security.kms_key_ids.primary[purpose],
      var.grant_dr_keys ? local.security.kms_key_ids.dr[purpose] : "",
    ])
  }
}

module "app_project" {
  source   = "../../../../modules/app-project"
  for_each = var.apps

  name            = "${var.project_prefix}-${local.env}-${each.key}"
  folder_id       = local.org.folder_ids[local.env]
  billing_account = coalesce(var.app_billing_account, var.billing_account)
  deletion_policy = var.project_deletion_policy
  labels          = merge(var.labels, { env = local.env, app = each.key, managed_by = "terraform" })
  apis            = each.value.apis

  host_project_id  = local.network.host_project_id
  subnet_self_link = local.network.subnet_self_link

  workloads_sa  = local.workloads_sa
  viewer_groups = each.value.viewer_groups
  cmek_keys     = local.cmek_keys

  # Only prod joins the VPC-SC perimeter (spec: the perimeter protects prod).
  vpc_sc_perimeter_name = local.env == "prod" ? local.security.vpc_sc_perimeter_name : null
  vpc_sc_enforced       = local.security.vpc_sc_enforced
}

check "environment_is_an_env" {
  assert {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "This root needs TF_VAR_environment = dev, qa or prod (the pipeline sets it from the folder name)."
  }
}
