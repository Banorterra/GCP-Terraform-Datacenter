# Stage 3 (envs/shared) variables. Shared ones (org_id, billing_account, environment, regions, labels,
# state_bucket) come from variables_common.tf.

variable "project_prefix" {
  description = "Short company prefix used in project IDs. Must match stages 0-2."
  type        = string
  default     = "bnt"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,2}$", var.project_prefix))
    error_message = "project_prefix must be 2-3 lowercase letters/digits and start with a letter."
  }
}

variable "cidr_plan" {
  description = <<-EOT
    IP ranges for the hub, on-prem simulation and the three spokes. Sandbox defaults do not overlap.
    Replace with the client's signed plan once it exists (spec: "el plan de IP firmado del cliente").
    Each entry gives the whole block (routing/BGP) and the primary subnet CIDR used by the VPC.
  EOT
  type = object({
    hub = object({
      block        = string
      subnet_cidr  = string
      router_asn   = number
      vpn_bgp_peer = string # /30 link-local range for BGP (GCP side gets .1, onprem side .2)
    })
    onprem = object({
      block        = string
      subnet_cidr  = string
      router_asn   = number
      vpn_bgp_peer = string
    })
    dev  = object({ block = string, subnet_cidr = string })
    qa   = object({ block = string, subnet_cidr = string })
    prod = object({ block = string, subnet_cidr = string })
  })
  default = {
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
}

variable "flow_logs_sampling" {
  description = "Fraction of VPC flow logs sampled (spec: 50%)."
  type        = number
  default     = 0.5

  validation {
    condition     = var.flow_logs_sampling > 0 && var.flow_logs_sampling <= 1
    error_message = "flow_logs_sampling must be in (0, 1]."
  }
}

variable "onprem_vm_machine_type" {
  description = "Machine type for the simulated on-prem VM. e2-micro is the smallest option to keep cost near zero."
  type        = string
  default     = "e2-micro"
}

variable "onprem_dns_zone" {
  description = "Private DNS zone that simulates the client's internal domain (served from the on-prem VPC). Must end with a dot."
  type        = string
  default     = "banorterra.local."
}

variable "hub_dns_zone" {
  description = "Private DNS zone for GCP-internal names (served from the hub). Must end with a dot."
  type        = string
  default     = "gcp.banorterra.internal."
}

variable "iap_source_range" {
  description = "IAP TCP forwarding source range. Google-fixed."
  type        = string
  default     = "35.235.240.0/20"
}

variable "pipeline_sa_project_id" {
  description = "Seed project of stage 0, home of the pipeline service accounts."
  type        = string
}
