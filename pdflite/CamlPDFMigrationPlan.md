# CamlPDF to MoonBit Migration Plan

This is the project-specific plan for porting the vendored CamlPDF code in
`.repos/` to MoonBit. The general, library-agnostic OCaml-to-MoonBit rules live
in `OCaml2MoonBit.md`. The separate high-level architecture checklist lives in
`CamlPDFArchitecturePlan.md`, and the active prioritized progress checklist
lives in `CamlPDFMigrationTodo.md`.

Update this file whenever the CamlPDF architecture understanding, migration
ordering, acceptance criteria, or deferred behavior changes. Update
`CamlPDFMigrationTodo.md` whenever substantial migration work changes what is
covered or what should be prioritized next.

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
   offset handling, checked cursor errors, CamlPDF-style input error context
   formatting, CamlPDF-style byte-predicate `getuntil`/`ignoreuntil` helpers,
   read-at-position, remaining-input, and non-advancing peek byte slices,
   one-allocation `BytesView` concatenation, MSB-first bitstream read/write,
   Int64-backed 32-bit bit values, aligned write-bitstream append,
   CamlPDF-style filled-byte construction, explicit physical byte copying, and
   byte/int-array conversion helpers, a non-mutating byte-map replacement for
   CamlPDF's mutable `bytes_selfmap`, an in-memory byte-output builder, and
   checked byte-output positioned/slice/fill writes with black-box tests.

2. Small pure support modules.
   Port `.repos/pdftransform`, `.repos/pdfunits`, `.repos/pdfpaper`, and the
   safe subset of `.repos/pdfutil` needed by later code. Prefer local functions
   over a broad util module when a helper has only one caller. Add assertion
   tests for matrix math, rectangles, units, and paper sizes.
   Status: started with `PdfUnit` conversions, `PaperSize` constants, and the
   first `Pdftransform` matrix operations: translate, scale, rotate, shear,
   compose, apply, operation-list ordering, `compose`/`append` operation-list
   helpers, operation/matrix debug string helpers, inversion, and
   CamlPDF-compatible matrix decomposition/recomposition
   with abnormal floating results normalized at the API boundary. The MoonBit
   port intentionally preserves CamlPDF's historical conversion constants,
   including the `PdfPoint -> Centimetre` divisor `28.3456`.

