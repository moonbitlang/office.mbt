#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

profile=full
summary=none
report="${PARITY_JSON_REPORT:-_build/semantic_parity/report.json}"
inspect_only=0
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile|--summary|--json-report)
      [[ $# -ge 2 ]] || { echo "$1 requires a value" >&2; exit 2; }
      case "$1" in
        --profile) profile="$2" ;;
        --summary) summary="$2" ;;
        --json-report) report="$2" ;;
      esac
      shift 2
      ;;
    --help|-h)
      printf 'Wrapper options: --profile full|fast|ultrafast|smoke --summary none|human|json\n'
      exec python3 scripts/semantic_parity.py --help
      ;;
    --list-scenarios|--dry-run-config)
      inspect_only=1
      args+=("$1")
      shift
      ;;
    *) args+=("$1"); shift ;;
  esac
done
case "$profile" in
  full) ;;
  fast|ultrafast|smoke)
    args=(--scenario cf --scenario controls --sort-scenarios ${args[@]+"${args[@]}"})
    if [[ "$profile" != fast ]]; then args+=(--skip-validate); fi
    ;;
  *) echo "Unknown parity profile: $profile" >&2; exit 2 ;;
esac
case "$summary" in none|human|json) ;; *) echo "Unknown summary mode: $summary" >&2; exit 2 ;; esac

if [[ "$inspect_only" == 1 ]]; then
  exec python3 scripts/semantic_parity.py --json-report "$report" ${args[@]+"${args[@]}"}
fi
if [[ "${SHOW_PARITY_ENV:-0}" == 1 ]]; then
  printf 'Parity configuration: profile=%s summary=%s report=%s\n' "$profile" "$summary" "$report"
fi
if [[ "$profile" != smoke && "${SKIP_PARITY_FINGERPRINT_CHECK:-0}" != 1 ]]; then
  python3 scripts/semantic_parity_fingerprint_test.py
fi

MBT_DIR="_build/semantic_parity/mbt"
EXCELIZE_DIR="_build/semantic_parity/excelize"
rm -rf "$MBT_DIR" "$EXCELIZE_DIR"
python3 scripts/semantic_parity.py \
  --mbt-dir "$MBT_DIR" --excelize-dir "$EXCELIZE_DIR" \
  --print-summary --print-durations --json-report "$report" \
  ${args[@]+"${args[@]}"}

case "$summary" in
  human) python3 scripts/semantic_parity_report_summary.py "$report" ;;
  json) python3 scripts/semantic_parity_report_summary.py "$report" --as-json --compact ;;
esac
