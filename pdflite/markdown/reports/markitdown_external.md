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
| `unicode_cjk_unified_ideographs_u4e00.pdf` | Decrypts successfully but only emits page headings for the 534-page chart. | Extracts 1,518,212 characters. | Text extraction for this CJK chart remains a high-value gap; investigate embedded font/CMap handling before treating this fixture as passing. |