3. Core object model and document state.
   Port `.repos/pdf.mli` in slices:
   `PdfObject`, `PdfStream`, ordered dictionaries, indirect references,
   document/object-map state, lazy object states, stream `ToGet` metadata,
   lookup helpers, add/remove/iterate object operations, traversal,
   renumbering, and name tree helpers. Use `PdfName` for names, `Bytes` for PDF
   strings and streams, `ArrayView`/`BytesView` for read-only sequence
   parameters, and `FixedArray` for fixed OCaml-array semantics.
   Status: started with byte-owned `PdfName` plus borrowed construction and
   inspection APIs (`pdf_name_of_view`, `PdfName::view`), `PdfObject`,
   `PdfStream`, `ToGet`, ordered dictionary
   construction, immediate lookup, add/replace/remove helpers, stream
   dictionary mutation, side-effecting deferred stream materialization with
   `/Length` correction, object map entries, parsed/deferred object states,
   document defaults, checked catalog lookup, add/remove object logging,
   explicit object-entry collection construction, object-number selection,
   parsed object-entry and stream-entry snapshots with generation numbers,
   deterministic object-number/generation callback iteration,
   raising-callback stream-object iteration, in-place object mapping that
   preserves parsed-state tags, and tests preserving CamlPDF's new-key
   dictionary order. Public catalog lookup now resolves trailer `/Root` first,
   while retaining the document-root fallback used by synthetic tests without
   a trailer root, and feature-level catalog readers for bookmarks,
   destinations, merge, page labels, optional content, and structure
   parent-tree reads now share that core path. Page-tree active-catalog reads
   also use the core path while preserving the trailer-root flag needed for
   replacement. Immediate dictionary-only
   indirect lookup is ported for object-level helpers. CamlPDF-style
   `unique_key` dictionary-name selection is ported for dictionaries and stream
   dictionaries, using ASCII-prefixed PDF names. Direct indirection resolution
   and direct dictionary lookup, required dictionary lookup with caller-chosen
   errors, `/[n` array-index lookup inside lookup chains, immediate indirect
   number extraction, trailer-rooted chain replacement with indirect-object
   preservation, trailer-rooted chain removal with indirect-object preservation,
   sorted referenced-object traversal with skipped keys and marker dictionaries,
   explicit change-table object renumbering, compact object renumbering,
   offset renumbering, and multi-document disjoint compact renumbering,
   raw stream-byte extraction at the owned-byte boundary, deferred stream
   decryption markers on `ToGet` so parsed ARC4/AESV2/AESV3 encrypted stream
   bytes can remain file-backed until `stream_bytes`/`get_stream` forces them,
   CamlPDF-style trailer
   `/ID` generation/replacement with reproducible-ID environment handling, PDF
   numeric extraction, rectangle parsing, rectangle/QuadPoints transformation,
   matrix parsing, matrix object rendering, and document deep-copy isolation for
   mutable MoonBit object containers, stream records, stream byte payloads,
   deferred-stream cursor state, and trailer dictionaries are also started.
   The one-level `recurse_array`/`recurse_dict` mapping helpers are ported with
   CamlPDF's default dictionary-order reversal and explicit preserve-order
   option. Name-tree and number-tree helpers are started with
   sorted/deduplicated readers and builders that emit child tree nodes through
   the document object map for larger trees. CamlPDF's no-clash name-tree and
   number-tree merge helpers are also started by flattening readable inputs and
   rebuilding sorted trees.

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
   `LexString` outputs and regression tests for escape handling. Top-level
   single-token and token-array lexing over `BytesView` are exposed so callers
   can lex borrowed slices without allocating. A primitive lexeme-to-object
   parser now covers comments, scalar objects, indirect references, arrays,
   dictionaries, and CamlPDF-style empty-dictionary recovery for malformed
   dictionary contents. Borrowed `BytesView` parse entry points are exposed for
   direct and indirect primitive objects. The primitive scanner can now lex
   object syntax from `Bytes` into token arrays and parse a single object from
   bytes, stopping before `stream`, `startxref`, and inline-image `ID` data
   until stream-aware reading is implemented.

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
   `StreamGot(Bytes)` data at the object boundary and accepting borrowed
   `BytesView` input for parser callsites; the primitive document loader now
   includes those direct-length stream objects. A classic xref-table reader is
   also started for the current writer's output: it follows the final
   `startxref`, reads one classic xref section, parses the trailer dictionary,
   sets `/Root` and `first_xref`, and loads in-use plain objects by offset. It
   can resolve direct stream `/Length n` and plain indirect stream
   `/Length n 0 R` entries through that xref table. Incremental trailer
   `/Prev` chains are started for classic xref tables, preserving newer entries
   over older ones, including newer free entries that hide older objects, and
   public `pdf_revisions_from_view`/`pdf_revisions_from_bytes` helpers count
   those revisions from the xref metadata, keeping the borrowed `BytesView`
   entry point separate from the owned `Bytes` compatibility wrapper. Strict
   revision-specific document reads are now started with
   `pdf_read_classic_document_revision_from_view`/`_from_bytes` and
   `pdf_read_document_revision_from_view`/`_from_bytes`: revision `1` is the
   newest xref section, larger revision numbers skip newer sections and read
   older `/Prev` state, and invalid or missing revisions raise `BadRevision`.
   The revision-specific path is covered for classic update chains and
   xref-stream update/delete chains over an older classic base revision.
   Xref table line reading now accepts LF, CR, and CRLF terminators, so strict
   classic xref parsing handles CR-only files without falling back to
   reconstruction. Xref
   stream reading is now started for direct/filter-decodable stream data,
   default `/Size` ranges, explicit `/Index` ranges, and ordinary type-1
   entries; xref stream objects are omitted from the loaded object map, and
   type-2 object-stream entries are now resolved after their containing
   `/ObjStm` object has been loaded. Missing `/Type /XRef` is now tolerated
   for xref streams with real xref-stream structure such as `/W`, matching
   CamlPDF's parser, while explicit wrong `/Type` values remain rejected. The
   malformed reconstruction path now applies the same rule when it scans
   xref-stream dictionaries as trailer candidates after unusable `startxref`
   pointers.
   Object stream extraction is started for
   direct/filter-decodable stream data with direct or indirect `/N` and
   `/First` dictionaries, including malformed header, offset, index, and
   object-number mismatch checks. Object-stream extraction now uses the
   document-aware stream decoder once the containing object stream is loaded,
   so indirect `/Filter` metadata on `/ObjStm` streams is honored.
   Password-aware document reads now decrypt encrypted `/ObjStm` streams before
   slicing embedded objects, including the absent-password path that falls back
   to a blank user password, then load the embedded objects as already
   decrypted parser states so the later document-wide password decryption pass
   skips them. Password-aware parsed ARC4/AESV2/AESV3 stream objects now also
   retain CamlPDF-style deferred decryption state on their `ToGet` records
   until forcing materializes plaintext bytes and corrects `/Length`. Strict
   stream-object parsing now
   mirrors CamlPDF's stream-start padding tolerance by skipping space, NUL,
   form-feed, and tab bytes between the `stream` keyword and the line break or
   first data byte, without applying that padding rule before `endstream`.
   It also mirrors CamlPDF's unreadable and mismatched `/Length` recovery by
   rewinding and scanning through the following `endstream` marker when the
   length is missing, indirect-unavailable, non-integer, unparseable, negative,
   a stream object, or does not land on a valid terminator boundary. Valid
   strict-reader `/Length` streams now preserve lazy CamlPDF-style stream
   loading by storing `StreamToGet` cursor slices until an owned-byte boundary
   materializes them; malformed recovered streams still store eager
   `StreamGot` bytes because their boundaries are discovered by repair
   scanning. Indirect stream-length resolution now parses only the referenced
   object segment and uses its complete/incomplete state to distinguish plain
   integer length providers from stream objects, avoiding raw byte false
   positives when a valid length object mentions `stream` in a PDF comment.
   Empty indirect object segments like `n gen obj endobj` now parse as `null`,
   and plain non-stream indirect objects may omit the final `endobj` when the
   lexer stops before following non-stream syntax. Primitive scans now also
   continue across an adjacent `n gen obj` header after such a malformed plain
   object, matching CamlPDF's `parse_finish` fallback for malformed objects.
   Stream-looking incomplete objects still go through the stricter stream
   completion path.
   Hybrid-reference files with a
   classic trailer `/XRefStm`
   entry are now started by merging the pointed-to xref stream into the same
   revision while preserving the classic trailer as the document trailer.
   Xref-stream `/Prev` chains are also covered, including newer updates and
   free entries hiding older objects. The reader now mirrors CamlPDF's
   non-fatal first-object `/Linearized` probe and records the result in
   `PdfDocument::was_linearized`; the byte-level probe is exposed as
   `pdf_is_linearized`. Final trailer cleanup now mirrors CamlPDF's removal of
   xref machinery keys such as `/Prev`, `/XRefStm`, `/W`, `/Index`, `/Type`,
   `/Filter`, and `/DecodeParms`, while deriving `/Size` from the loaded
   document object map. A first malformed-file reconstruction path is
   started for public reads with missing `startxref`, malformed startxref
   numbers, startxref pointers that are not xref sections or are past EOF,
   malformed xref rows, malformed trailer syntax, a strict-read trailer missing
   `/Root`, or xref rows pointing at junk object offsets: it scans recoverable
   indirect objects, selects the latest trailer whose `/Root` points at a
   parsed dictionary, sets `first_xref` to zero, and keeps stricter xref errors
   on the strict classic reader path. Reconstructed trailer scanning also
   accepts CamlPDF-style `trailer <<...>>` and `trailer<<...>>` dictionaries.
   Public reads now also mirror CamlPDF's post-strict-read page-tree probe:
   when `endpage` would fail because the catalog or page-tree objects were
   omitted from the xref, the public reader falls back to reconstruction and
   recovers the body-scanned page objects while the strict reader keeps
   exposing the xref-limited object map.
   Xref-stream trailer reconstruction is now
   started for missing or unusable `startxref` pointers, using `/Type /XRef`
   stream dictionaries as trailer candidates while stripping stream/xref-only
   keys; object-stream integrity errors still propagate instead of being hidden
   by this recovery.
   Startxref discovery now mirrors CamlPDF's EOF-centered lookup by ignoring
   trailing junk after the final `%%EOF` marker.
   The strict classic xref reader now also mirrors CamlPDF's malformed-row
   workaround that treats `0000000000 _____ n` rows as free entries instead of
   failing the table, including marker tokens with suffix junk after the
   leading `n`, and accepts repeated `xref` marker lines plus `xref n m`
   section headers inside or at the start of a classic table.
   `startxref n` pointers on one line are covered too. It also accepts
   CamlPDF-style fixed-width xref rows whose separator columns are malformed
   independently while the offset, generation, and `n`/`f` columns remain
   parseable, and classic trailers whose dictionary starts immediately after
   the `trailer` keyword without intervening whitespace.
   Broader malformed xref-table recovery remains deferred. The reconstruction
   scan now builds a temporary offset table before materializing objects, so
   recovered streams can resolve plain indirect `/Length n 0 R` entries. Public
   reconstruction can now also recover stream objects with missing or unreadable
   `/Length` values by scanning through the following `endstream` marker and
   correcting `/Length`, and reconstructed object tokenization now skips raw
   `endobj` byte sequences inside literal strings by retrying the next candidate
   terminator. The reconstruction offset scan now also advances past complete
   indirect objects and recovered streams, avoiding false top-level objects from
   object-looking bytes inside stream payloads while retaining byte-wise
   recovery after incomplete plain objects. When a malformed object body starts
   at a plausible indirect-object header, the scanner now mirrors CamlPDF's
   line-oriented recovery by skipping to the next trimmed line beginning or
   ending with `endobj`, so nested object-looking bytes inside that bad object
   are not reconstructed as top-level objects. It still skips stream objects
   with malformed `stream`, `endstream`, or `endobj` markers, truncated stream
   data, malformed object bodies, and invalid PDF name hex escapes when a later
   reconstructed catalog remains valid.
   `pdf_read_document_from_bytes` is now the public
   byte-backed reader entry point and handles classic tables plus the started
   xref-stream/object-stream subset; borrowed `BytesView` entry points are now
   exposed for header reads, primitive object scans, strict classic reads,
   public fallback reads, and password-aware public reads, with owned `Bytes`
   functions kept as compatibility wrappers. Reader
   hardening now covers malformed headers, missing/bad `startxref`, CamlPDF-style
   non-digit prefixes before `startxref` offsets, malformed xref rows, malformed
   trailers, cyclic `/Prev` chains, CR/CRLF stream line breaks, indirect
   stream-length failures, xref/object mismatch errors, and public fallback
   reconstruction after strict-read catalog/page-tree probe failures.
   A password-aware byte-reader wrapper is now started:
   `pdf_read_document_from_bytes_with_passwords` preserves the existing
   plain-reader API while returning a `PdfDecryptionResult?` for parsed classic
   encrypted documents. Revision-aware password wrappers are also started for
   `Bytes` and borrowed `BytesView` inputs, sharing the strict revision reader
   before password authentication/decryption is applied.

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
   CamlPDF-style PDF name rendering plus literal-string and hex-string rendering
   is exposed for byte strings through `pdf_write_name`,
   `pdf_write_literal_string`, and `pdf_write_hex_string`. The CamlPDF
   `make_pdf_string`, `make_hex_pdf_string`, `string_of_pdf`,
   `string_of_pdf_including_data`, and `format_real` helpers are exposed as
   byte-oriented wrappers so PDF syntax and binary strings stay out of MoonBit
   UTF-16 `String`; the primary real formatter remains `pdf_write_real`.
   Real number serialization now avoids exponent notation and includes the
   CamlPDF fixed-six formatting branch for tiny non-integer real numbers plus
   12-significant-digit rounding for ordinary plain-decimal and exponent-form
   intermediate strings, expanding the rounded result back to PDF-compatible
   exponent-free decimal bytes.
   Writer-side lazy `StreamToGet` materialization now borrows the requested
   cursor slice during stream serialization. A separate
   `pdf_write_document_with_xref_stream` path is now started for PDF 1.5-style
   uncompressed xref stream output with `/W [1 4 2]`, free entries for object
   gaps, and a public reader round-trip gate. A Flate-backed
   `pdf_write_document_with_compressed_xref_stream` wrapper is also started and
   round-trips through the existing xref-stream reader. Classic incremental
   update output is started with `pdf_write_document_incremental_update`, which
   appends the current parsed object map and a new trailer with `/Prev` pointing
   to the supplied original bytes' `startxref`. Xref-stream incremental update
   output is now started with
   `pdf_write_document_incremental_update_with_xref_stream`, appending the
   current parsed object map plus an uncompressed xref stream with `/Prev`.
   Compressed xref-stream incremental update output is also started with
   `pdf_write_document_incremental_update_with_compressed_xref_stream`, using
   the existing Flate stream encoder and the xref-stream reader as its
   round-trip gate. Classic incremental updates now use the document event log
   to emit only changed or deleted object rows, preserving unchanged objects
   through `/Prev`; reader materialization no longer records loaded objects as
   user mutations. Xref-stream incremental updates now use the same changed
   object detection and emit sparse `/Index` ranges for changed/deleted objects
   plus the xref stream object. ARC4 encrypted output is now covered for full
   writes and incremental updates through the classic writer plus the
   uncompressed and Flate-compressed xref-stream writer paths. AESV2 encrypted
   full-document output is started behind an explicit IV-provider API and now
   has classic-writer plus uncompressed and Flate-compressed xref-stream
   round-trip gates. AESV3 revision 5 full-document output is started behind
   explicit typed random-field and IV-provider callbacks, with classic-writer
   plus uncompressed and Flate-compressed xref-stream round-trip gates. The
   public writer surface now has a `PdfWriteMode` dispatch API for both full
   document writes and incremental-update writes, plus direct encrypted-writer
   wrappers for ARC4, AESV2, AESV3, and AESV3 ISO workflows, matching CamlPDF's
   main encrypt-at-write use case while keeping AES random material explicit
   through provider callbacks. Native-target AESV2 and AESV3 convenience output
   is now started with a pdflite-owned OS random-byte FFI boundary
   (`/dev/urandom` on POSIX, `BCryptGenRandom` on Windows), covering AESV2 IVs
   and AESV3 file keys, salts, permissions padding, and object IVs. Saved-state
   AESV2/AESV3 recrypt convenience wrappers and native async file wrappers use
   the same boundary. Provider callback types now allow `PdfError` propagation,
   matching MoonBit's checked-error model for fallible entropy.

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
   behavior. ASCIIHex, ASCII85, LZW decode, RunLength, and Flate now expose
   borrowed `BytesView` entry points alongside owned `Bytes` compatibility
   wrappers. A first filter-name dispatch layer maps `/ASCIIHexDecode`/`/AHx`,
   `/ASCII85Decode`/`/A85`, `/RunLengthDecode`/`/RL`,
   `/FlateDecode`/`/Fl`, `/LZWDecode`/`/LZW`, and identity `/Crypt` to those
   byte codecs, with borrowed dispatch APIs for encode/decode when callers
   already hold slices. Low-level Flate decode is started for zlib-wrapped stored,
   fixed-Huffman, and dynamic-Huffman DEFLATE blocks with Adler-32 validation;
   Flate encode now chooses between zlib stored blocks, compact fixed-Huffman
   literal blocks, a conservative fixed-Huffman length/distance path for
   distance-1 repeated-byte runs, and a bounded fixed-Huffman prior-prefix
   match path for short LZ77-style matches. Flate encode now also builds a
   dynamic-Huffman block over the same bounded token stream, RLE-compresses the
   code-length alphabet, validates the result through decode round trips, and
   keeps the shortest of stored, fixed, repeat, match, and dynamic outputs so
   incompressible data can still fall back safely. The fixed/dynamic paths now
   keep a bounded hash chain per byte prefix so a short recent match does not
   hide a longer older match. Unbounded full match search and zlib-level tuning
   remain deferred.
   Low-level LZW decode is started with clear/EOD handling and default
   EarlyChange 1; owned stream decode reads direct first-stage `/EarlyChange`
   from `/DecodeParms` or `/DP` for `/LZWDecode`/`/LZW`. Owned `StreamGot`
   stream dictionary integration is
   started for one-stage decode and explicit encode with direct `/Filter` or
   `/F` entries, first-filter array removal, `/DecodeParms` array advancement,
   and `/Length` refresh. A bounded full decode loop now removes all currently
   supported filters from owned streams.
   Predictor decoding is started for TIFF predictor 2 at 8 bpc and PNG row
   predictors, with borrowed view entry points for low-level predictor
   encode/decode, and owned stream decode now applies the first direct
   `/DecodeParms` or `/DP` predictor. Predictor encoding is started for TIFF
   predictor 2 at 8 bpc plus PNG None (`10`), Sub (`11`), Up (`12`), Average
   (`13`), Paeth (`14`), and Optimum (`15`) rows, including explicit
   negative-delta normalization to PDF byte range and row-local Optimum filter
   selection. Owned stream encode can now add a filter plus direct
   `/DecodeParms` predictor dictionary and round-trip through owned stream
   decode. Stream encoding now supports CamlPDF-style
   `only_if_smaller` gating, leaving streams unchanged unless the encoded data
   plus overhead is smaller than the original bytes. CamlPDF-style typed
   encoding and predictor choices are now exposed as `PdfStreamEncoding` and
   `PdfStreamPredictor`, with a `pdf_encode_stream_with_encoding` wrapper over
   the existing filter/predictor implementation; CCITT names map to
   `/CCITTFaxDecode`, while actual CCITT encoding remains an explicit
   unsupported-filter path. Stream filter
   encode/decode now materializes `StreamToGet` data only at the owned-byte
   boundary required by codec transforms. A
   document-aware `PdfDocument::pdf_decode_stream` path is now started for
   indirect `/Filter` and `/DecodeParms` entries, including array filters with
   indirect elements, short `/F` and `/DP` keys, predictor dictionaries reached
   through indirect references, and LZW `EarlyChange` reached through direct
   document lookup. A document-aware `pdf_decode_stream_until_unknown` slice now
   mirrors CamlPDF's stop-at-first-unsupported-filter behavior while preserving
   the remaining filter metadata. A document-wide
   `pdf_decode_streams_until_unknown` helper also starts the `pdfdecomp.ml`
   workflow by replacing every parsed stream with its decoded-until-unknown
   form, preserving object generation numbers and already-decrypted parser
   state; a writer/reader acceptance fixture checks that decoded streams and
   unsupported tail filters survive serialization. Content streams, sampled
   functions, indexed colour lookup streams, ToUnicode CMap streams, and staged
   image decoding now use the document-aware stream decoder internally, so
   indirect filter metadata is honored across those callers. Reader
   object-stream extraction also uses document-aware decoding after the object
   map is loaded. Further Flate tuning and other filters remain deferred.

