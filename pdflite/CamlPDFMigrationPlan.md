# CamlPDF to MoonBit Migration Plan

This is the project-specific plan for porting the vendored CamlPDF code in
`.repos/` to MoonBit. The general, library-agnostic OCaml-to-MoonBit rules live
in `OCaml2MoonBit.md`.

Update this file whenever the CamlPDF architecture understanding, migration
ordering, acceptance criteria, or deferred behavior changes.

## Source Snapshot

The vendored CamlPDF source in this checkout is under `.repos/` directly. The
first files inspected were `.repos/pdfio.mli`, `.repos/pdfio.ml`,
`.repos/pdf.mli`, `.repos/pdf.ml`, `.repos/pdfutil.mli`, and
`.repos/pdfutil.ml`.

CamlPDF identifies itself as package `camlpdf` version `2.9`: "Read, write and
modify PDF files". Its build order in `.repos/Makefile` is the clearest
high-level dependency map:

```text
pdfe pdfutil pdfio pdftransform pdfunits pdfpaper
pdfcryptprimitives pdf pdfcrypt pdfflate pdfcodec pdfwrite pdfgenlex
pdfread pdfjpeg pdfops pdfdest pdfmarks pdfpagelabels pdftree pdfst pdfpage
pdfannot pdffun pdfspace pdfimage pdfafm pdfafmdata pdfglyphlist pdfcmap
pdftext pdfstandard14 pdfdate pdfocg pdfmerge
```

The source is about 22,800 lines of OCaml. The largest and highest-risk modules
are `pdfread.ml`, `pdfcodec.ml`, `pdfpage.ml`, `pdfutil.ml`, `pdf.ml`,
`pdfcrypt.ml`, `pdftext.ml`, `pdfops.ml`, `pdfwrite.ml`, and `pdffun.ml`.

## Architecture

1. Foundation.
   `pdfe`, `pdfutil`, `pdfio`, `pdftransform`, `pdfunits`, and `pdfpaper`
   provide logging, list/string utilities, byte input/output, bitstreams,
   geometry, units, and paper sizes. Nearly every module opens `Pdfutil`, and
   parser/filter modules also depend on `Pdfio`.

2. Core PDF model.
   `pdf` defines `pdfobject`, streams, lazy/deferred object states, object maps,
   document state, dictionary lookup and replacement, indirect object lookup,
   renumbering, traversal, name trees, IDs, and rectangle/matrix helpers. Most
   other modules depend on this layer.

3. Compression and encryption infrastructure.
   `pdfcryptprimitives`, `pdfflate`, `pdfcodec`, and `pdfcrypt` implement
   primitive crypto, zlib/flate bindings, stream filters, predictors, stream
   encode/decode mutation, permission handling, and document encryption.

4. Reader and writer.
   `pdfgenlex` defines token/lexeme shapes. `pdfread` reads headers, xrefs,
   trailers, encrypted documents, object streams, dictionaries, strings, names,
   comments, and stream data from `Pdfio.input`. `pdfwrite` serializes objects,
   streams, xrefs, trailers, PDF strings, real numbers, and encrypted output.

5. Page, content, and document feature layer.
   `pdfpage`, `pdfops`, `pdftree`, `pdfst`, `pdfdest`, `pdfmarks`,
   `pdfpagelabels`, `pdfannot`, and `pdfocg` operate on the object model to
   expose page trees, content stream operators, destinations, bookmarks, page
   labels, annotations, optional content groups, and structure tree helpers.

6. Text, font, color, and image layer.
   `pdftext`, `pdfspace`, `pdfimage`, `pdfjpeg`, `pdfafm`, `pdfafmdata`,
   `pdfglyphlist`, `pdfcmap`, and `pdfstandard14` cover font models, encodings,
   PDFDocEncoding, UTF-8/UTF-16BE conversion, glyph names, color spaces, image
   extraction, JPEG data, AFM metrics, CMaps, and the standard fonts.

7. Application-level operations.
   `pdfmerge` combines documents and removes duplicate fonts. The examples also
   show canonical workflows for hello-PDF creation, merge, decompose streams,
   page-content modification, and encryption.

Primary data flow:

```text
file/channel/bytes
  -> Pdfio.input
  -> Pdfread lexing/parsing/xref resolution
  -> Pdf.t object graph with lazy stream/object states
  -> page/content/text/filter/encryption transformations
  -> Pdfwrite serialization
  -> output/file/bytes
```

MoonBit consequences for this project:

- Keep the first public API centered on pure `Bytes -> PdfDocument -> Bytes`
  transformations, then layer async file I/O at the boundary.
- Treat `Pdfio` and `Pdf` as the root of the port. The reader, writer, filters,
  and page/text APIs should not start until the byte cursor and object model are
  covered by focused tests.
- Preserve lazy/deferred object and stream states as explicit enums. This keeps
  compatibility with CamlPDF's lazy read path without making recursive parsing
  async.
- Handle native C dependencies deliberately. CamlPDF ships C stubs for flate,
  AES, and SHA2 (`flatestubs.c`, `miniz.c`, `rijndael-alg-fst.c`,
  `stubs-aes.c`, `sha2.c`, `stubs-sha2.c`). Each one needs an explicit
  MoonBit choice: pure MoonBit package, native binding, or deferred unsupported
  filter/encryption path.

## Migration Plan

0. Language and project foundation.
   Status: done for the first checkpoint. `OCaml2MoonBit.md` records validated
   general language rules. `ocaml2moonbit_wbtest.mbt` covers the byte/text,
   scalar, mutability, `FixedArray`, `ArrayView`, comprehension, and
   package-import assumptions. `pdf_bytes.mbt` starts the byte foundation with
   `PdfBytes`, `PdfName`, checked `Int` to `Byte` conversion, `ArrayView`
   inputs, and black-box tests in `pdflite_test.mbt`.

