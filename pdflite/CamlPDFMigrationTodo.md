# CamlPDF Migration Todo

This is the progress tracker for the pdflite CamlPDF migration. Update this
file whenever a substantial migration slice lands. Keep `OCaml2MoonBit.md`
library-agnostic; project architecture details belong in
`CamlPDFArchitecturePlan.md` and `CamlPDFMigrationPlan.md`.

Current estimate:

- Native main-feature parity: 90-92%.
- Full CamlPDF parity across deferred filters, malformed recovery, and backend
  breadth: 79-84%.

## P0: Native Main Workflows

- [x] ~~Byte foundation with `Bytes`/`BytesView` ownership boundaries.~~
- [x] ~~Core PDF object graph, dictionaries, indirect refs, streams, lazy stream
  slices, document state, traversal, and renumbering.~~
- [x] ~~Classic xref, xref-stream, compressed xref-stream, object-stream,
  revision-specific, and major reconstructed read paths.~~
- [x] ~~Full and incremental writer modes, including public `PdfWriteMode`
  dispatch.~~
- [x] ~~Native async file read/write wrappers for core, encrypted, and
  incremental workflows.~~
- [x] ~~Page tree read/write, `pages_of_pagetree`, `add_pagetree`, `add_root`,
  `endpage`, inherited page attributes, extraction, and cleanup.~~
- [x] ~~Public merge and extraction workflows through compressed
  read/write/reread boundaries.~~
- [x] ~~Example-level gates for `pdfdecomp.ml`, `pdftest.ml`, `pdfdraft.ml`,
  `pdfencrypt.ml`, and `pdfmergeexample.ml`.~~
- [x] ~~Page labels, bookmarks, annotations, duplicate annotation repair,
  old-style destinations, name-tree destinations, `/OpenAction`, optional
  content, AcroForm merge basics, trailer `/Info`, and structure-tree
  merge/pruning basics.~~
- [x] ~~`change_pages` bookmark/destination matrix rewriting and count-changing
  replacement with explicit reference mapping.~~
- [x] ~~ARC4/AESV2/AESV3 authentication, encryption, decryption, native
  secure-random writer paths, saved-state recrypt, encrypted object streams,
  lazy encrypted streams, and `/EncryptMetadata false`.~~
- [x] ~~Page resource lifecycle native gate: `renumber_pages`, `add_prefix`,
  `merge_content_streams`, and `process_xobjects` through
  read/edit/write/reread boundaries.~~
- [x] ~~Broader `change_pages` compatibility gate using resource-heavy pages and
  mixed destination/action references.~~
- [x] ~~Non-stream encrypted parser-state edge gate through public password-read
  or recrypt workflow.~~
- [x] ~~Broader encrypted malformed-reader gate beyond stream/object-stream data.~~
- [x] ~~Feature-rich classic malformed-xref reconstruction gate covering labels,
  annotations, destinations, name-tree destinations, catalog actions,
  `change_pages`, and compressed rewrite/reread.~~

## P1: Format Parity

- [x] ~~ASCIIHex, ASCII85, RunLength, LZW decode, Flate decode/encode,
  predictors, filter arrays, and stop-at-unknown stream decompression.~~
- [x] ~~Color spaces, functions, standard fonts, encodings, PDFDocEncoding,
  UTF-16BE, ToUnicode CMaps, Identity-H/V CID text basics, and native text
  extraction gates.~~
- [x] ~~Raw/encoded image extraction basics, including indexed raw samples,
  staged Flate-to-DCT pass-through, and inline image parsing gates.~~
- [x] ~~Identity-V predefined CMap native text gate with vertical width
  metadata through compressed read/write/reread boundaries.~~
- [x] ~~JPX and staged Flate-to-JBIG2 encoded image native gate with
  `/JBIG2Globals` through compressed read/write/decompress/reread boundaries.~~
- [x] ~~CCITT image XObject native gate through compressed
  read/write/decompress/reread boundaries.~~
