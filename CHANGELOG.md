# Changelog

Breaking and notable changes for the published modules in this workspace.
Entries are grouped by module and by the version they ship in; `Unreleased`
covers changes that have landed on `main` but are not yet published.

### moonbitlang/mbtexcel [0.2.0]

- **BREAKING**: Removed the `moonbitlang/mbtexcel/testutil` package.
  - Its byte-push helpers (`push_u16_le`, `push_u16_be`, `push_u32_le`,
    `push_u32_be`, `push_u64_le`, `push_bytes`) duplicated
    `moonbitlang/core/buffer`; use the core `Buffer` API instead
    (`write_uint16_le`/`write_uint16_be`, `write_uint_le`/`write_uint_be`,
    `write_uint64_le`, `write_bytes`, then `Buffer::to_bytes`).
  - Its `testutil/zip_fixture` ZIP byte fixture moved to
    `moonbitlang/docx2html/testutil/zip_fixture` (see docx2html below).

### moonbitlang/docx2html [0.6.1]

- Added `moonbitlang/docx2html/testutil/zip_fixture`, a test-only ZIP byte
  fixture moved from `moonbitlang/mbtexcel/testutil/zip_fixture`.
- Removed the test-only `moonbitlang/mbtexcel` dependency; no package in the
  module imported mbtexcel outside that fixture.

### moonbitlang/office-lib [0.6.1]

- **BREAKING**: Removed the `moonbitlang/office-lib/cmd/office` package and its
  internal `input_contract` helper; the unified CLI implementation moved to
  `moonbitlang/office` (see below).
- Removed the `moonbitlang/pagelayout` and `tonyfettes/unicode` dependencies,
  which only that CLI used.

### moonbitlang/office [0.2.0]

- Moved the unified CLI implementation from `moonbitlang/office-lib` into the
  module root package (`moonbitlang/office`) and its `input_contract` helper to
  `moonbitlang/office/internal/input_contract`; the module now declares the
  CLI's dependencies directly.

### moonbitlang/pdflite [0.2.0]

- **BREAKING**: Removed the `moonbitlang/pdflite/markdown/cmd` package; the
  standalone PDF→Markdown CLI now lives in the new `moonbitlang/pdf2md` module.
  The `moonbitlang/pdflite/markdown` library package is unchanged.

### moonbitlang/pdf2md [0.1.0]

- New module: the standalone PDF→Markdown CLI, a thin wrapper over
  `moonbitlang/pdflite/markdown`.