8. Page tree and content streams.
   Port `pdfpage`, `pdfops`, `pdftree`, and `pdfst` enough to reproduce the
   `pdfhello.ml`, `pdfdecomp.ml`, `pdftest.ml`, and `pdfdraft.ml` workflows:
   create a page, parse/write content operators, read pages from a page tree,
   modify page contents, replace image draws, remove unreferenced objects, and
   write the result.
   Status: started with CamlPDF-style page tree reference-number traversal
   through `/Root`, `/Pages`, and nested `/Kids`, plus `endpage` and
   `pages_of_pagetree_quick` counting, top-level `/Count` based
   `endpage_fast`, `page_object_number`, page records, blank/custom pages,
   page-tree construction, root installation, active-catalog `/Pages`
   resolution through trailer `/Root`, and
   `pages_of_pagetree` extraction with inherited `/Resources`, `/MediaBox`,
   `/Rotate`, indirect content preservation, and last-seen mediabox fallback.
   Root installation now matches CamlPDF's catalog-entry precedence: the new
   `/Type` and `/Pages` entries are authoritative, existing catalog extras are
   preserved from the active trailer-root catalog, and explicit extras replace
   same-name existing extras.
   CamlPDF's `replace_inherit` helper is also started as
   `PdfDocument::replace_inherit`, materializing inherited `/MediaBox`,
   `/CropBox`, `/Rotate`, and `/Resources` entries onto selected page objects
   while preserving immediate indirect resource references.
   Page-tree construction now preserves the flat shape for small page arrays
   and builds CamlPDF-style balanced `/Pages` branches for larger arrays,
   including `/Parent`, `/Kids`, and `/Count` checks.
   Page content mutation is started with `protect`, `prepend_operators`, and
   `postpend_operators` helpers over `PdfContentOp` streams.
   Page replacement is now started with a `change_pages` slice that builds a
   replacement page tree in a copied document and can renumber same-count old
   page indirect references to the new page objects. Its optional `changes`
   parameter now ports CamlPDF's explicit 1-based old/new page serial mapping
   for count-changing replacements. When no explicit mapping is supplied for a
   count-changing replacement, `change_pages` now mirrors CamlPDF by leaving
   existing references unchanged instead of rejecting the replacement.
   Replacement also preserves CamlPDF's document-level state expectations:
   version, `first_xref`, trailer extras such as `/ID`, catalog extras, and
   object-stream bookkeeping survive the copied replacement document.
   Matrix-aware destination rewrites are now started for `change_pages` callers
   that supply page matrices: bookmark
   targets, indirect and direct link annotation `/Dest` or GoTo `/A`
   destinations, and catalog `/OpenAction` destinations are transformed after
   page-reference renumbering. Named destination definitions in old-style
   catalog `/Dests` dictionaries and `/Root/Names/Dests` name trees are also
   transformed, so
   preserved named and string destinations resolve to the new page-space
   coordinates after page matrix changes. These catalog destination transform
   paths, including `/OpenAction`, now prefer the active catalog through
   trailer `/Root`, matching CamlPDF's parsed-PDF lookup path while retaining
   the document-root fallback for synthetic fixtures. Bookmark matrix rewrites
   now keep CamlPDF's count-changing guard: when explicit serial `changes`
   replace a different number of pages, bookmark page references are renumbered
   but bookmark coordinates are not matrix-transformed, while catalog
   `/OpenAction` and annotation destinations still run through the matrix
   pass. Transformed annotation, GoTo action, and `/OpenAction` destinations
   are now written as freshly allocated indirect destination objects, matching
   CamlPDF's `rewrite_dest` path, while direct annotation dictionaries in
   annotation arrays still participate in the MoonBit port's broader transform
   coverage. Matrix rewrites also now skip full-page `/Fit` and `/FitB`
   destinations and integer page targets, matching CamlPDF's page-object-only,
   coordinate-bearing destination filter. Malformed annotation, `/OpenAction`,
   and catalog destination-definition entries no longer abort the matrix pass;
   their page references are still renumbered, but bad coordinates are left
   unchanged like CamlPDF's logged failure path. Native acceptance now also
   covers a resource-heavy `change_pages` replacement after a compressed reader
   boundary, preserving page resources while transforming mixed direct and
   indirect link destinations, GoTo action annotations, catalog `/OpenAction`,
   old-style `/Dests`, name-tree action destinations, and bookmark resolution
   through write/reread. A minimal `pdf_of_pages`
   is started for 1-based page extraction and reordering by composing
   `pages_of_pagetree`, `change_pages`, and
   `remove_unreferenced`; references to selected old page objects are rewritten
   to the new page objects, duplicated annotation references are copied to fresh
   object numbers, copied annotation `/Popup` and `/Parent` links are repaired
   within each extracted page, inherited page attributes are materialized before
   extraction so parent `/CropBox` entries and inherited indirect `/Resources`,
   `/MediaBox`, and `/Rotate` references survive, and `/Root/Names/Dests` name-tree
   entries whose page targets were nulled are pruned. Old-style
   catalog `/Dests` dictionary
   entries are also pruned after selected page references are rewritten; this
   destination cleanup also follows trailer `/Root` for parsed PDFs.
   CamlPDF's duplicate page-reference repair is now ported for malformed or
   object-preserving page trees: repeated `/Kids` references are copied to fresh
   page objects, the first repeated kid is rewritten, and stale page-tree
   `/Parent` links are repaired recursively.
   Page-label handling is started: extracted documents drop stale source
   `/PageLabels` by default and can retain selected-page numbering with
   `retain_numbering=true`. Bookmark extraction is also started: bookmarks are
   filtered to selected target pages, named and string destination targets are
   resolved for page-membership checks while preserving their original target
   syntax, ancestor outline context is retained, and selected page targets are
   renumbered with the extracted page tree; malformed bookmark sets are treated
   as absent instead of aborting extraction. Structure
   tree trimming is started behind `process_struct_tree=true`: structure nodes
   whose `/Pg` points to removed pages are deleted and ancestor `/K` child
   lists are pruned until stable. Broader retained-numbering behavior remains
   deferred.
   `minimum_valid_pdf` is also ported as a writable one-page A4 document
   constructor. Unreferenced-object pruning is started with a
   `remove_unreferenced` pass that follows indirect references from the active
   trailer-root catalog and trailer, removes unreachable parsed objects, and
   nullifies references to page objects no longer present in the active page
   tree before pruning.
   Content stream support is now started with a byte-preserving `PdfContentOp`
   subset, uncompressed content stream construction, indirect stream parsing
   through `PdfDocument`, and parsing for the core path, color, XObject, and
   text operators used by the `pdfhello.ml` workflow. Operator coverage now
   also includes dash patterns, rendering intent, flatness, Bezier curves, text
   state operators, color-space/color setters including named SCN/scn patterns,
   CamlPDF's malformed `SC`/`sc`/`SCN`/`scn` fallback to black-like
   `[0 0 0]` operands for Distiller-style bad color operators, `TJ` array
   filtering that skips malformed non-string/non-number elements, shadings,
   malformed dash-array rejection for `d`, text quote operators, Type 3 glyph
   metrics, marked-content operators, compatibility-section markers, and
   artifact marker helpers. A
   `pdfdraft.ml`-style acceptance fixture now replaces image XObject draws and
   inline images with crossed-box path operators, drops image XObject resource
   entries, Flate-encodes the rewritten content stream, prunes the removed image
   object, and verifies writer/reader round-trip behavior.
   A `pdfhello.ml`-style public workflow fixture now builds an A4 page with
   Times-Italic `/F0` resources, writes and reads the document, parses the
   rendered content operators back, and verifies standard-font text extraction
   for the `"Hello, World!"` PDF bytes.
   Inline images are started with a conservative unfiltered `BI ... ID ... EI`
   parse/render path that preserves image data as `Bytes`; known-size
   unfiltered inline images now read exact byte counts from direct
   width/height/colour-space/bits metadata or image-mask metadata, preserving
   `EI` byte sequences inside payloads. Text-encoded inline image filters
   whose first filter is ASCIIHex or ASCII85 now consume encoded bytes through
   the filter terminator (`>` or `~>`) before reading the inline-image `EI`
   marker, then decode through the stream codec pipeline and flatten without
   stale filter metadata.
   The CamlPDF `concat_bytess` helper is exposed as
   `pdf_content_concat_streams`, with borrowed
   `pdf_content_concat_stream_views`, preserving the whitespace inserted
   between split content streams before parsing. The CamlPDF `string_of_op`
   and `string_of_ops` helpers are exposed as `pdf_string_of_content_op` and
   `pdf_string_of_content_ops`, returning `PdfBytes` so debug output remains
   byte-preserving; the older `pdf_content_bytes_of_op` naming remains
   available over the same renderer. Content
   parsing now has a borrowed `BytesView` entry point,
   `pdf_parse_content_ops_from_view`, with the owned `Bytes` parser kept as a
   compatibility wrapper. A `pdftest.ml`-style acceptance fixture now parses
   split page content streams, rewrites each page to a single rendered content
   stream through `change_pages`, prunes unreferenced objects, writes the
   document, and reads the operators back.
   The CamlPDF resource-aware `components` helper is started as
   `PdfDocument::colour_space_components`, covering device, calibrated,
   resource-named, ICCBased, Indexed, Separation, Pattern-with-base, and DeviceN
   spaces for inline-image and image-data sizing callers.
   Resource-aware content parsing is started with
   `PdfDocument::parse_content_ops_with_resources`, so inline images whose
   colour space comes from `/Resources/ColorSpace` can use exact byte counts and
   preserve `EI` sequences inside unfiltered payloads. Page-level content
   mutation and resource-renumbering paths now use that resource-aware parser
   when the `PdfPage` or page object already carries a resource dictionary. A
   raw-byte resource-aware parser,
   `PdfDocument::parse_content_bytes_with_resources`, and borrowed
   `PdfDocument::parse_content_view_with_resources` are also exposed for the
   CamlPDF `parse_single_stream` use case. RunLength inline image filters are
   now decoded by consuming the encoded chunks through their EOD marker, so
   `EI` byte sequences inside the compressed payload do not terminate the image
   early. Flate inline image filters are also started by validating and
   consuming the zlib stream prefix before reading the following inline-image
   `EI` marker, covering stored-block payloads that contain `EI` byte
   sequences. LZW inline image filters now consume through the LZW EOD code
   before reading `EI`, while ordinary stream decoding still keeps its tolerant
   missing-EOD behavior. Decoded inline images are flattened without stale
   filter metadata, including supported multi-filter arrays such as
   ASCII85-plus-Flate and RunLength-plus-ASCIIHex where the first filter
   supplies the inline-image data boundary. DCT inline image filter arrays are
   now treated as JPEG payloads whenever DCT is the first filter, so byte
   sequences such as `EI` inside JPEG data do not terminate parsing early; the
   DCT dictionary metadata is preserved because JPEG decoding remains deferred.
   Inline image streams with leading supported filters before a deferred stage,
   such as `/Filter [ /A85 /DCT ]` or ASCIIHex before `/CCITTFaxDecode`, now
   decode the supported wrapper and preserve the remaining filter plus payload
   bytes instead of attempting to decode unsupported image stages. Inline image
   rendering now mirrors CamlPDF's safer default for unfiltered images by
   emitting Flate inline data with `/F /Fl` and `/L`, while filtered inline
   images such as DCT remain byte-preserving. Re-parsing decoded inline images
   also strips stale `/Length`/`/L` metadata alongside filter and
   decode-parameter keys.
   Inline images now honor declared `/L` or `/Length` byte counts before
   falling back to marker scanning when filter or colour-space metadata is not
   enough to compute a size, preserving opaque binary payloads that contain
   `EI` without requiring every filter codec or resource colour space yet.
   After a known inline-image payload has been consumed, the parser now mirrors
   CamlPDF's recovery behavior for malformed trailing bytes by scanning forward
   to a later `EI` marker instead of failing immediately.
   Broader binary inline image filter handling and resource-dependent inline
   image sizing remain deferred.
   Resource-prefix support is started with `shortest_unused_prefix`, scanning
   page and page-tree resource dictionaries with CamlPDF's lower-case prefix
   sequence. `add_prefix` is also started for page/page-tree resources and
   indirect content streams, including shared stream protection and resource
   names inside supported content operators. CamlPDF's `merge_content_streams`
   helper is now started as `PdfDocument::merge_content_streams`, and
   `add_prefix` pre-merges split content arrays when individual streams cannot
   be parsed on their own. Form XObject processing is started with
   `PdfDocument::process_xobjects`, applying a raising callback to indirect
   `/Form` XObject streams while preserving original stream dictionary entries
   and dropping stale `/Filter` metadata after replacement. Deferred form
   stream data is materialized before the callback and has its `/Length`
   corrected, matching CamlPDF's `Pdf.getstream` call. CamlPDF's
   polymorphic `ppstub` helper is ported as `pdf_page_process_stub`, returning
   the callback result, original page number token, and identity matrix for
   page-processing flows that do not transform coordinates. `renumber_pages`
   is now started for page arrays: it assigns fresh `/rN` resource names per
   page and resource category, rewrites supported resource-backed content
   operators, preserves direct device color-space names, and emits a single
   uncompressed rewritten content stream per returned page. CamlPDF's
   `combine_pdf_resources` helper is started as
   `PdfDocument::combine_pdf_resources`, unioning standard resource
   subdictionaries while preserving unknown top-level resource keys. CamlPDF's
   warning/log behavior for missing optional marked-content properties is
   represented by preserving the original name; broader destination/bookmark
   rewrites remain deferred to
   `change_pages`.

   Destination support is started with typed `PdfTargetPage` and
   `PdfDestination` values, direct destination-array parsing/writing, `/D`
   dictionary following, shallow named/string destination preservation, old
   catalog `/Dests` lookup for named destinations through trailer `/Root`
   with an in-memory root fallback, and `/Root/Names/Dests` name-tree lookup
   for string destinations through the same active-catalog path. Matrix
   transformation is also started for
   page-object targets, with CamlPDF-style coordinate clipping and `/GoTo`
   action `/D` rewriting. Page/destination convenience helpers are started
   with `page_number_of_target` and `target_of_page_number`;
   page-number lookup now resolves named and string destinations when the
   catalog or destination name tree contains the target.

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
   replacement. The CamlPDF bookmark debug-line helper is also ported as
   `pdf_string_of_bookmark`, returning `PdfBytes` so bookmark titles remain
   byte-preserving. Bookmark read/remove/add now resolve the active catalog
   through trailer `/Root`, matching CamlPDF for real parsed documents while
   retaining a document-root fallback for synthetic in-memory test fixtures.
   `change_pages` matrix integration is started for
   transformed page destinations, including named destination definitions
   retained in the catalog or destination name tree.

