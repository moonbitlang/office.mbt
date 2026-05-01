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
   dictionary mutation, object map entries, parsed/deferred object states,
   document defaults, add/remove object logging, and tests preserving CamlPDF's
   new-key dictionary order. Direct indirection resolution, direct dictionary
   lookup, lookup chains, number extraction, rectangle parsing, matrix parsing,
   and matrix object rendering are also started. Name-tree and number-tree
   helpers are started with sorted/deduplicated readers and builders that emit
   child tree nodes through the document object map for larger trees.

4. Lexer and primitive parser.
   Port `.repos/pdfgenlex` and the lexical subset of `.repos/pdfread`:
   whitespace and delimiter predicates, numbers, names with `#xx` escapes,
   literal strings, hex strings, comments, dictionaries, arrays, and stream-data
   lexemes. Use snapshot tests for malformed inputs and `@test.assert_eq` for
   stable tokens.
   Status: started with the byte-oriented `PdfLexeme` enum, PDF whitespace and
   delimiter predicates, whitespace dropping, regular-token `BytesView`
   scanning over `ByteCursor`, boolean and number lexing, CamlPDF-compatible
   double-minus number salvage, and name lexing with byte-preserving `#xx` hex
   escapes. Comments, literal strings, hex strings, array/dictionary delimiter
   tokens, and primitive keyword tokens are also started, with byte-preserving
   `LexString` outputs and regression tests for escape handling. A primitive
   lexeme-to-object parser now covers comments, scalar objects, indirect
   references, arrays, dictionaries, and CamlPDF-style empty-dictionary recovery
   for malformed dictionary contents. The primitive scanner can now lex object
   syntax from `Bytes` into token arrays and parse a single object from bytes,
   stopping before `stream`, `startxref`, and inline-image `ID` data until
   stream-aware reading is implemented.

5. Minimal PDF reader.
   Implement header, xref, trailer, indirect object parsing, object streams only
   as a deferred state initially, and lazy/eager read entry points over
   `Bytes`. Acceptance target: parse compact hand-written one-page PDFs and
   inspect the object map. Encryption and most filters can report structured
   unsupported errors at this phase.
   Status: started with byte-backed PDF header detection over `ByteCursor`,
   including CamlPDF's first-1024-bytes scan and `(2, 0)` default version
   fallback when no valid header is found. Primitive indirect object parsing is
   also started for `n gen obj ... endobj` forms whose bodies do not require
   stream-aware lexing, and a primitive document loader can collect multiple
   non-stream indirect objects from byte input into `PdfDocument`. Direct-length
   stream object parsing is started for `/Length n` streams, materializing owned
   `StreamGot(Bytes)` data at the object boundary; the primitive document loader
   now includes those direct-length stream objects. A classic xref-table reader
   is also started for the current writer's output: it follows the final
   `startxref`, reads one classic xref section, parses the trailer dictionary,
   sets `/Root` and `first_xref`, and loads in-use plain objects by offset. It
   can resolve direct stream `/Length n` and plain indirect stream
   `/Length n 0 R` entries through that xref table. Incremental trailer
   `/Prev` chains are started for classic xref tables, preserving newer entries
   over older ones, including newer free entries that hide older objects. Xref
   streams, object streams, encryption, and malformed-file reconstruction remain
   deferred. `pdf_read_document_from_bytes` is now the public byte-backed reader
   entry point and currently delegates to the classic xref reader.

6. Minimal PDF writer.
   Port object rendering, dictionary/array rendering, stream rendering, xref,
   trailer, real formatting, and PDF string/name escaping from `.repos/pdfwrite`.
   Acceptance target: build a tiny PDF in MoonBit, serialize it, parse it back,
   and compare stable structure. This becomes the first round-trip gate.
   Status: started with byte-oriented primitive object rendering, PDF name and
   literal string escaping, indirect object rendering, and direct `StreamGot`
   stream rendering. Minimal classic xref-table, trailer dictionary, header,
   `startxref`, and `%%EOF` document serialization are also started, with a
   primitive writer-reader round-trip test for parsed objects. Owned stream
   serialization now writes a direct `/Length` entry from the byte payload.
   Real number serialization now avoids exponent notation, but complete
   CamlPDF `format_real` parity remains deferred. Incremental update handling,
   compressed xref streams, encrypted output, and lazy `StreamToGet`
   materialization remain deferred.

