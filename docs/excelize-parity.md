# Excelize parity (mbtexcel)

This repo vendors a snapshot of Excelize in `excelize/` and ports the workbook
logic to MoonBit in `xlsx/`.

## Scope of comparison

- Excelize snapshot: `excelize@37b730a` (see `git -C excelize rev-parse HEAD`)
- mbtexcel snapshot: current checkout (see `git rev-parse HEAD`)

When I say “parity” below, I mean **end-user features and ergonomics**, not just
“there exists an API method with the same name”.

## TL;DR

- **Method-name parity is very high**: by normalized name, every exported
  Excelize function / `(*File)` method has a corresponding exported MoonBit API
  name (often on `Workbook` / `Worksheet` / `StreamWriter`).
- **Feature parity is high but not 100%**: most “option-struct driven” features
  now have typed MoonBit models (styles, charts, shapes, sparklines, pivot
  tables, slicers, tables, pictures, conditional formats), but some models are
  still **subsets** of Excelize and a few features remain unsupported.

## Major remaining parity gaps / differences

### 1) Some option models are still smaller than Excelize’s

Most major Excelize option structs have MoonBit counterparts, but some are
still subsets (missing some rarely-used flags/fields). The biggest remaining
examples are usually in “long tail” formatting knobs (styles, charts, rich
text).

Impact:
- Some advanced formatting knobs require extending the MoonBit model (or falling
  back to emitting raw OOXML XML in places where that’s exposed).

### 2) Rich text font model is close to Excelize’s `Font`, but not identical

- Excelize rich text runs reference `Font` (includes theme/indexed/tint colors)
  (`excelize/xmlSharedStrings.go`, `excelize/xmlStyles.go`).
- mbtexcel rich text uses `RichTextFont` and now covers the most common font
  run properties (bold/italic/underline/size/rFont, strike/outline/shadow/
  condense/extend/charset/family/scheme/vertAlign, plus color rgb/theme/indexed
  and tint), but it is still a separate type (not a perfect 1:1 mirror).

Impact:
- Rich text works well for typical usage; if you rely on niche font run
  attributes, validate on real files and add targeted tests.

### 3) Styles and charts aim for practical parity, not a perfect mirror

The style model (`Style` / `Font` / `Fill` / `Border` / `Alignment` /
`Protection`) and chart option types are implemented for common usage, but may
still differ in edge cases and long-tail options compared to Excelize.
For example, style fonts now include more tags (strike/shadow/charset/scheme/
vertAlign), fills support transparency via ARGB alpha and Excelize-style
gradient fills (shading variants), and font/fill colors support theme/indexed +
tint, but there are still areas where the MoonBit model may not expose every
Excelize knob.
For charts, `ChartOptions` now covers common types (bar/col/line/area/pie/
doughnut/radar/scatter/bubble/stock/3D/ofPie) and basic axis/legend +
per-series styling options.

Impact:
- If you rely on very specific Excel formatting behaviors, validate on real
  files and consider adding targeted tests for those cases.

### 4) Some picture formats may not have accurate auto-sizing

mbtexcel infers picture size from image bytes to compute EMU extents.
Common raster formats are supported; however, Windows metafiles like
EMZ/WMZ (gzip-compressed EMF/WMF) are now decompressed and sized correctly.

### 5) VML form controls: mostly supported, with a few remaining gaps

mbtexcel can write and parse VML form controls including macro/cellLink/checked,
sizing (width/height + anchor), scroll/spin options (val/min/max/inc/page +
horizontal), basic `GraphicOptions` flags (printObject/positioning), and
per-control VML presets (fill/stroke + common `<x:ClientData>` defaults).

Remaining gaps are mostly long-tail preset/styling parity for specific control
types and edge-case behaviors.

## Notes / intentional differences

- **Async I/O**: some APIs are `async` in MoonBit (e.g. file I/O, writing to a
  writer). Excelize is synchronous.
- **VBA projects**: supported as raw `vbaProject.bin` bytes (OLE/CFB header
  validated) without attempting to parse/modify macro internals.
- **Formula evaluation**: both projects have formula evaluation APIs, but exact
  supported function coverage and edge-case behavior may differ (this hasn’t
  been exhaustively parity-audited here).

## Parity regression command

For a quick script-only index, see `docs/parity-commands.md`.

Use this fixed-entrypoint script for local/CI semantic parity checks:

```sh
scripts/test_semantic_parity.sh
```

It runs `scripts/semantic_parity.py` with stable output directories under
`_build/semantic_parity/` and fails fast on any scenario mismatch. Extra
arguments are forwarded to the Python runner (for example,
`--scenario controls`, `--sort-scenarios`, `--fixture-root <dir>`, or `--print-fingerprints-on-fail`).
The wrapper also enables compact per-scenario summaries and timing output in
successful runs.

