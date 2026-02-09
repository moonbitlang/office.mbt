#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

required_patterns=(
  "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT"
  "parity preflight matrix smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract preflight"
  "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh"
)

for pattern in "${required_patterns[@]}"; do
  if rg -Fq "$pattern" scripts/test_parity_gates.sh; then
    echo "[OK] scripts/test_parity_gates.sh contains: $pattern"
  else
    echo "[MISSING] scripts/test_parity_gates.sh missing: $pattern"
    exit 1
  fi
done

json_output="$(scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh --json)"
PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_JSON="$json_output" python3 - <<'PY'
import json
import os

payload = json.loads(
    os.environ[
        "PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_JSON"
    ]
)
if "result" not in payload:
    raise SystemExit(
        "missing 'result' in matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker json output"
    )
if payload["result"] not in ("pass", "fail"):
    raise SystemExit(
        "invalid 'result' in matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker json output"
    )
if "checks" not in payload:
    raise SystemExit(
        "missing 'checks' in matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker json output"
    )
if not isinstance(payload["checks"], list):
    raise SystemExit(
        "'checks' must be a list in matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker json output"
    )

required_checks = {
    "required_pattern::SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT",
    "required_pattern::parity preflight matrix smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract preflight",
    "required_pattern::scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh",
    "matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_json_top_level",
    "matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_json_entry_schema",
    "matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_json_required_checks",
    "matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_invalid_arg_usage",
}
seen_checks = set()

for entry in payload["checks"]:
    for key in ("check", "ok", "detail"):
        if key not in entry:
            raise SystemExit(
                "missing "
                f"'{key}' in matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker entry"
            )
    if not isinstance(entry["check"], str):
        raise SystemExit(
            "'check' must be a string in matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker entry"
        )
    if not isinstance(entry["ok"], bool):
        raise SystemExit(
            "'ok' must be a bool in matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker entry"
        )
    if not isinstance(entry["detail"], str):
        raise SystemExit(
            "'detail' must be a string in matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker entry"
        )
    seen_checks.add(entry["check"])

missing_checks = sorted(required_checks - seen_checks)
if missing_checks:
    raise SystemExit(
        "missing required checks in matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker json output: "
        f"{missing_checks}"
    )
PY

set +e
invalid_output="$({
  scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh --bad 2>&1
})"
invalid_code=$?
set -e
if [[ $invalid_code -ne 2 ]]; then
  echo "Expected exit code 2 for invalid args, got ${invalid_code}"
  exit 1
fi
if ! rg -Fq "Usage: scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh [--json]" <<<"$invalid_output"; then
  echo "check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract invalid-arg usage message mismatch."
  exit 1
fi

echo "Parity preflight matrix smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker contract check passed."