1. Low-level byte and input layer.
   Port the useful subset of `.repos/pdfio.mli` first:
   `ByteCursor` over `Bytes`, `BytesView` for read-only byte slices, byte
   builders, copy/freeze helpers, input position/source labels, `peek`, `read`,
   `rewind`, `nudge`, line reading, EOF behavior, and bitstream read/write.
   Keep this synchronous and in-memory. Add white-box tests for offset
   accounting and black-box tests for public byte helpers. Prefer `BytesView`
   return values for slices and call `.to_owned()` only for explicit ownership
   boundaries.
   Status: started with `ByteCursor` backed by `BytesView`, byte/line reads,
   offset handling, checked cursor errors, MSB-first bitstream read/write, and
   black-box tests.

2. Small pure support modules.
   Port `.repos/pdftransform`, `.repos/pdfunits`, `.repos/pdfpaper`, and the
   safe subset of `.repos/pdfutil` needed by later code. Prefer local functions
   over a broad util module when a helper has only one caller. Add assertion
   tests for matrix math, rectangles, units, and paper sizes.
   Status: started with `PdfUnit` conversions, `PaperSize` constants, and the
   first `Pdftransform` matrix operations: translate, scale, rotate, shear,
   compose, apply, operation-list ordering, and inversion. The MoonBit port
   intentionally preserves CamlPDF's historical conversion constants, including
   the `PdfPoint -> Centimetre` divisor `28.3456`.

3. Core object model and document state.
   Port `.repos/pdf.mli` in slices:
   `PdfObject`, `PdfStream`, ordered dictionaries, indirect references,
   document/object-map state, lazy object states, stream `ToGet` metadata,
   lookup helpers, add/remove/iterate object operations, traversal,
   renumbering, and name tree helpers. Use `PdfName` for names, `Bytes` for PDF
   strings and streams, `ArrayView`/`BytesView` for read-only sequence
   parameters, and `FixedArray` for fixed OCaml-array semantics.
   Status: started with `PdfObject`, `PdfStream`, `ToGet`, ordered dictionary
   construction, immediate lookup, add/replace/remove helpers, stream
   dictionary mutation, and tests preserving CamlPDF's new-key dictionary order.

4. Lexer and primitive parser.
   Port `.repos/pdfgenlex` and the lexical subset of `.repos/pdfread`:
   whitespace and delimiter predicates, numbers, names with `#xx` escapes,
   literal strings, hex strings, comments, dictionaries, arrays, and stream-data
   lexemes. Use snapshot tests for malformed inputs and `@test.assert_eq` for
   stable tokens.

5. Minimal PDF reader.
   Implement header, xref, trailer, indirect object parsing, object streams only
   as a deferred state initially, and lazy/eager read entry points over
   `Bytes`. Acceptance target: parse compact hand-written one-page PDFs and
   inspect the object map. Encryption and most filters can report structured
   unsupported errors at this phase.

6. Minimal PDF writer.
   Port object rendering, dictionary/array rendering, stream rendering, xref,
   trailer, real formatting, and PDF string/name escaping from `.repos/pdfwrite`.
   Acceptance target: build a tiny PDF in MoonBit, serialize it, parse it back,
   and compare stable structure. This becomes the first round-trip gate.

7. Stream filters and predictors.
   Port `pdfcodec` incrementally. Start with no-op/raw streams plus
   ASCIIHex/ASCII85/RunLength because they are byte-local. Then add flate and
   predictors after deciding whether to bind C/zlib or use a MoonBit package.
   Keep DCT/JBIG2/CCITT behavior behind explicit capability checks until image
   support needs them.

8. Page tree and content streams.
   Port `pdfpage`, `pdfops`, `pdftree`, and `pdfst` enough to reproduce the
   `pdfhello.ml`, `pdfdecomp.ml`, and `pdftest.ml` workflows: create a page,
   parse/write content operators, read pages from a page tree, modify page
   contents, remove unreferenced objects, and write the result.

9. Text, fonts, color spaces, and images.
   Port `pdftext`, `pdfstandard14`, `pdfglyphlist`, `pdfcmap`, `pdfafm`,
   `pdfspace`, `pdfimage`, and `pdfjpeg` in that order. Treat encoding
   conversion as byte-sensitive: PDF strings remain `Bytes`, decoded human text
   becomes `String` only through named encoding helpers.

10. Encryption.
    Port `pdfcryptprimitives` and `pdfcrypt` once reader/writer/filter basics
    are stable. Decide the primitive strategy first, then add permission flags,
    key derivation, stream/string encryption, decryption, and re-encryption.
    Use small known-vector tests before document-level encrypted fixtures.

11. Higher-level document features.
    Port destinations, bookmarks/marks, page labels, annotations, optional
    content groups, merge, duplicate-font removal, date helpers, and remaining
    utilities. Use CamlPDF examples and regression fixtures as acceptance tests.

12. Async I/O and command-facing APIs.
    Add async native-target wrappers for reading and writing files after the
    pure `Bytes` APIs are stable. Async wrappers should load/store bytes and
    call the synchronous core. Add `moon test --target native` coverage for
    async file APIs.

13. Compatibility and coverage hardening.
    Add fixture suites as features land, update snapshots deliberately, and use
    `moon coverage analyze > uncovered.log` to find untested parser, writer,
    filter, and page-tree branches.

## Update Discipline

Each migration slice should leave behind:

- The source OCaml file(s) covered.
- The MoonBit files added or changed.
- The verification command(s) used.
- Any known incompatibility or deferred behavior.
