variable "project_id" {
  description = "Project that holds the key ring (the security project)."
  type        = string
}

variable "location" {
  description = "Region of the key ring, for example northamerica-south1. A CMEK key must be in the same region as the data it protects."
  type        = string

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.location))
    error_message = "location must be a single region such as northamerica-south1 (no multi-regions or global)."
  }
}

variable "keyring_name" {
  description = "Name of the key ring. Key rings and keys can never be deleted in GCP, so a name can be used only once per project and location."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,63}$", var.keyring_name))
    error_message = "keyring_name must be 1-63 letters, digits, '_' or '-'."
  }
}

variable "keys" {
  description = "Keys to create in the ring, by name. Each one may override the rotation period. Purpose is always ENCRYPT_DECRYPT (symmetric, what CMEK uses)."
  type = map(object({
    rotation_period = optional(string)
  }))

  validation {
    condition     = length(var.keys) > 0 && alltrue([for k in keys(var.keys) : can(regex("^[a-zA-Z0-9_-]{1,63}$", k))])
    error_message = "keys needs at least one entry, and key names must be 1-63 letters, digits, '_' or '-'."
  }
}

variable "rotation_period" {
  description = "Default automatic rotation period, in seconds with an 's' suffix. Spec: every 90 days (7776000s) at most."
  type        = string
  default     = "7776000s"

  validation {
    condition     = can(regex("^[0-9]+s$", var.rotation_period)) && try(tonumber(trimsuffix(var.rotation_period, "s")) >= 86400 && tonumber(trimsuffix(var.rotation_period, "s")) <= 7776000, false)
    error_message = "rotation_period must be between 86400s (1 day, the GCP minimum) and 7776000s (90 days, the spec maximum)."
  }
}

variable "protection_level" {
  description = "SOFTWARE (0.06 USD per key version per month) or HSM (about 1-2.50 USD per version per month)."
  type        = string
  default     = "SOFTWARE"

  validation {
    condition     = contains(["SOFTWARE", "HSM"], var.protection_level)
    error_message = "protection_level must be SOFTWARE or HSM."
  }
}

variable "destroy_scheduled_duration" {
  description = "How long a key version stays in DESTROY_SCHEDULED before it is gone for good (and stops being billed). 1 day is the minimum."
  type        = string
  default     = "86400s"

  validation {
    condition     = can(regex("^[0-9]+s$", var.destroy_scheduled_duration)) && try(tonumber(trimsuffix(var.destroy_scheduled_duration, "s")) >= 86400 && tonumber(trimsuffix(var.destroy_scheduled_duration, "s")) <= 10368000, false)
    error_message = "destroy_scheduled_duration must be between 86400s (1 day) and 10368000s (120 days)."
  }
}

variable "labels" {
  description = "Labels for every key. Add the key's own app label here; the provider's default_labels add the rest."
  type        = map(string)
  default     = {}
}

variable "encrypters_decrypters" {
  description = "Members that may encrypt and decrypt with each key (roles/cloudkms.cryptoKeyEncrypterDecrypter), by key name. Usually service agents, for example service-<number>@gs-project-accounts.iam.gserviceaccount.com."
  type        = map(list(string))
  default     = {}

  validation {
    condition     = alltrue([for k in keys(var.encrypters_decrypters) : contains(keys(var.keys), k)])
    error_message = "Every key in encrypters_decrypters must also be in keys."
  }
}

variable "keyring_viewers" {
  description = "Members that may see the key ring and its keys, not use them (roles/cloudkms.viewer). Use groups, not users."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for m in var.keyring_viewers : can(regex("^(group|serviceAccount|domain):", m))])
    error_message = "keyring_viewers takes group:, serviceAccount: or domain: members; the spec forbids granting individual users."
  }
}
