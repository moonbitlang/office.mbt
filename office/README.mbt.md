# bobzhang/office-lib

`bobzhang/office-lib` is the implementation module behind the published
`moonx bobzhang/office` command. It provides the facade for the XLSX engine in
`bobzhang/mbtexcel` and the DOCX engine in `bobzhang/docx2html`.

The module is intentionally young and may make breaking changes while the
major-parity program in `../docs/office-major-parity.md` is underway.
Registry publication follows the dependency-first process in
`../docs/office-release.md`; workspace resolution is not a release gate.

The public facade identifies a structurally valid OOXML package while checking
that its extension agrees with its package content. Agent-facing JSON uses one
deterministic `office.output/1` envelope for success, failure, and warnings:

```mbt check
///|
test "document format names" {
  inspect(@office.DocumentFormat::Xlsx.name(), content="xlsx")
  inspect(@office.DocumentFormat::Docx.name(), content="docx")
}
```

The canonical executable exposes only implemented capabilities:

```text
moonx bobzhang/office help
moonx bobzhang/office help docx
moonx bobzhang/office help xlsx
moonx bobzhang/office help all --json
moonx bobzhang/office help all --jsonl
moonx bobzhang/office identify report.docx --json
moonx bobzhang/office create xlsx report.xlsx --sheet Data --json
moonx bobzhang/office batch report.xlsx changes.json --out revised.xlsx --json
moonx bobzhang/office raw list report.docx --json
moonx bobzhang/office raw read report.docx /document --json
```

`docx`/`word` and `xlsx`/`excel` are the only format names and aliases. The
capability inventory carries a deterministic CRC-32 fingerprint so automation
can detect contract drift. Command families publish explicit variant schemas;
the raw record describes every `list`, `read`, `replace`, and `edit` input,
output, constraint, and output mode. PowerPoint and MCP are intentionally
absent.

`bobzhang/office-lib/xlsx` provides the bounded mutation SDK behind the canonical
creation and batch commands. It prefers `xlsx.batch/2`, retains exact
`xlsx.batch/1` behavior and shared resource accounting, validates complete candidates, and publishes through the shared
async transaction boundary. See `../docs/office-xlsx-mutations.md`.

The `bobzhang/office-lib/docx` package provides the preservation-safe SDK layer for
editing existing DOCX files. Its async `transact_docx` entry point composes the
A4 bounded read and atomic publisher with exact source-pinned byte-splice plans,
strict archive-backed DOCX validation, and the authoritative transaction
preservation report. It is deliberately not listed by `office help` yet: the
package is the foundation for later user-facing DOCX commands, not a partial
CLI promise.
