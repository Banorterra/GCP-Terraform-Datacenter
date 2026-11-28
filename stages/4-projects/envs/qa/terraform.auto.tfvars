# Non-secret values for stage 4 envs/qa, committed so GitHub Actions uses them.
# org_id, billing_account, state_bucket and environment (qa) come from the pipeline (TF_VAR_*).

project_prefix = "bnt"

# Seed project of stage 0 (output seed_project_id), home of the pipeline service accounts.
pipeline_sa_project_id = "bnt-b-seed-5d99"

labels = {
  owner       = "equipo6"
  cost_center = "ti-001"
}

# TODO: Hervey's billing account (ADR 0007), not created yet. null = the main account, which has no free slot,
# so the apply fails until this is set.
app_billing_account = null

# One application project (bnt-qa-app-xxxx). Its APIs are the ones the stage 5 components use.
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