9. Text, fonts, color spaces, and images.
   Port `pdftext`, `pdfstandard14`, `pdfglyphlist`, `pdfcmap`, `pdfafm`,
   `pdfspace`, `pdfimage`, and `pdfjpeg` in that order. Treat encoding
   conversion as byte-sensitive: PDF strings remain `Bytes`, decoded human text
   becomes `String` only through named encoding helpers.
   Status: started with a `pdf_space` foundation for typed colour spaces,
   CamlPDF-compatible debug names, separation colourant names, direct device
   colour-space alias parsing, pattern-with-base parsing, and object rendering
   for device, calibrated, ICCBased, Indexed, Pattern, Separation, and DeviceN
   colour spaces, returning `PdfNull` through the document-level writer when a
   constructed colour-space table cannot be represented safely. A document-aware
   `read_colour_space` entry point now resolves `/ColorSpace` resources and
   nested single-item arrays, and parses CalGray, CalRGB, and Lab dictionaries
   with CamlPDF-compatible defaults for missing optional BlackPoint, Gamma,
   Matrix, and Range entries. ICCBased stream parsing is started for direct and
   indirect stream objects, including `/N`, default alternates, explicit
   `/Alternate`, default or explicit `/Range`, and `/Metadata`. Indexed table
   parsing is started for `/Indexed` and `/I` spaces backed by byte strings or
   decodable stream data, with RGB/CMYK component tables and recursive
   alternate-space handling. Separation and DeviceN parsing is started for
   colourant names, alternate spaces, raw tint-transform objects, and DeviceN
   attributes. `pdftext`/`pdfstandard14` are started with the standard 14 font
   enum, CamlPDF-compatible canonical names and aliases, PDF-name conversion,
   baseline/stem/flag helpers, typed simple encoding values and differences,
   predefined encoding name conversion, simple-font `/Encoding` dictionary
   parsing, standard-14 font detection/reading, byte-oriented UTF-16BE PDF
   Unicode string emission, BOM detection, strict UTF-16BE codepoint parsing,
   byte-oriented UTF-8 codepoint conversion, PDFDocEncoding conversion,
   PDF document string UTF-8/UTF-16BE simplification helpers, and
   CamlPDF-style font descriptor reading for metric defaults, font-file
   references, and `/CharSet` parsing. Simple font metric reading is also
   started with 256-entry width tables, `/MissingWidth` filling, direct/indirect
   numeric width entries, and Type3 top-level metric dictionaries. Simple-font
   records are started for Type1, MMType1, Type3, and TrueType fonts, including
   byte-preserving base font names and Type3 glyph metadata. Font-level
   dispatch is started for standard-14, simple, and Type0 CID-keyed fonts,
   including CamlPDF's `/TrueType` standard-14 compatibility path, byte-backed
   CID system info, predefined and indirect CMap encodings, descendant font
   descriptors, horizontal `/W` widths, vertical `/W2` widths, and default CID
   widths. The `Identity-H` and `Identity-V` predicates are also started over
   the typed CMap encoding model, with a separate public two-byte-code
   predicate for `/Identity-H` and `/Identity-V` CID text so callers do not
   have to treat vertical writing as horizontal identity encoding. Font-writing
   groundwork is started with custom encoding
   dictionary emission and a Type1 font dictionary helper for predefined
   encodings. Standard-14 font writing is started through `write_font`, with
   optional object-number placement. Type3 font writing is also started for
   the same minimal subset as CamlPDF's current writer: zero placeholder font
   box/matrix/width entries, `CharProcs` names mapped to null glyph bodies,
   implicit-in-font-file encoding omission, and indirect custom encoding
   dictionaries. Embedded TrueType font writing is started for the cpdf-style
   subset with `/FontFile2`, descriptor metrics, widths, predefined base
   encodings, `FillUndefinedWithStandard` collapsed to its base encoding, and
   optional object-number placement. Font descriptors now carry an optional
   typed ToUnicode map, and TrueType font writing can emit the same simple
   `/ToUnicode` CMap stream shape as CamlPDF when that map is present. Reading
   simple uncompressed `beginbfchar` forms, sequential `beginbfrange` forms,
   and array-form `beginbfrange` forms is also started. `/ToUnicode` stream
   data is decoded through the supported filter pipeline before parsing, and
   parsed maps are attached to simple or CID font descriptors. Compact
   one-line `beginbfchar`/`beginbfrange` sections with entries before the end
   marker are also accepted. `beginbfchar` lines can contain repeated
   source-to-Unicode pairs, and sequential `beginbfrange` lines can contain
   repeated source ranges. Sequential `beginbfrange` Unicode increments also
   carry across UTF-16BE bytes, so ranges such as `00FE`, `00FF`, `0100` are
   decoded without truncating to the final byte.
   AFM parsing is started with a byte-oriented `pdf_read_afm` API that returns
   header entries, character-code widths, glyph-name widths, and kerning pairs
   without converting AFM syntax or glyph names through `String`. Standard 14
   built-in AFM table access is now started with generated tables derived from
   the vendored CamlPDF AFM data, plus CamlPDF-compatible byte-oriented
   `text_width` helpers that use character-code widths for implicit encodings,
   glyph-name widths for explicit encodings, `/space` fallback for undefined
   encoded bytes, and optional byte-pair kerning.
   A first `PdfTextExtractor` API is started for ToUnicode-backed byte strings
   and `/Identity-H`/`/Identity-V` CID text, including decoded glyph records,
   glyph-name extraction, flattened codepoint extraction, odd-length composite
   string rejection, and reverse ToUnicode charcode lookup for single Unicode
   codepoints. Basic Latin glyph-list-backed fallback is also started for
   StandardEncoding, MacRomanEncoding, WinAnsiEncoding, custom encoding
   differences, effective encoding-table/reverse-table export, and reverse
   charcode lookup over that subset.
   StandardEncoding fallback is started for CamlPDF's annotation-text control
   bytes plus common high-byte punctuation, ligatures, bullets, text marks,
   Adobe Standard accent marks, and common ligature/Latin glyph names.
   MacRoman high-byte fallback is started for common accented Latin letters,
   the contiguous lower-vowel accent block, and the `0xA0..0xAF`
   punctuation/symbol block, plus unambiguous sparse `0xB0..0xBF` entries
   and `0xC0..0xFF` entries. MacRoman and WinAnsi `/mu` now resolve to the
   AGL micro-sign codepoint, while implicit Symbol still resolves `/mu` to the
   Greek small mu codepoint. MacRoman byte `0xFD` is normalized to the AGL glyph
   name `/hungarumlaut`; the CamlPDF source table spells this entry
   `/hungrumlaut`, which is absent from the bundled Adobe glyph list and AFMs.
   The WinAnsi high-byte fallback now covers the CamlPDF table, including
   Euro, smart quotes, dashes, copyright, Latin-1 accented letters, common
   symbols, and the high-byte `/space` and `/hyphen` entries.
   MacExpert fallback is started for the well-defined ligature, oldstyle digit,
   superior digit, inferior digit, fraction, small-capital, accented
   small-capital, small accent-mark, small punctuation/currency, and
   superior/inferior punctuation and letter codepoints.
   Glyph-name decoding now handles suffix-stripped names such as `/A.alt`,
   `uniXXXX` names, `uXXXX` names, CamlPDF TrueType-style `/Gxx` glyph names
   including the source table's `/G6D` and duplicate `/GA6` quirks, and the
   CamlPDF glyph-list control names `/controlCR`, `/controlLF`, `/controlHT`,
   and `/controlFF`; the `/Delta`, `/Omega`, and `/mu`
   conflicts between AGL names and Symbol font names are handled with
   font-specific codepoint lookup. The single-codepoint Latin Extended-A and
   Latin Extended-B names present in CamlPDF's bundled Adobe Glyph List are now
   also covered for common simple-font encoding differences. Basic Latin,
   general-punctuation, Latin-1 spacing aliases, IPA-extension,
   spacing-modifier, combining-mark, currency, letterlike, arrow, Greek,
   Cyrillic descriptive and AFII alias, Armenian, Hebrew AFII/descriptive core
   and presentation-form, Arabic core and presentation-form, Devanagari,
   Bengali, Gurmukhi, Gujarati, Thai,
   math-operator,
   Roman-numeral, technical, enclosed-alphanumeric,
   CJK-symbol/Hangzhou, Hiragana, Katakana, Bopomofo,
   Hangul compatibility jamo, Enclosed CJK, CJK compatibility square/unit,
   CJK vertical/small presentation-form,
   Latin Extended Additional, private-use, Halfwidth/Fullwidth, box-drawing,
   block-element, geometric-shape, miscellaneous-symbol, and dingbat alias AGL
   names missing from the base encoding tables are covered as well.
   Multi-codepoint AGL sequence names are decoded to their full Unicode
   scalar sequence and deliberately remain excluded from single-codepoint
   reverse charcode lookup.
   Reverse charcode lookup scans the effective encoding for single-codepoint
   glyphs.
   ToUnicode CMap parsing now
   handles `bfchar` pairs split across lines, inline and multiline `bfrange`
   array mappings, including range headers split before the array, whitespace
   inside hex strings, PDF whitespace separators between CMap tokens, odd
   hex-string nibbles, and multiple compact
   `beginbfchar`/`beginbfrange` sections on the same physical line. The
   section scan now also follows CamlPDF's whitespace-elided pass, so
   whitespace-split `beginbfchar`/`endbfchar` and
   `beginbfrange`/`endbfrange` markers are accepted. Inline `bfrange` parsing
   now consumes repeated array-form and sequential entries from one line
   instead of stopping after the first array mapping. Multiline `bfrange`
   arrays now also resume parsing after the closing `]`, so trailing same-line
   range entries are retained like CamlPDF's whitespace-elided pass, and mixed
   sequential entries before a later multiline array are kept. A small
   public parsed-CMap API is also started: borrowed CMap bytes and direct or
   indirect stream objects can now return a typed map plus `/WMode`, decoding
   supported stream filters first. `/WMode` parsing now follows PDF whitespace
   tokenization across physical line boundaries and skips malformed candidate
   values before accepting a later valid `/WMode`.
   Standard-14 built-in text extraction is started for implicit encodings:
   non-symbol fonts use the current StandardEncoding subset, while Symbol and
   ZapfDingbats use focused built-in glyph/codepoint subsets. The Symbol
   subset now includes all positive-code Symbol AFM glyph bytes, with common
   set, logic, arrow, double-arrow, math, ASCII punctuation, Greek variant,
   legal mark, extender, integral, and assembly glyph codepoints.
   The ZapfDingbats subset now includes the
   cross/star, starburst, sparkle, geometric, quote-style, high-byte card
   suit, circled-digit, filled-circled-digit, circled-sans-serif-digit,
   negative-circled-sans-serif-digit, high-byte arrow glyph blocks including
   the gapped final arrow tail, and the remaining bracket glyph names from
   CamlPDF's dingbat Unicode map.
   Broader predefined/general `pdfcmap` parsing remains deferred.
   MacExpert byte coverage now matches CamlPDF's table
   for forward extraction, and reverse charcode lookup also honors CamlPDF's
   duplicate `/hyphensuperior` alias for byte `0x5F` while byte extraction keeps
   `/hypheninferior` as the primary glyph name.
   `pdffun` is started with Type 0 sampled, Type 2 interpolation, Type 3
   stitching, and Type 4 calculator function parsing/evaluation for
   numeric and boolean literals, named numeric/comparison/logic operators,
   nested `if`/`ifelse` procedures, comments, doubled-minus malformed numbers,
  stack operators, CamlPDF-style calculator debug string rendering, and
  deterministic whole-function debug string rendering in place of CamlPDF's
  stdout-only `print_function`, with stream decoding for sampled/calculator
  functions, domain clamping, and range clamping. Type 4 calculator integer and float
   stack values now stay distinct, preserving CamlPDF-style integer-only
   operator checks and 32-bit wrapping arithmetic for integer add/sub/mul.
   CamlPDF's `pdfobject_of_function` helper is started as
   `PdfDocument::pdf_object_of_function`, writing Type 2 interpolation
   dictionaries and Type 3 stitching dictionaries with child functions placed
   into the document object map. As in CamlPDF, sampled and calculator function
   serialization currently emits only the common dictionary entries.
   `pdfjpeg` is started with byte-cursor and function-style
   helpers that extract JPEG data through the `FF D9` EOI marker while leaving
   following bytes unread, and content inline image parsing now uses that path
   for `/DCT`, `/DCTDecode`, and single-item filter arrays. `pdfimage` is
   started with typed image result and pixel-layout enums plus image
   `/ColorSpace`/`/CS` and `/BitsPerComponent`/`/BPC` lookup helpers and
   CamlPDF-style `colspace`/`bpc` convenience wrappers,
   including image-mask defaults. `get_image_24bpp` is started for encoded
   JPEG/JPEG2000/JBIG2 pass-through, single-item encoded filter arrays, JBIG2
   globals, filter-stage decoding up to raw or encoded-image stop filters,
   raw 8-bit RGB/CalRGB, packed 1-bit, 2-bit, and 4-bit RGB/CalRGB,
   Gray/CalGray, CMYK, and ICCBased alternate conversion to RGB24.
   Raw 1-bit row-padded image masks plus 2-bit and 4-bit row-padded
   DeviceGray/CalGray images are also started. Indexed RGB/CalRGB and CMYK
   table images are started for 8-bit, 4-bit, 2-bit, and 1-bit row-padded
   samples, including ICCBased and DeviceN bases through their basic alternate
   colour spaces. Lab-backed indexed table conversion is started for 8-bit,
   4-bit, 2-bit, and 1-bit row-padded samples. CamlPDF-style
   `/Decode` handling is started
   for raw image masks and 8-bit raw samples, including default decode arrays
   for encoded image metadata. Encoded image metadata now also preserves
   explicit `/Decode` arrays on `/Indexed` color spaces, matching CamlPDF's
   JPEG/JPEG2000/JBIG2 pass-through result shape. JBIG2 encoded image metadata
   now preserves `/JBIG2Globals` from direct `/DecodeParms`, short `/DP`, and
   first decode-parameter array entries, including after earlier filter stages
   have been decoded and the remaining decode-parameter array has shifted
   forward.
   The raw-image decode path now has a borrowed
   `BytesView` helper for sliced inputs while preserving the owned fast path
   for no-op decode cases, so `.to_owned()` stays at borrowed-to-owned
   boundaries. Raw `/Decode` is now applied before colour-space conversion,
   matching CamlPDF for CMYK and Separation samples where post-RGB decode is
   not equivalent. Separation image pixels are started for 8-bit samples with
   Type 2 and Type 4 tint functions and DeviceCMYK alternates.
   Type 4 calculator bitshift direction, logical right-shift behavior, and
   masked-width behavior are covered. JPEG decoding remains deferred.

