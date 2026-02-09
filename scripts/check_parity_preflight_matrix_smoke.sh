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
  echo "Usage: scripts/check_parity_preflight_matrix_smoke.sh [--json]"
  exit 2
fi

CHECK_PARITY_JSON_MODE="$json_mode" python3 - <<'PY'
import json
import os
import subprocess
import sys
from pathlib import Path

json_mode = os.environ["CHECK_PARITY_JSON_MODE"] == "1"
results = []
failed = False


def add_result(name: str, ok: bool, detail: str) -> None:
    global failed
    results.append({"check": name, "ok": ok, "detail": detail})
    if not ok:
        failed = True
    if not json_mode:
        marker = "[PASS]" if ok else "[FAIL]"
        print(f"{marker} {name}: {detail}")


gate_source = Path("scripts/test_parity_gates.sh").read_text(encoding="utf-8")
required_patterns = [
    "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_PREFLIGHT",
    "parity preflight matrix smoke preflight",
    "scripts/check_parity_preflight_matrix_smoke.sh",
]
for pattern in required_patterns:
    ok = pattern in gate_source
    detail = "present" if ok else "missing"
    add_result(f"required_pattern::{pattern}", ok, detail)

cases = [
    {
        "name": "default",
        "env": {},
        "expected": {
            "wrapper_preflight": "enabled",
            "env_helper_preflight": "enabled",
            "preflight_status_helper_preflight": "enabled",
            "gate_toggle_consistency_preflight": "enabled",
            "gate_toggle_contract_preflight": "enabled",
            "gate_show_toggle_contract_preflight": "enabled",
            "preflight_matrix_smoke_preflight": "enabled",
            "preflight_matrix_smoke_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_preflight": "enabled",
            "docs_preflight": "enabled",
            "docs_wrapper_coverage_preflight": "enabled",
        },
    },
    {
        "name": "all_skipped",
        "env": {
            "SKIP_PARITY_WRAPPER_PREFLIGHT": "1",
            "SKIP_PARITY_ENV_HELPER_PREFLIGHT": "1",
            "SKIP_PARITY_PREFLIGHT_STATUS_HELPER_PREFLIGHT": "1",
            "SKIP_PARITY_GATE_TOGGLE_PREFLIGHT": "1",
            "SKIP_PARITY_GATE_TOGGLE_CONTRACT_PREFLIGHT": "1",
            "SKIP_PARITY_GATE_SHOW_TOGGLE_PREFLIGHT": "1",
            "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_PREFLIGHT": "1",
            "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_PREFLIGHT": "1",
            "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_PREFLIGHT": "1",
            "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT": "1",
            "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT": "1",
            "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT": "1",
            "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT": "1",
            "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT": "1",
            "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT": "1",
            "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT": "1",
            "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT": "1",
            "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT": "1",
            "SKIP_PARITY_DOCS_PREFLIGHT": "1",
            "SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT": "1",
        },
        "expected": {
            "wrapper_preflight": "skipped",
            "env_helper_preflight": "skipped",
            "preflight_status_helper_preflight": "skipped",
            "gate_toggle_consistency_preflight": "skipped",
            "gate_toggle_contract_preflight": "skipped",
            "gate_show_toggle_contract_preflight": "skipped",
            "preflight_matrix_smoke_preflight": "skipped",
            "preflight_matrix_smoke_contract_preflight": "skipped",
            "preflight_matrix_smoke_contract_contract_preflight": "skipped",
            "preflight_matrix_smoke_contract_contract_contract_preflight": "skipped",
            "preflight_matrix_smoke_contract_contract_contract_contract_preflight": "skipped",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_preflight": "skipped",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_preflight": "skipped",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_preflight": "skipped",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_preflight": "skipped",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_preflight": "skipped",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_preflight": "skipped",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_preflight": "skipped",
            "docs_preflight": "skipped",
            "docs_wrapper_coverage_preflight": "n/a (docs preflight skipped)",
        },
    },
    {
        "name": "docs_coverage_only_skipped",
        "env": {"SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT": "1"},
        "expected": {
            "wrapper_preflight": "enabled",
            "env_helper_preflight": "enabled",
            "preflight_status_helper_preflight": "enabled",
            "gate_toggle_consistency_preflight": "enabled",
            "gate_toggle_contract_preflight": "enabled",
            "gate_show_toggle_contract_preflight": "enabled",
            "preflight_matrix_smoke_preflight": "enabled",
            "preflight_matrix_smoke_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_preflight": "enabled",
            "docs_preflight": "enabled",
            "docs_wrapper_coverage_preflight": "skipped",
        },
    },
    {
        "name": "docs_skip_takes_precedence",
        "env": {
            "SKIP_PARITY_DOCS_PREFLIGHT": "1",
            "SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT": "1",
        },
        "expected": {
            "wrapper_preflight": "enabled",
            "env_helper_preflight": "enabled",
            "preflight_status_helper_preflight": "enabled",
            "gate_toggle_consistency_preflight": "enabled",
            "gate_toggle_contract_preflight": "enabled",
            "gate_show_toggle_contract_preflight": "enabled",
            "preflight_matrix_smoke_preflight": "enabled",
            "preflight_matrix_smoke_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_preflight": "enabled",
            "preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_preflight": "enabled",
            "docs_preflight": "skipped",
            "docs_wrapper_coverage_preflight": "n/a (docs preflight skipped)",
        },
    },
]

