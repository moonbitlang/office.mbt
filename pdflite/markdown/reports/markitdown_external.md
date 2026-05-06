# MarkItDown External Fixture Comparison

Initial run: 2026-05-06 with:

```sh
./markdown/external_fixtures/download.py
./markdown/tools/compare_markitdown.py \
  --output-dir markdown/reports/markitdown_external \
  markdown/external_fixtures/downloads/adobe_supplement_iso32000_1.pdf \
  markdown/external_fixtures/downloads/unicode_cjk_unified_ideographs_u4e00.pdf
```

The PDFs are download-only fixtures; only source metadata and SHA-256 hashes
are checked in.

## Result

| Fixture | pdflite result | MarkItDown result | Current judgement |
| --- | --- | --- | --- |
| `adobe_supplement_iso32000_1.pdf` | Extracts 14,692 characters after blank-password decryption and first-pass positioned text ordering. Current line-shape metric is 220 lines at 65.8 characters/line on average. Page headings are expected converter policy. | Extracts 14,668 characters, with 335 lines at 42.8 characters/line on average. | The comparison exposed and fixed the encrypted-stream boundary for blank/open user-password PDFs. Optional `pdftotext -layout` extracts 17,586 characters, 242 lines, and the same 6 replacement characters with no raw controls, so remaining differences are layout-space policy rather than text loss. |
| `unicode_cjk_unified_ideographs_u4e00.pdf` | Extracts 1,451,941 characters after form-XObject recursion, shared-font extractor caching, Markdown control-scalar sanitization, first-pass positioned text ordering, suppression of unreliable `.notdef`/control glyph runs, and a validated Han/kana `TJ` spacing guard that preserves Hangul word spaces. The comparison script records 20,963 unique U+4E00-9FFF glyphs and a line-shape metric of 52,933 lines at 26.4 characters/line on average. | Extracts 1,518,212 characters, records the same 20,963 unique U+4E00-9FFF glyphs, and reports 534 lines at 2,842.1 characters/line on average. | The original page-heading-only failure is fixed, pdflite no longer emits raw C0/C1 controls or replacement characters for the chart, and chart pages now follow row/column reading order. `pdftotext -layout` now runs in the comparison script and records the same 20,963 chart glyphs with 5,469,467 characters, 78,168 lines, and 69.0 characters/line on average. MarkItDown is effectively one very long line per page, while pdftotext preserves physical spacing; the remaining gap is table/layout-space reconstruction, not missing CJK chart cells or broad glyph loss. |
