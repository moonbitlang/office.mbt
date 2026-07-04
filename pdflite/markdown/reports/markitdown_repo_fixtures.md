# MarkItDown Repository Fixture Comparison

Initial run: 2026-05-07 after cloning MarkItDown to a temporary local checkout:

```sh
git clone --depth 1 https://github.com/microsoft/markitdown.git /tmp/markitdown
./markdown/tools/compare_markitdown.py \
  --markitdown-cmd /tmp/pdflite-markitdown-venv/bin/markitdown \
  --output-dir markdown/reports/markitdown_repo_fixtures \
  /tmp/markitdown/packages/markitdown/tests/test_files/*.pdf
```

The generated per-file outputs and diffs are ignored because the MarkItDown
checkout is reference data only. This checked-in summary records the quality
gaps that the upstream fixtures expose.

## Result

| Fixture | pdflite | MarkItDown | Current judgement |
| --- | --- | --- | --- |
| `MEDRPT-2024-PAT-3847_medical_report_scan.pdf` | 33 characters, mostly page headings. | 1 character. | Both converters are effectively empty on this scanned PDF without OCR, so OCR is not needed for baseline parity with MarkItDown's default PDF converter. |
| `RECEIPT-2024-TXN-98765_retail_purchase.pdf` | 1,479 characters over 69 lines. | 1,482 characters over 80 lines. | Close text coverage. pdflite is more compact and keeps explicit page headings. |
| `REPAIR-2022-INV-001_multipage.pdf` | 3,118 characters over 80 lines, including 30 pipe-table rows. | 5,090 characters over 76 lines. | pdflite now reconstructs the customer/vehicle and estimate totals regions as Markdown tables. MarkItDown still emits more complete tables for the supplies/totals area. |
| `SPARSE-2024-INV-1234_borderless_table.pdf` | 2,130 characters over 48 lines, including 22 pipe-table rows. | 2,712 characters over 44 lines. | pdflite now reconstructs both inventory tables with blank cells preserved. MarkItDown still pads/alines cells and has slightly richer table coverage. |
| `masterformat_partial_numbering.pdf` | 521 characters over 12 lines. | 524 characters over 27 lines. | Similar text coverage. MarkItDown preserves more blank-line layout and applies its MasterFormat `.1` numbering repair. |
| `movie-theater-booking-2024.pdf` | 2,583 characters over 60 lines, including 24 pipe-table rows. | 4,031 characters over 62 lines. | pdflite now emits Markdown tables for the order metadata, booking summary, totals, representatives, and first schedule/detail rows. MarkItDown still extracts more of the dense schedule rows as tables. |
| `test.pdf` | 5,187 characters over 61 lines. | 5,193 characters over 64 lines. | Coverage is close. pdflite now matches MarkItDown on several chunk-boundary spaces such as `question: how`, `use multi-agent conversations`, `made conversable`, and `centric computation`; it still misses intra-run spaces in the first line, for example `Largelanguagemodels(LLMs)arebecoming...`. |

## Implementation Notes

MarkItDown's PDF converter delegates prose extraction to `pdfminer.high_level.extract_text`.
For forms and tables, it uses `pdfplumber` word/table extraction and then emits
Markdown tables. The comparison therefore points to two concrete parity tracks:

- Improve pdflite's text-state layout reconstruction: character advances, word
  spacing, character spacing, horizontal scaling, `TJ` displacements, and font
  widths need to feed the line/word grouping heuristic.
- Continue improving the table/form reconstruction pass. pdflite now clusters
  positioned rows and columns and emits conservative Markdown tables. Remaining
  gaps are mostly dense rows whose cells are merged into a single text run.

A small fallback-width adjustment was kept because it improves word-boundary
inference on MarkItDown's prose fixture without increasing the sampled
split-word counters in the PDF specification fixture. A conservative table
reconstruction pass was also kept because it improves the upstream table-heavy
fixtures without introducing a table false positive in MarkItDown's prose
fixture. A raw font-width experiment was also measured but not wired into
markdown layout: without the full PDF text state (`Tc`, `Tw`, `Tz`, and matrix
scaling), it removed needed spaces in the PDF specification fixture. A more
aggressive per-glyph experiment was intentionally not kept: it broke existing
Markdown package tests by interleaving text runs. The next large improvement
should be a designed text-state reconstruction pass, not another local
threshold tweak.
