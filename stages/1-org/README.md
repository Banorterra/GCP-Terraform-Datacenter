# Stage 1: org

Referencia: `terraform-example-foundation/1-org`. Corre desde el pipeline como `sa-terraform-org`,
prefijo de state `1-org`. Lee stage 0 vía `terraform_remote_state` (bucket de `var.state_bucket`,
prefijo `0-bootstrap`).

## Estado (2026-11-22)

Implementada en la rama `feat/stage-1-org` (commit `d60d9f8`). Validado localmente con
`terraform fmt -recursive`, `terraform init -backend=false`, `terraform validate` y
`terraform test` (3/3 pass con `mock_provider`). **Sin aplicar** contra la org sandbox todavía.

## Decisiones tomadas

| Tema | Decisión | Por qué |
|---|---|---|
| Org Policy API | **v2** (`google_org_policy_policy`) | API actual de GCP (soporta condiciones y dry-run). El example-foundation aún usa v1 pero v2 evita una migración futura |
| Wrapping de módulos | **Módulos oficiales inline** en `stages/1-org` con `version = "~> X.Y"` | Entrega stage 1 en una rama chica; los wrappers en `modules/<nombre>` quedan como follow-up con su propio ADR |
| Project factory | `terraform-google-modules/project-factory/google ~> 18.0` (mismo pin que stage 0) | Consistencia con stage 0 |
| Budgets | Uno por proyecto en `common` + uno por folder (`dev`/`qa`/`prod`), alertas 50/90/100% a Pub/Sub | Cubre el acceptance del spec (alertas accionables) sin inflar el blast radius en sandbox |
| Audit retention lock | Opt-in vía `var.audit_log_retention_locked` (default `false`) | Locking es IRREVERSIBLE; prende el flag solo antes de cutover a prod |
| Organizaciones de folders | `common` + `dev` + `qa` + `prod` bajo el mismo `parent_folder` que stage 0 | Match con el spec; no hay folder `network` separado (el hub vive en `common`) |
| Regiones permitidas | `in:northamerica-south1-locations` + `in:us-south1-locations` (ADR 0005) | Querétaro primaria, Dallas DR |

## Lo que ya quedó

### Folders
- `common`, `dev`, `qa`, `prod` colgados de `parent_folder` (o del org root si está vacío).

### Proyectos en `common`
- `<prefix>-c-net-hub` — hub de Shared VPC, HA VPN a on-prem, DNS (stage 3 lo llena).
- `<prefix>-c-logging` — bucket del sink de auditoría (ya creado aquí) + log views.
- `<prefix>-c-security` — KMS, Secret Manager, SCC notifications (stage 2 lo llena; el topic de SCC ya vive aquí).
- `<prefix>-c-backup` — vaults de Backup y DR (stage 5 lo llena).

### Host projects de red (uno por entorno)
- `<prefix>-dev-net-host`, `<prefix>-qa-net-host`, `<prefix>-prod-net-host`.
- Stage 3 habilita Shared VPC en estos; aquí solo se crean con las APIs mínimas.

### Organization Policies (v2, enforcement activo)
- `gcp.resourceLocations` → solo primary + DR.
- `compute.vmExternalIpAccess` → deny all (sin IPs externas en VMs).
- `iam.disableServiceAccountKeyCreation`, `iam.disableServiceAccountKeyUpload` → sin llaves de SA.
- `compute.requireOsLogin`, `compute.disableSerialPortAccess`, `compute.disableNestedVirtualization`.
- `compute.skipDefaultNetworkCreation`, `iam.automaticIamGrantsForDefaultServiceAccounts`.
- `storage.uniformBucketLevelAccess`, `storage.publicAccessPrevention`.
- `sql.restrictPublicIp`, `sql.restrictAuthorizedNetworks`.

### Logging / auditoría
- Bucket GCS `<prefix>-c-audit-logs-<org_id>` en el proyecto `logging`, con `retention_policy`
  y versioning. Locking opt-in.
- Sink `google_logging_organization_sink` con `include_children = true` capturando
  `cloudaudit.googleapis.com/activity|data_access|system_event`.
- Writer identity del sink con `roles/storage.objectCreator` en el bucket.

### Security Command Center
- Pub/Sub topic `<prefix>-scc-findings` en el proyecto `security`.
- `google_scc_notification_config` publicando todos los `state = "ACTIVE"` al topic.
- IAM: `service-org-<org_id>@security-center-api.iam.gserviceaccount.com` como `pubsub.publisher`.

