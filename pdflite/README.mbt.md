# pdflite

`bobzhang/pdflite` is a byte-oriented PDF toolkit for MoonBit. The root
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

## Native CLI

The native CLI wrapper lives in `cmd/main` and uses
`moonbitlang/core/argparse` for help, version text, subcommands, and parse
errors. Build it from this repository with:

```sh
moon run --target native --release --build-only cmd/main
```

The executable is written to `_build/native/release/build/cmd/main/main.exe`.
For example:

```sh
_build/native/release/build/cmd/main/main.exe info fixtures/camlpdf/logo.pdf
_build/native/release/build/cmd/main/main.exe info --json fixtures/camlpdf/logo.pdf
_build/native/release/build/cmd/main/main.exe validate fixtures/camlpdf/logo.pdf
_build/native/release/build/cmd/main/main.exe rewrite fixtures/camlpdf/logo.pdf _build/logo-roundtrip.pdf
```

Black-box CLI documentation tests live in `tests/cram`. Moon Cram is currently
available in MoonBit nightly, so run them with a nightly toolchain:

```sh
moon run --target native --release --build-only cmd/main
PDFLITE_CLI="$PWD/_build/native/release/build/cmd/main/main.exe" \
PDFLITE_LOGO_PDF="$PWD/fixtures/camlpdf/logo.pdf" \
moon cram test --shell /bin/bash --timeout-seconds 120 tests/cram
```

## Release Check

Before publishing, run the executable release checklist:

```sh
moon run --target native scripts/release_check.mbtx
```

For the slower full native suite and registry dry run:

```sh
moon run --target native scripts/release_check.mbtx -- --full-native-tests --publish-dry-run
```

The script runs `moon info`, `moon fmt --check`, all-target checking, focused
native CLI tests, Moon Cram CLI documentation tests, the checked-in fixture
round-trip matrix, the large fixture rewrite smoke test, and `moon package`.

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

- PDF byte data stays byte-oriented. `PdfBytes` is `Bytes`; `PdfName` and
  `PdfString` store raw bytes until an explicit text-decoding API is used.
- Object numbers are one-based in normal document allocation. Missing or
  deferred objects are represented explicitly instead of being guessed.
- Public parsing and writing APIs raise `PdfError` for typed failure classes.
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
  let name = @pdflite.pdf_name_of_bytes(
    try! @pdflite.pdf_bytes_of_int_array([47, 65, 32, 66]),
  )
  @test.assert_eq(
    @pdflite.pdf_int_array_of_bytes(@pdflite.pdf_write_name(name)),
    [47, 65, 35, 50, 48, 66],
  )
}
```

## Package Notes

- `PdfDocument` owns the object table, root catalog pointer, trailer dictionary,
  encryption state, and revision metadata.
- `@syntax.PdfObject` values preserve PDF syntax-level objects, including byte strings,
  names, dictionaries, streams, and indirect references.
- Read APIs raise `PdfError` for malformed input rather than silently repairing
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