required_env_keys = [
    "SKIP_PARITY_WRAPPER_PREFLIGHT",
    "SKIP_PARITY_ENV_HELPER_PREFLIGHT",
    "SKIP_PARITY_PREFLIGHT_STATUS_HELPER_PREFLIGHT",
    "SKIP_PARITY_GATE_TOGGLE_PREFLIGHT",
    "SKIP_PARITY_GATE_TOGGLE_CONTRACT_PREFLIGHT",
    "SKIP_PARITY_GATE_SHOW_TOGGLE_PREFLIGHT",
    "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_PREFLIGHT",
    "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_PREFLIGHT",
    "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_PREFLIGHT",
    "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT",
    "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT",
    "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT",
    "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT",
    "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT",
    "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT",
    "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT",
    "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT",
    "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT",
    "SKIP_PARITY_DOCS_PREFLIGHT",
    "SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT",
]

for case in cases:
    env = os.environ.copy()
    env.update(case["env"])
    proc = subprocess.run(
        ["scripts/show_parity_preflight_status.sh", "--json"],
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )
    if proc.returncode != 0:
        add_result(case["name"], False, f"show_parity_preflight_status exit={proc.returncode}")
        continue
    try:
        payload = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        add_result(case["name"], False, f"invalid json: {exc}")
        continue

    mismatches = []
    for key, expected in case["expected"].items():
        actual = payload.get(key)
        if actual != expected:
            mismatches.append(f"{key} expected {expected!r}, got {actual!r}")

    env_payload = payload.get("env", {})
    for key in required_env_keys:
        if key not in env_payload:
            mismatches.append(f"missing env key {key!r}")

    if mismatches:
        add_result(case["name"], False, "; ".join(mismatches))
    else:
        add_result(case["name"], True, "status/env resolution matched")

invalid_cases = [
    (
        "gate_invalid_compact_without_json",
        {
            "SHOW_PARITY_PREFLIGHT_STATUS": "1",
            "SHOW_PARITY_PREFLIGHT_STATUS_COMPACT": "1",
        },
        "SHOW_PARITY_PREFLIGHT_STATUS_COMPACT=1 requires SHOW_PARITY_PREFLIGHT_STATUS=json",
    ),
    (
        "gate_invalid_compact_value",
        {
            "SHOW_PARITY_PREFLIGHT_STATUS": "json",
            "SHOW_PARITY_PREFLIGHT_STATUS_COMPACT": "bad",
        },
        "Invalid SHOW_PARITY_PREFLIGHT_STATUS_COMPACT=bad (expected 0 or 1)",
    ),
    (
        "gate_invalid_show_toggle_value",
        {
            "SHOW_PARITY_PREFLIGHT_STATUS": "bad",
        },
        "Invalid SHOW_PARITY_PREFLIGHT_STATUS=bad (expected 0, 1, or json)",
    ),
]

for name, overrides, expected_message in invalid_cases:
    env = os.environ.copy()
    env.update(overrides)
    proc = subprocess.run(
        ["scripts/test_parity_gates.sh"],
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )
    combined_output = f"{proc.stdout}\n{proc.stderr}"
    exit_ok = proc.returncode == 2
    message_ok = expected_message in combined_output
    ok = exit_ok and message_ok
    detail = f"exit={proc.returncode}, message_present={message_ok}"
    add_result(name, ok, detail)

payload = {
    "result": "fail" if failed else "pass",
    "checks": results,
}
if json_mode:
    print(json.dumps(payload, indent=2, sort_keys=False))
else:
    if failed:
        print("Parity preflight matrix smoke check failed.")
    else:
        print("Parity preflight matrix smoke check passed.")

if failed:
    sys.exit(1)
PY
