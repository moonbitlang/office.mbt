# MarkItDown PDF Specification Comparison

Initial run: 2026-05-07 with:

```sh
./markdown/external_fixtures/download.py
./markdown/tools/compare_markitdown.py \
  --markitdown-cmd /tmp/pdflite-markitdown-venv/bin/markitdown \
  --output-dir markdown/reports/markitdown_pdf_spec \
  markdown/external_fixtures/downloads/pdf_reference_iso32000_1_2008.pdf
```

The PDF is a download-only fixture. Only the source URL and SHA-256 hash are
checked in.

## Result

| Fixture | pdflite result | MarkItDown result | Current judgement |
| --- | --- | --- | --- |
| `pdf_reference_iso32000_1_2008.pdf` | Extracts 2,095,153 characters over 36,702 lines with no replacement characters and no raw C0/C1 controls. The output includes the PDF 32000-1:2008 cover text, ISO 32000-1 references, major table-of-contents sections such as Syntax, Graphics, Text, and Interactive Features, plus conservative Markdown tables for many specification tables and examples. | Extracts 2,123,016 characters over 78,950 lines with no replacement characters and no raw C0/C1 controls. | The converters differ in layout policy and line breaking, but both complete on the full 756-page encrypted/tagged PDF reference. `pdftotext -layout` extracts 2,771,451 characters over 49,175 lines with no replacement characters and 48 raw controls. This fixture also exposed an eager-reader performance issue: the classic indirect-object reader tokenized beyond `endobj`, which was pathological for the document's 126,988 in-use objects. The reader now stops at the first object boundary. |

The Poppler `pdftotext` baseline was produced with `pdftotext` 26.04.0.

## Quality comparison

| Output | Strengths | Weak spots | Best use |
| --- | --- | --- | --- |
| pdflite markdown | Produces the most Markdown-shaped artifact: explicit `# Page N` headings, conservative Markdown tables for aligned rows, no form-feed page separators, no replacement characters, and no raw C0/C1 controls. Its line count is much lower than MarkItDown's, so the output is less blank-line-heavy. | The current positional spacing heuristic sometimes inserts spaces inside words, for example `vie wed`, `acce pt`, `doc ument`, `an d`, and `spec ific`. It still extracts less total text than MarkItDown and Poppler on this fixture. | Downstream Markdown workflows that need deterministic page boundaries, sanitized text, and basic table shape. |
| MarkItDown | Better word reconstruction on the sampled prose. The first-page text keeps words such as `viewed`, `accept`, `the copyright`, and `document` intact where pdflite currently splits some of them. It also emits more text than pdflite. | The result is closer to extracted text than structured Markdown for this PDF: no Markdown headings, form-feed page breaks, and many blank or short lines. | Text-fidelity comparator for pdflite's spacing and glyph reconstruction. |
| `pdftotext -layout` | Best physical-layout baseline among the three: it preserves columns, indentation, and table-like spacing most aggressively, and extracts the most text. | Plain text rather than Markdown. It uses form-feed page breaks and emits 48 raw controls on this fixture. | Layout and coverage baseline, not the Markdown target. |

The main pdflite quality gap is therefore not decoding corruption: all three
outputs have zero replacement characters, and pdflite has no raw controls. The
gap is word-boundary reconstruction. After the fallback-width and table
reconstruction adjustments, the same sampled fragment probe still found
pdflite-only split forms such as `spec ific` 21 times, `an d the` 9 times,
`doc ument` 5 times, and `acce pt` 2 times; MarkItDown and Poppler had zero
matches for those split forms in the same sample.

A follow-up raw font-width experiment was not kept in the markdown layout path.
It preserved those sampled split-word counters, but it removed needed spaces in
other specification fragments because raw glyph width alone does not include
the complete PDF text state (`Tc`, `Tw`, `Tz`, and matrix scaling). The next
spacing fix should therefore model text-state advances explicitly before using
measured font widths for layout.
