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
| `adobe_supplement_iso32000_1.pdf` | Extracts 14,692 characters after blank-password decryption and first-pass positioned text ordering. Page headings are expected converter policy. | Extracts 14,668 characters. | The comparison exposed and fixed the encrypted-stream boundary for blank/open user-password PDFs. Remaining differences are layout policy. |
| `unicode_cjk_unified_ideographs_u4e00.pdf` | Extracts 1,451,941 characters after form-XObject recursion, shared-font extractor caching, Markdown control-scalar sanitization, first-pass positioned text ordering, suppression of unreliable `.notdef`/control glyph runs, and a validated Han/kana `TJ` spacing guard that preserves Hangul word spaces. | Extracts 1,518,212 characters. | The original page-heading-only failure is fixed, pdflite no longer emits raw C0/C1 controls or replacement characters for the chart, and chart pages now follow row/column reading order. Rechecking after the `TJ` guard left the chart metrics unchanged, so the sampled CJK spaces appear to come from table/content layout rather than that operator pattern. Remaining differences need table-cell, line-joining, and missing-cell review against MarkItDown and `pdftotext`. |
