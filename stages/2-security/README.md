# Stage 2: security

Corre desde el pipeline como `sa-terraform-security`, prefijo de state `2-security`. Lee las salidas de
`1-org` (`terraform_remote_state`). Todo vive en el proyecto `<prefijo>-c-security` que crea la etapa 1.

## Crea

| Recurso | Para qué | Quién lo usa |
|---|---|---|
| Cloud KMS: un key ring en Querétaro y otro en Dallas, con llaves `storage`, `sql` y `gke` (rotación 90 días) | Cifrado CMEK de buckets, Cloud SQL y GKE. La llave tiene que estar en la misma región que el dato | Etapas 4 y 5 (salida `kms_key_ids`) |
| Secret Manager: `vpn-psk-onprem` y `sql-admin-pass`, replicados en las dos regiones | Que ningún secreto viva en código ni en tfvars (reto) | La etapa 3 lee la PSK de la VPN y la 5 la contraseña de Cloud SQL |
| VPC Service Controls: access policy de la org, access level `pipeline`, perímetro `prod` en **dry-run** | Perímetro para los proyectos de prod con datos sensibles (reto) | La etapa 4 agrega los proyectos de servicio de prod al perímetro |
| IAM de lectura para `security_reader_groups` | El equipo de seguridad ve llaves y metadatos de secretos, nunca el valor | Personas, por grupo (no usuarios sueltos) |

## Decisiones

| Tema | Decisión | Por qué |
|---|---|---|
| Módulo | `modules/kms` (propio), una instancia por región | El reto pide el módulo `kms` con README, ejemplo y prueba |
| Nivel de protección | `SOFTWARE` | 0.06 USD por versión al mes contra 1-2.50 USD de HSM |
| Nombre del key ring | `<prefijo>-c-sec-kr-<región>-<sufijo aleatorio>` | GCP nunca borra key rings ni llaves: sin sufijo, un apply después de un destroy falla con "already exists" |
| Valores de los secretos | `ephemeral "random_password"` + `secret_data_wo` (write-only) | El valor no queda en el plan, ni en el state, ni en los comentarios del PR. Requiere Terraform >= 1.11 (`versions_stage.tf`) |
| Rotar un secreto | Subir `version` del secreto en `var.secrets` | El siguiente apply escribe una versión nueva con otro valor |
| Quién lee cada secreto | Solo la SA de la etapa que lo usa (`secretAccessor` por secreto) | Mínimo privilegio |
| VPC-SC | `vpc_sc_enforce = false` (dry-run) | Un perímetro aplicado sin revisar los logs puede bloquear al pipeline y a los service agents de Google. El reto lo recomienda |
| Servicios restringidos | Storage, BigQuery, Cloud SQL, GKE | Los que guardan datos de prod |
| Proyectos del perímetro | Stage 2 mete el `prod-net-host`; stage 4 agrega los de servicio con `..._perimeter_(dry_run_)resource` | Por eso el perímetro ignora cambios en su lista de recursos |
| Access policy | Se crea si `access_policy_id` está vacío | Una organización solo puede tener una. Si ya existe, poner su número en la variable |

## Permisos que necesita

- Etapa 0 (`sa.tf`): `accesscontextmanager.policyAdmin` en la organización. Ya aplicado.
- Etapa 1 (`stage_access.tf`): `cloudkms.admin` y `secretmanager.admin` en el proyecto de seguridad, y las APIs
  `cloudkms` y `secretmanager` encendidas ahí. **Aplica la etapa 1 con ese cambio antes de la etapa 2.**
- La SA de plan (`sa-terraform-plan-security`) ya tiene `roles/viewer` en la org (etapa 0): no necesita nada más.

## Costo estimado

| Recurso | Cantidad | USD/mes |
|---|---|---|
| Versiones de llave KMS (software) | 6 (3 llaves x 2 regiones) | ~0.36 |
| Versiones de secreto activas | 4 (2 secretos x 2 réplicas) | 0 (la capa gratuita cubre 6) |
| Operaciones KMS / accesos a secretos | pocas | ~0 |
| VPC Service Controls, access policy | | 0 |
| **Total** | | **< 1** |

Cada rotación crea una versión nueva de cada llave (las anteriores siguen cobrando mientras existan): cada 90 días
sube unos 0.36 USD al mes.

## Destroy

`terraform destroy` funciona: programa la destrucción de las versiones de llave (1 día), borra secretos, perímetro,
access level y access policy. Los key rings y las llaves quedan como nombres ocupados en el proyecto (no cuestan).
El equipo decidió no destruir esta etapa.

## Cómo correrla localmente

```bash
cd stages/2-security
cp terraform.tfvars.example terraform.tfvars   # llena org_id, billing_account, state_bucket

terraform init -backend-config="bucket=$(cd ../0-bootstrap && terraform output -raw state_bucket)"

export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT="$(
  cd ../0-bootstrap && terraform output -json stage_service_accounts | jq -r .security
)"

terraform plan -out tfplan
terraform test     # pruebas con mock provider, no toca GCP
```
