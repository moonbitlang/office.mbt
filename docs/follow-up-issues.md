# Follow-up issues

These are non-blocking follow-ups discovered while investigating slow tests.

1. **Optimize ISO protection hashing**
   - Motivation: workbook/sheet protection tests are slow because `spinCount=100000` is intentionally expensive.
   - Potential improvement: avoid per-iteration buffer concatenation in `gen_iso_password_hash` by implementing incremental/streaming hashing (similar to `excelize/crypt.go`’s `hashing` function with `hash.Hash.Write`).

2. **Keep dynamic-array spill shape inference in sync**
   - The spill shape inference now short-circuits scalar functions and only computes shapes for functions that may spill.
   - If new array-returning functions are added later, the spill allowlist should be updated (tests should catch this, but it’s easy to miss in reviews).

3. **Combo chart long-tail parity**
   - Current combo chart support focuses on common CatAx/ValAx combos (e.g. column + line) with optional secondary Y axis.
   - Follow-ups: improve secondary-axis OOXML fidelity (delete/crosses/crossBetween) and expand edge-case coverage as needed.

4. **Semantic parity runner**
   - True “Excelize behavior parity” needs comparing outputs against a runnable Go Excelize (or porting more of Excelize’s Go test assertions 1:1).
   - This environment currently has no `go` toolchain, so the workflow is: build an API-by-API mapping report and iterate tests/behavior one-by-one.

5. **`xlsx/` coverage plan (95–98% target is large)**
   - Current `xlsx/` package coverage is ~80.75% (25277/31302).
   - Biggest remaining gaps are concentrated in `xlsx/formula_builtins.mbt`, `xlsx/formula_eval.mbt`, `xlsx/read.mbt`, `xlsx/write.mbt`, `xlsx/workbook.mbt`, and `xlsx/worksheet.mbt`.
   - Prefer black-box tests; many remaining uncovered lines appear to be defensive/unreachable branches (worth auditing and possibly simplifying).

6. **OpenXML validator failures on complex demo outputs (resolved: 2026-02-08)**
   - Fixed and regression-covered: chart child ordering/enum mapping, worksheet x14 conditional-format ext ordering, pivot cache references, and pivot/slicer XML schema shape.
   - `cmd/demos` outputs `dashboard.xlsx`, `combo_chart.xlsx`, `interactive_controls.xlsx`, and `pivot_slicer.xlsx` now validate with `scripts/validate_xlsx.sh`.

7. **Validator handling for encrypted demo workbooks (resolved: 2026-02-08)**
   - Added `scripts/validate_demos.sh` to validate the canonical `cmd/demos` output set and skip the encrypted demo using encrypted-shape detection (ZIP encrypted-package parts or encrypted container signatures).
   - This avoids false negatives from `secure_password.xlsx` when running bulk demo validation.

## Architecture refactor backlog

These are follow-ups discovered while reviewing the current package architecture
(see `docs/architecture.md` and `docs/architecture-improvements.md`).

Completed (already landed):

1. **Split IO helpers by subsystem (inside `xlsx/`)**
   - `xlsx/read_*.mbt` and `xlsx/write_*.mbt` extracted from the read/write hubs.

2. **Centralize OOXML string/fragment utilities + `.rels` parsing**
   - `xlsx/ooxml_utils.mbt` and `xlsx/ooxml_rels.mbt` added with unit tests.

3. **Extract pure crypto/hash + base64 into dedicated packages**
   - `crypto/` and `base64/` packages; `xlsx/` uses them via imports/wrappers.

4. **Split very large API/type hubs**
   - `xlsx/workbook_types.mbt`, `xlsx/worksheet_types.mbt`,
     `xlsx/formula_eval_types.mbt`, `xlsx/formula_parse.mbt`,
     `xlsx/formula_eval.mbt`, `xlsx/formula_builtins.mbt`.

Remaining follow-ups:

5. **Decouple IO configuration from `Workbook` (resolved: 2026-02-08)**
   - `Workbook` now stores a single `WorkbookIOContext` instead of separate
     `file_path`, `zip_writer`, and `charset_transcoder` fields.
   - Read/write/save flows use explicit IO-context plumbing end-to-end
     (`open_reader`, `open_file`, `Workbook::read_zip_reader`, write wrappers,
     and save paths).

6. **Introduce a scalable worksheet cell store (if performance becomes a priority)**
   - Options: index cache, row-grouped storage, or dual representation; maintain deterministic write output and stream-writer semantics.

7. **Decide whether `ooxml/` should become a shared read/write “package layer”**
   - Either keep it write-only, or add parsing for `.rels` / content types and consume it from `xlsx/read`.

8. **Further split `xlsx/formula_builtins.mbt` (resolved: 2026-02-08)**
   - Built-ins were split by category into:
     `xlsx/formula_builtins.mbt` (core dispatch + core helpers),
     `xlsx/formula_builtins_financial.mbt`, and
     `xlsx/formula_builtins_stats.mbt`.
