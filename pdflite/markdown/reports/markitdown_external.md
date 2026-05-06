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
| `adobe_supplement_iso32000_1.pdf` | Extracts 14,543 characters after blank-password decryption. Page headings and content-stream ordering are expected converter policy. | Extracts 14,668 characters. | The comparison exposed and fixed the encrypted-stream boundary for blank/open user-password PDFs. Remaining differences are layout policy. |
| `unicode_cjk_unified_ideographs_u4e00.pdf` | Extracts 1,230,374 characters after form-XObject recursion, shared-font extractor caching, and Markdown control-scalar sanitization. | Extracts 1,518,212 characters. | The original page-heading-only failure is fixed, and pdflite no longer emits raw C0/C1 controls in this fixture. Remaining differences need layout/text-quality review, especially reading order and unresolved glyph placeholders. |
