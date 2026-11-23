# Security Command Center notifications: every new finding goes to a Pub/Sub topic in the
# security project. Downstream consumers (dashboards, PagerDuty, etc.) subscribe to it.
# SCC must be enabled at the organization level (tier Standard is free; Premium/Enterprise is
# billed separately — not provisioned here).

resource "google_pubsub_topic" "scc_findings" {
  project = module.common_projects["security"].project_id
  name    = "${var.project_prefix}-scc-findings"
  labels  = merge(local.base_labels, { app = "scc" })
}

# SCC uses a service-managed identity to publish. Grant it publisher on the topic.
# The identity is generated per org on first use: projects/<org-number>/serviceAccounts/
# service-org-<org-id>@security-center-api.iam.gserviceaccount.com
resource "google_pubsub_topic_iam_member" "scc_publisher" {
  project = google_pubsub_topic.scc_findings.project
  topic   = google_pubsub_topic.scc_findings.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-org-${var.org_id}@security-center-api.iam.gserviceaccount.com"
}

# SCC API v2 (Google retired the v1 notification API). location "global" is the only one for
# organizations without data residency.
resource "google_scc_v2_organization_notification_config" "all_findings" {
  config_id    = "${var.project_prefix}-scc-all-findings"
  organization = var.org_id
  location     = "global"
  description  = "All new SCC findings for the organization."
  pubsub_topic = google_pubsub_topic.scc_findings.id

  streaming_config {
    filter = var.scc_notification_filter
  }

  depends_on = [google_pubsub_topic_iam_member.scc_publisher]
}

# The v1 resource never got created (its API is gone). If a failed attempt left it in the state,
# forget it instead of calling the retired API to delete it.
removed {
  from = google_scc_notification_config.all_findings

  lifecycle {
    destroy = false
  }
}
