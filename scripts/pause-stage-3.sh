#!/usr/bin/env bash
# Destroy stage 3 envs/shared so the HA VPN (~$155/month) stops billing. Leaves stages 0, 1, 2 and
# the three env spokes intact. Re-apply this root to bring it back; the public VPN IPs change on
# re-apply, so if the client whitelists them, update the whitelist too.
#
# Usage: scripts/pause-stage-3.sh [-y]      # -y = non-interactive

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STAGE_DIR="${ROOT_DIR}/stages/3-networks/envs/shared"
BOOTSTRAP_DIR="${ROOT_DIR}/stages/0-bootstrap"

cd "${STAGE_DIR}"

if [[ ! -f .terraform/terraform.tfstate && ! -d .terraform ]]; then
  echo "[pause-stage-3] not initialized here; running terraform init"
  STATE_BUCKET="$(cd "${BOOTSTRAP_DIR}" && terraform output -raw state_bucket)"
  terraform init -backend-config="bucket=${STATE_BUCKET}" -input=false
fi

NETWORKS_SA="$(cd "${BOOTSTRAP_DIR}" && terraform output -json stage_service_accounts | jq -r .networks)"
export GOOGLE_IMPERSONATE_SERVICE_ACCOUNT="${NETWORKS_SA}"

APPROVE_FLAG=""
if [[ "${1:-}" == "-y" ]]; then
  APPROVE_FLAG="-auto-approve"
else
  cat <<EOF
About to destroy stage 3 envs/shared (HA VPN, hub VPC, simulated on-prem VPC + VM, NCC, DNS).
Stages 0/1/2 and the env spokes are NOT touched.
Impersonating: ${NETWORKS_SA}
Press Enter to continue, Ctrl-C to abort.
EOF
  read -r _
fi

terraform destroy ${APPROVE_FLAG}

echo "[pause-stage-3] done. Resume with: cd ${STAGE_DIR} && terraform apply"
