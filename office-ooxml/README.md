# Office OOXML foundations

`moonbitlang/office-ooxml` is a peer module in the root `moon.work`. It owns
format-independent OPC packaging and XML support, below the document engines.

- `opc`: named parts, content types, relationships, cloning, and ZIP input/output
  through `moonbit-community/flate@0.8.1`.
- `uri`: logical/physical part-name conversion, conflict detection, and relationship
  URI rules extracted from DOCX. `docx2html/opc` re-exports its existing public
  entry points; PPTX package relationship paths use the same implementation.
- `xml`: QName, extension-tree storage, reader events, and XML writing. Reading
  uses `Milky2018/xml@0.4.1`'s namespace-aware pull parser. The adapter expands
  empty elements and coalesces entity-split text to keep document readers stable.

PPTX uses `opc` and `xml` directly. DOCX retains its document validation and
budget-aware XML layer. XLSX retains its cancellable, budget-aware scanner and
part-name registry; those contracts are not replaced by the PPTX adapter.

The reader rejects malformed XML, empty documents, and DOCTYPE declarations.
It retains attribute order, expanded names, and CDATA, but does not preserve
comments, processing instructions, namespace declaration spelling, or prefixes
inside attribute values. It buffers the document; it is not an incremental
byte-stream parser.

The existing writer remains because the external writer currently emits literal
attribute whitespace; XML readers normalize that whitespace. Office's writer
uses character references for tabs, newlines, and carriage returns.

`Package::to_bytes()` raises `OpcError` for ZIP write failures. `Package::open()`
currently uses flate's default read policy; this alone does not introduce package
resource limits. Unchanged part payloads survive a package round trip; ZIP
compression bytes and metadata are not promised to remain identical.

Run from the repository root:

```sh
moon test office-ooxml/opc office-ooxml/xml office-ooxml/uri --target native --deny-warn
```

The OPC container and XML model/writer originated in the PPTX import. See
[provenance](../pptx/UPSTREAM.md) and the retained [Apache-2.0 license](LICENSE).
