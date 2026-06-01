# Mammoth Parity Ledger

This ledger tracks the native MoonBit port against the vendored upstream
`.repos/mammoth` JavaScript library. It is intentionally behavior-oriented:
the MoonBit API is typed and bytes-first rather than a one-to-one copy of
Mammoth's dynamic JS surface.

## Current Scope

| Area | Status | Notes |
| --- | --- | --- |
| DOCX input | Covered | Public APIs accept `BytesView`; path loading lives in the native CLI. |
| HTML conversion | Covered | Includes style maps, pretty printing, notes, comments, tables, hyperlinks, bookmarks, checkboxes, images, complex fields, text boxes, and diagnostics. |
| Markdown conversion | Covered | Reuses the document converter and covers Mammoth list, image, anchor, escaping, and option behavior. |
| Raw text extraction | Covered | Uses the parsed document model and avoids forcing image reads. |
| Embedded style maps | Covered | `read_embedded_style_map` and `embed_style_map` read/rewrite DOCX bytes without exposing a mutable JSZip-like archive. |
| External linked images | Covered | Disabled by default; enabled through `external_file_access=true` plus a loader callback. |
| Document model helpers | Covered | Exposes typed enum constructors plus lower-snake helper functions for Mammoth node shapes. |
| Style-map parser | Covered | Carries Mammoth grammar, diagnostics, string-option normalization, and valid-mapping preservation. |
| XML/ZIP helpers | Covered | Includes namespace mapping, `mc:AlternateContent`, XML writing quirks, path helpers, content types, relationships, and ZIP reads. |
| Native CLI | Covered | Supports stdout, output file, output dir image extraction, markdown output, style-map files, pretty HTML, and Mammoth-style option forms. |
| Upstream fixtures | Covered | All `.docx` fixtures under `.repos/mammoth/test/test-data` are vendored into tests; `empty.zip` is used for invalid-docx coverage. |

## Carried Fixtures

- `comments.docx`
- `embedded-style-map.docx`
- `empty.docx`
- `endnotes.docx`
- `external-picture.docx`
- `footnote-hyperlink.docx`
- `footnotes.docx`
- `simple-list.docx`
- `single-paragraph.docx`
- `strict-format.docx`
- `strikethrough.docx`
- `tables.docx`
- `text-box.docx`
- `tiny-picture-target-base-relative.docx`
- `tiny-picture.docx`
- `underline.docx`
- `utf8-bom.docx`

## Intentional API Differences

- Mammoth's `{ path }`, `{ buffer }`, `ArrayBuffer`, and async JSZip-like input
  objects are not recreated in the core library. Callers load bytes themselves,
  and the CLI handles filesystem paths.
- Mammoth image objects expose async `read(...)` helpers. MoonBit images carry
  eager `Image.data : Bytes`, so converters inspect the bytes directly.
- Mammoth's mutable archive write surface is replaced by focused byte-to-byte
  helpers such as `embed_style_map`.
- Mammoth's deprecated `styleMapping()` runtime-error shim is not ported.
  MoonBit callers pass style-map strings directly.
- JavaScript package/browser integration surfaces are outside this native-first
  package's current scope.

## Validation Gate

Use this gate before publishing or claiming a parity milestone:

```bash
moon info && moon fmt
moon test --target native
moon check --target native --warn-list +73
moon check --target all --warn-list +73
git diff --check
```

When public APIs change, inspect `pkg.generated.mbti` after `moon info` and
bump `moon.mod` before publishing because Mooncakes versions are immutable.
