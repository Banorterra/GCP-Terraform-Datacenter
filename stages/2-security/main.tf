# Stage 2: security. Cloud KMS, Secret Manager and VPC Service Controls.
# Runs as sa-terraform-security. Its roles: Access Context Manager admin at the organization (stage 0,
# sa.tf) and Cloud KMS + Secret Manager admin on the security project (stage 1, stage_access.tf).
#
# Reads the outputs of stage 1 (prefix 1-org; read access from stage 0, state_read.tf).

data "terraform_remote_state" "org" {
  backend = "gcs"

  config = {
    bucket = var.state_bucket
    prefix = "1-org"
  }
}

locals {
  org = data.terraform_remote_state.org.outputs

  security_project_id = local.org.common_project_ids["security"]

  # The pipeline identities of the stages that consume what this stage creates.
  pipeline_sa = {
    for s in ["org", "security", "networks", "projects", "workloads"] :
    s => "sa-terraform-${s}@${var.pipeline_sa_project_id}.iam.gserviceaccount.com"
  }
  plan_sa = {
    for s in ["org", "security", "networks", "projects", "workloads"] :
    s => "sa-terraform-plan-${s}@${var.pipeline_sa_project_id}.iam.gserviceaccount.com"
  }

  base_labels = merge(var.labels, {
    env        = var.environment
    managed_by = "terraform"
  })
}
