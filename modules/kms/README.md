# Module: kms

Cloud KMS key ring with symmetric keys for CMEK (Cloud Storage, Cloud SQL, GKE, Persistent Disk). Keys rotate on
their own (90 days by default, the spec's maximum). Optional IAM: encrypter/decrypter per key (service agents) and
read-only access to the ring for groups.

AWS analogy: an AWS KMS customer managed key with automatic rotation. GCP adds the key ring, a regional folder of
keys, and a CMEK key must be in the same region as the data it encrypts.

**Destroy:** GCP never deletes key rings or keys. `terraform destroy` schedules every key version for destruction
(`destroy_scheduled_duration`, 1 day by default, after which billing stops) and drops the ring from the state, but
the names stay taken. Give `keyring_name` a random suffix if the ring may be recreated.

Example: [examples/basic](examples/basic). Tests: `terraform test` from this folder (mock provider).

Regenerate the tables below with `terraform-docs markdown table --output-file README.md .`

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 6.50.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_kms_crypto_key.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key) | resource |
| [google_kms_crypto_key_iam_member.encrypter_decrypter](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_kms_key_ring.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_key_ring) | resource |
| [google_kms_key_ring_iam_member.viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_key_ring_iam_member) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_destroy_scheduled_duration"></a> [destroy\_scheduled\_duration](#input\_destroy\_scheduled\_duration) | How long a key version stays in DESTROY\_SCHEDULED before it is gone for good (and stops being billed). 1 day is the minimum. | `string` | `"86400s"` | no |
| <a name="input_encrypters_decrypters"></a> [encrypters\_decrypters](#input\_encrypters\_decrypters) | Members that may encrypt and decrypt with each key (roles/cloudkms.cryptoKeyEncrypterDecrypter), by key name. Usually service agents, for example service-<number>@gs-project-accounts.iam.gserviceaccount.com. | `map(list(string))` | `{}` | no |
| <a name="input_keyring_name"></a> [keyring\_name](#input\_keyring\_name) | Name of the key ring. Key rings and keys can never be deleted in GCP, so a name can be used only once per project and location. | `string` | n/a | yes |
| <a name="input_keyring_viewers"></a> [keyring\_viewers](#input\_keyring\_viewers) | Members that may see the key ring and its keys, not use them (roles/cloudkms.viewer). Use groups, not users. | `list(string)` | `[]` | no |
| <a name="input_keys"></a> [keys](#input\_keys) | Keys to create in the ring, by name. Each one may override the rotation period. Purpose is always ENCRYPT\_DECRYPT (symmetric, what CMEK uses). | <pre>map(object({<br/>    rotation_period = optional(string)<br/>  }))</pre> | n/a | yes |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels for every key. Add the key's own app label here; the provider's default\_labels add the rest. | `map(string)` | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | Region of the key ring, for example northamerica-south1. A CMEK key must be in the same region as the data it protects. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project that holds the key ring (the security project). | `string` | n/a | yes |
| <a name="input_protection_level"></a> [protection\_level](#input\_protection\_level) | SOFTWARE (0.06 USD per key version per month) or HSM (about 1-2.50 USD per version per month). | `string` | `"SOFTWARE"` | no |
| <a name="input_rotation_period"></a> [rotation\_period](#input\_rotation\_period) | Default automatic rotation period, in seconds with an 's' suffix. Spec: every 90 days (7776000s) at most. | `string` | `"7776000s"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_key_ids"></a> [key\_ids](#output\_key\_ids) | Key ID by key name, in the form CMEK settings take (kms\_key\_name, encryption.default\_kms\_key\_name). |
| <a name="output_keyring_id"></a> [keyring\_id](#output\_keyring\_id) | Key ring ID: projects/<project>/locations/<location>/keyRings/<name>. |
<!-- END_TF_DOCS -->