10. Encryption.
    Port `pdfcryptprimitives` and `pdfcrypt` once reader/writer/filter basics
    are stable. Decide the primitive strategy first, then add permission flags,
    key derivation, stream/string encryption, decryption, and re-encryption.
    Use small known-vector tests before document-level encrypted fixtures.
    Status: started with the pure ARC4 primitive from `pdfcryptprimitives`,
    exposed as `pdf_arc4_crypt` over `BytesView` inputs and covered with
    standard ARC4 known vectors plus round-trip and empty-key tests. CamlPDF's
    permission enum and signed PDF `/P` mask conversion are also started,
    preserving the R2/R3 denied-permission bit order and signed `Int32`
    values such as `-4`, `-8`, and `-3904`. The MD5 and SHA-256 digest wrappers
    are started through `moonbitlang/x/crypto`, with RFC/FIPS vectors over
    `BytesView` input. Local SHA-384 and SHA-512 primitives are also started for
    the CamlPDF AESV3 revision 6 `shamix` path, with standard FIPS vector tests.
    MD5-backed Algorithm 3.1 object-key derivation is started for R2/R3/R4
    encryption, including object/generation little-endian byte packing,
    key-length truncation, and the AESV2 `sAlT` suffix branch. PDF password
    padding and R2/R3/R4 file-key derivation are also started, including the
    revision 4 no-metadata marker branch. R2/R3/R4 `/U` user-password entry
    generation and user-password authentication are started over the ARC4/MD5
    path. R2/R3/R4 `/O` owner-password entry generation, padded-user recovery,
    and owner-password authentication are also started. AES block,
    IV-prefixed CBC, and ECB primitives are started through the portable
    `illusory0x0/rijndael` MoonBit package, with CamlPDF-compatible PKCS#7
    padding handling. ARC4 object data encryption/decryption using derived
    object keys is started for the legacy string/stream path. AESV2 object data
    encryption/decryption is also started for IV-prefixed strings and stream
    payloads using derived AES object keys. AESV3 object data
    encryption/decryption is started with the unwrapped 32-byte file key.
    Deterministic AES IV and AESV3 random-field provider adapters are started
    for reproducible fixtures, backed by `moonbitlang/core/random` with an
    explicit SHA-256-derived Chacha seed. Native-target secure random bytes are
    started through a pdflite-owned C FFI boundary and are used for AESV2
    convenience writer/recrypt IVs plus AESV3 convenience file keys, salts,
    permissions padding, and IVs; `@random` and `@env.now` remain excluded from
    cryptographic IV/salt generation. Recursive ARC4 crypt plus AESV2/AESV3
    encrypt/decrypt object walks are started for PDF strings, arrays,
    dictionaries, and stream dictionaries/data. Owned stream data is still
    materialized at the crypt boundary with `/Length` refreshed, while parsed
    `StreamToGet` data can carry deferred ARC4/AESV2/AESV3 decryption state and
    materialize only when forced. Stream crypt skipping now matches
    the CamlPDF cases for `/Type /Metadata` when
    `no_encrypt_metadata=true` and identity `/Crypt` filters with absent,
    explicit `/Identity`, or nameless first `/DecodeParms`; non-identity crypt
    filters still decrypt. `/EncryptMetadata false` is now parsed into
    `PdfEncryptionValues` and applied automatically for R4 file-key derivation
    and stream skipping. Copied document-level ARC4, AESV2, and AESV3 revision 5
    user-password and owner-password decryption passes are also started for
    parsed objects, preserving already-decrypted and deferred parser states and
    allowing the encryption dictionary object to be skipped. CamlPDF-style
    `is_encrypted` detection now mirrors CamlPDF's direct `/Encrypt` lookup.
    Single-stream decryption is started for the reader path, authenticating
    optional user/owner passwords and decrypting ARC4, AESV2, and AESV3
    revision 5 stream objects without mutating the document.
    A combined `decrypt_with_passwords` convenience path now tries supplied
    user and owner passwords, falls back to an absent/blank user password when
    no credentials are supplied, and returns permissions with the decrypted
    document. CamlPDF-style encrypted-document introspection is also started
    with `what_encryption` and `permissions`, reporting standard ARC4/AES
    method families and denied permission lists without requiring decryption.
    Decrypted document copies now preserve a `PdfSavedEncryption` snapshot of
    the original encryption values, matching CamlPDF's prerequisite state for
    future re-encryption after modification. Re-encryption is started for saved
    40-bit ARC4, 128-bit ARC4 revision 3, 128-bit ARC4 revision 4, and
    explicit-IV-provider AESV2 revision 4 and AESV3 revision 5 documents.
    Saved-state recrypt now promotes `ObjectParsedAlreadyDecrypted` parser
    entries back to ordinary parsed plaintext before encrypting, so non-stream
    payload objects extracted from encrypted object streams are encrypted again
    instead of being written as cleartext.
    AESV2 recrypt also has classic plus uncompressed and Flate-compressed
    xref-stream incremental update gates; AESV3 revision 5 and revision 6/ISO
    recrypt have a classic writer/read/decrypt round-trip gate plus classic,
    uncompressed xref-stream, and Flate-compressed xref-stream incremental
    update gates, including `/EncryptMetadata false` metadata-stream skipping.
    Default AESV2 and AESV3 recrypt are now started on native through the same
    secure random-byte boundary. Provider callbacks are fallible where entropy
    can fail, so callers and tests can let `PdfError` propagate rather than
    hiding random-source failures behind deterministic fallbacks.
    Typed standard-encryption dictionary
    parsing is started with CamlPDF-compatible `/V`, `/R`, `/Length`,
    `/CF`/`/StdCF`/`/CFM`, `/O`, `/U`, `/P`, trailer `/ID`, `/OE`, and `/UE`
    handling. The parser now reports structured errors for unencrypted files,
    unsupported encryption methods, malformed required entries, short `/O` or
    `/U` entries, and missing trailer IDs. Typed password authentication and
    file-key derivation are started on top of parsed encryption values for
    ARC4 revisions 2/3 and AESV2 revision 4. AESV3 revision 5 SHA-256 and
    revision 6/ISO `shamix` user-password and owner-password authentication are
    also started, including `/UE` and `/OE` file-key unwrap through
    AES-256-CBC with no padding. AESV3 `/Perms` parsing and validation is
    started for revision 5 and 6 file-key unwraps, including missing, short,
    corrupt marker, and `/P` mismatch errors.
    Parsed-object output encryption is started with CamlPDF-style 40-bit ARC4,
    128-bit ARC4 revision 3, 128-bit ARC4 revision 4 crypt filters, and an
    explicit-IV-provider AESV2 revision 4 path: it preserves or installs trailer
    `/ID`, derives `/O` and `/U`, encrypts parsed objects in a copy, installs an
    indirect `/Encrypt` dictionary, applies the revision 4 `/EncryptMetadata`
    file-key and metadata-stream rules, and round-trips through the existing
    password decryption APIs. A `pdfencrypt.ml`-style fixture now covers
    AES-128 output with blank user password, owner password, `NoEdit`/`NoPrint`
    denied permissions, classic writing, parsing, and user/owner decryption.
    Provider-backed AESV3 revision 5 and revision
    6/ISO output is also started: it accepts explicit file-key, salt, `/Perms`
    padding, and object-IV providers, derives `/U`, `/O`, `/UE`, `/OE`, and
    `/Perms`, applies `/EncryptMetadata` stream skipping, and round-trips
    through user and owner password decryption. A named
    `encrypt_256bit_aesv3_iso_with_providers` helper now mirrors CamlPDF's
    AES-256 ISO output entry point while preserving deterministic provider
    injection for tests. The revision 4 ARC4 path now also has
    classic-writer/classic-reader/decrypt,
    xref-stream-writer/xref-stream-reader/decrypt, and encrypted incremental
    update integration gates.
    Revision 6/ISO `shamix` now uses the local SHA-256/SHA-384/SHA-512 helpers
    plus the CamlPDF AES-CBC loop, and AESV3 revision 6 parsed-object crypt now
    shares the existing AESV3 file-key object crypt path.
    The document-level decryption entry points for parsed ARC4, AESV2, and AESV3
    documents remove `/Encrypt` from the copied trailer, skip the indirect
    encryption dictionary object, preserve deferred parsed stream decryption for
    file-backed streams, and return CamlPDF-style denied permissions. Remaining
    encrypted malformed-reader compatibility outside streams and object-stream
    expansion remains deferred.

