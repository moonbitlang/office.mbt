# pdflite

`moonbitlang/pdflite` is a byte-oriented PDF toolkit for MoonBit. The root
package exposes the public document model, object parser/writer, page tree
helpers, content operators, text extraction, filters, images, fonts, encryption,
and high-level read/write entry points.

```mermaid
flowchart LR
  Bytes[PDF bytes] --> Reader[pdf_read_document_from_bytes]
  Reader --> Document[PdfDocument]
  Document --> Pages[page tree and resources]
  Document --> Objects[object table]
  Pages --> Content[content operators]
  Objects --> Writer[pdf_write_document]
  Content --> Writer
  Writer --> BytesOut[PDF bytes]
```

Use this package when callers need a complete in-memory PDF document. Use the
subpackages for narrower concerns such as byte primitives, transforms, Flate,
dates, low-level cryptography, async file IO, or Markdown extraction.

## Command-line operations

This module is a library. The existing-PDF CLI is provided by `office pdf`:

```sh
moonx moonbitlang/office pdf info input.pdf --json
moonx moonbitlang/office pdf extract input.pdf selected.pdf --pages '1-3,5'
```

The former standalone CLI has been removed. See [Office PDF commands](../docs/office-pdf.md)
for native/Wasm source commands, unified output, publication rules, and acceptance checks.

## Release checks

Normal CI runs the library tests and Office native/Wasm PDF CLI checks. From the workspace
root, run focused checks when changing the PDF engine:

```sh
moon check pdflite
moon test --target native pdflite
moon test --target wasm pdflite
```

Publish from the `pdflite/` module directory with `moon publish`; the tool checks
the packaged module before publishing. Use `moon publish --dry-run` for a
preflight without publishing a version. See the workspace
[release process](../docs/office-release.md) for module ordering and credentials.

## What This Package Owns

- The public `PdfDocument` representation and its object table.
- PDF syntax objects such as arrays, dictionaries, streams, names, strings,
  numbers, booleans, nulls, and indirect references.
- Readers for headers, trailers, classic xref tables, xref streams, object
  streams, damaged-startxref reconstruction, revisions, and encrypted inputs.
- Writers for classic xref tables, xref streams, compressed xref streams,
  generated trailer IDs, incremental updates, and encrypted outputs.
- Page-tree construction, page queries, resource renumbering, merge/extract
  helpers, bookmarks, destinations, annotations, optional content groups, and
  content stream operators.
- Text/font/image helpers that need the full document graph.

## Pedantic Boundaries

- PDF byte data stays byte-oriented. `@core.PdfBytes` is `Bytes`; `@core.PdfName` and
  `PdfString` store raw bytes until an explicit text-decoding API is used.
- Object numbers are one-based in normal document allocation. Missing or
  deferred objects are represented explicitly instead of being guessed.
- Public parsing and writing APIs raise `@core.PdfError` for typed failure classes.
  Tests should assert concrete errors where the input class is stable.
- Methods that mutate a document mutate the in-memory object table directly.
  Functional wrapper APIs, when present, copy before mutation.
- Encryption APIs distinguish authentication, object crypt filters, saved
  encryption state, denied permissions, and recryption paths.

## Checked Examples

Create a minimum valid document, serialize it, and read it back:

```moonbit check
///|
test "minimum document round trip" {
  let document = try! @pdflite.pdf_minimum_valid_pdf()
  let bytes = try! @pdflite.pdf_write_document(document)
  let version = try! @reader.pdf_read_header_from_bytes(bytes)
  if version.major != 1 || version.minor != 0 {
    fail("expected a PDF 1.0 header")
  }
  let parsed = try! @pdflite.pdf_read_document_from_bytes(bytes)
  inspect(try! parsed.endpage(), content="1")
}
```

Write byte-preserving PDF names. Names are bytes, not MoonBit Unicode strings:

```moonbit check
///|
test "name writer escapes delimiter bytes" {
  let name = @core.pdf_name_of_bytes(
    try! @core.pdf_bytes_of_int_array([47, 65, 32, 66]),
  )
  @test.assert_eq(@core.pdf_int_array_of_bytes(@pdflite.pdf_write_name(name)), [
    47, 65, 35, 50, 48, 66,
  ])
}
```

## Package Notes

- `PdfDocument` owns the object table, root catalog pointer, trailer dictionary,
  encryption state, and revision metadata.
- `@syntax.PdfObject` values preserve PDF syntax-level objects, including byte strings,
  names, dictionaries, streams, and indirect references.
- Read APIs raise `@core.PdfError` for malformed input rather than silently repairing
  data. Reconstruction helpers are explicit APIs.
- Writer APIs can emit classic xref tables, xref streams, compressed xref
  streams, generated trailer IDs, incremental updates, and encrypted output.

## Verification Notes

- `README.mbt.md` blocks are blackbox tests for the root package.
- Most root tests should run on all MoonBit targets. Native-only random or file
  behavior belongs in targeted test files or the `async_io` package.
- For public API changes, run `moon info` and review `pkg.generated.mbti`.
- For behavior changes, run `moon test`; for native reader/writer coverage, also
  run native-target tests.
