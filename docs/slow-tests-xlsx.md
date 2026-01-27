# Slow tests report

- Generated at: `2026-01-28 01:14:01 +0800`
- Build metadata: `/Users/hongbozhang/git/mbtexcel/_build/native/debug/test`
- Per-test timeout: `10.0s`
- Filters: `{'package': ['xlsx']}`
- p50/p95/p99 computed from OK tests (including `#skip` tests).

## Summary

- Total tests measured: `380`
- OK: `380`; failed: `0`; timed out: `0`
- p50: `2.258s`, p95: `2.371s`, p99: `2.940s` (OK tests only)
- Suggested slow thresholds: `p95=2.371s` and `p99=2.940s`

## Method

1. Build only to generate native test drivers and metadata:
   - `moon test --build-only`
2. Enumerate tests from `__{blackbox,whitebox,internal}_test_info.json` under `_build/native/debug/test/**`.
3. Run each test in isolation via the generated native driver (faster + avoids `moon test` orchestration):
   - `tcc @<pkg>.<suite>_test.rspfile <file>.mbt:<index>-<index+1>`
4. Measure wall-clock time per test; classify as timeout if exceeding the per-test timeout.

## Results

This report highlights timeouts, the slowest tests, and percentile-based outliers.

### Very slow (OK) tests (>= max(p99, 5s) = `5.000s`)

- `8.284s` `xlsx` `blackbox` `workbook_protection_test.mbt:2` `#0` workbook protection roundtrip
- `6.322s` `xlsx` `blackbox` `sheet_props_test.mbt:91` `#3` sheet protection xor and sha512

### Slow (OK) tests (>= max(p95, 3s) = `3.000s`)

- `8.284s` `xlsx` `blackbox` `workbook_protection_test.mbt:2` `#0` workbook protection roundtrip
- `6.322s` `xlsx` `blackbox` `sheet_props_test.mbt:91` `#3` sheet protection xor and sha512
- `4.786s` `xlsx` `blackbox` `io_password_test.mbt:26` `#1` options password used for write_to_buffer and save_as
- `4.119s` `xlsx` `blackbox` `io_password_test.mbt:2` `#0` open file and reader with password

### Top 30 slowest OK tests

- `8.284s` `xlsx` `blackbox` `workbook_protection_test.mbt:2` `#0` workbook protection roundtrip
- `6.322s` `xlsx` `blackbox` `sheet_props_test.mbt:91` `#3` sheet protection xor and sha512
- `4.786s` `xlsx` `blackbox` `io_password_test.mbt:26` `#1` options password used for write_to_buffer and save_as
- `4.119s` `xlsx` `blackbox` `io_password_test.mbt:2` `#0` open file and reader with password
- `2.626s` `xlsx` `whitebox` `encryption_wbtest.mbt:411` `#1` agile verify password
- `2.408s` `xlsx` `blackbox` `calc_test.mbt:5192` `#123` calc bond functions
- `2.387s` `xlsx` `blackbox` `calc_test.mbt:5964` `#136` calc complex functions
- `2.385s` `xlsx` `blackbox` `calc_test.mbt:3000` `#48` calc text b error functions
- `2.385s` `xlsx` `blackbox` `calc_test.mbt:4934` `#113` calc xlfn dynamic array functions
- `2.382s` `xlsx` `blackbox` `calc_test.mbt:7446` `#173` calc ttest errors (T.TEST) bad args
- `2.381s` `xlsx` `blackbox` `calc_test.mbt:3431` `#72` calc wrap functions
- `2.377s` `xlsx` `blackbox` `sheet_management_test.mbt:49` `#5` sheet copy replaces target contents
- `2.376s` `xlsx` `blackbox` `row_col_dimensions_test.mbt:74` `#2` insert and remove cols adjust ranges
- `2.375s` `xlsx` `blackbox` `color_convert_test.mbt:19` `#1` rgb to hsl samples
- `2.373s` `xlsx` `blackbox` `calc_test.mbt:2783` `#46` calc string coercion
- `2.372s` `xlsx` `blackbox` `header_footer_image_test.mbt:61` `#1` header footer image read roundtrip
- `2.372s` `xlsx` `blackbox` `calc_test.mbt:5175` `#122` calc depreciation functions
- `2.372s` `xlsx` `blackbox` `calc_test.mbt:5626` `#131` calc bond function errors
- `2.372s` `xlsx` `blackbox` `calc_test.mbt:4960` `#114` calc spill frequency and trend
- `2.371s` `xlsx` `blackbox` `cell_value_test.mbt:68` `#4` typed setters and cell type
- `2.369s` `xlsx` `blackbox` `calc_test.mbt:7437` `#172` calc ttest errors (TTEST) unequal variance df
- `2.368s` `xlsx` `blackbox` `header_footer_image_test.mbt:141` `#3` header footer image invalid extension
- `2.367s` `xlsx` `blackbox` `calc_test.mbt:5604` `#130` calc depreciation errors
- `2.362s` `xlsx` `blackbox` `calc_test.mbt:2795` `#47` calc math and text functions
- `2.362s` `xlsx` `blackbox` `merge_cells_test.mbt:2` `#0` merge cells write and dimension
- `2.362s` `xlsx` `blackbox` `row_col_dimensions_test.mbt:2` `#0` row and column dimensions roundtrip
- `2.362s` `xlsx` `blackbox` `io_test.mbt:173` `#6` write_to returns byte length
- `2.361s` `xlsx` `blackbox` `stream_test.mbt:117` `#5` stream writer column helpers require pre-row
- `2.357s` `xlsx` `blackbox` `calc_test.mbt:3178` `#57` calc sort error functions
- `2.353s` `xlsx` `blackbox` `stream_test.mbt:89` `#4` stream writer table merge and row opts

