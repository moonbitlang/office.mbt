# Slow tests report

- Generated at: `2026-01-27 23:24:28 +0800`
- Build metadata: `/Users/hongbozhang/git/mbtexcel/_build/native/debug/test`
- Per-test timeout: `10.0s`
- p50/p95/p99 computed from OK tests (including `#skip` tests).

## Summary

- Total tests measured: `442`
- OK: `438`; failed: `0`; timed out: `4`
- p50: `2.313s`, p95: `2.497s`, p99: `3.775s` (OK tests only)
- Suggested slow thresholds: `p95=2.497s` and `p99=3.775s`

## Method

1. Build only to generate native test drivers and metadata:
   - `moon test --build-only`
2. Enumerate tests from `__{blackbox,whitebox,internal}_test_info.json` under `_build/native/debug/test/**`.
3. Run each test in isolation via the generated native driver (faster + avoids `moon test` orchestration):
   - `tcc @<pkg>.<suite>_test.rspfile <file>.mbt:<index>-<index+1>`
4. Measure wall-clock time per test; classify as timeout if exceeding the per-test timeout.

## Results

This report highlights timeouts, the slowest tests, and percentile-based outliers.

### Timeouts (likely non-terminating / extremely slow)

- `TIMEOUT>10.0s` `xlsx` `blackbox` `calc_test.mbt:4616` `#105` calc database functions attrs=['#skip']
- `TIMEOUT>10.0s` `xlsx` `blackbox` `calc_test.mbt:6243` `#140` calc stats functions attrs=['#skip']
- `TIMEOUT>10.0s` `xlsx` `blackbox` `calc_test.mbt:6323` `#141` calc stats errors attrs=['#skip']
- `TIMEOUT>10.0s` `xlsx` `blackbox` `calc_test.mbt:7307` `#165` calc ttest functions attrs=['#skip']

### Very slow (OK) tests (>= max(p99, 5s) = `5.000s`)

- `8.402s` `xlsx` `blackbox` `workbook_protection_test.mbt:2` `#0` workbook protection roundtrip
- `6.533s` `xlsx` `blackbox` `sheet_props_test.mbt:91` `#3` sheet protection xor and sha512

### Slow (OK) tests (>= max(p95, 3s) = `3.000s`)

- `8.402s` `xlsx` `blackbox` `workbook_protection_test.mbt:2` `#0` workbook protection roundtrip
- `6.533s` `xlsx` `blackbox` `sheet_props_test.mbt:91` `#3` sheet protection xor and sha512
- `4.865s` `xlsx` `blackbox` `io_password_test.mbt:26` `#1` options password used for write_to_buffer and save_as
- `4.767s` `.` `blackbox` `mbtexcel_test.mbt:157` `#14` mbtexcel workbook protection invalid password
- `4.273s` `xlsx` `blackbox` `io_password_test.mbt:2` `#0` open file and reader with password

### Top 30 slowest OK tests

- `8.402s` `xlsx` `blackbox` `workbook_protection_test.mbt:2` `#0` workbook protection roundtrip
- `6.533s` `xlsx` `blackbox` `sheet_props_test.mbt:91` `#3` sheet protection xor and sha512
- `4.865s` `xlsx` `blackbox` `io_password_test.mbt:26` `#1` options password used for write_to_buffer and save_as
- `4.767s` `.` `blackbox` `mbtexcel_test.mbt:157` `#14` mbtexcel workbook protection invalid password
- `4.273s` `xlsx` `blackbox` `io_password_test.mbt:2` `#0` open file and reader with password
- `2.926s` `xlsx` `blackbox` `sheet_background_io_test.mbt:2` `#0` set sheet background from file
- `2.741s` `.` `blackbox` `mbtexcel_e2e_test.mbt:375` `#18` mbtexcel e2e workbook protection xml
- `2.635s` `xlsx` `whitebox` `encryption_wbtest.mbt:411` `#1` agile verify password
- `2.588s` `xlsx` `blackbox` `sheet_management_test.mbt:12` `#1` sheet name validation
- `2.583s` `xlsx` `blackbox` `cell_value_test.mbt:23` `#1` formatted cell value
- `2.582s` `xlsx` `blackbox` `calc_test.mbt:3846` `#84` calc error functions
- `2.581s` `xlsx` `blackbox` `calc_test.mbt:593` `#14` calc chi-square test functions
- `2.579s` `.` `blackbox` `mbtexcel_e2e_test.mbt:15` `#1` mbtexcel password wrappers
- `2.574s` `xlsx` `blackbox` `picture_ops_test.mbt:55` `#3` picture from bytes invalid extension
- `2.572s` `xlsx` `blackbox` `picture_ops_test.mbt:2` `#0` picture get and delete
- `2.563s` `xlsx` `blackbox` `iterators_test.mbt:100` `#5` get_rows and get_cols expand gaps
- `2.546s` `xlsx` `blackbox` `options_test.mbt:44` `#3` options long time pattern
- `2.529s` `xlsx` `blackbox` `date_convert_test.mbt:16` `#1` excel date to time 1904
- `2.524s` `xlsx` `blackbox` `compat_test.mbt:20` `#1` compat auto filter and background bytes
- `2.520s` `xlsx` `blackbox` `table_ops_test.mbt:21` `#1` table delete missing
- `2.517s` `xlsx` `blackbox` `chart_sheet_test.mbt:2` `#0` chart sheet write and read
- `2.515s` `xlsx` `blackbox` `shape_form_control_slicer_test.mbt:51` `#2` slicer add/get/delete and xml
- `2.494s` `xlsx` `blackbox` `style_test.mbt:80` `#4` default font roundtrip
- `2.479s` `xlsx` `blackbox` `calc_test.mbt:3940` `#88` calc weibull function errors
- `2.476s` `xlsx` `blackbox` `calc_test.mbt:55` `#2` calc product and sumproduct functions
- `2.476s` `xlsx` `blackbox` `calc_test.mbt:6193` `#138` calc series and sign functions
- `2.475s` `xlsx` `blackbox` `sheet_props_test.mbt:198` `#6` page break insert remove and shift
- `2.455s` `xlsx` `blackbox` `color_ops_test.mbt:11` `#1` get base color from theme and indexed colors
- `2.452s` `xlsx` `blackbox` `sheet_management_test.mbt:112` `#9` active sheet write and read
- `2.450s` `xlsx` `blackbox` `rich_text_test.mbt:11` `#0` rich text set/get

