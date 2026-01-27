# Slow Tests Analysis

This repo ships a profiler (`scripts/find_slow_tests.py`) that runs each MoonBit test in isolation via the generated native driver and records per-test wall time.

This document explains:

- Why some tests were effectively non-terminating in the `xlsx` package (and how they were fixed).
- Why the remaining “slow” tests are slow (expected vs bug), with pointers to the vendored `excelize` Go reference implementation.

## How the non-terminating tests were identified

1. Generate a baseline report (xlsx package only):
   - `python3 scripts/find_slow_tests.py --package xlsx --timeout 10 --report docs/slow-tests-xlsx.md`
2. The report previously showed timeouts in `xlsx/calc_test.mbt`:
   - `calc database functions`
   - `calc stats functions`
   - `calc stats errors`

These tests were marked `#skip` so `moon test` would complete, but the profiler runs tests directly via the native driver and can still reproduce “hangs” per test.

## Root cause (bug)

The timeouts were not caused by the database/stats functions themselves. They were caused by an interaction between:

- Resolving blank cells inside a range, which falls back to spill detection.
- Spill detection (`spill_value_for_cell`) scanning all formula cells and calling `array_shape_from_expr` to decide whether a formula produces a dynamic array (“spills”).
- `array_shape_from_expr` previously *evaluated function-call arguments for every function*, including scalar functions like `DAVERAGE(...)`.

When `array_shape_from_expr` evaluated arguments, it re-evaluated the same range expressions again, which triggered more blank-cell spill checks, which re-entered spill detection, and so on. In practice this caused runaway repeated range evaluation and tests that exceeded minutes.

## Fix

In `xlsx/formula_eval.mbt`, `array_shape_from_expr` now treats “unknown / scalar” functions as `(1, 1)` *without* evaluating their arguments, and only runs the expensive shape logic for functions that can actually spill (dynamic arrays / array-returning functions such as `SORT`, `FILTER`, `FREQUENCY`, `XLOOKUP`, `TREND`, etc.).

With this change:

- The previously skipped calc tests now complete, so their `#skip` attributes were removed.
- Dynamic array tests were verified to still pass (the spill allowlist includes array-returning functions used by the test suite).

## Remaining slow tests (expected)

The slowest remaining tests are related to password protection and encryption:

- `xlsx/workbook_protection_test.mbt` `workbook protection roundtrip`
- `xlsx/sheet_props_test.mbt` `sheet protection xor and sha512`
- `xlsx/io_password_test.mbt` (open/write with password)

These are expected to be slow because Office protection uses high iteration (“spin count”) password hashing:

- In vendored `excelize`, the defaults are `sheetProtectionSpinCount = 1e5` and `workbookProtectionSpinCount = 1e5`. See `excelize/crypt.go`.
- Excelize’s `genISOPasswdHash` loops `spinCount` times and hashes `key || iterator` each round. See `excelize/crypt.go` (`genISOPasswdHash`, `hashing`).

Our MoonBit implementation follows the same specification, so these tests are “slow by design”, not correctness bugs. Performance can still be improved (see follow-ups).

## Follow-ups / performance opportunities

- ISO password hashing: our implementation currently builds new byte buffers per iteration (`hash_concat` style). Excelize hashes via `hash.Hash.Write`, avoiding explicit concatenation; similar streaming-style hashing could reduce allocations and speed up protection-related tests.
- Keep the spill allowlist in sync: if new array-returning functions are added, the spill allowlist used by shape inference should be extended accordingly (tests should catch regressions).