11. Higher-level document features.
    Continue bookmarks/marks, page labels, annotations, optional content
    groups, merge, duplicate-font removal, date helpers, and remaining
    utilities. Use CamlPDF examples and regression fixtures as acceptance tests.
    Status: started with typed page label styles/records, `/PageLabels`
    number-tree reading, replacement writing, empty-list removal, returned
    catalog-copy updates, basic completion, bounded range insertion,
    single-page label lookup, rendered label bytes for
    decimal/roman/letter/prefix-only styles, adjacent range coalescing,
    merge-label construction for selected page ranges, CamlPDF-compatible
    label-style debug string parsing/rendering, byte-preserving page-label
    debug-line rendering, malformed page-label range key fallback to page 1
    with odd trailing `/Nums` entries ignored like CamlPDF, malformed empty
    `/PageLabels` trees rejected, and active-catalog page-label
    read/write/remove through trailer `/Root` with document-root fallback for
    synthetic fixtures. Annotation support is
    started with typed subtypes, borders, colours, byte-preserving
    contents/subjects, page annotation reading with popup-parent filtering,
    page-record annotation insertion, CamlPDF-compatible `/Unknown`
    serialization for unknown subtypes, and geometry transforms for `/Rect`,
    `/QuadPoints`, and `/L` on both indirect annotation objects and direct
    annotation dictionaries inside `/Annots` arrays. Date support is started
    with typed PDF dates,
    CamlPDF-compatible default fields, Distiller Y2K recovery, checked ranges,
    borrowed `BytesView`/owned `Bytes` parsing, local-time delimiter quirks,
    PDF date string/byte rendering, and `PdfString` object conversion helpers.
    Optional content group support
    is started with typed OCG usage/configuration/application records,
    `/OCProperties` reading, returned-copy writing/removal, byte-preserving
    PDF strings, and explicit `PdfName` fields for PDF name values. OCG
    read/write/remove now resolve the active catalog through trailer `/Root`,
    matching CamlPDF for parsed documents while preserving the document-root
    fallback for synthetic fixtures. OCG merge preparation is
    started with a typed helper for combining already-renumbered optional
    content metadata across documents. Merge support code is started with
    returned-copy object renumbering by positive offset, including root,
    trailer, and nested indirect-reference rewriting. Merge catalog-entry
    reads for AcroForm, OpenAction, named destinations, and name dictionaries
    now resolve the active catalog through trailer `/Root`, with a
    document-root fallback for synthetic fixtures. Merge catalog-extra scans
    and structure-root scans use the same active catalog path, and merge
    catalog-entry additions are based on that active catalog. A first minimal
    document merge helper now extracts requested page ranges, offsets object
    numbers, concatenates pages, preserves the maximum input version, and
    removes unreferenced imported roots/catalogs. Merge page-label retention is wired
    through the existing page-label merge helper behind an explicit option.
    Merge bookmark retention now reuses per-document page extraction to filter
    bookmarks, then retargets retained page-object destinations to the merged
    page tree. Malformed source bookmark sets are ignored during extraction and
    merge, matching CamlPDF's warning-and-continue merge behavior while
    preserving valid bookmarks from other inputs. Merge optional-content
    retention now combines already-renumbered OCG metadata before unreferenced
    imported OCG objects are pruned, and a malformed optional-content merge is
    treated as absent merged OCG metadata instead of aborting the document
    merge. Basic
    AcroForm merge support now flattens retained `/Fields` arrays, retains
    non-field form entries with later entries replacing earlier duplicate keys,
    and preserves referenced field objects through the final cleanup. Named
    destination retention now merges old-style catalog `/Dests` and name-tree
    `/Names` `/Dests`, retargeting page-object destinations to the merged page
    tree. Malformed retained destination definitions fall back to raw
    object-level page-reference renumbering instead of aborting the merge,
    matching CamlPDF's dictionary/name-tree merge path. Destination-name
    collisions across merged `/Names/Dests` trees and old-style catalog
    `/Dests` dictionaries are now disambiguated with CamlPDF-style `-fN`
    suffixes. String and name destination callsites such as
    link annotation `/Dest` entries, GoTo action `/D` entries, and retained
    named/string-target bookmarks are rewritten to the renamed keys, including
    cross-document callsites that fall back to the first global renamed target.
    Merge trailer info retention now preserves the first available `/Info`
    dictionary through the merged trailer, and merged documents now install a
    trailer `/ID` entry at the final merge boundary.
    Safe catalog-entry retention now carries first-seen non-page/non-handled
    catalog entries, such as viewer preferences. Catalog `/OpenAction`
    retention is now started behind the same flag: the merge keeps the first
    valid destination/action that still targets a retained page, retargets its
    page reference to the merged page tree, rewrites named targets through
    collision suffixes, drops named-target actions when named destinations
    are not retained, and ignores malformed actions instead of aborting the
    merge. Duplicate-font removal is started with
    CamlPDF-style identical stream coalescing: references to duplicate
    `StreamGot`, deferred `StreamToGet`, or already-decrypted stream objects
    are rewritten to the first matching stream after comparing borrowed
    stream-data views, and `pdf_merge_documents` can run this pass behind an
    explicit option. Generic
    name-dictionary merge support now retains non-destination `/Names` name
    trees such as `/EmbeddedFiles` and `/JavaScript`; `/Dests` remains on the
    destination-aware path so page-object targets are retargeted. The merge
    path now also rewrites retained object references from selected source page
    objects to the newly built merged page objects, matching CamlPDF's
    post-page-tree renumbering pass more closely. A `pdfmergeexample.ml`-style
    acceptance fixture now exercises the public renumber/copy/add-page-tree/root
    workflow, unreferenced-object pruning, classic writing, and reading as one
    end-to-end path. Structure-tree retention is
    started for the single-root case: extraction trims removed page nodes, the
    merged catalog keeps that `/StructTreeRoot`, and global page-reference
    rewriting retargets retained `/Pg` links. Multi-root structure-tree merging
    is now started by creating a merged `/StructTreeRoot`, adopting each
    retained root's `/K` children, and rewriting immediate child `/P` links to
    the new root. Structure parent-tree renumbering is also started:
    `/StructParent` and `/StructParents` integer keys are made globally unique
    across merged inputs and the merged root receives a combined `/ParentTree`;
    the standalone `pdf_renumber_parent_trees` helper now mirrors CamlPDF's
    pre-merge parent-tree renumbering pass for document arrays, including
    trailer-rooted `/StructTreeRoot`/`/ParentTree` lookup and replacement for
    parsed PDFs while preserving the document-root fallback used by synthetic
    tests without a trailer `/Root`.
    Multi-root structure metadata merging now covers `/IDTree`, `/RoleMap`,
    `/ClassMap`, `/Namespaces`, `/PronunciationLexicon`, and `/AF`. Optional
    top-level `/Document` wrapping is started behind
    `add_toplevel_document=true`, adding the PDF/UA-2 namespace and placing
    merged `/K` children under that document node.

