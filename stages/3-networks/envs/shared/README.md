# Stage 3: envs/shared

Root compartido de la etapa 3. Crea el hub (VPC, HA VPN, NCC, DNS) y la simulación de on-premise
(una segunda VPC con una VM Linux, dentro del mismo proyecto `net-hub` para no gastar un lugar de
billing). Los roots por entorno (`envs/{dev,qa,prod}/`) se conectan a lo que
este root expone.

Corre como `sa-terraform-networks`, prefijo de state `3-networks/shared`. Lee stage 1 (project IDs)
y stage 2 (VPN PSK secret) vía `terraform_remote_state`.

## Costo

Este root es el **más caro de todo el landing zone** porque el HA VPN se cobra por hora, estés o no
mandando tráfico.

| Recurso | USD/mes aprox | Nota |
|---|---|---|
| HA VPN (4 túneles: 2 por lado) | **~$146** | $0.05/h/túnel × 4 × 730h. Es el 95% del costo |
| VM `onprem-sim` (`e2-micro` Querétaro) | ~$7 | Querétaro no tiene free-tier |
| Boot disk 10 GB pd-balanced | ~$1 | |
| Cloud NAT de on-prem (1 VM) | ~$1 | $0.0014/h por VM; solo para el `apt-get` del arranque |
| Cloud DNS (4 zonas) | ~$0.80 | $0.20/zona/mes |
| NCC: VPC spoke del hub + hybrid spoke de la VPN | ~$0 | Se cobra por GB; tráfico sandbox negligible |
| Flow logs 50% | ~$1 | Mínimo sin tráfico |
| Resto (VPC, subnets, router, IP interna, firewall) | $0 | Gratis |
| **Total** | **~$156/mes** | |

### Pausar cuando no se usa

Para ahorrar ~$155/mes entre sesiones de trabajo, se puede destruir **solo este root** (stage 0/1/2
y los spokes de otros entornos quedan intactos) y volverlo a aplicar cuando se necesite el VPN. El
re-apply tarda ~5 min.

```bash
cd stages/3-networks/envs/shared
terraform init -backend-config="bucket=$(cd ../../../0-bootstrap && terraform output -raw state_bucket)"
export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT="$(
  cd ../../../0-bootstrap && terraform output -json stage_service_accounts | jq -r .networks
)"
terraform destroy -auto-approve
```

El script `scripts/pause-stage-3.sh` corre esto por ti.

Al volver, un `terraform apply` (o un push a `main` que toque el root) vuelve a levantar todo con
los mismos nombres, CIDRs y ASNs — pero **la IP de los túneles VPN cambia**, así que si el
cliente tiene reglas de firewall contra nuestras IPs públicas del VPN, hay que actualizarlas.

### Optimizaciones que **no** hice y por qué

| Opción | Ahorro | Por qué no |
|---|---|---|
| Classic VPN en vez de HA VPN | ~$110/mes | El reto exige HA VPN |
| onprem-sim en `us-central1` (free tier e2-micro) | ~$7/mes | Rompe `gcp.resourceLocations` |
| Un solo túnel por lado | ~$73/mes | No es HA; rompe el spec |

## Qué expone

Outputs que consumen los spokes (`envs/{dev,qa,prod}`):
- `ncc_hub_id` — hub al que se attachan como spokes.
- `hub_vpc_id`, `hub_vpc_name`, `hub_project_id`, `hub_subnet_self_link`.
- `hub_dns_zone_name`, `hub_dns_zone`, `onprem_dns_zone` — zonas a las que se hace DNS peering.
- `onprem_host_internal_ip` — IP interna de la VM para pruebas Sprint 4.
- `cidr_plan` — plan de IPs completo (hub + onprem + dev/qa/prod) para no re-declarar CIDRs.

## Cómo correrlo

### Pre-requisitos
- Stage 1 aplicado con las APIs de red en `net-hub` (compute, dns, networkconnectivity, servicenetworking) y `roles/compute.instanceAdmin.v1` para `sa-terraform-networks` en `net-hub` (PR #23).
- Stage 2 aplicado con el secret `vpn-psk-onprem` en Secret Manager.

### Vía pipeline (recomendado)
`pr.yml` corre `plan` en el PR; `apply.yml` corre `apply` al mergear a `main`.

### Local
```bash
cd stages/3-networks/envs/shared
terraform init -backend-config="bucket=$(cd ../../../0-bootstrap && terraform output -raw state_bucket)"
export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT="$(
  cd ../../../0-bootstrap && terraform output -json stage_service_accounts | jq -r .networks
)"
terraform plan -out tfplan
terraform apply tfplan
```

### Validación sin credenciales
```bash
terraform fmt -check
terraform validate
terraform test   # usa mock_provider; no toca GCP
```

## Sprint 4 gate

Antes de arrancar Sprint 4, una VM en `prod` debe:
1. Hacer `ping -c3 $(terraform output -raw onprem_host_internal_ip)` → responde.
2. `dig host.banorterra.local` desde dentro de la VPC prod → resuelve a la IP interna del on-prem.
3. `curl http://host.banorterra.local/` → responde (python http.server del startup script).

Si los 3 funcionan, el HA VPN + BGP + DNS cross-forwarding está bien.