- [x] ~~Embedded TrueType `FontFile2` plus `/ToUnicode` native text gate through
  compressed read/write/reread boundaries.~~
- [x] ~~CCITT `/K 0` and `/K < 0` native stream decode with `/DecodeParms`
  parsing and `/CCF` alias coverage.~~
- [x] ~~Typed CCITT Group 3 `/K 0` stream encoding with `/DecodeParms`
  round-trip coverage.~~
- [x] ~~Typed CCITT Group 4 `/K < 0` stream encoding with `/DecodeParms`
  round-trip coverage.~~
- [x] ~~Real xref-stream/object-stream malformed-startxref recovery through a
  checked-in CamlPDF fixture, multi-page text extraction, compressed rewrite,
  and reread.~~
- [x] ~~Multi-revision xref-stream/object-stream malformed-startxref recovery
  gate where the newest revision moves `/Root` into an object stream.~~
- [x] ~~Real CamlPDF intro compressed-xref incremental malformed-startxref
  recovery where the newest revision reuses an older xref-stream object number
  for ordinary payload data.~~
- [x] ~~Password-aware xref-stream/object-stream malformed-startxref recovery
  for encrypted object streams, including decrypted embedded payload materialization.~~
- [x] ~~Hybrid classic trailer `/XRefStm` malformed-startxref recovery, loading
  both table and xref-stream objects while sanitizing trailer xref keys.~~
- [x] ~~Classic multi-revision `/Prev` malformed-startxref recovery, selecting
  the newest body-scanned catalog while sanitizing trailer xref keys.~~
- [x] ~~Predefined UCS2 horizontal/vertical CMap two-byte text extraction gate
  through reader and extractor boundaries.~~
- [x] ~~Predefined UTF16 horizontal/vertical CMap two-byte text extraction
  through CID-keyed reader and extractor boundaries.~~
- [x] ~~Mixed-byte predefined CMap charcode segmentation for common EUC, RKSJ,
  Big5, UHC, and GBK families through `/ToUnicode` text extraction.~~
- [x] ~~RKSJ predefined CMap built-in ASCII and half-width Katakana fallback
  when `/ToUnicode` is absent, including reverse charcode lookup.~~
- [ ] Broader built-in non-UCS2 predefined CMap mapping tables beyond the RKSJ
  single-byte fallback, plus more vertical-writing text behavior when
  `/ToUnicode` is absent.
- [x] ~~Type3 font `/ToUnicode` native text gate with indirect CharProcs,
  custom encoding, metrics, compressed rewrite, and reread.~~
- [x] ~~Direct Type3 CharProc stream reader coverage for preserved `d0`/`d1`
  glyph programs and expanded Type3 metrics.~~
- [ ] More TrueType and Type3 glyph-program edge coverage beyond the current
  Type3 and embedded TrueType gates.
- [x] ~~Structured DCT/JPEG marker payload native gate for Flate-to-DCT image
  XObjects and DCT inline images with embedded `EI` bytes before EOI.~~
- [ ] Additional real-world DCT/JPEG encoded-payload corpus coverage.
- [ ] Optional external JBIG2 decoder integration and broader CCITT corpus
  validation.
- [x] ~~Explicit zlib-style Flate level API across direct Flate, filter, and
  stream encoding surfaces.~~
- [x] ~~Fast explicit Flate levels fall back to stored blocks for incompressible
  data instead of forcing larger fixed-Huffman output.~~
- [ ] Byte-identical zlib strategy and performance parity beyond explicit
  Flate level selection.
- [ ] Broader malformed xref-table/xref-stream/object-stream recovery beyond
  the current bad-startxref real-corpus, multi-revision, and encrypted
  object-stream gates.

## P2: Backend Breadth And Compatibility

- [x] ~~Native target is the stabilization target.~~
- [x] ~~Full native test suite is passing with coverage currently complete.~~
- [x] ~~Known native-only interface divergence is documented for secure-random
  AES helpers and `async_io`.~~