12. Async I/O and command-facing APIs.
    Add async native-target wrappers for reading and writing files after the
    pure `Bytes` APIs are stable. Async wrappers should load/store bytes and
    call the synchronous core. Add `moon test --target native` coverage for
    async file APIs.
    Status: started with a native-only `async_io` package using
    `moonbitlang/async/fs`. It exposes `pdf_read_document_from_file` and
    `pdf_write_document_to_file` wrappers around the pure byte reader/writer,
    plus file revision counting, revision-specific file reads,
    password-based encrypted reads,
    revision-specific password reads, uncompressed and Flate-compressed
    xref-stream file writes, mode-dispatched full and incremental writes,
    direct encrypted ARC4/AESV2/AESV3 file writes with provider-backed AES
    randomness, native secure-random AESV2/AESV3 file writes, and
    classic/xref-stream incremental-update file writes. Native async tests cover
    plain round-trip, xref-stream round-trip, encrypted password read,
    mode-dispatched compressed xref output, encrypted writer file output across
    ARC4/AESV2/AESV3 variants plus the native secure-random AESV2/AESV3
    wrappers, classic incremental readback, revision-specific incremental
    readback, uncompressed plus compressed xref-stream incremental readback, and
    mode-dispatched compressed
    incremental update readback; test paths now use core
    `@env.current_dir` and `@env.now` to avoid fixed filename collisions under
    repeated or concurrent native test runs.

13. Compatibility and coverage hardening.
    Add fixture suites as features land, update snapshots deliberately, and use
    `moon coverage analyze > uncovered.log` to find untested parser, writer,
    filter, and page-tree branches.
    Status: started with a coverage pass that tightened public `ByteCursor`
    boundary tests for remaining length, `peek`, end views, negative offsets,
    rewind errors, seek-past-end reads, and owned line allocation. Annotation
    coverage was also broadened through public APIs for subtype
    serialization/parsing, border-style parsing, preserved rest entries,
    existing annotation arrays, and malformed quadpoint preservation. Bookmark
    coverage now includes preserved string destinations, action destinations,
    action fallback behavior, missing titles, and malformed color arrays.
    Codec coverage now includes ASCII85 malformed inputs, LZW EOF/reset/error
    boundaries, predictor identity/Paeth/short-row/error paths, stream
    filter/decode-parameter composition, `only_if_smaller` stream encode
    gating, excessive filter-stage bounds, and RunLength
    long-literal/truncated-input behavior. Content-stream coverage
    now includes broad operator render/parse round trips, unknown operator
    preservation, inline-image comments and malformed dictionaries, nested
    content objects, and parse errors for malformed arrays and non-stream
    content references. Date coverage now includes short-year padding,
    positive timezone rendering, `Z` and trailing non-local timezone parsing,
    incomplete optional fields, non-digit failures, and Distiller Y2K recovery.
    A focused whitebox check now covers the duplicate-stream comparison
    fallback for non-stream objects. Destination coverage now includes all
    supported direct destination variants, malformed destination targets,
    named/string lookup fallbacks, destination object rendering, page-number
    target variants, and coordinate transforms for `FitBH`, `FitBV`, and
    partial `XYZ` targets. Lookup and transform coverage now includes recursive
    indirect-reference depth guards, non-dictionary direct lookup, bad rectangle
    contents, operation-to-matrix dispatch, overflow-scaled matrix inversion,
    and parser-private already-decrypted object-state copying. Pure helper
    coverage now also covers `ToGet` accessors, non-dictionary stream
    dictionary views, checked dictionary mutation errors, stream dictionary
    replace/remove branches, all public unit-conversion arms, and the exported
    ISO/US paper-size constants. Parser and writer coverage now includes
    truncated array/dictionary recovery, malformed indirect-object prefixes,
    byte escaping for uppercase hex, control-character string escapes,
    deferred object write errors, writer-side `StreamToGet` materialization,
    and private scientific/fixed-small real formatting branches used by
    exponent-free PDF number serialization. Page-label coverage now includes
    empty-source continuation insertion, high-value Roman
    labels, lowercase letter labels, writing all public label style variants,
    private lowercase byte preservation, and the private root guard used by
    page-label removal/write paths. Annotation/bookmark coverage now includes
    malformed annotation dictionaries, missing annotation arrays, bad existing
    annotation arrays, non-array quadpoint transform preservation, rect-only
    annotation transforms, private annotation rest validation, and the private
    bookmark outline root guard. Structure trimming coverage now includes
    `/Obj`-based child pruning that removes now-empty parent `/K` arrays, plus
    private survival-helper checks for `/Pg`, direct non-indirect `/K` items,
    and non-dictionary structure values. Codec coverage now includes malformed
    decode-parameter dispatch during stream decode, document-aware indirect
    filter/decode-parameter resolution, stop-at-unknown stream decode behavior,
    plus private filter-entry, decode-parameter, predictor-byte-width, and LZW
    table-validation guards.
    Name/number tree coverage now includes malformed key-type rejection,
    duplicate number-key replacement, large nested tree construction with child
    `/Limits`, and private grouping threshold checks. Flate coverage now
    includes empty and short zlib inputs, fixed-Huffman blocks, invalid stored
    block lengths, invalid block types, empty stored-block encoding, and private
    bit-reader/Huffman-table guards. Lexeme coverage now includes all debug-name
    variants, uppercase/lowercase hex escapes in names, false and malformed
    booleans, malformed/oversized numbers, literal-string escape edge cases,
   hex-string EOF/error cases, and token dispatch for booleans, hex strings,
   non-special `s` keywords, and inline-image stop markers. Reader coverage now
   removes `pdf_reader.mbt` from the uncovered-line report by testing public
   malformed-file behavior, private byte-view/xref helpers, indirect stream
   length resolution failures, CamlPDF-compatible malformed zero-offset xref row
   handling, repeated and inline xref section markers, trailing startxref junk
   after EOF, inline startxref pointers, malformed startxref-number recovery,
   and by deleting two unreachable defensive branches around xref blank-line
   parsing and post-loop trailer presence. Stream-object coverage now also
   checks CamlPDF's ignored
   stream-start padding bytes before newline or data, plus missing, unreadable,
   unparseable, negative, short, and long declared `/Length` values that recover
   through `endstream` scanning; the obsolete public `StreamLengthExpected`
   reconstruction arm is removed because strict stream-length failures now
   convert to malformed-stream scanning.
    Date, document-copy, renumbering, and writer coverage now remove those
    files from the uncovered-line report by covering private short-date and
    stream materialization guards and by replacing impossible map-key `None`
    arms with explicit key-invariant unwraps. Parser and page-label coverage now remove
    those files from the uncovered-line report by replacing impossible parser
    progress checks and non-empty page-label no-break arms with simpler
    invariant-preserving control flow. Bookmark and codec coverage now remove
    those files from the uncovered-line report by covering the private bookmark
    traversal depth guard and LZW bit-reader error conversion, while removing an
    impossible empty LZW expansion check. Flate coverage now removes
    `pdf_flate.mbt` from the uncovered-line report with direct private tests for
    dynamic-code-length symbol bounds, repeated-length overflow, malformed
    dynamic repeats, invalid length symbols, invalid distance symbols, and
    backwards copies past the available output. Content coverage now exercises
    private malformed operand fallbacks, inline-image data boundaries, unknown
    and inline-image render sections, complex-object reads, and invalid
    known-operator parsing; `pdf_content.mbt` is down to one defensive
    post-decode stream-shape branch. Merge coverage now removes
    `pdf_merge.mbt` from the uncovered-line report with whitebox checks for
    version guards, catalog extras, structure-parent renumbering, structure
    lexicon merging, AcroForm field merging, catalog-root errors, and all
    destination retargeting variants. Optional-content-group coverage now
    removes `pdf_ocg.mbt` from the uncovered-line report with whitebox checks
    for malformed array readers, sparse order/app dictionaries, usage
    fallbacks, malformed OCProperties roots, copy/merge helpers, and optional
    writer fields. Page coverage now removes `pdf_page.mbt` from the
    uncovered-line report with whitebox checks for page-tree guards, duplicate
    page-object repair, parent-link repair, content stream shapes, destination
    and annotation transform fallbacks, duplicate annotation/destination
    cleanup, resource prefixing and renumbering, and reference collection edge
    cases. Colour-space coverage now covers typed
    debug-name variants, document resource fallbacks, calibrated defaults,
    ICCBased defaults and malformed dictionaries, Indexed table parsing and
    malformed table bounds, and Separation/DeviceN parsing fallbacks.
    Function coverage now directly exercises Type 4 trig, angle, conversion,
    integer division, remainder, log, bitshift direction, logical right shift,
    masked shift counts, integer wrapping, float rejection for integer
    operators, comment, and malformed-number paths. Writer and core stream-data
    coverage now removes `pdf_writer.mbt` and `pdf_object.mbt` from the
    uncovered-line report by testing `%.12g`-style real formatting branches,
    scientific exponent expansion, malformed private formatter inputs, and
    invalid deferred stream slices. Content coverage now removes
    `pdf_content.mbt` from the uncovered-line report by testing remaining
    inline-image DCT branches and replacing an impossible post-decode fallback
    with a private stream-returning decoder helper. Colour-space stream-table
    coverage now removes `pdf_space.mbt` from the uncovered-line report by
    reusing that private stream-returning decoder at the indexed-table
    ownership boundary. Image coverage now removes `pdf_image.mbt` from the
    uncovered-line report by tightening the staged image decoder to return a
    private raw/JPEG/JPX/JBIG2 stream enum, materializing deferred stream data
    at the owned-byte boundary, and testing malformed image metadata, decode
    arrays, encoded decode defaults, indexed-table edge cases, unsupported raw
    spaces, JBIG2 globals, and private decode math. Function coverage now
    removes `pdf_fun.mbt` from the uncovered-line report by exercising sampled
    function option/default/error paths, interpolation and stitching dictionary
    validation, calculator parser errors, calculator evaluator stack/type
    errors, and private sampled/stitching guard paths. Flate coverage now
    includes dynamic-Huffman code-length generation, canonical code emission,
    code-length RLE branches, empty/error fallback paths, and a black-box
    dynamic block round trip. Text coverage now
    removes `pdf_text.mbt` from the uncovered-line report by using the private
    stream-returning decoder for ToUnicode streams, simplifying CMap marker
    extraction, and covering malformed encodings, font descriptors, CID widths,
    ToUnicode CMap parser guards, glyph fallback paths, and UTF-8 failure modes.
    Native-random coverage now exercises the secure-random wrapper's success,
    negative-length raise, provider-failure raise paths, AESV2/AESV3 decrypting
    writer output, and AESV3 saved-state recrypt without asserting incidental
    error constructors. The unused template `cmd/main` executable was removed
    rather than testing placeholder `Hello` output. A refreshed coverage
    pass reports no uncovered lines.

