# Slow tests report

- Generated at: `2026-01-28 01:29:21 +0800`
- Build metadata: `/Users/hongbozhang/git/mbtexcel/_build/native/debug/test`
- Per-test timeout: `10.0s`
- p50/p95/p99 computed from OK tests (including `#skip` tests).

## Summary

- Total tests measured: `455`
- OK: `455`; failed: `0`; timed out: `0`
- p50: `2.256s`, p95: `2.372s`, p99: `3.357s` (OK tests only)
- Suggested slow thresholds: `p95=2.372s` and `p99=3.357s`

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

- `8.309s` `xlsx` `blackbox` `workbook_protection_test.mbt:2` `#0` workbook protection roundtrip
- `6.301s` `xlsx` `blackbox` `sheet_props_test.mbt:91` `#3` sheet protection xor and sha512

### Slow (OK) tests (>= max(p95, 3s) = `3.000s`)

- `8.309s` `xlsx` `blackbox` `workbook_protection_test.mbt:2` `#0` workbook protection roundtrip
- `6.301s` `xlsx` `blackbox` `sheet_props_test.mbt:91` `#3` sheet protection xor and sha512
- `4.767s` `xlsx` `blackbox` `io_password_test.mbt:26` `#1` options password used for write_to_buffer and save_as
- `4.711s` `.` `blackbox` `mbtexcel_test.mbt:157` `#14` mbtexcel workbook protection invalid password
- `4.180s` `xlsx` `blackbox` `io_password_test.mbt:2` `#0` open file and reader with password

### Top 30 slowest OK tests

- `8.309s` `xlsx` `blackbox` `workbook_protection_test.mbt:2` `#0` workbook protection roundtrip
- `6.301s` `xlsx` `blackbox` `sheet_props_test.mbt:91` `#3` sheet protection xor and sha512
- `4.767s` `xlsx` `blackbox` `io_password_test.mbt:26` `#1` options password used for write_to_buffer and save_as
- `4.711s` `.` `blackbox` `mbtexcel_test.mbt:157` `#14` mbtexcel workbook protection invalid password
- `4.180s` `xlsx` `blackbox` `io_password_test.mbt:2` `#0` open file and reader with password
- `2.655s` `xlsx` `whitebox` `encryption_wbtest.mbt:411` `#1` agile verify password
- `2.653s` `.` `blackbox` `mbtexcel_e2e_test.mbt:375` `#18` mbtexcel e2e workbook protection xml
- `2.553s` `.` `blackbox` `mbtexcel_e2e_test.mbt:15` `#1` mbtexcel password wrappers
- `2.405s` `xlsx` `blackbox` `calc_test.mbt:732` `#17` calc gcd and lcm functions
- `2.394s` `xlsx` `blackbox` `calc_test.mbt:3266` `#62` calc drop functions
- `2.389s` `xlsx` `blackbox` `sheet_management_test.mbt:65` `#6` sheet visibility roundtrip
- `2.387s` `xlsx` `blackbox` `date_convert_test.mbt:2` `#0` excel date to time 1900
- `2.384s` `xlsx` `blackbox` `image_test.mbt:2` `#0` image drawing package
- `2.382s` `xlsx` `blackbox` `header_footer_image_test.mbt:61` `#1` header footer image read roundtrip
- `2.381s` `xlsx` `blackbox` `calc_test.mbt:5483` `#127` calc dollar function errors
- `2.381s` `xlsx` `blackbox` `calc_test.mbt:702` `#16` calc f test functions
- `2.378s` `xlsx` `blackbox` `date_convert_test.mbt:30` `#2` excel date to time invalid
- `2.378s` `xlsx` `blackbox` `calc_test.mbt:7468` `#174` calc ttest errors (T.TEST) range mismatch
- `2.377s` `xlsx` `blackbox` `calc_test.mbt:2795` `#47` calc math and text functions
- `2.375s` `xlsx` `blackbox` `calc_test.mbt:5604` `#130` calc depreciation errors
- `2.375s` `xlsx` `blackbox` `calc_test.mbt:4498` `#101` calc na function
- `2.374s` `xlsx` `blackbox` `calc_test.mbt:4533` `#103` calc type and t functions
- `2.372s` `xlsx` `blackbox` `calc_test.mbt:5052` `#117` calc amortization and euroconvert functions
- `2.372s` `xlsx` `blackbox` `conditional_format_test.mbt:61` `#2` conditional format invalid type
- `2.372s` `xlsx` `blackbox` `calc_test.mbt:4934` `#113` calc xlfn dynamic array functions
- `2.371s` `xlsx` `blackbox` `calc_test.mbt:7446` `#173` calc ttest errors (T.TEST) bad args
- `2.371s` `xlsx` `blackbox` `table_test.mbt:2` `#0` table write and relationships
- `2.366s` `xlsx` `blackbox` `calc_test.mbt:298` `#7` calc stdev functions
- `2.365s` `xlsx` `blackbox` `stream_test.mbt:173` `#8` workbook row stream
- `2.365s` `xlsx` `blackbox` `calc_test.mbt:4508` `#102` calc sheet functions