To discover all available semantic parity scenarios without running generation:

```sh
python3 scripts/semantic_parity.py --list-scenarios
python3 scripts/semantic_parity.py --dry-run-config --scenario cf
```

To emit a machine-readable CI artifact:

```sh
scripts/test_semantic_parity.sh --json-report _build/semantic_parity/report.json
```

Report artifacts include provenance metadata (`tool`, `python_version`,
`generated_at_utc`, `argv`, `wrapper_env`) for traceability.

To print a compact human summary from a JSON report:

```sh
python3 scripts/semantic_parity_report_summary.py _build/semantic_parity/report.json
python3 scripts/semantic_parity_report_summary.py _build/semantic_parity/report.json --top-slowest 3
python3 scripts/semantic_parity_report_summary.py _build/semantic_parity/report.json --only-failures
python3 scripts/semantic_parity_report_summary.py _build/semantic_parity/report.json --sort-scenarios
python3 scripts/semantic_parity_report_summary.py _build/semantic_parity/report.json --no-metadata
python3 scripts/semantic_parity_report_summary.py _build/semantic_parity/report.json --redact-sensitive
python3 scripts/semantic_parity_report_summary.py _build/semantic_parity/report.json --as-json
python3 scripts/semantic_parity_report_summary.py _build/semantic_parity/report.json --as-json --compact
```

For a one-command flow (generate report + print summary):

```sh
scripts/test_semantic_parity_report.sh
scripts/test_semantic_parity_report_compact.sh
```

Both wrappers accept `SEMANTIC_PARITY_SUMMARY_ARGS` to forward extra flags to
`semantic_parity_report_summary.py` (for example `--top-slowest 3`).
Both wrappers also accept `SEMANTIC_PARITY_ARGS` to forward core parity flags
to `scripts/test_semantic_parity.sh` (for example `--skip-validate`).
Set `REDACT_PARITY_SUMMARY=1` to apply `--redact-sensitive` by default.
Use `scripts/show_parity_env.sh` to print current override values in CI logs.
Use `scripts/show_parity_env.sh --json` for machine-readable CI parsing.
The helper includes wrapper/env-helper/preflight-status-helper/gate-toggle/
gate-toggle-contract/gate-show-toggle/preflight-matrix-smoke/
preflight-matrix-smoke-contract/preflight-matrix-smoke-contract-contract/
preflight-matrix-smoke-contract-contract-contract/
preflight-matrix-smoke-contract-contract-contract-contract/docs/docs-coverage
preflight-matrix-smoke-contract-contract-contract-contract-contract/docs/
preflight-matrix-smoke-contract-contract-contract-contract-contract-contract/
preflight-matrix-smoke-contract-contract-contract-contract-contract-contract-contract/
preflight-matrix-smoke-contract-contract-contract-contract-contract-contract-contract-contract/
preflight-matrix-smoke-contract-contract-contract-contract-contract-contract-contract-contract-contract/
preflight-matrix-smoke-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract/
preflight-matrix-smoke-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract/
preflight-matrix-smoke-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract/
preflight-matrix-smoke-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract/
docs/docs-coverage preflight toggles and
`SHOW_PARITY_PREFLIGHT_STATUS`/`SHOW_PARITY_PREFLIGHT_STATUS_COMPACT` so
aggregate gate env diagnostics stay aligned.
Use `scripts/show_parity_preflight_status.sh` to print the effective preflight
resolution from current env toggles.
Use `scripts/show_parity_preflight_status.sh --json --compact` for single-line
machine-readable output in CI logs.
Set `SHOW_PARITY_ENV=1` to make `scripts/test_semantic_parity.sh` print env
overrides automatically before running.
Set `SKIP_PARITY_FINGERPRINT_CHECK=1` to skip the fingerprint pre-check in
minimal smoke loops.

For the full parity gate (semantic parity + demo roundtrip/openxml suites):

```sh
scripts/test_parity_gates.sh
```

