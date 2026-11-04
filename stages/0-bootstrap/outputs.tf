output "seed_project_id" {
  description = "Project that holds the state bucket and the stage service accounts."
  value       = module.seed_bootstrap.seed_project_id
}

output "cicd_project_id" {
  description = "Project that holds the Workload Identity pool used by GitHub Actions."
  value       = module.cicd.project_id
}

output "state_bucket" {
  description = "GCS bucket for Terraform state (pass it to every stage: terraform init -backend-config=bucket=...)."
  value       = module.seed_bootstrap.gcs_bucket_tfstate
}

output "wif_provider_name" {
  description = "Full resource name of the Workload Identity provider."
  value       = module.gh_oidc.provider_name
}

output "stage_service_accounts" {
  description = "Service account email per stage."
  value       = { for k, sa in google_service_account.stage : k => sa.email }
}

output "github_repository_variables" {
  description = "None of these are secrets. Create them as repository variables (Settings > Secrets and variables > Actions > Variables) before running the workflows."
  value = merge(
    {
      WIF_PROVIDER    = module.gh_oidc.provider_name
      TF_STATE_BUCKET = module.seed_bootstrap.gcs_bucket_tfstate
    },
    { for k, sa in google_service_account.stage : "TF_SA_${upper(k)}" => sa.email }
  )
}
