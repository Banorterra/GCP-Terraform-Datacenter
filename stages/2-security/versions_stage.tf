# Extra requirement of this stage, on top of versions.tf (copied from stages/_shared, do not edit that one).
# Terraform 1.11+ for write-only attributes (secret_data_wo), used with the ephemeral random_password so that
# generated secrets never reach the plan or the state. The repo pins 1.17.0 in .terraform-version.
terraform {
  required_version = ">= 1.11"
}
