# Minimal use of modules/network-spoke: the dev network attached to an existing NCC hub. Run from this folder with
# `terraform init && terraform plan -var host_project_id=... -var ncc_hub_id=... -var hub_network_id=...`.

terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

variable "host_project_id" {
  description = "Network host project of dev."
  type        = string
}

variable "ncc_hub_id" {
  description = "ID of the NCC hub."
  type        = string
}

variable "hub_network_id" {
  description = "ID of the hub VPC."
  type        = string
}

module "spoke" {
  source = "../.."

  project_id       = var.host_project_id
  env              = "dev"
  prefix           = "ex"
  region           = "northamerica-south1"
  subnet_cidr      = "10.10.0.0/24"
  ncc_hub_id       = var.ncc_hub_id
  hub_network_id   = var.hub_network_id
  dns_zone         = "dev.example.internal."
  peered_dns_zones = ["example.internal.", "corp.example.local."]
  onprem_cidrs     = ["172.16.0.0/16"]
  labels           = { env = "dev" }
}

output "subnet_self_link" {
  description = "Subnet that stage 4 shares with the app projects."
  value       = module.spoke.subnet_self_link
}
