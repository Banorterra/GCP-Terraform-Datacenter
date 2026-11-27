# Stage 3 (envs/<env>) variables. Shared ones (org_id, billing_account, environment, regions, labels, state_bucket)
# come from variables_common.tf. The CIDRs come from cidr_plan in 3-networks/shared, so they are not repeated here.

variable "project_prefix" {
  description = "Short company prefix used in names. Must match stages 0-2."
  type        = string
  default     = "bnt"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,2}$", var.project_prefix))
    error_message = "project_prefix must be 2-3 lowercase letters/digits and start with a letter."
  }
}

variable "secondary_ranges" {
  description = "Secondary ranges of the subnet (GKE pods and services, stage 5). Must sit inside cidr_plan.<env>.block."
  type        = map(string)
  default     = {}
}

variable "flow_logs_sampling" {
  description = "Fraction of VPC flow logs sampled (spec: 50%)."
  type        = number
  default     = 0.5
}

variable "ncc_spoke_group" {
  description = "NCC group of the spoke. null = the STAR hub's edge group (output ncc_edge_group of 3-networks/shared)."
  type        = string
  default     = null
}

variable "enable_gate_vm" {
  description = "Create the Sprint 4 gate VM in this environment (spec: a prod VM reaches on-prem by private IP and resolves its DNS). Turn on for the test, then off."
  type        = bool
  default     = false
}