## Active Native Acceptance Milestone

The migration is now focused on native feature parity through broad public
workflow gates, rather than isolated small edge cases. The first acceptance
layer is `pdf_native_acceptance_test.mbt`, a black-box suite that exercises
public APIs end to end:

- construct a one-page standard-font document and verify classic xref,
  xref-stream, and compressed xref-stream read/write/reread invariants;
- extract text from parsed page content with a filtered ToUnicode CMap stream
  after compressed xref-stream write/read boundaries, including `Tj` and `TJ`
  content operators and reverse charcode lookup;
- extract Type0 `/Identity-H` CID-keyed text from parsed page content after
  compressed xref-stream write/read boundaries, including two-byte `Tj`/`TJ`
  text and public font identity predicates;
- extract Type0 `/Identity-H` CID-keyed text with a filtered `/ToUnicode` CMap
  after compressed xref-stream write/read boundaries, including two-byte
  `Tj`/`TJ` text remapping and reverse charcode lookup;
- extract images from page resources and parsed content after compressed
  xref-stream write/read boundaries, including Flate-decoded raw `/Indexed`
  image XObjects, staged Flate-then-DCT encoded-image pass-through, and Flate
  inline images that survive document-wide stream decompression and reread;
- preserve a partially decoded stream-filter workflow through read/write/reread;
- append and read classic and compressed-xref-stream incremental revisions,
  including newest-versus-older revision checks;
- append and read a mode-dispatched compressed-xref-stream incremental revision
  through the public `PdfWriteMode` API;
- recover a valid page tree when the strict xref table omits `/Pages` and page
  objects, then normalize the reconstructed document through the writer;
- read a valid page tree whose `/Pages` and `/Page` objects live inside an
  object stream, then normalize it through the classic writer and reread it;
- write AES-128 encrypted output and read it through the public password
  wrapper with both user and owner passwords.
- preserve deferred ARC4/AESV2/AESV3 stream decryption when password-aware reads
  parse file-backed streams, then force plaintext and `/Length` correction.
- write AESV2 encrypted output through the native secure-random convenience
  writer, prove repeated writes differ with a fixed file ID, and decrypt the
  result through the public password wrapper.
- write AESV3 and AESV3 ISO encrypted output through native secure-random
  convenience writers, decrypt the results, and recrypt a modified AESV3
  document from saved encryption state.
- run a `pdfencrypt.ml`-style AES-128 encrypted writer workflow with blank user
  password, owner password, `NoEdit`/`NoPrint` denied permissions, and classic
  output readable by both default blank-user and owner-password paths.
- decrypt AES-128 output through the public wrapper, mutate the decrypted
  document, recrypt with the saved encryption state, append an incremental
  update, and read both newest and older encrypted revisions.
- preserve `/EncryptMetadata false` through compressed AESV2 encrypted output,
  public password reads, plaintext metadata inspection in encrypted bytes,
  saved-state recrypt, compressed rewrite, and owner-password reread.
- merge two generated documents, write/read through a compressed xref stream,
  extract pages in a new order, and reread the extracted document.
- run a `pdfmergeexample.ml`-style manual merge workflow over documents that
  were first parsed through compressed xref streams, using public renumber,
  page-tree rebuild, root creation, and unreferenced-object cleanup APIs, then
  compressed write/reread the merged output.
- retain merged page labels and bookmark targets through a public
  merge/write/read compressed xref-stream boundary.
- merge documents that were first parsed through compressed xref streams while
  retaining AcroForm fields, optional content groups, structure trees with
  parent trees, and the first trailer `/Info` dictionary through the merged
  compressed write/read boundary.
- run a `pdfdecomp.ml`-style document-wide stream decompression workflow,
  preserve unsupported tail filter metadata, write compressed xref-stream
  output, and reread the decompressed stream.
- run a `pdftest.ml`-style split-content parse/rewrite workflow through
  `change_pages`, remove stale objects, write compressed xref-stream output,
  and reread the normalized single-stream page content.
- run a `pdfdraft.ml`-style image replacement workflow that removes image
  XObjects and inline images, preserves form XObjects, writes compressed
  xref-stream output, and rereads the transformed content.
- run a page resource lifecycle workflow after a compressed xref-stream read:
  materialize and process Form XObjects, prefix resource dictionaries and
  content references while merging split content streams, duplicate and
  `renumber_pages`, then write/reread the renamed pages.
- replace a resource-heavy page with `change_pages` after a compressed
  xref-stream read while preserving page resources and transforming direct and
  indirect link destinations, GoTo action annotations, catalog `/OpenAction`,
  old-style `/Dests`, name-tree destinations, and bookmark resolution through
  write/reread.
- run `change_pages` after a compressed xref-stream read boundary, rewrite
  bookmark page references with a matrix transform, write/reread, and verify
  the transformed bookmark target.
- run count-changing `change_pages` after a compressed xref-stream read
  boundary with explicit serial reference mapping, preserving trailer `/ID` and
  root metadata while retargeting bookmarks and transforming catalog
  `/OpenAction` destinations through write/reread.
- extract pages that reuse annotation and popup objects after a compressed
  xref-stream read boundary, duplicating the annotation pairs and repairing
  `/Popup` and `/Parent` links through write/reread.
- extract a selected page with `process_struct_tree=true` after a compressed
  xref-stream read boundary, pruning structure tree kids that target dropped
  pages while retargeting the surviving kid through write/reread.
- preserve document-level feature state through a compressed xref-stream
  read/edit/write/reread lifecycle: page labels, link annotations, old-style
  destinations, name-tree destinations, open actions, and matrix-transformed page
  targets.
- exercise native async file wrappers for encrypted incremental updates:
  encrypted write to disk, password read, decrypt/mutate/recrypt, compressed
  xref-stream incremental write, revision count, and newest/older encrypted
  revision reads.
- read AES-128 encrypted xref-stream documents whose referenced object lives
  inside an encrypted `/ObjStm`, proving password-aware object-stream expansion
  for explicit passwords and implicit blank user passwords while avoiding double
  decryption of the embedded object.
- recrypt a decrypted AESV2 document whose non-stream payload came from an
  encrypted `/ObjStm`, proving saved-state recrypt encrypts
  `ObjectParsedAlreadyDecrypted` plaintext before compressed write/read.
- read a minimal page tree through a CamlPDF-tolerated malformed classic xref
  table, then normalize it through the writer and reread it.
- decrypt an AES-128 document after forcing malformed-xref reconstruction,
  proving direct encrypted objects still pass through the public password
  wrapper after xref fallback.

Near-term work should extend this suite with the next visible public workflow
gate, then fix the reader/parser/encryption gap it exposes. Isolated malformed
input quirks should be added only when they unblock one of the native gates.
Broader backend validation remains deferred until native feature parity is
stable.

## Update Discipline

Each migration slice should leave behind:

- The source OCaml file(s) covered.
- The MoonBit files added or changed.
- The verification command(s) used.
- Any known incompatibility or deferred behavior.