- [ ] All-backend validation after native parity is stable.
- [x] ~~Checked-in CamlPDF fixture PDFs read, multi-page text-extract,
  compressed-write, document-wide stream-decompress, and reread through native
  async file wrappers.~~
- [x] ~~Checked-in CamlPDF logo fixture reconstructs from a bad `startxref`
  pointer through native async file wrappers, compressed rewrite, and reread.~~
- [x] ~~Checked-in CamlPDF intro fixture reconstructs from a bad `startxref`
  pointer despite xref-stream/object-stream storage, then compressed rewrites
  and rereads with multi-page text extraction intact.~~
- [x] ~~Checked-in CamlPDF intro fixture accepts a compressed-xref-stream
  incremental update through native async file wrappers, with newest/older
  revision reads preserving tutorial text.~~
- [x] ~~Checked-in CamlPDF intro fixture recovers the newest compressed-xref
  incremental update after corrupting the final `startxref`, including reused
  object-number payloads, compressed rewrite, reread, and text extraction.~~
- [ ] Broader real-world PDF corpus testing.
- [ ] Performance tuning for large files, object streams, filters, and text/image
  extraction.
- [ ] Optional external-tool integration decisions for filter families that
  CamlPDF handled with C stubs or external binaries.

## Immediate Work Order

- [x] ~~Add the page resource lifecycle native acceptance gate.~~
- [x] ~~Add one broader `change_pages` compatibility gate.~~
- [x] ~~Add one non-stream encrypted parser-state gate.~~
- [x] ~~Add one broader encrypted malformed-reader gate beyond stream/object-stream data.~~
- [x] ~~Add one predefined-CMap text gate.~~
- [x] ~~Add a predefined UCS2 CMap reader/extractor gate.~~
- [x] ~~Add one remaining filter/image-family gate.~~
- [x] ~~Expand malformed-reader recovery from realistic documents.~~
- [x] ~~Add one Type3/TrueType font edge gate.~~
- [x] ~~Decide and start one CCITT/JPEG decode implementation slice.~~
- [x] ~~Add CCITT Group 3 encode parity for typed stream encoding.~~
- [x] ~~Add CCITT Group 4 encode parity for typed stream encoding.~~
- [x] ~~Add a CCITT image XObject native acceptance gate.~~
- [x] ~~Add a checked-in real PDF read/write corpus gate.~~
- [x] ~~Widen checked-in real PDF text extraction across multiple pages and
  compressed/decompressed reread boundaries.~~
- [x] ~~Add a checked-in real PDF incremental update and revision-read gate.~~
- [x] ~~Add a checked-in real PDF malformed-startxref reconstruction gate.~~
- [x] ~~Extend the real malformed-startxref gate to xref-stream/object-stream
  PDFs.~~
- [x] ~~Add a hybrid classic `/XRefStm` malformed-startxref reconstruction gate.~~
- [x] ~~Add a classic multi-revision `/Prev` malformed-startxref reconstruction
  gate.~~
- [x] ~~Add explicit Flate compression-level encoding APIs.~~
- [x] ~~Improve fast Flate-level behavior for incompressible streams.~~
- [ ] Add real-world CCITT image corpus coverage.
- [x] ~~Add a multi-revision malformed xref-stream/object-stream recovery gate.~~
- [x] ~~Add a real-file malformed compressed-xref incremental update recovery
  gate.~~
- [x] ~~Add a Type3 `/ToUnicode` native acceptance gate.~~
- [x] ~~Add a structured DCT/JPEG marker payload native gate.~~
- [x] ~~Add mixed-byte predefined CMap `/ToUnicode` extraction coverage.~~
- [x] ~~Add RKSJ no-`/ToUnicode` predefined-CMap single-byte fallback
  coverage.~~
- [ ] Add one broader non-UCS2 predefined-CMap mapping table beyond the RKSJ
  single-byte fallback.
- [ ] Revisit non-native backend validation after native parity is stable.
