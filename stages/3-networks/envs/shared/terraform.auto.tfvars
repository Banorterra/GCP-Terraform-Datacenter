# Non-secret values for stage 3 envs/shared, committed so GitHub Actions uses them.
# org_id, billing_account, state_bucket and environment come from the pipeline (TF_VAR_*).

project_prefix         = "bnt"
pipeline_sa_project_id = "bnt-b-seed-5d99"

labels = {
  owner       = "equipo6"
  cost_center = "ti-001"
}

# IP plan from the team's diagrams (hub 10.0.0.0/22, prod 10.10/16, dev 10.20/16, qa 10.30/16, on-prem
# 172.16.0.0/16). Not the client's signed plan yet. Keep in sync with the spoke roots and policies/network.rego.
cidr_plan = {
  hub = {
    block        = "10.0.0.0/22"
    subnet_cidr  = "10.0.0.0/24"
    router_asn   = 64512
    vpn_bgp_peer = "169.254.10.0/30"
  }
  onprem = {
    block        = "172.16.0.0/16"
    subnet_cidr  = "172.16.1.0/24"
    router_asn   = 64513
    vpn_bgp_peer = "169.254.10.0/30"
  }
  dev  = { block = "10.20.0.0/16", subnet_cidr = "10.20.0.0/24" }
  qa   = { block = "10.30.0.0/16", subnet_cidr = "10.30.0.0/24" }
  prod = { block = "10.10.0.0/16", subnet_cidr = "10.10.0.0/24" }
}
