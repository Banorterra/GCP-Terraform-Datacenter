# Rename to backend.tf AFTER the first apply, then migrate the local state:
#   terraform init -migrate-state -backend-config="bucket=$(terraform output -raw state_bucket)"
terraform {
  backend "gcs" {
    # bucket is passed at init time so nothing here needs editing.
    prefix = "0-bootstrap"
  }
}
