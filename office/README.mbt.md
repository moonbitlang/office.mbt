# bobzhang/office

`bobzhang/office` is the agent-oriented facade for the XLSX engine in
`bobzhang/mbtexcel` and the DOCX engine in `bobzhang/docx2html`.

The module is intentionally young and may make breaking changes while the
major-parity program in `../docs/office-major-parity.md` is underway.

The first public API identifies a structurally valid OOXML package while
checking that its extension agrees with its package content:

```mbt check
///|
test "document format names" {
  inspect(@office.DocumentFormat::Xlsx.name(), content="xlsx")
  inspect(@office.DocumentFormat::Docx.name(), content="docx")
}
```
