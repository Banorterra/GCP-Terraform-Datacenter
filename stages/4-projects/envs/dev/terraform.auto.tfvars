# Non-secret values for stage 4 envs/dev, committed so GitHub Actions uses them.
# org_id, billing_account, state_bucket and environment (dev) come from the pipeline (TF_VAR_*).

project_prefix = "bnt"

# Seed project of stage 0 (output seed_project_id), home of the pipeline service accounts.
pipeline_sa_project_id = "bnt-b-seed-5d99"

labels = {
  owner       = "equipo6"
  cost_center = "ti-001"
}

# Jesús's account (ADR 0007). It has a free slot once c-logging is retired (ADR 0008, step 2).
app_billing_account = "012B54-FF8A43-91674F"

# One application project (bnt-dev-app-xxxx). Its APIs are the ones the stage 5 components use.
apps = {
  app = {
    apis = [
      "container.googleapis.com",           # GKE
      "sqladmin.googleapis.com",            # Cloud SQL
      "servicenetworking.googleapis.com",   # private IP for Cloud SQL, Filestore, Memorystore
      "storage.googleapis.com",             # Cloud Storage
      "file.googleapis.com",                # Filestore
      "redis.googleapis.com",               # Memorystore
      "backupdr.googleapis.com",            # Backup and DR Service
      "binaryauthorization.googleapis.com", # Binary Authorization for GKE
      "cloudkms.googleapis.com",            # CMEK
      "monitoring.googleapis.com",
      "logging.googleapis.com",
      "iam.googleapis.com",
    ]
    viewer_groups = ["grp-devops@banorterra.com"]
  }
}
