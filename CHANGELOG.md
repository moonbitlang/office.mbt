# Changelog

Breaking and notable changes for the published modules in this workspace.
Entries are grouped by module and by the version they ship in; `Unreleased`
covers changes that have landed on `main` but are not yet published.

### moonbitlang/ooxml [Unreleased]

- Add shared OPC, XML, and URI packages below the document engines. Extract
  DOCX's URI rules and preserve its existing public entry points as re-exports.
- Use flate for ZIP I/O and `Milky2018/xml@0.5.0` for namespace-aware XML reading.
  Version 0.5.0 fixes the reported attribute-whitespace serialization issue;
  keep the existing Office writer in this dependency upgrade.

### moonbitlang/docx2html [Unreleased]

- Depend on `ooxml/uri` for OPC part names and relationship URI rules.
  Existing `docx2html/opc` functions and registry types remain available through
  re-exports; DOCX-specific validation and resource budgets remain in DOCX.

### moonbitlang/pptx [Unreleased]

- Move low-level `opc` and `xml` imports to `moonbitlang/ooxml/...`.
  Replace fzip with flate; `Presentation::save()` now raises `PptxError` and
  `Package::to_bytes()` raises `OpcError` on ZIP write failure.
- Reject malformed XML, empty documents, and DOCTYPE declarations through the
  shared XML reader.

- Add PPTX parsing, building, and writing, derived from t-ujiie-g/moon-pptx
  0.10.0; retain upstream attribution and Apache-2.0 notices.
- Organize PPTX as an Office module with direct package directories, shared
  demos, and `cmd/demos` and `cmd/bench` executables under the root workspace.
- Integrate root scripts, the shared OpenXML SDK validator, the common CI and
  release workflow, and Office warning conventions. Existing public library
  document-model import paths remain `moonbitlang/pptx/...`.
- Restrict imported implementation fields and helpers to their owning packages.
  Use `Presentation::opc_package()` for raw OPC edits, and `Part::bytes()`,
  `ContentTypes::defaults()` / `overrides()`, and `Relationships::items()` for
  snapshots. Package enumeration and part payloads no longer expose writable
  backing storage.

### moonbitlang/mbtexcel [0.2.0]

- **BREAKING**: Moved the `testutil/zip_fixture` ZIP byte fixture out of
  `moonbitlang/mbtexcel/testutil` to
  `moonbitlang/docx2html/testutil/zip_fixture` (see docx2html below), and
  dropped the package's byte-push helpers (`push_u16_le`, `push_u16_be`,
  `push_u32_le`, `push_u32_be`, `push_u64_le`, `push_bytes`), which duplicated
  `moonbitlang/core/buffer`; use the core `Buffer` API instead
  (`write_uint16_le`/`write_uint16_be`, `write_uint_le`/`write_uint_be`,
  `write_uint64_le`, `write_bytes`, then `Buffer::to_bytes`).

### moonbitlang/docx2html [0.6.1]

- Added `moonbitlang/docx2html/testutil/zip_fixture`, a test-only ZIP byte
  fixture moved from `moonbitlang/mbtexcel/testutil/zip_fixture`.
- Removed the test-only `moonbitlang/mbtexcel` dependency; no package in the
  module imported mbtexcel outside that fixture.

### moonbitlang/office-lib [0.6.1]

- **BREAKING**: Moved the unified CLI implementation and its internal
  `input_contract` helper from `moonbitlang/office-lib/cmd/office` to the
  `moonbitlang/office` module (`office-cli`); importers of
  `moonbitlang/office-lib/cmd/office` should use the new location (see below).
- Removed the `moonbitlang/pagelayout` and `tonyfettes/unicode` dependencies,
  which only that CLI used.

### moonbitlang/office [0.2.0]

- Moved the unified CLI implementation from `moonbitlang/office-lib` into the
  module root package (`moonbitlang/office`) and its `input_contract` helper to
  `moonbitlang/office/internal/input_contract`; the module now declares the
  CLI's dependencies directly.

### moonbitlang/pdflite [0.2.1]

- Enable the `cmd/pdflite` CLI on Wasm for the default `moonx` launcher, while
  retaining native support. Run the CLI Cram suite on both backends in CI.
- Align the CLI version string with the module version and document the
  published launcher in the README and CLI skill.
- Remove redundant CLI whitebox tests and their test-only imports; retain
  command-line coverage in the Cram suite.

### moonbitlang/pdflite [0.2.0]

- **BREAKING**: Moved the standalone PDF→Markdown CLI from
  `moonbitlang/pdflite/markdown/cmd` to the new `moonbitlang/pdf2md` module.
  The `moonbitlang/pdflite/markdown` library package is unchanged.

### moonbitlang/pdf2md [0.1.0]

- New module: the standalone PDF→Markdown CLI, a thin wrapper over
  `moonbitlang/pdflite/markdown`.
