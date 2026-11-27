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
    # random_id / random_password (stage 2 uses the ephemeral random_password for secrets).
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}
