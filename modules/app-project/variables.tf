variable "name" {
  description = "Display name of the project, <prefix>-<env>-<app> (for example bnt-dev-app). The project ID adds a random 4-character suffix."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{3,24}[a-z0-9]$", var.name))
    error_message = "name must be 5-26 lowercase letters, digits or '-' (the 5-character suffix brings the ID to 30 at most)."
  }
}

variable "folder_id" {
  description = "Folder of the environment, as folders/<number> (output folder_ids of stage 1)."
  type        = string

  validation {
    condition     = can(regex("^folders/[0-9]+$", var.folder_id))
    error_message = "folder_id must look like folders/123456789."
  }
}

variable "billing_account" {
  description = "Billing account that pays for the project, format XXXXXX-XXXXXX-XXXXXX. The stage 4 service account needs Billing Account User on it."
  type        = string

  validation {
    condition     = can(regex("^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$", var.billing_account))
    error_message = "billing_account must look like 01ABCD-23EF45-6789AB."
  }
}

variable "labels" {
  description = "Labels of the project (the spec's mandatory ones: env, app, owner, cost_center, managed_by)."
  type        = map(string)
  default     = {}
}

variable "apis" {
  description = "APIs to enable in the project. compute.googleapis.com is always added (Shared VPC needs it)."
  type        = list(string)
  default     = []
}

variable "deletion_policy" {
  description = "PREVENT, DELETE or ABANDON. DELETE in the sandbox so the stage can be destroyed."
  type        = string
  default     = "DELETE"

  validation {
    condition     = contains(["PREVENT", "DELETE", "ABANDON"], var.deletion_policy)
    error_message = "deletion_policy must be PREVENT, DELETE or ABANDON."
  }
}

variable "host_project_id" {
  description = "Shared VPC host project of the environment (output host_project_id of 3-networks/<env>)."
  type        = string
}

variable "subnet_self_link" {
  description = "Subnet of the Shared VPC the project may use (output subnet_self_link of 3-networks/<env>)."
  type        = string

  validation {
    condition     = can(regex("projects/[^/]+/regions/[^/]+/subnetworks/[^/]+$", var.subnet_self_link))
    error_message = "subnet_self_link must end in projects/<p>/regions/<r>/subnetworks/<name>."
  }
}

variable "workloads_sa" {
  description = "Email of the stage 5 service account (sa-terraform-workloads), which deploys into this project."
  type        = string
}

variable "workloads_roles" {
  description = "Roles of the stage 5 service account in this project. Only what the stage 5 components need."
  type        = list(string)
  default = [
    "roles/container.admin",
    "roles/compute.instanceAdmin.v1",
    "roles/compute.loadBalancerAdmin",
    "roles/compute.securityAdmin",
    "roles/cloudsql.admin",
    "roles/storage.admin",
    "roles/file.editor",
    "roles/redis.admin",
    "roles/backupdr.admin",
    "roles/binaryauthorization.policyEditor",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/resourcemanager.projectIamAdmin",
    "roles/monitoring.editor",
  ]
}

variable "viewer_groups" {
  description = "Groups that can see the project (spec: people read, the pipeline changes)."
  type        = list(string)
  default     = []
}

variable "cmek_keys" {
  description = "CMEK keys the project's service agents may use, by purpose: storage, sql or gke (outputs kms_key_ids of stage 2). Each purpose gets its own service agents."
  type        = map(list(string))
  default     = {}

  validation {
    condition     = alltrue([for k in keys(var.cmek_keys) : contains(["storage", "sql", "gke"], k)])
    error_message = "cmek_keys keys must be storage, sql or gke."
  }
}

variable "grant_gke_firewall_admin" {
  description = "Let the GKE service agent manage firewall rules in the host project (needed for GKE load balancer health checks in a Shared VPC)."
  type        = bool
  default     = true
}

variable "vpc_sc_perimeter_name" {
  description = "VPC-SC perimeter to put the project in (prod only), as accessPolicies/<n>/servicePerimeters/<name>. null = no perimeter."
  type        = string
  default     = null
}

variable "vpc_sc_enforced" {
  description = "true adds the project to the enforced config of the perimeter too, not only the dry-run one (output vpc_sc_enforced of stage 2)."
  type        = bool
  default     = false
}
