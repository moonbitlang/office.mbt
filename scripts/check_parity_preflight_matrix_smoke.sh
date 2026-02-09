#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
import json
import os
import subprocess
import sys

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
    "SKIP_PARITY_DOCS_PREFLIGHT",
    "SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT",
]

failed = False
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
        print(f"[FAIL] {case['name']} returned {proc.returncode}")
        print(proc.stdout.strip())
        print(proc.stderr.strip())
        failed = True
        continue
    try:
        payload = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        print(f"[FAIL] {case['name']} emitted invalid json: {exc}")
        failed = True
        continue

    mismatches = []
    for key, expected in case["expected"].items():
        actual = payload.get(key)
        if actual != expected:
            mismatches.append(f"{key}: expected {expected!r}, got {actual!r}")

    env_payload = payload.get("env", {})
    for key in required_env_keys:
        if key not in env_payload:
            mismatches.append(f"missing env key {key!r}")

    if mismatches:
        print(f"[FAIL] {case['name']}")
        for item in mismatches:
            print(f"  - {item}")
        failed = True
    else:
        print(f"[PASS] {case['name']}")

if failed:
    raise SystemExit(1)
PY

set +e
compact_without_json_output="$(SHOW_PARITY_PREFLIGHT_STATUS=1 SHOW_PARITY_PREFLIGHT_STATUS_COMPACT=1 scripts/test_parity_gates.sh 2>&1)"
compact_without_json_code=$?
set -e
if [[ $compact_without_json_code -ne 2 ]]; then
  echo "Expected exit code 2 for compact-without-json combo, got ${compact_without_json_code}"
  exit 1
fi
if ! rg -Fq "SHOW_PARITY_PREFLIGHT_STATUS_COMPACT=1 requires SHOW_PARITY_PREFLIGHT_STATUS=json" <<<"$compact_without_json_output"; then
  echo "Missing compact-without-json guard message in test_parity_gates output."
  exit 1
fi

set +e
invalid_compact_value_output="$(SHOW_PARITY_PREFLIGHT_STATUS=json SHOW_PARITY_PREFLIGHT_STATUS_COMPACT=bad scripts/test_parity_gates.sh 2>&1)"
invalid_compact_value_code=$?
set -e
if [[ $invalid_compact_value_code -ne 2 ]]; then
  echo "Expected exit code 2 for invalid compact toggle value, got ${invalid_compact_value_code}"
  exit 1
fi
if ! rg -Fq "Invalid SHOW_PARITY_PREFLIGHT_STATUS_COMPACT=bad (expected 0 or 1)" <<<"$invalid_compact_value_output"; then
  echo "Missing invalid compact toggle message in test_parity_gates output."
  exit 1
fi

set +e
invalid_show_toggle_output="$(SHOW_PARITY_PREFLIGHT_STATUS=bad scripts/test_parity_gates.sh 2>&1)"
invalid_show_toggle_code=$?
set -e
if [[ $invalid_show_toggle_code -ne 2 ]]; then
  echo "Expected exit code 2 for invalid SHOW_PARITY_PREFLIGHT_STATUS value, got ${invalid_show_toggle_code}"
  exit 1
fi
if ! rg -Fq "Invalid SHOW_PARITY_PREFLIGHT_STATUS=bad (expected 0, 1, or json)" <<<"$invalid_show_toggle_output"; then
  echo "Missing invalid SHOW_PARITY_PREFLIGHT_STATUS message in test_parity_gates output."
  exit 1
fi

echo "Parity preflight matrix smoke check passed."
