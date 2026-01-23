# Testing Plan

Goal: Add unit and end-to-end tests to protect key Excelize-like behaviors before refactoring, and fix any bugs surfaced by tests.

## Scope

Primary focus:
- Public wrapper API (`mbtexcel.mbt`) surface coverage.
- XLSX read/write roundtrips for core workbook features.
- Regression tests for known tricky parts (styles, formulas, validations, merges, streams, encryption).

Secondary focus:
- Parsing and serialization of OOXML components (relationships, content types).
- Zip reader/writer integration and stream-based IO.

Out of scope for now:
- Performance benchmarking (track separately).
- Full Excelize parity gaps (track via issues).

## Test Inventory Targets

### Root package (wrapper API)
- Creation helpers: `new_workbook`, `new_file`.
- Read/write: `read`, `read_with_password`, `write`, `write_with_password`.
- IO wrappers: `open_file`, `open_reader`, `read_zip_reader`.
- Cell helpers: `split_cell_name`, `join_cell_name`, `cell_name_to_coordinates`, `coordinates_to_cell_name`.
- Column helpers: `column_name_to_number`, `column_number_to_name`.
- Time conversion: `excel_date_to_time` (+ 1904 format).
- Color helpers: `rgb_to_hsl`, `hsl_to_rgb`, `theme_color`.
- Error paths: invalid cell refs, invalid column/row, invalid password.

### XLSX package
- Workbook lifecycle: create sheets, rename, order, delete.
- Cell values: string, numeric, bool, error, rich text, inline strings.
- Formulas: set/get, calc chain, spill/dynamic arrays (minimal smoke).
- Styles: add, set/get, number formats, conditional styles.
- Row/col dimensions: style ranges, height/width, hidden, outline.
- Merges: add/remove and read back.
- Hyperlinks: external and location, shift after insert.
- Data validation: list and range, delete by sqref, read back.
- Tables, pivots, charts: basic write/read presence.
- Images: insert/read size, header/footer images.
- Encryption: write/read with password.
- Options: unzip limits, raw cell values, culture formatting.
- Stream writer: column styles, row options, row order, close state.

### OOXML / ZIP packages
- Content types: add/update, roundtrip.
- Relationships: add/update, resolve targets.
- ZIP: read/write, crc, deflate, data descriptors.

## End-to-End Scenarios

- Multi-sheet workbook with:
  - values (mixed types),
  - styles,
  - formulas,
  - merges,
  - data validations,
  - hyperlinks,
  - tables/sparklines (smoke),
  - save and re-open.
- Encrypted workbook save + open with correct/incorrect password.
- Stream write + read back values/styles.
- Reader/pipe IO (`open_reader`, `read_zip_reader`) + write-to-writer.

## Regression & Negative Tests

- Invalid sheet name and duplicate sheet name.
- Invalid cell reference, invalid range refs.
- Invalid style id, invalid data validation length.
- Unsupported/invalid encryption info.
- XML parsing errors (missing required tags).

## Tooling & Commands

- `moon check`
- `moon info`
- `moon fmt`
- `moon test --filter "mbtexcel*"` for focused wrapper tests
- `moon test` (full suite)
- `moon test --update` when snapshots change
- `moon coverage analyze` (target: >= 90% overall coverage)
- For long-running tests, consider `#skip` and run a final pass with `--include-skipped`.

## Todo Tracking (testing-plan.md only)

- Keep all follow-up items in this file.
- Do **not** use `bd` for tracking.

## Checklist

Discovery and planning
- [x] Audit existing tests/fixtures and identify gaps (wrapper APIs, error paths, roundtrips).
- [x] Write this plan and keep it updated.

Wrapper coverage
- [x] Add unit tests for top-level wrapper APIs and edge/error cases.
- [x] Add IO wrapper tests (`open_file`, `open_reader`, `read_zip_reader`).

E2E coverage
- [x] Add e2e tests covering multi-sheet + formulas + styles + merges + validations.
- [x] Add e2e test for hyperlinks/table/sparkline smoke.
- [x] Add e2e test for stream writer roundtrip.
- [x] Add e2e test for encrypted workbook roundtrip via wrappers.

XLSX package gaps
- [x] Add explicit tests for workbook/sheet ops (rename, delete, reorder).
- [x] Add tests for row/col style ranges and hidden flags.
- [x] Add tests for image/header-footer image roundtrip.
- [x] Add tests for options (raw cell values, unzip limits).

Quality gates
- [x] Run `moon check`.
- [x] Run `moon info`.
- [x] Run `moon fmt`.
- [x] Run `moon test --filter "mbtexcel*"`.
- [ ] Run full `moon test` (takes >300s locally; pending).
- [ ] Run `moon coverage analyze` and confirm >= 90% overall coverage.

Bug fixes
- [x] Fix bugs discovered by tests (data validations were not parsed on read).

Hygiene
- [x] Commit and push changes in logical chunks.
- [ ] Track long-running full test suite in this plan (no external issue).

## Notes

- Full `moon test` timed out locally after 300s; filtered tests pass.
- `gh issue create` and `gh api` hung/timed out when trying to file the issue.
- `moon coverage analyze` timed out at 300s; `moon coverage analyze -p .` timed out at 120s. Rerun with smaller scope or longer timeout.
- Conditional formats are not parsed on read yet; e2e test verifies XML output instead.

## Current Todo (Active)

- [ ] Run full `moon test` (use `#skip` for known long tests, then finalize with `--include-skipped`).
- [ ] Run `moon coverage analyze` and confirm >= 90% overall coverage.
