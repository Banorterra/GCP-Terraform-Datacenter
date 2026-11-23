# Essential Contacts: where Google sends important notices about the organization (security incidents,
# billing problems, legal and suspension notices, outages). Without them, Google writes to the org admins
# at @banorterra.com, a mailbox nobody reads. Free.
#
# Organizations created after May 2024 only allow contacts in their own domain
# (essentialcontacts.allowedContactDomains). We manage that policy here and add the domains of
# var.alert_emails so the team's real mailboxes can be contacts.

locals {
  contact_domains = distinct(concat(
    ["@${data.google_organization.org.domain}"],
    [for e in var.alert_emails : "@${lower(split("@", e)[1])}"],
  ))
}

resource "google_org_policy_policy" "essential_contacts_domains" {
  name   = "${local.org_policy_parent}/policies/essentialcontacts.allowedContactDomains"
  parent = local.org_policy_parent

  spec {
    inherit_from_parent = false

    rules {
      values {
        allowed_values = local.contact_domains
      }
    }
  }
}

resource "google_essential_contacts_contact" "team" {
  count = nonsensitive(length(var.alert_emails))

  parent                              = "organizations/${var.org_id}"
  email                               = var.alert_emails[count.index]
  language_tag                        = "es"
  notification_category_subscriptions = ["ALL"]

  depends_on = [google_org_policy_policy.essential_contacts_domains]
}
