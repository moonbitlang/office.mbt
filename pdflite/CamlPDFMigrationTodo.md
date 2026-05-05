# CamlPDF Migration Todo

This is the progress tracker for the pdflite CamlPDF migration. Update this
file whenever a substantial migration slice lands. Keep `OCaml2MoonBit.md`
library-agnostic; project architecture details belong in
`CamlPDFArchitecturePlan.md` and `CamlPDFMigrationPlan.md`.

Current estimate:

- Native main-feature parity: 75-79%.
- Full CamlPDF parity across deferred filters, malformed recovery, and backend
  breadth: 64-69%.

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

## P1: Format Parity

- [x] ~~ASCIIHex, ASCII85, RunLength, LZW decode, Flate decode/encode,
  predictors, filter arrays, and stop-at-unknown stream decompression.~~
- [x] ~~Color spaces, functions, standard fonts, encodings, PDFDocEncoding,
  UTF-16BE, ToUnicode CMaps, Identity-H/V CID text basics, and native text
  extraction gates.~~
- [x] ~~Raw/encoded image extraction basics, including indexed raw samples,
  staged Flate-to-DCT pass-through, and inline image parsing gates.~~
- [ ] Broader predefined CMap semantics and vertical-writing text behavior.
- [ ] More Type3/TrueType font edge coverage.
- [ ] JPEG pixel decoding.
- [ ] CCITT/JBIG2 external-style decode behavior and remaining image filter
  families.
- [ ] Fuller zlib/Flate compression tuning parity.
- [ ] Broader malformed xref-table/object recovery driven by public workflows.

## P2: Backend Breadth And Compatibility

- [x] ~~Native target is the stabilization target.~~
- [x] ~~Full native test suite is passing with coverage currently complete.~~
- [x] ~~Known native-only interface divergence is documented for secure-random
  AES helpers and `async_io`.~~
- [ ] All-backend validation after native parity is stable.
- [ ] Real-world PDF corpus testing.
- [ ] Performance tuning for large files, object streams, filters, and text/image
  extraction.
- [ ] Optional external-tool integration decisions for filter families that
  CamlPDF handled with C stubs or external binaries.

## Immediate Work Order

- [x] ~~Add the page resource lifecycle native acceptance gate.~~
- [x] ~~Add one broader `change_pages` compatibility gate.~~
- [x] ~~Add one non-stream encrypted parser-state gate.~~
- [x] ~~Add one broader encrypted malformed-reader gate beyond stream/object-stream data.~~
- [ ] Add one predefined-CMap text gate.
- [ ] Add one remaining filter/image-family gate.
- [ ] Expand malformed-reader recovery from realistic documents.
- [ ] Revisit non-native backend validation after native parity is stable.
