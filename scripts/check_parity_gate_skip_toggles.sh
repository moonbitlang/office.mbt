#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

json_mode=0
if [[ "${1:-}" == "--json" ]]; then
  json_mode=1
  shift
fi
if [[ $# -ne 0 ]]; then
  echo "Usage: scripts/check_parity_gate_skip_toggles.sh [--json]"
  exit 2
fi

expected=(
  "SKIP_PARITY_WRAPPER_PREFLIGHT"
  "SKIP_PARITY_ENV_HELPER_PREFLIGHT"
  "SKIP_PARITY_PREFLIGHT_STATUS_HELPER_PREFLIGHT"
  "SKIP_PARITY_GATE_TOGGLE_PREFLIGHT"
  "SKIP_PARITY_GATE_TOGGLE_CONTRACT_PREFLIGHT"
  "SKIP_PARITY_DOCS_PREFLIGHT"
  "SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT"
)

parity_gate_source="$(cat scripts/test_parity_gates.sh)"
env_json="$(scripts/show_parity_env.sh --json)"
preflight_json="$(scripts/show_parity_preflight_status.sh --json)"
EXPECTED_KEYS="$(printf '%s\n' "${expected[@]}")" \
CHECK_PARITY_JSON_MODE="$json_mode" \
PARITY_GATE_SOURCE="$parity_gate_source" \
PARITY_ENV_JSON="$env_json" \
PARITY_PREFLIGHT_JSON="$preflight_json" \
python3 - <<'PY'
import json
import os
import sys

json_mode = os.environ["CHECK_PARITY_JSON_MODE"] == "1"
expected = [line.strip() for line in os.environ["EXPECTED_KEYS"].splitlines() if line.strip()]
gate_source = os.environ["PARITY_GATE_SOURCE"]
env_payload = json.loads(os.environ["PARITY_ENV_JSON"])
preflight_payload = json.loads(os.environ["PARITY_PREFLIGHT_JSON"])
preflight_env = preflight_payload.get("env", {})

checks = []
for key in expected:
    in_gate = key in gate_source
    in_env = key in env_payload
    in_preflight = key in preflight_env
    checks.append(
        {
            "key": key,
            "in_test_parity_gates": in_gate,
            "in_show_parity_env_json": in_env,
            "in_show_parity_preflight_status_json_env": in_preflight,
            "ok": in_gate and in_env and in_preflight,
        }
    )

failed = [entry for entry in checks if not entry["ok"]]
result = "pass" if not failed else "fail"

if json_mode:
    print(json.dumps({"result": result, "checks": checks}, indent=2, sort_keys=False))
else:
    for entry in checks:
        if entry["ok"]:
            print(f"[OK] {entry['key']}")
        else:
            print(
                f"[MISSING] {entry['key']} "
                f"(gate={entry['in_test_parity_gates']}, "
                f"env={entry['in_show_parity_env_json']}, "
                f"preflight={entry['in_show_parity_preflight_status_json_env']})"
            )
    if failed:
        print("Parity gate skip-toggle consistency check failed.")
    else:
        print("Parity gate skip-toggle consistency check passed.")

if failed:
    sys.exit(1)
PY
