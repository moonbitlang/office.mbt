#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

json_output="$(scripts/show_parity_preflight_status.sh --json)"
PARITY_PREFLIGHT_JSON="$json_output" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["PARITY_PREFLIGHT_JSON"])
required_keys = [
    "wrapper_preflight",
    "env_helper_preflight",
    "preflight_status_helper_preflight",
    "gate_toggle_consistency_preflight",
    "gate_toggle_contract_preflight",
    "gate_show_toggle_contract_preflight",
    "docs_preflight",
    "docs_wrapper_coverage_preflight",
    "env",
]
missing = [k for k in required_keys if k not in payload]
if missing:
    raise SystemExit(f"missing keys in preflight status json output: {missing}")
env = payload["env"]
required_env = [
    "SKIP_PARITY_WRAPPER_PREFLIGHT",
    "SKIP_PARITY_ENV_HELPER_PREFLIGHT",
    "SKIP_PARITY_PREFLIGHT_STATUS_HELPER_PREFLIGHT",
    "SKIP_PARITY_GATE_TOGGLE_PREFLIGHT",
    "SKIP_PARITY_GATE_TOGGLE_CONTRACT_PREFLIGHT",
    "SKIP_PARITY_GATE_SHOW_TOGGLE_PREFLIGHT",
    "SKIP_PARITY_DOCS_PREFLIGHT",
    "SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT",
]
missing_env = [k for k in required_env if k not in env]
if missing_env:
    raise SystemExit(f"missing env keys in preflight status json output: {missing_env}")
PY

compact_output="$(scripts/show_parity_preflight_status.sh --json --compact)"
PARITY_PREFLIGHT_COMPACT_JSON="$compact_output" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["PARITY_PREFLIGHT_COMPACT_JSON"])
required_keys = [
    "wrapper_preflight",
    "env_helper_preflight",
    "preflight_status_helper_preflight",
    "gate_toggle_consistency_preflight",
    "gate_toggle_contract_preflight",
    "gate_show_toggle_contract_preflight",
    "docs_preflight",
    "docs_wrapper_coverage_preflight",
    "env",
]
missing = [k for k in required_keys if k not in payload]
if missing:
    raise SystemExit(f"missing keys in compact preflight status json output: {missing}")
PY

overridden_output="$(
  SKIP_PARITY_WRAPPER_PREFLIGHT=1 \
  SKIP_PARITY_ENV_HELPER_PREFLIGHT=1 \
  SKIP_PARITY_PREFLIGHT_STATUS_HELPER_PREFLIGHT=1 \
  SKIP_PARITY_GATE_TOGGLE_PREFLIGHT=1 \
  SKIP_PARITY_GATE_TOGGLE_CONTRACT_PREFLIGHT=1 \
  SKIP_PARITY_GATE_SHOW_TOGGLE_PREFLIGHT=1 \
  SKIP_PARITY_DOCS_PREFLIGHT=1 \
  SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT=1 \
  scripts/show_parity_preflight_status.sh --json
)"
PARITY_PREFLIGHT_OVERRIDDEN_JSON="$overridden_output" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["PARITY_PREFLIGHT_OVERRIDDEN_JSON"])
if payload["wrapper_preflight"] != "skipped":
    raise SystemExit("wrapper_preflight did not resolve to skipped")
if payload["env_helper_preflight"] != "skipped":
    raise SystemExit("env_helper_preflight did not resolve to skipped")
if payload["preflight_status_helper_preflight"] != "skipped":
    raise SystemExit("preflight_status_helper_preflight did not resolve to skipped")
if payload["gate_toggle_consistency_preflight"] != "skipped":
    raise SystemExit("gate_toggle_consistency_preflight did not resolve to skipped")
if payload["gate_toggle_contract_preflight"] != "skipped":
    raise SystemExit("gate_toggle_contract_preflight did not resolve to skipped")
if payload["gate_show_toggle_contract_preflight"] != "skipped":
    raise SystemExit("gate_show_toggle_contract_preflight did not resolve to skipped")
if payload["docs_preflight"] != "skipped":
    raise SystemExit("docs_preflight did not resolve to skipped")
if payload["docs_wrapper_coverage_preflight"] != "n/a (docs preflight skipped)":
    raise SystemExit("docs_wrapper_coverage_preflight did not resolve to n/a (docs preflight skipped)")
PY

set +e
compact_without_json_output="$(scripts/show_parity_preflight_status.sh --compact 2>&1)"
compact_without_json_code=$?
set -e
if [[ $compact_without_json_code -ne 2 ]]; then
  echo "Expected exit code 2 for --compact without --json, got ${compact_without_json_code}"
  exit 1
fi
if ! rg -Fq "Usage: scripts/show_parity_preflight_status.sh [--json [--compact]]" <<<"$compact_without_json_output"; then
  echo "show_parity_preflight_status compact-without-json usage message mismatch."
  exit 1
fi

set +e
invalid_output="$(scripts/show_parity_preflight_status.sh --nope 2>&1)"
invalid_code=$?
set -e
if [[ $invalid_code -ne 2 ]]; then
  echo "Expected exit code 2 for invalid args, got ${invalid_code}"
  exit 1
fi
if ! rg -Fq "Usage: scripts/show_parity_preflight_status.sh [--json [--compact]]" <<<"$invalid_output"; then
  echo "show_parity_preflight_status invalid-arg usage message mismatch."
  exit 1
fi

echo "Parity preflight status helper regression check passed."
