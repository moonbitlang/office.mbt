# Parity Command Index

Quick command index for parity-related workflows.

## Core gates

```sh
scripts/test_parity_gates.sh
scripts/test_semantic_parity.sh
scripts/test_demo_roundtrip.sh
```

## Fast loops

```sh
scripts/test_semantic_parity_fast.sh
scripts/test_semantic_parity_ultrafast.sh
scripts/test_semantic_parity_ultrasmoke.sh
```

## Report flows

```sh
scripts/test_semantic_parity_report.sh
scripts/test_semantic_parity_report_compact.sh
python3 scripts/semantic_parity_report_summary.py _build/semantic_parity/report.json
```

## Diagnostics helpers

```sh
scripts/check_parity_wrappers.sh
scripts/check_parity_wrappers.sh --json
scripts/show_parity_env.sh
python3 scripts/semantic_parity.py --list-scenarios
python3 scripts/semantic_parity.py --dry-run-config
```

## Common env toggles

```sh
PARITY_JSON_REPORT=/path/to/report.json
SKIP_PARITY_WRAPPER_PREFLIGHT=1
SEMANTIC_PARITY_ARGS='--skip-validate'
SEMANTIC_PARITY_SUMMARY_ARGS='--top-slowest 3'
REDACT_PARITY_SUMMARY=1
SHOW_PARITY_ENV=1
SKIP_PARITY_FINGERPRINT_CHECK=1
```
