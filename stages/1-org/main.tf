# Stage 1: organization layout, policies, logging, SCC and budgets.
# The service account that runs this stage is stage_service_accounts["org"] (see stages/0-bootstrap/sa.tf);
# it already holds the roles listed there (orgpolicy.policyAdmin, logging.configWriter, folderAdmin, etc.).
#
# No terraform_remote_state of stage 0: nothing here needs its outputs (everything comes from variables),
# and the stage SA may only read its own 1-org/ prefix of the state bucket.

locals {
  # Same convention as stage 0: everything hangs off var.parent_folder when set, otherwise the org root.
  # parent_folder is passed in by the operator; it must match stage 0's var.parent_folder.
  parent = var.parent_folder != "" ? "folders/${var.parent_folder}" : "organizations/${var.org_id}"

  # Folder taxonomy. bootstrap folder lives in stage 0; we only create the four below.
  folders = toset(["common", "dev", "qa", "prod"])

  # Environment folders that get a network host project in stage 1 (stage 3 will build the VPCs).
  env_folders = toset(["dev", "qa", "prod"])

  # Projects inside the common folder. Each one gets a short name used in the project ID
  # (<prefix>-c-<domain>). The project ID limit is 30 chars; prefix is 2-3 chars.
  # extra_apis: APIs on top of the minimal set in projects.tf, for the stage that fills the project.
  common_projects = {
    # Stage 3 fills net-hub: the hub VPC, the simulated on-prem VPC with its VM (a second VPC here, not its
    # own project, to save a billing slot), the HA VPN between them, Cloud DNS and the NCC hub.
    net-hub = {
      app         = "net-hub"
      description = "Hub VPC, simulated on-prem VPC, HA VPN, DNS and NCC (stage 3 fills it)."
      extra_apis = [
        "compute.googleapis.com",
        "dns.googleapis.com",
        "networkconnectivity.googleapis.com",
        "servicenetworking.googleapis.com",
      ]
    }
    logging = { app = "logging", description = "Org-level audit sink bucket and log views.", extra_apis = [] }
    security = {
      app         = "security"
      description = "KMS, Secret Manager, SCC notifications (stage 2 fills it)."
      extra_apis  = ["cloudkms.googleapis.com", "secretmanager.googleapis.com"]
    }
    backup = { app = "backup", description = "Backup and DR vaults (stage 5 fills it).", extra_apis = [] }
  }

  base_labels = merge(var.labels, {
    env        = var.environment
    managed_by = "terraform"
  })
}

resource "google_folder" "env" {
  for_each = local.folders

  display_name        = each.value
  parent              = local.parent
  deletion_protection = var.folder_deletion_protection
}
