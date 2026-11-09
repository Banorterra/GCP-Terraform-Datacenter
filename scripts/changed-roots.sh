#!/usr/bin/env bash
# Prints a GitHub Actions matrix (JSON) with the Terraform roots to plan.
#   changed-roots.sh [BASE_REF]   roots touched by the diff BASE_REF...HEAD
#   changed-roots.sh --all        every root except 0-bootstrap (used by the drift job)
# A change under modules/, stages/_shared/, .github/workflows/ or .terraform-version affects every root.
# 0-bootstrap is never returned: it is applied once, by hand.
set -euo pipefail

all_roots() {
  find stages -name backend.tf -not -path '*/.terraform/*' -exec dirname {} \; | sort
}

roots=()
if [[ "${1:-}" == "--all" ]]; then
  mapfile -t roots < <(all_roots)
else
  base="${1:-origin/main}"
  changed="$(git diff --name-only "${base}...HEAD" || true)"
  if grep -qE '^(modules/|stages/_shared/|\.terraform-version|\.github/workflows/)' <<<"$changed"; then
    mapfile -t roots < <(all_roots)
  else
    while read -r r; do
      if grep -q "^${r}/" <<<"$changed"; then roots+=("$r"); fi
    done < <(all_roots)
  fi
fi

printf '%s\n' "${roots[@]:-}" | jq -R . | jq -s 'map(select(length > 0))' | jq -c '
  {include: [
    .[] | select(startswith("stages/0-bootstrap") | not) | (split("/")) as $p
    | {
        dir: .,
        stage: $p[1],
        env: (if ($p | length) > 3 then $p[3] else "" end),
        gh_env: (if ($p | length) > 3 then $p[3] else "shared" end),
        sa_key: ({"1-org": "ORG", "2-security": "SECURITY", "3-networks": "NETWORKS",
                  "4-projects": "PROJECTS", "5-workloads": "WORKLOADS"}[$p[1]])
      }
  ]}'
