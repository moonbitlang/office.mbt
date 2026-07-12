# bobzhang/office

`bobzhang/office` is the agent-oriented facade for the XLSX engine in
`bobzhang/mbtexcel` and the DOCX engine in `bobzhang/docx2html`.

The module is intentionally young and may make breaking changes while the
major-parity program in `../docs/office-major-parity.md` is underway.

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
office help
office help docx
office help xlsx
office help all --json
office help all --jsonl
office identify report.docx --json
```

`docx`/`word` and `xlsx`/`excel` are the only format names and aliases. The
capability inventory carries a deterministic CRC-32 fingerprint so automation
can detect contract drift. PowerPoint and MCP are intentionally absent.
