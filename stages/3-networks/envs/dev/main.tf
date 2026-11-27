# Stage 3 (envs/<env>): the environment network, attached as a spoke to the hub of envs/shared. The dev, qa and
# prod roots are identical; the environment comes from TF_VAR_environment, set by the pipeline from the folder.
#
# Runs as sa-terraform-networks. Reads stage 1 (the net-host project of this environment) and 3-networks/shared
# (NCC hub, hub VPC, CIDR plan, DNS zones) via terraform_remote_state. Apply envs/shared first: without its state
# this root cannot plan.

data "terraform_remote_state" "org" {
  backend = "gcs"

  config = {
    bucket = var.state_bucket
    prefix = "1-org"
  }
}

data "terraform_remote_state" "shared" {
  backend = "gcs"

  config = {
    bucket = var.state_bucket
    prefix = "3-networks/shared"
  }
}

locals {
  org    = data.terraform_remote_state.org.outputs
  shared = data.terraform_remote_state.shared.outputs

  env       = var.environment
  cidr      = local.shared.cidr_plan[local.env]
  host_proj = local.org.net_host_project_ids[local.env]
}

module "spoke" {
  source = "../../../../modules/network-spoke"

  project_id         = local.host_proj
  env                = local.env
  prefix             = var.project_prefix
  region             = var.primary_region
  subnet_cidr        = local.cidr.subnet_cidr
  secondary_ranges   = var.secondary_ranges
  flow_logs_sampling = var.flow_logs_sampling

  hub_project_id  = local.shared.hub_project_id
  ncc_hub_id      = local.shared.ncc_hub_id
  ncc_spoke_group = coalesce(var.ncc_spoke_group, local.shared.ncc_edge_group)
  hub_network_id  = local.shared.hub_vpc_id

  dns_zone         = "${local.env}.${local.shared.hub_dns_zone}"
  peered_dns_zones = [local.shared.hub_dns_zone, local.shared.onprem_dns_zone]
  onprem_cidrs     = [local.shared.cidr_plan.onprem.block]

  enable_gate_vm   = var.enable_gate_vm
  gate_target_host = "host.${trimsuffix(local.shared.onprem_dns_zone, ".")}"

  labels = merge(var.labels, { env = local.env, managed_by = "terraform" })
}

check "environment_is_an_env" {
  assert {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "This root needs TF_VAR_environment = dev, qa or prod (the pipeline sets it from the folder name)."
  }
}
