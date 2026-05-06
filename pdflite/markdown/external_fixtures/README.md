# External Markdown Fixtures

This directory tracks download metadata for larger or license-restricted PDFs
used in manual Markdown acceptance. The PDFs themselves are not checked in.

Run:

```sh
./markdown/external_fixtures/download.py
```

The downloader stores PDFs under `markdown/external_fixtures/downloads/` and
updates `manifest.lock.json` with file sizes and SHA-256 hashes. Use those
downloaded files with:

```sh
./markdown/tools/compare_markitdown.py \
  --output-dir markdown/reports/markitdown_external \
  markdown/external_fixtures/downloads/adobe_supplement_iso32000_1.pdf \
  markdown/external_fixtures/downloads/unicode_cjk_unified_ideographs_u4e00.pdf
```

Keep MoonBit tests network-free; these fixtures are for manual and scripted
acceptance runs outside the test runner.
