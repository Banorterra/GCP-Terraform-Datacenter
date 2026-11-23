# Stage 1: org

Referencia: `terraform-example-foundation/1-org`. Corre desde el pipeline como `sa-terraform-org`,
prefijo de state `1-org` en el bucket de la etapa 0. Lee la etapa 0 vía `terraform_remote_state`.

Crea los folders `common`, `dev`, `qa` y `prod`; los proyectos `net-hub`, `logging`, `security` y `backup`
en `common`; un proyecto de red spoke (`<prefijo>-<env>-net-host`) por entorno; las políticas de
organización; el sink de auditoría; las notificaciones de SCC; los presupuestos y los Essential Contacts.

## Decisiones

| Tema | Decisión | Por qué |
|---|---|---|
| Org Policy API | **v2** (`google_org_policy_policy`) | API actual de GCP (condiciones, dry-run). Requiere `orgpolicy.googleapis.com` en el proyecto seed (etapa 0) |
| Módulos | `terraform-google-modules/project-factory/google ~> 18.0`, inline | Mismo pin que la etapa 0. Wrappers en `modules/` quedan para después |
| Folders | `common` + `dev` + `qa` + `prod` bajo el mismo padre que la etapa 0 | Igual al reto y al diagrama 1. No hay folder `network` aparte (el hub vive en `common`) |
| Proyecto de red por entorno | `<prefijo>-<env>-net-host` | El reto pide "un proyecto de red spoke" por entorno; es el host de la Shared VPC del entorno (diagrama 2) |
| Cuenta de servicio por proyecto | No se crea (`create_project_sa = false`) | Nadie la usa y el reto no la pide |
| Regiones permitidas | `in:northamerica-south1-locations` + `in:us-south1-locations` | ADR 0005: Querétaro primaria, Dallas DR |
| Políticas de organización | Sin llaves de SA, sin IPs externas en VMs, Shielded VM, OS Login, sin red default, buckets uniformes y sin acceso público, Cloud SQL sin IP pública, IAM solo para principales de la organización, contactos solo de dominios permitidos | Lo que pide el reto más el endurecimiento del example foundation |
| IAM solo para la organización | `iam.allowedPolicyMemberDomains` con el customer ID de Cloud Identity y el principal set de la organización | El principal set deja pasar cuentas de servicio, service agents (por ejemplo el de SCC) y el pool de GitHub |
| Retención de auditoría | **Bloqueada**, 1 día en el sandbox | El reto pide retención bloqueada. Con 1 día el bloqueo es real pero se puede destruir al terminar. Al bloquear, GCS pone un *lien* en el proyecto de logging hasta que el bucket se borra |
| Borrado | `folder_deletion_protection = false`, `project_deletion_policy = "DELETE"` | Sandbox con crédito limitado: tiene que funcionar `terraform destroy` |
| Presupuestos | Uno de 300 USD para toda la cuenta de facturación + uno de 10 USD por proyecto, con `EXCLUDE_ALL_CREDITS` | Con `INCLUDE_ALL_CREDITS` el crédito de prueba deja el costo en 0 y nunca hay alertas |
| Avisos | Correos de `ALERT_EMAILS` (secret de GitHub) como canales de Monitoring y Essential Contacts | Los buzones `@banorterra.com` no se leen. Es secret para que los correos no salgan en el repo público ni en los planes |

## Variables

Los valores del equipo que no son secretos están en `terraform.auto.tfvars` (se commitea). El pipeline pasa
`org_id`, `billing_account`, `state_bucket` y `environment` como `TF_VAR_*`, y `alert_emails` desde el
secret `ALERT_EMAILS` (lista JSON, por ejemplo `["alguien@example.com"]`).

## Antes del primer apply

1. Activar Security Command Center (nivel Standard) en la organización. La notificación de hallazgos
   necesita la identidad `service-org-<org_id>@security-center-api.iam.gserviceaccount.com`, que solo existe
   con SCC activado.
2. Aplicar la etapa 0 localmente para habilitar `orgpolicy.googleapis.com` en el proyecto seed.
3. Crear el secret `ALERT_EMAILS` en GitHub (Settings > Secrets and variables > Actions > Secrets).
4. Revisar que la cuenta de facturación permita ligar 7 proyectos más.

## Pasos manuales que quedan fuera de Terraform

- **Exportación de facturación a BigQuery.** Google no tiene API para activarla; se hace en la consola
  (Billing > Billing export) apuntando a un dataset de BigQuery en una región permitida.

## Cómo correrla localmente

```bash
cd stages/1-org
cp terraform.tfvars.example terraform.tfvars   # llena org_id, billing_account, state_bucket, alert_emails

terraform init -backend-config="bucket=$(cd ../0-bootstrap && terraform output -raw state_bucket)"

# Impersonar la SA de la etapa, como el pipeline
export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT="$(
  cd ../0-bootstrap && terraform output -json stage_service_accounts | jq -r .org
)"

terraform plan -out tfplan
terraform apply tfplan
```

Validación sin credenciales: `terraform fmt -check`, `terraform validate`, `terraform test` (usa
`mock_provider`).

`.terraform.lock.hcl` fija los providers (los mismos que la etapa 0) con hashes para linux, darwin y windows.
