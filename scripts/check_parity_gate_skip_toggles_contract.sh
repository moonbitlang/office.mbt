#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

json_output="$(scripts/check_parity_gate_skip_toggles.sh --json)"
PARITY_TOGGLE_CHECK_JSON="$json_output" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["PARITY_TOGGLE_CHECK_JSON"])
if "result" not in payload:
    raise SystemExit("missing 'result' in skip-toggle checker json output")
if "checks" not in payload:
    raise SystemExit("missing 'checks' in skip-toggle checker json output")
if not isinstance(payload["checks"], list):
    raise SystemExit("'checks' must be a list in skip-toggle checker json output")
for entry in payload["checks"]:
    for key in (
        "key",
        "in_test_parity_gates",
        "in_show_parity_env_json",
        "in_show_parity_preflight_status_json_env",
        "ok",
    ):
        if key not in entry:
            raise SystemExit(f"missing '{key}' in skip-toggle checker entry")
PY

set +e
invalid_output="$(scripts/check_parity_gate_skip_toggles.sh --bad 2>&1)"
invalid_code=$?
set -e
if [[ $invalid_code -ne 2 ]]; then
  echo "Expected exit code 2 for invalid args, got ${invalid_code}"
  exit 1
fi
if ! rg -Fq "Usage: scripts/check_parity_gate_skip_toggles.sh [--json]" <<<"$invalid_output"; then
  echo "check_parity_gate_skip_toggles invalid-arg usage message mismatch."
  exit 1
fi

echo "Parity gate skip-toggle checker contract check passed."