7. Stream filters and predictors.
   Port `pdfcodec` incrementally. Start with no-op/raw streams plus
   ASCIIHex/ASCII85/RunLength because they are byte-local. Add flate through
   pure MoonBit zlib/DEFLATE code, then layer predictors on decoded bytes.
   Keep DCT/JBIG2/CCITT behavior behind explicit capability checks until image
   support needs them.
   Status: started with low-level ASCIIHex encode/decode over `Bytes`. The
   decoder skips PDF whitespace, accepts uppercase and lowercase hex digits,
   pads an odd final nibble before `>`, and reports malformed data with
   `InvalidHexEscape`. Low-level ASCII85 encode/decode is also started, with
   zero-word `z` compression, `~>` termination, whitespace-tolerant decoding,
   partial final tuple handling, and structured malformed-data errors.
   Low-level RunLength encode/decode is also started, with literal chunks,
   repeat chunks, EOD marker handling, and tolerant missing-EOD decode
   behavior. A first filter-name dispatch layer maps `/ASCIIHexDecode`/`/AHx`,
   `/ASCII85Decode`/`/A85`, `/RunLengthDecode`/`/RL`,
   `/FlateDecode`/`/Fl`, `/LZWDecode`/`/LZW`, and identity `/Crypt` to those
   byte codecs. Low-level Flate decode is started for zlib-wrapped stored,
   fixed-Huffman, and dynamic-Huffman DEFLATE blocks with Adler-32 validation;
   Flate encode emits valid zlib stored blocks for semantic round-tripping,
   leaving compression-ratio work for later.
   Low-level LZW decode is started with clear/EOD handling and default
   EarlyChange 1; owned stream decode reads direct first-stage `/EarlyChange`
   from `/DecodeParms` or `/DP` for `/LZWDecode`/`/LZW`. Owned `StreamGot`
   stream dictionary integration is
   started for one-stage decode and explicit encode with direct `/Filter` or
   `/F` entries, first-filter array removal, `/DecodeParms` array advancement,
   and `/Length` refresh. A bounded full decode loop now removes all currently
   supported filters from owned streams.
   Predictor decoding is started for TIFF predictor 2 at 8 bpc and PNG row
   predictors, and owned stream decode now applies the first direct
   `/DecodeParms` or `/DP` predictor. Predictor encoding is started for PNG Sub
   (`11`) and PNG Up (`12`) rows, including explicit negative-delta
   normalization to PDF byte range. Owned stream encode can now add a filter
   plus direct `/DecodeParms` predictor dictionary and round-trip through owned
   stream decode. Flate compression heuristics, indirect filter dictionaries,
   deferred stream materialization, and other filters remain deferred.

