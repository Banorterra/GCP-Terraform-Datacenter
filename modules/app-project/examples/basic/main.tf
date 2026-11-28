# Minimal use of modules/app-project: a dev application project with GKE, attached to the dev Shared VPC.
# Run from this folder with `terraform init && terraform plan` and the variables below.

terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

variable "folder_id" {
  description = "Folder of the environment, folders/<number>."
  type        = string
}

variable "billing_account" {
  description = "Billing account that pays for the project."
  type        = string
}

variable "subnet_self_link" {
  description = "Shared VPC subnet the project may use."
  type        = string
}

module "app_project" {
  source = "../.."

  name             = "ex-dev-app"
  folder_id        = var.folder_id
  billing_account  = var.billing_account
  labels           = { env = "dev", app = "app", owner = "equipo6", cost_center = "ti-001", managed_by = "terraform" }
  apis             = ["container.googleapis.com", "storage.googleapis.com"]
  host_project_id  = "ex-dev-net-host"
  subnet_self_link = var.subnet_self_link
  workloads_sa     = "sa-terraform-workloads@ex-seed.iam.gserviceaccount.com"
  viewer_groups    = ["grp-devops@example.com"]
}

output "project_id" {
  description = "ID of the new project."
  value       = module.app_project.project_id
}
