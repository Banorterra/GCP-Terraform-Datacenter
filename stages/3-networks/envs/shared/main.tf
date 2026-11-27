# Stage 3 (envs/shared): the hub VPC, the simulated on-prem VPC with a Linux VM, the HA VPN that joins
# the two, the private DNS hub and the Network Connectivity Center hub that stages 3/{dev,qa,prod}
# attach their spokes to.
#
# Runs as sa-terraform-networks. Reads stage 1 (common_project_ids and folder IDs) and stage 2 (the
# VPN pre-shared key secret).

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

locals {
  org      = data.terraform_remote_state.org.outputs
  security = data.terraform_remote_state.security.outputs

  net_hub_project = local.org.common_project_ids["net-hub"]
  # The simulated on-prem network is a second VPC inside net-hub, not its own project: every free-trial
  # billing account links at most 3 projects (ADR 0007) and a separate project would use a slot.
  # Its VPC is still isolated: it only reaches the hub VPC through the HA VPN.
  onprem_sim_project = local.net_hub_project

  base_labels = merge(var.labels, {
    env        = var.environment
    managed_by = "terraform"
  })
}
