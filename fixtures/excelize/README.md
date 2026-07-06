# Vendored excelize test fixtures

These files are a small, verbatim subset of the test fixtures from the
[excelize](https://github.com/qax-os/excelize) project (`qax-os/excelize`),
vendored here so the mbtexcel parity/fixture tests are self-contained and do
not require cloning the upstream Go repository at test time (previously fetched
into `.repos/excelize/` in CI).

## Contents

| File | Upstream path | Consumed by |
| --- | --- | --- |
| `test/CalcChain.xlsx` | `test/CalcChain.xlsx` | `xlsx/excelize_fixture_calc_chain_test.mbt` |
| `test/Book1.xlsx` | `test/Book1.xlsx` | `xlsx/iterators_excelize_parity_test.mbt` |
| `test/MergeCell.xlsx` | `test/MergeCell.xlsx` | `xlsx/excelize_fixture_merge_cell_test.mbt` |
| `test/SharedStrings.xlsx` | `test/SharedStrings.xlsx` | `xlsx/excelize_fixture_shared_strings_test.mbt` |
| `test/BadWorkbook.xlsx` | `test/BadWorkbook.xlsx` | `xlsx/excelize_fixture_bad_workbook_test.mbt` |
| `test/encryptAES.xlsx` | `test/encryptAES.xlsx` | `xlsx/excelize_fixture_encrypt_aes_test.mbt` |
| `test/encryptSHA1.xlsx` | `test/encryptSHA1.xlsx` | `xlsx/excelize_fixture_encrypt_sha1_test.mbt` |
| `test/OverflowNumericCell.xlsx` | `test/OverflowNumericCell.xlsx` | `xlsx/excelize_fixture_overflow_numeric_cell_test.mbt` |
| `logo.png` | `logo.png` | `xlsx/picture_ops_test.mbt` |

The files are byte-for-byte copies of the upstream fixtures; do not edit them.
To refresh, re-copy from a checkout of `qax-os/excelize` at the same relative
paths.

## License

excelize is distributed under the BSD 3-Clause License; the upstream license
text is preserved in `LICENSE` in this directory and applies to these files.

> Note: this directory vendors only test *data*. The full excelize source
> checkout (used by developer-only parity tooling such as
> `scripts/semantic_parity.py`) is still fetched separately into `/excelize`
> or `/.repos/excelize` and remains git-ignored.
