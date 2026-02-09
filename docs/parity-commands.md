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
scripts/check_parity_docs_refs.sh
scripts/check_parity_docs_wrapper_coverage.sh
scripts/show_parity_env.sh
scripts/show_parity_preflight_status.sh
scripts/show_parity_preflight_status.sh --json
python3 scripts/semantic_parity.py --list-scenarios
python3 scripts/semantic_parity.py --dry-run-config
```

## Common env toggles

```sh
PARITY_JSON_REPORT=/path/to/report.json
SKIP_PARITY_WRAPPER_PREFLIGHT=1
SKIP_PARITY_DOCS_PREFLIGHT=1
SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT=1
SEMANTIC_PARITY_ARGS='--skip-validate'
SEMANTIC_PARITY_SUMMARY_ARGS='--top-slowest 3'
REDACT_PARITY_SUMMARY=1
SHOW_PARITY_ENV=1
SKIP_PARITY_FINGERPRINT_CHECK=1
```

## Combined env patterns

```sh
# Fastest local sanity loop.
scripts/test_semantic_parity_ultrasmoke.sh

# Compact CI JSON output with fast parity options.
SEMANTIC_PARITY_ARGS='--skip-validate' \
SEMANTIC_PARITY_SUMMARY_ARGS='--top-slowest 1' \
scripts/test_semantic_parity_report_compact.sh --scenario cf --scenario controls --sort-scenarios

# Aggregate gate with preflights skipped (when externally guaranteed).
SKIP_PARITY_WRAPPER_PREFLIGHT=1 \
SKIP_PARITY_DOCS_PREFLIGHT=1 \
scripts/test_parity_gates.sh
```
