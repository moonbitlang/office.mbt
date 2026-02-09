#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -ne 0 ]]; then
  echo "Usage: scripts/check_parity_preflight_matrix_smoke_contract_x62.sh"
  exit 2
fi

python3 - <<'PY'
import json
import subprocess
import sys
from pathlib import Path

results = []
failed = False


def add_result(name: str, ok: bool, detail: str) -> None:
    global failed
    results.append((name, ok, detail))
    if not ok:
        failed = True
    marker = "[PASS]" if ok else "[FAIL]"
    print(f"{marker} {name}: {detail}")


gate_source = Path("scripts/test_parity_gates.sh").read_text(encoding="utf-8")
required_patterns = [
    "SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT",
    "parity preflight matrix smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract preflight",
    "scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh",
]
for pattern in required_patterns:
    ok = pattern in gate_source
    detail = "present" if ok else "missing"
    add_result(f"required_pattern::{pattern}", ok, detail)

json_proc = subprocess.run(
    ["scripts/check_parity_preflight_matrix_smoke_contract_x61.sh", "--json"],
    capture_output=True,
    text=True,
    check=False,
)
if json_proc.returncode != 0:
    add_result(
        "matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_json_invocation",
        False,
        f"exit={json_proc.returncode}",
    )
else:
    try:
        payload = json.loads(json_proc.stdout)
    except json.JSONDecodeError as exc:
        add_result(
            "matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_json_parse",
            False,
            f"invalid json: {exc}",
        )
        payload = None
    if payload is not None:
        top_level_ok = (
            "result" in payload
            and payload["result"] in ("pass", "fail")
            and "checks" in payload
            and isinstance(payload["checks"], list)
        )
        add_result(
            "matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_json_top_level",
            top_level_ok,
            "validated",
        )

        required_checks = {
            "required_pattern::SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT",
            "required_pattern::parity preflight matrix smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract preflight",
            "required_pattern::scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh",
            "matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_json_top_level",
            "matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_json_entry_schema",
            "matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_json_required_checks",
            "matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_invalid_arg_usage",
        }
        seen_checks = set()
        entry_schema_ok = True
        for entry in payload.get("checks", []):
            for key in ("check", "ok", "detail"):
                if key not in entry:
                    entry_schema_ok = False
            if not isinstance(entry.get("check"), str):
                entry_schema_ok = False
            if not isinstance(entry.get("ok"), bool):
                entry_schema_ok = False
            if not isinstance(entry.get("detail"), str):
                entry_schema_ok = False
            if isinstance(entry.get("check"), str):
                seen_checks.add(entry["check"])
        add_result(
            "matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_json_entry_schema",
            entry_schema_ok,
            "validated",
        )

        missing_checks = sorted(required_checks - seen_checks)
        required_checks_ok = not missing_checks
        detail = "all required checks present"
        if missing_checks:
            detail = f"missing checks: {missing_checks}"
        add_result(
            "matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_json_required_checks",
            required_checks_ok,
            detail,
        )

invalid_proc = subprocess.run(
    ["scripts/check_parity_preflight_matrix_smoke_contract_x61.sh", "--bad"],
    capture_output=True,
    text=True,
    check=False,
)
invalid_output = f"{invalid_proc.stdout}\n{invalid_proc.stderr}"
invalid_ok = (
    invalid_proc.returncode == 2
    and "Usage: scripts/check_parity_preflight_matrix_smoke_contract_x61.sh [--json]"
    in invalid_output
)
add_result(
    "matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_invalid_arg_usage",
    invalid_ok,
    f"exit={invalid_proc.returncode}",
)

if failed:
    print("Parity preflight matrix smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker contract check failed.")
else:
    print("Parity preflight matrix smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker contract check passed.")

if failed:
    sys.exit(1)
PY
