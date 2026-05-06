# PDF Markdown Acceptance Plan

This plan tracks the separate PDF-to-Markdown acceptance layer for `pdflite`.
It is intentionally outside the core CamlPDF-compatible package so experiments
with extraction quality, fixtures, and third-party comparison do not pollute the
library API.

## Goals

- Provide a small `bobzhang/pdflite/markdown` package that converts a parsed
  `PdfDocument` or PDF bytes into deterministic Markdown.
- Start with locally generated fixtures so tests are reproducible and licensing
  is clear.
- Use downloaded PDFs only after the small fixtures pass, and keep each fixture
  source, license, and expected extraction contract documented.
- Compare converter output with Microsoft's OSS `markitdown` tool in a
  separate report/script. Treat differences as prompts to inspect pdflite text,
  layout, CMap, and font behavior, not as automatic failures.

## Non-Goals For The First Slice

- No table reconstruction, image extraction, OCR, reading-order ML, or semantic
  heading inference.
- No network access during MoonBit tests.
- No required MarkItDown dependency in the MoonBit package or CI test path.

## Incremental Checklist

- [x] ~~Create the separate `markdown` MoonBit package.~~
- [x] ~~Add `pdf_document_to_markdown` and `pdf_bytes_to_markdown` public APIs.~~
- [x] ~~Add deterministic in-memory tests for simple Latin text extraction.~~
- [x] ~~Add deterministic in-memory tests for CJK/Unicode text extraction.~~
- [x] ~~Add a Pandoc fixture generator under a script or fixtures directory.~~
- [x] ~~Check in generated small fixtures with source Markdown and license
  notes.~~
- [x] ~~Add native fixture tests for Pandoc-generated Latin and CJK PDFs.~~
- [x] ~~Add a MarkItDown comparison script that writes normalized side-by-side
  outputs and a JSON/Markdown report outside the test runner.~~
- [x] ~~Extend the MarkItDown comparison report with replacement-character and
  raw-control counters so text-quality regressions are visible without ad hoc
  scans.~~
- [x] ~~Add selected online real-world fixtures, starting with public PDF spec
  and CJK-heavy documents whose redistribution terms are clear.~~
- [x] ~~Fix the first core extraction bugs found by the comparison loop, and
  record each fixed bug in `CamlPDFMigrationTodo.md`.~~
- [x] ~~Sanitize non-text control scalars in Markdown output and verify the
  external Adobe supplement and Unicode CJK chart pdflite outputs contain no
  raw C0/C1 controls.~~
- [x] ~~Add first-pass positioned text ordering for Markdown extraction,
  including placed form XObjects, and verify the Unicode CJK chart output now
  follows row/column order.~~
- [x] ~~Add scalar-aware fullwidth chunk-width estimation so adjacent
  positioned CJK glyph chunks are not separated just because they are
  fullwidth.~~
- [x] ~~Suppress unreliable `.notdef`/non-text-control glyph runs in Markdown
  extraction so the Unicode CJK chart no longer emits replacement characters
  for custom no-ToUnicode metadata glyphs.~~
- [x] ~~Make `TJ` array spacing context-aware so Latin and Hangul word gaps
  remain visible but Han/kana-style ToUnicode glyph pairs are not forced apart
  by synthetic word-space adjustments.~~
- [x] ~~Track unique U+4E00-9FFF glyph coverage in the MarkItDown comparison
  script so Unicode chart comparisons separate text coverage from layout
  policy.~~
- [ ] Continue fixing extraction/layout bugs found by the comparison loop.

## First Converter Contract

The first converter is deliberately simple:

- one `# Page N` heading per page;
- extracted text in content-stream order;
- whitespace normalized enough to make snapshots stable;
- UTF-8 Markdown output using pdflite's Unicode codepoint extraction;
- unsupported text fragments skipped only when the current content stream has
  no resolvable font resource.

This gives us an end-to-end gate over reader, page tree, content parsing, font
lookup, text extraction, Unicode encoding, and Markdown serialization before we
add larger fixtures.