### Budgets
- Pub/Sub topic `<prefix>-budget-alerts` en el proyecto `logging`.
- Un `google_billing_budget` por proyecto de `common` (monto `var.budget_common_project_monthly_amount`).
- Un `google_billing_budget` por folder de entorno, filtrando por label `env`
  (monto desde `var.budget_env_monthly_amount`).
- Umbrales: 50 %, 90 %, 100 % → Pub/Sub.

### Outputs expuestos para stages 2–4
`folder_ids`, `common_project_ids`, `common_project_numbers`, `net_host_project_ids`,
`audit_log_bucket`, `audit_log_sink_writer`, `scc_findings_topic`, `budget_alerts_topic`,
`org_policy_names`.

### Tests
`tests/plan.tftest.hcl` con 3 runs (`folders_and_projects`, `org_policies`,
`sinks_and_notifications`) usando `mock_provider` y `override_data` para el remote state.

## Lo que falta

- **Apply real** en la org sandbox. No se ha corrido `terraform plan`/`apply` contra GCP.
- **Lock file multi-plataforma**: `.terraform.lock.hcl` no se commiteó. Después del primer
  apply exitoso agregar hashes para linux/darwin/windows como se hizo con stage 0 (PR #5).
- **Billing export a BigQuery**: el spec lo pide; sigue siendo un paso manual (el dataset se
  crea por consola/CLI y se enlaza al billing account). Documentarlo en un runbook.
- **Essential Contacts** a nivel org (seguridad, billing, legal) — no implementado todavía.
- **Dry-run flag** real para org policies: `var.org_policy_dry_run` existe como placeholder
  pero no está cableado en los recursos. Cablearlo si se quiere stage de cambios sin enforce.
- **Wrappers en `modules/<nombre>`** (`organization-policies`, `log-export`, `budget`) con su
  propio ADR; hoy están inline.
- **Conftest/OPA**: `policies/*.rego` nunca se corrió contra el plan JSON de stage 1.
- **tflint**: no está instalado en la máquina de desarrollo.
- **Validar la identidad de SCC**: formato `service-org-<org_id>@security-center-api...`
  depende de que SCC esté habilitado a nivel org. Si falla el primer apply, habilitar SCC
  manualmente antes.

## Cómo correrlo

### Pre-requisitos
- Stage 0 ya aplicado (está — ver commit `e3f4715`).
- Tu identidad humana con permiso para impersonar `sa-terraform-org` (lo da stage 0).
- Terraform >= 1.9 (ver `.terraform-version`).

### Local (impersonando la SA de stage 1)

```bash
git checkout feat/stage-1-org
cd stages/1-org

# 1. Variables
cp terraform.tfvars.example terraform.tfvars
# Edita terraform.tfvars con:
#   - org_id, billing_account, project_prefix, parent_folder (si usas sandbox-dentro-de-org)
#   - state_bucket = output state_bucket de stage 0
#   - labels con owner y cost_center en minúsculas (ti-001, no TI-001)

# 2. Init contra el bucket de state de stage 0
terraform init \
  -backend-config="bucket=$(cd ../0-bootstrap && terraform output -raw state_bucket)"

# 3. Impersonar la SA de org (como lo hace el pipeline)
export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT="$(
  cd ../0-bootstrap && terraform output -json stage_service_accounts | jq -r .org
)"

# 4. Plan y apply
terraform plan -out tfplan
terraform apply tfplan

# 5. Segundo plan: debería mostrar "No changes" (acceptance criteria del spec)
terraform plan
```

### Vía pipeline (recomendado una vez que `feat/read-only-plan-sas` esté en main)
Abre un PR desde `feat/stage-1-org` → main. `pr.yml` corre `terraform plan` con la SA
read-only. Cuando mergees, `apply.yml` corre `terraform apply`.

### Tests

```bash
cd stages/1-org
terraform test
```

No requiere credenciales (usa `mock_provider`).

### Checks que corremos antes de cada PR

```bash
terraform fmt -recursive stages/1-org/
terraform init -backend=false  # desde stages/1-org
terraform validate
terraform test
# tflint stages/1-org/   # si está instalado
```

## Siguiente

Stage 3 (red con HA VPN hacia `onprem-sim`) consume `net_host_project_ids` y
`folder_ids["common"]` de los outputs de arriba. Después van 2 y 4 en paralelo.
