# Parity commands

```sh
# Full comparison and demo roundtrip/OpenXML tests.
scripts/test_parity_gates.sh

# Select the comparison scope and optional report summary.
scripts/test_semantic_parity.sh --profile full
scripts/test_semantic_parity.sh --profile fast --summary human
scripts/test_semantic_parity.sh --profile ultrafast
scripts/test_semantic_parity.sh --profile smoke --summary json

# Inspect configuration without generating workbooks.
scripts/test_semantic_parity.sh --list-scenarios
scripts/test_semantic_parity.sh --profile fast --dry-run-config

# Read an existing report or run demo tests separately.
python3 scripts/semantic_parity_report_summary.py _build/semantic_parity/report.json --top-slowest 3
scripts/test_demo_roundtrip.sh
scripts/check_parity_docs_refs.sh
```

`fast` selects `cf` and `controls`; `ultrafast` also skips OpenXML validation;
`smoke` additionally skips fingerprint regression. Prefer `full` for release
validation. `--json-report PATH` selects the report destination, with
`PARITY_JSON_REPORT` as its environment default. `--summary human|json` selects
summary output; advanced summary flags belong to the Python summary command.

`SHOW_PARITY_ENV=1` prints overrides. `SKIP_PARITY_FINGERPRINT_CHECK=1` skips only
the fingerprint regression. See [Excelize parity](excelize-parity.md) for the
comparison's coverage and fixture requirements.
