variable "project_id" {
  description = "Network host project of the environment (stage 1 net_host_project_ids), e.g. bnt-dev-net-host."
  type        = string
}

variable "env" {
  description = "Environment: dev, qa or prod. Goes into every name."
  type        = string

  validation {
    condition     = contains(["dev", "qa", "prod"], var.env)
    error_message = "env must be dev, qa or prod."
  }
}

variable "prefix" {
  description = "Company prefix used in names (bnt)."
  type        = string
}

variable "region" {
  description = "Region of the subnet, Cloud Router and Cloud NAT."
  type        = string
}

variable "subnet_cidr" {
  description = "Primary range of the environment subnet (cidr_plan.<env>.subnet_cidr)."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.subnet_cidr))
    error_message = "subnet_cidr must be an IPv4 CIDR, e.g. 10.10.0.0/24."
  }
}

variable "secondary_ranges" {
  description = "Secondary ranges of the subnet, by name (e.g. GKE pods and services for stage 5). Empty = none."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for c in values(var.secondary_ranges) : can(cidrnetmask(c))])
    error_message = "Every secondary range must be an IPv4 CIDR."
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

variable "ncc_hub_id" {
  description = "ID of the Network Connectivity Center hub (output ncc_hub_id of 3-networks/shared)."
  type        = string
}

variable "ncc_spoke_group" {
  description = <<-EOT
    NCC group of the spoke. With a STAR hub, set the hub's "edge" group so environments only reach the center
    (the hub VPC) and never each other. null = the hub's default group (MESH: spokes reach each other).
  EOT
  type        = string
  default     = null
}

variable "hub_network_id" {
  description = "ID of the hub VPC, the target of the DNS peering zones."
  type        = string
}

variable "dns_zone" {
  description = "Private zone of this environment, ending with a dot (e.g. dev.gcp.banorterra.internal.)."
  type        = string

  validation {
    condition     = endswith(var.dns_zone, ".")
    error_message = "dns_zone must end with a dot."
  }
}

variable "peered_dns_zones" {
  description = "Domains resolved by the hub VPC (its own zone and the on-prem forwarding zone), each ending with a dot."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for z in var.peered_dns_zones : endswith(z, ".")])
    error_message = "Every peered zone must end with a dot."
  }
}

variable "onprem_cidrs" {
  description = "On-prem ranges allowed in to VMs tagged allow-onprem (ICMP, 80, 443)."
  type        = list(string)
  default     = []
}

variable "iap_source_range" {
  description = "IAP TCP forwarding range (Google-fixed), allowed to SSH into VMs tagged ssh."
  type        = string
  default     = "35.235.240.0/20"
}

variable "psa_cidr" {
  description = "Range reserved for private services access (Cloud SQL, Filestore, Memorystore with private IP, used by stages 4 and 5). Must sit inside the environment block and clear of the subnet and secondary ranges. null = no private services access."
  type        = string
  default     = null

  validation {
    condition     = var.psa_cidr == null || can(cidrhost(var.psa_cidr, 0))
    error_message = "psa_cidr must be a CIDR range such as 10.20.160.0/20."
  }
}

variable "health_check_ranges" {
  description = "Google-fixed ranges of load balancer health checks and proxies, allowed in to every VM and GKE node (stage 5 load balancers)."
  type        = list(string)
  default     = ["35.191.0.0/16", "130.211.0.0/22"]
}

variable "labels" {
  description = "Labels for the resources that support them (DNS zones, NCC spoke)."
  type        = map(string)
  default     = {}
}

variable "enable_gate_vm" {
  description = "Create the Sprint 4 gate VM: a small VM that, at boot, resolves gate_target_host over DNS, pings it and fetches http://<host>/, and prints GATE: lines. Turn on for the test or the demo only."
  type        = bool
  default     = false
}

variable "gate_target_host" {
  description = "On-prem host the gate VM tests (e.g. host.banorterra.local). Required when enable_gate_vm is true."
  type        = string
  default     = ""
}

variable "gate_vm_machine_type" {
  description = "Machine type of the gate VM."
  type        = string
  default     = "e2-micro"
}
