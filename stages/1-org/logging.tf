# Organization-level audit log sink to a Cloud Storage bucket in the logging project.
# The bucket has a locked retention policy (spec: "retención bloqueada"). Once locked, the retention
# period CANNOT be shortened or removed, even by project owners, and GCS puts a lien on the logging
# project until the bucket is gone. The sandbox uses a 1-day period (var.audit_log_retention_days),
# so terraform destroy can empty and delete the bucket once its newest object is a day old.

resource "google_storage_bucket" "audit_logs" {
  project                     = module.common_projects["logging"].project_id
  name                        = "${var.project_prefix}-c-audit-logs-${var.org_id}"
  location                    = var.primary_region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true # sandbox: destroy deletes the objects (only those past retention)

  versioning {
    enabled = true
  }

  retention_policy {
    retention_period = var.audit_log_retention_days * 24 * 3600
    is_locked        = var.audit_log_retention_locked
  }

  labels = merge(local.base_labels, { app = "audit-logs" })
}

# Aggregated sink at the organization: captures all admin and data-access logs for every project
# under the org and routes them to the bucket above.
resource "google_logging_organization_sink" "audit" {
  name             = "${var.project_prefix}-org-audit-sink"
  org_id           = var.org_id
  destination      = "storage.googleapis.com/${google_storage_bucket.audit_logs.name}"
  include_children = true
  filter           = var.audit_log_filter
}

# Org sinks write as the organization's Logging service agent
# (service-org-<org-id>@gcp-sa-logging). Google creates it lazily, and the first apply failed because
# it did not exist yet when the bucket IAM was set. Reading the org's Logging settings makes Google
# create it, so the IAM grant below waits for this read.
data "google_logging_organization_settings" "org" {
  organization = var.org_id

  depends_on = [google_logging_organization_sink.audit]
}

# The sink's writer identity needs object creation on the bucket.
resource "google_storage_bucket_iam_member" "audit_sink_writer" {
  bucket = google_storage_bucket.audit_logs.name
  role   = "roles/storage.objectCreator"
  member = google_logging_organization_sink.audit.writer_identity

  depends_on = [data.google_logging_organization_settings.org]
}