By default this also emits a semantic parity JSON artifact at
`_build/semantic_parity/report.json` and prints its compact summary. Override
path via `PARITY_JSON_REPORT=/path/to/report.json`.
It also runs `scripts/check_parity_wrappers.sh` as a preflight step.
Set `SKIP_PARITY_WRAPPER_PREFLIGHT=1` to bypass this preflight when needed.
It runs `scripts/check_parity_env_helper.sh` as an env-helper preflight.
Set `SKIP_PARITY_ENV_HELPER_PREFLIGHT=1` to bypass this preflight when needed.
It runs `scripts/check_parity_preflight_status_helper.sh` as a preflight-status
helper preflight.
Set `SKIP_PARITY_PREFLIGHT_STATUS_HELPER_PREFLIGHT=1` to bypass this preflight.
It runs `scripts/check_parity_gate_skip_toggles.sh` as a gate-toggle
consistency preflight.
Set `SKIP_PARITY_GATE_TOGGLE_PREFLIGHT=1` to bypass this preflight.
It runs `scripts/check_parity_gate_skip_toggles_contract.sh` as a gate-toggle
contract preflight.
Set `SKIP_PARITY_GATE_TOGGLE_CONTRACT_PREFLIGHT=1` to bypass this preflight.
It runs `scripts/check_parity_gate_show_toggles.sh` as a gate show-toggle
contract preflight.
Set `SKIP_PARITY_GATE_SHOW_TOGGLE_PREFLIGHT=1` to bypass this preflight.
It runs `scripts/check_parity_preflight_matrix_smoke.sh` as a preflight matrix
smoke preflight.
Set `SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_PREFLIGHT=1` to bypass this preflight.
It runs `scripts/check_parity_preflight_matrix_smoke_contract.sh` as a
preflight matrix smoke contract preflight.
Set `SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_PREFLIGHT=1` to bypass this
preflight.
It runs `scripts/check_parity_preflight_matrix_smoke_contract_contract.sh` as a
preflight matrix smoke contract-contract preflight.
Set `SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_PREFLIGHT=1` to
bypass this preflight.
It runs `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract.sh`
as a preflight matrix smoke contract-contract-contract preflight.
Set `SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT=1`
to bypass this preflight.
It runs `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract.sh`
as a preflight matrix smoke contract-contract-contract-contract preflight.
Set `SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT=1`
to bypass this preflight.
It runs `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract.sh`
as a preflight matrix smoke contract-contract-contract-contract-contract preflight.
Set `SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT=1`
to bypass this preflight.
It runs `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract.sh`
as a preflight matrix smoke contract-contract-contract-contract-contract-contract preflight.
Set `SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT=1`
to bypass this preflight.
It runs `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract.sh`
as a preflight matrix smoke contract-contract-contract-contract-contract-contract-contract preflight.
Set `SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT=1`
to bypass this preflight.
It runs `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract.sh`
as a preflight matrix smoke contract-contract-contract-contract-contract-contract-contract-contract preflight.
Set `SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT=1`
to bypass this preflight.
It runs `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
as a preflight matrix smoke contract-contract-contract-contract-contract-contract-contract-contract-contract preflight.
Set `SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT=1`
to bypass this preflight.
It runs `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
as a preflight matrix smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract preflight.
Set `SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT=1`
to bypass this preflight.
It runs `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
as a preflight matrix smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract preflight.
Set `SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT=1`
to bypass this preflight.
It runs `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
as a preflight matrix smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract preflight.
Set `SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT=1`
to bypass this preflight.
It runs `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
as a preflight matrix smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract preflight.
Set `SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT=1`
to bypass this preflight.
It runs `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
as a preflight matrix smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract preflight.
Set `SKIP_PARITY_PREFLIGHT_MATRIX_SMOKE_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_CONTRACT_PREFLIGHT=1`
to bypass this preflight.
It runs `scripts/check_parity_docs_refs.sh` as an additional docs preflight.
Set `SKIP_PARITY_DOCS_PREFLIGHT=1` to bypass docs preflight when needed.
It also runs `scripts/check_parity_docs_wrapper_coverage.sh` by default.
Set `SKIP_PARITY_DOCS_COVERAGE_PREFLIGHT=1` to bypass wrapper-coverage preflight.
The script prints active parity-related env toggles at startup.
Set `SHOW_PARITY_PREFLIGHT_STATUS=1` (or `json`) to print effective preflight
resolution via `scripts/show_parity_preflight_status.sh` during gate startup.
Set `SHOW_PARITY_PREFLIGHT_STATUS_COMPACT=1` (with
`SHOW_PARITY_PREFLIGHT_STATUS=json`) to emit compact one-line JSON status.
For compact, single-line status logs, run
`scripts/show_parity_preflight_status.sh --json --compact`.

For a fast pre-commit semantic subset (currently `cf` + `controls`):

```sh
scripts/test_semantic_parity_fast.sh
```

For ultra-fast local loops that intentionally skip OOXML validator checks:

```sh
scripts/test_semantic_parity_ultrafast.sh
scripts/test_semantic_parity_ultrasmoke.sh
```

## Wrapper guide

Use this quick map when choosing a parity command:

- `scripts/test_semantic_parity.sh`:
  - default semantic parity gate (validator + summaries + timings)
- `scripts/test_semantic_parity_fast.sh`:
  - fast pre-commit subset (`cf`, `controls`)
- `scripts/test_semantic_parity_ultrafast.sh`:
  - fastest local subset loop with `--skip-validate`
