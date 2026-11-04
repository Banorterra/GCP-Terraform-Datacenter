# Stage 2: security

Reference: the example puts KMS and Secret Manager projects in `1-org` (shared) and `2-environments` (per environment),
and VPC Service Controls in `3-networks`. The spec groups them here. Runs as `sa-terraform-security`, state prefix `2-security`.

## Creates
- Cloud KMS key rings in the primary and DR regions, 90-day rotation (CMEK for state-adjacent data, storage, SQL, GKE).
- Secret Manager secrets for anything sensitive (VPN pre-shared keys, database passwords). Terraform reads them; they never sit in code or tfvars.
- VPC Service Controls: an access policy, an access level for the pipeline service accounts, and a perimeter around `prod` projects with sensitive data.

## Notes
- Start the perimeter in dry-run mode and read the violation logs before enforcing, otherwise it can block the pipeline and Google APIs.
- An organization normally has a single access policy. Decide in one place (this stage) who creates it; the example creates it in `1-org`.
- Cloud KMS key IDs are consumed by stages 3-5; export them as outputs.
