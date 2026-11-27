# Non-secret values for stage 3 envs/qa, committed so GitHub Actions uses them.
# org_id, billing_account, state_bucket and environment (qa) come from the pipeline (TF_VAR_*).
# The subnet CIDR comes from cidr_plan.qa in 3-networks/shared (sandbox plan, block 10.30.0.0/16).

project_prefix = "bnt"

labels = {
  owner       = "equipo6"
  cost_center = "ti-001"
}

# For GKE in stage 5, inside 10.30.0.0/16 and clear of the primary subnet 10.30.0.0/24.
secondary_ranges = {
  pods     = "10.30.64.0/18"
  services = "10.30.128.0/20"
}