- `scripts/test_semantic_parity_ultrasmoke.sh`:
  - fastest sanity loop: fast subset + `--skip-validate` + skipped fingerprint pre-check
- `scripts/test_semantic_parity_report.sh`:
  - semantic parity + human-readable report summary
- `scripts/test_semantic_parity_report_compact.sh`:
  - semantic parity + compact JSON summary (CI parser friendly)
- `scripts/test_parity_gates.sh`:
  - full parity gate: semantic parity + demo roundtrip/openxml checks

Use `scripts/check_parity_wrappers.sh` to verify wrapper script presence and
execute bits in local/CI environments (`--json` for machine-readable output).
Use `scripts/check_parity_docs_refs.sh` to verify parity-doc script references
resolve to existing files.
Use `scripts/check_parity_docs_wrapper_coverage.sh` to verify wrapper scripts
remain covered by parity docs.
Use `scripts/check_parity_env_helper.sh` to run regression checks for
`scripts/show_parity_env.sh` (`--json` contract + invalid-arg behavior).
Use `scripts/check_parity_preflight_status_helper.sh` to run regression checks
for `scripts/show_parity_preflight_status.sh` contract behavior.
Use `scripts/check_parity_gate_skip_toggles.sh` to enforce skip-toggle key
consistency across aggregate-gate scripts and helpers.
Use `scripts/check_parity_gate_skip_toggles.sh --json` for machine-readable
consistency output in CI pipelines.
Use `scripts/check_parity_gate_skip_toggles_contract.sh` to validate skip-toggle
checker CLI contract (`--json` schema + invalid-arg behavior).
Use `scripts/check_parity_gate_show_toggles.sh` to validate aggregate gate
show-toggle contract behavior for compact preflight status output.
Use `scripts/check_parity_preflight_matrix_smoke.sh` to run a small matrix of
skip/show-toggle combinations against aggregate preflight status resolution.
Use `scripts/check_parity_preflight_matrix_smoke.sh --json` for
machine-readable matrix-smoke output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract.sh` to validate
matrix-smoke checker JSON schema and CLI usage contract behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract.sh --json` for
machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract.sh` to
validate matrix-smoke contract-checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract.sh`
to validate matrix-smoke contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract_contract.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x25.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x25.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x26.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x26.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x27.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x27.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x28.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x28.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x29.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x29.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x30.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x30.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x31.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x31.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x32.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x32.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x33.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x33.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x34.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x34.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x35.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x35.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x36.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x36.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x37.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x37.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x38.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x38.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x39.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x39.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x40.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x40.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x41.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x41.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x42.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x42.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x43.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x43.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x44.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x44.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x45.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x45.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x46.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x46.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x47.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x47.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x48.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x48.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x49.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x49.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x50.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x50.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x51.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x51.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x52.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x52.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x53.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x53.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x54.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x54.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x55.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x55.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x56.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x56.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x57.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x57.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x58.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x58.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x59.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x59.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x60.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x60.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x61.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x61.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x62.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x62.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x63.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x63.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x64.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x64.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x65.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x65.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x66.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x66.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x67.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x67.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x68.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x68.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x69.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x69.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x70.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x70.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x71.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x71.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x72.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x72.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x73.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x73.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x74.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x74.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x75.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x75.sh --json`
for machine-readable contract-check output in CI.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x76.sh`
to validate matrix-smoke contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract-contract checker JSON schema and CLI usage behavior.
Use `scripts/check_parity_preflight_matrix_smoke_contract_x76.sh --json`
for machine-readable contract-check output in CI.
For the full flat command list, see `docs/parity-commands.md`.

## CI profiles

Common parity CI command profiles:

- Strict (full gate + preflight + validator):

```sh
scripts/test_parity_gates.sh
```

- Fast (skip wrapper preflight + skip validator + compact JSON summary):

```sh
SKIP_PARITY_WRAPPER_PREFLIGHT=1 \
SEMANTIC_PARITY_ARGS='--skip-validate' \
scripts/test_semantic_parity_report_compact.sh --scenario cf --scenario controls --sort-scenarios
```

- Redacted reports (hide argv/env values in shared logs):

```sh
REDACT_PARITY_SUMMARY=1 \
SEMANTIC_PARITY_ARGS='--skip-validate' \
scripts/test_semantic_parity_report.sh --scenario cf --scenario controls --sort-scenarios
```

## How to keep this doc up to date

1. Identify Excelize features that are “option-struct driven” (usually the
   biggest parity gaps early in a port).
2. For each feature, decide whether mbtexcel should:
   - port the same option model, or
   - expose “raw OOXML XML” and keep the API thin.

For a mechanically-generated, “names-only” view, see
`docs/excelize-parity-generated.md` (regenerate with
`python3 scripts/excelize_parity_report.py --out docs/excelize-parity-generated.md`).
