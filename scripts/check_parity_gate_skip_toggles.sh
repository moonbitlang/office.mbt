#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

expected=(
  "SKIP_PARITY_WRAPPER_PREFLIGHT"
  "SKIP_PARITY_ENV_HELPER_PREFLIGHT"
  "SKIP_PARITY_PREFLIGHT_STATUS_HELPER_PREFLIGHT"
  "SKIP_PARITY_DOCS_PREFLIGHT"
  "SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT"
)

for key in "${expected[@]}"; do
  if ! rg -Fq "$key" scripts/test_parity_gates.sh; then
    echo "Missing skip toggle in scripts/test_parity_gates.sh: $key"
    exit 1
  fi
done

env_json="$(scripts/show_parity_env.sh --json)"
preflight_json="$(scripts/show_parity_preflight_status.sh --json)"
EXPECTED_KEYS="$(printf '%s\n' "${expected[@]}")" \
PARITY_ENV_JSON="$env_json" \
PARITY_PREFLIGHT_JSON="$preflight_json" \
python3 - <<'PY'
import json
import os

expected = [line.strip() for line in os.environ["EXPECTED_KEYS"].splitlines() if line.strip()]
env_payload = json.loads(os.environ["PARITY_ENV_JSON"])
preflight_payload = json.loads(os.environ["PARITY_PREFLIGHT_JSON"])
preflight_env = preflight_payload.get("env", {})

missing_env = [key for key in expected if key not in env_payload]
if missing_env:
    raise SystemExit(f"missing keys in show_parity_env --json: {missing_env}")

missing_preflight = [key for key in expected if key not in preflight_env]
if missing_preflight:
    raise SystemExit(f"missing keys in show_parity_preflight_status --json env: {missing_preflight}")
PY

echo "Parity gate skip-toggle consistency check passed."