8. Page tree and content streams.
   Port `pdfpage`, `pdfops`, `pdftree`, and `pdfst` enough to reproduce the
   `pdfhello.ml`, `pdfdecomp.ml`, and `pdftest.ml` workflows: create a page,
   parse/write content operators, read pages from a page tree, modify page
   contents, remove unreferenced objects, and write the result.
   Status: started with CamlPDF-style page tree reference-number traversal
   through `/Root`, `/Pages`, and nested `/Kids`, plus `endpage` and
   top-level `/Count` based `endpage_fast`, `page_object_number`, page records,
   blank/custom pages, page-tree construction, root installation, and
   `pages_of_pagetree` extraction with inherited `/Resources`, `/MediaBox`,
   `/Rotate`, indirect content preservation, and last-seen mediabox fallback.
   Page-tree construction now preserves the flat shape for small page arrays
   and builds CamlPDF-style balanced `/Pages` branches for larger arrays,
   including `/Parent`, `/Kids`, and `/Count` checks.
   Page content mutation is started with `protect`, `prepend_operators`, and
   `postpend_operators` helpers over `PdfContentOp` streams.
   Page replacement is now started with a `change_pages` slice that builds a
   replacement page tree in a copied document and can renumber same-count old
   page indirect references to the new page objects. Matrix-aware destination
   rewrites are now started for `change_pages` callers that supply page
   matrices: bookmark targets, link annotation `/Dest` or GoTo `/A`
   destinations, and catalog `/OpenAction` destinations are transformed after
   page-reference renumbering. A minimal `pdf_of_pages` is started for 1-based
   page extraction
   and reordering by composing `pages_of_pagetree`, `change_pages`, and
   `remove_unreferenced`; references to selected old page objects are rewritten
   to the new page objects, duplicated annotation references are copied to fresh
   object numbers, copied annotation `/Popup` and `/Parent` links are repaired
   within each extracted page, and `/Root/Names/Dests` name-tree entries whose
   page targets were nulled are pruned. Old-style catalog `/Dests` dictionary
   entries are also pruned after selected page references are rewritten.
   Page-label handling is started: extracted documents drop stale source
   `/PageLabels` by default and can retain selected-page numbering with
   `retain_numbering=true`. Bookmark extraction is also started: bookmarks are
   filtered to selected target pages, ancestor outline context is retained, and
   selected page targets are renumbered with the extracted page tree. Structure
   tree trimming is started behind `process_struct_tree=true`: structure nodes
   whose `/Pg` points to removed pages are deleted and ancestor `/K` child
   lists are pruned until stable. Broader retained-numbering behavior remains
   deferred.
   `minimum_valid_pdf` is also ported as a writable one-page A4 document
   constructor. Unreferenced-object pruning is started with a
   `remove_unreferenced` pass that follows indirect references from the catalog
   and trailer, removes unreachable parsed objects, and nullifies references to
   page objects no longer present in the active page tree before pruning.
   Content stream support is now started with a byte-preserving `PdfContentOp`
   subset, uncompressed content stream construction, indirect stream parsing
   through `PdfDocument`, and parsing for the core path, color, XObject, and
   text operators used by the `pdfhello.ml` workflow. Operator coverage now
   also includes dash patterns, rendering intent, flatness, Bezier curves, text
   state operators, color-space/color setters including named SCN/scn patterns,
   shadings, text quote operators, Type 3 glyph metrics, marked-content
   operators, compatibility-section markers, and artifact marker helpers.
   Inline images are started with a conservative unfiltered `BI ... ID ... EI`
   parse/render path that preserves image data as `Bytes`; ambiguous inline
   image terminators and filter-aware inline image compression remain deferred.
   Resource-prefix support is started with `shortest_unused_prefix`, scanning
   page and page-tree resource dictionaries with CamlPDF's lower-case prefix
   sequence. `add_prefix` is also started for page/page-tree resources and
   indirect content streams, including shared stream protection and resource
   names inside supported content operators. `renumber_pages` is now started
   for page arrays: it assigns fresh `/rN` resource names per page and resource
   category, rewrites supported resource-backed content operators, preserves
   direct device color-space names, and emits a single uncompressed rewritten
   content stream per returned page. CamlPDF's warning/log behavior for missing
   optional marked-content properties is represented by preserving the original
   name; broader destination/bookmark rewrites remain deferred to
   `change_pages`.

   Destination support is started with typed `PdfTargetPage` and
   `PdfDestination` values, direct destination-array parsing/writing, `/D`
   dictionary following, shallow named/string destination preservation, old
   catalog `/Dests` lookup for named destinations, and `/Root/Names/Dests`
   name-tree lookup for string destinations. Matrix transformation is also
   started for page-object targets, with CamlPDF-style coordinate clipping and
   `/GoTo` action `/D` rewriting. Page/destination convenience helpers are
   started with `page_number_of_target` and `target_of_page_number`.

   Bookmark support is started with typed `PdfBookmarkColour` and
   `PdfBookmark` records, `/Root/Outlines` traversal, level reconstruction,
   byte-preserving titles, direct destination and GoTo action target reading,
   `preserve_actions` behavior matching CamlPDF's shallow read path, `/Count`
   open-state handling, colour/flag extraction, root/no-outline behavior, and
   bookmark target transformation through `PdfDestination`. Bookmark removal
   is also started as a returned-copy catalog replacement that drops
   `/Outlines` and updates the trailer `/Root`. Bookmark tree construction and
   replacement are started with fresh outline object numbering, `/Parent`,
   `/First`, `/Last`, `/Next`, `/Prev`, and positive/negative `/Count` link
   generation, destination-vs-action field selection, and returned-copy catalog
   replacement. `change_pages` matrix integration is started for transformed
   page destinations.

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
    Continue bookmarks/marks, page labels, annotations, optional content
    groups, merge, duplicate-font removal, date helpers, and remaining
    utilities. Use CamlPDF examples and regression fixtures as acceptance tests.
    Status: started with typed page label styles/records, `/PageLabels`
    number-tree reading, replacement writing, empty-list removal, returned
    catalog-copy updates, basic completion, bounded range insertion,
    single-page label lookup, rendered label bytes for
    decimal/roman/letter/prefix-only styles, adjacent range coalescing, and
    merge-label construction for selected page ranges. Annotation support is
    started with typed subtypes, borders, colours, byte-preserving
    contents/subjects, page annotation reading with popup-parent filtering,
    page-record annotation insertion, and geometry transforms for `/Rect`,
    `/QuadPoints`, and `/L`. Date support is started with typed PDF dates,
    CamlPDF-compatible default fields, Distiller Y2K recovery, checked ranges,
    and PDF date string rendering. Optional content group support is started
    with typed OCG usage/configuration/application records, `/OCProperties`
    reading, returned-copy writing/removal, byte-preserving PDF strings, and
    explicit `PdfName` fields for PDF name values. OCG merge preparation is
    started with a typed helper for combining already-renumbered optional
    content metadata across documents. Merge support code is started with
    returned-copy object renumbering by positive offset, including root,
    trailer, and nested indirect-reference rewriting. A first minimal document
    merge helper now extracts requested page ranges, offsets object numbers,
    concatenates pages, preserves the maximum input version, and removes
    unreferenced imported roots/catalogs. Merge page-label retention is wired
    through the existing page-label merge helper behind an explicit option.
    Merge bookmark retention now reuses per-document page extraction to filter
    bookmarks, then retargets retained page-object destinations to the merged
    page tree. Merge optional-content retention now combines already-renumbered
    OCG metadata before unreferenced imported OCG objects are pruned. Basic
    AcroForm merge support now flattens retained `/Fields` arrays while
    preserving referenced field objects through the final cleanup. Named
    destination retention now merges old-style catalog `/Dests` and name-tree
    `/Names` `/Dests`, retargeting page-object destinations to the merged page
    tree. Merge trailer info retention now preserves the first available
    `/Info` dictionary through the merged trailer. Safe catalog-entry retention
    now carries first-seen non-page/non-handled catalog entries, such as viewer
    preferences, while dropping `/OpenAction` and other entries that require
    dedicated merge semantics.

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
