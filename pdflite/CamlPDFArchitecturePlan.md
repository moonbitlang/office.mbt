# CamlPDF Architecture Plan

This is the project-specific architecture checklist for the MoonBit port of the
vendored CamlPDF sources in `.repos/`. Keep `OCaml2MoonBit.md` library-agnostic;
update this file when the project architecture, migration order, or remaining
work changes.

## Architecture Layers

1. Foundation bytes and geometry.
   Owner modules: `pdf_bytes.mbt`, `pdf_io.mbt`, `pdf_transform.mbt`,
   `pdf_units.mbt`, `pdf_paper.mbt`.
   Status: mostly complete for in-memory synchronous operation. Keep byte data
   as `Bytes`/`BytesView`, with ownership changes only at explicit boundaries.

2. Core object graph.
   Owner modules: `pdf_object.mbt`, `pdf_document.mbt`, `pdf_writer.mbt`,
   `pdf_reader.mbt`, `pdf_renumber.mbt`.
   Status: broad coverage for objects, streams, lazy/deferred stream slices,
   reading, writing, strict/reconstructed xrefs, object streams, name trees, and
   renumbering. Strict classic xref parsing now includes CamlPDF's fixed-width
   malformed-separator tolerance for independently bad separator columns,
   malformed zero-offset in-use rows whose marker starts with `n`, inline
   `xref n count` subsection headers, inline `startxref n` pointers, CR/CRLF
   line terminators, glued reconstructed trailer dictionaries, and
   revision-specific reads where revision `1` is newest and larger numbers
   follow older `/Prev` state across classic and xref-stream update chains.
   Strict stream parsing also skips CamlPDF's ignored padding bytes after the
   `stream` keyword while preserving trailing stream bytes before `endstream`,
   and falls back to CamlPDF-style `endstream` scanning when `/Length` is
   missing, unreadable, or lands away from the stream terminator. Valid
   strict-reader `/Length` streams now keep their payloads as `StreamToGet`
   cursor slices and materialize only at owned-byte boundaries such as
   `stream_bytes`, writer output, filter decoding, and crypt transforms;
   malformed recovered streams remain eager `StreamGot` data because their
   boundaries come from a repair scan. Indirect stream-length providers are now
   classified by parsing the referenced object segment, so ordinary length
   objects containing the word `stream` in comments do not get mistaken for
   stream objects.
   Xref-stream reading now also mirrors CamlPDF's tolerance for missing
   `/Type /XRef` when the stream still carries xref-stream structure such as
   `/W`, while keeping explicit wrong `/Type` values rejected; the malformed
   reconstruction path applies the same rule when using xref-stream
   dictionaries as trailer candidates.
   Object-stream extraction now resolves CamlPDF-style indirect `/N` and
   `/First` metadata through the partially loaded document before slicing
   embedded objects.
   Empty indirect objects of the form `n gen obj endobj` now parse as `null`,
   and plain non-stream indirect objects may omit the final `endobj` when
   parsing reaches following non-stream syntax; primitive scans also continue
   across an adjacent `n gen obj` header after such a malformed plain object,
   matching CamlPDF's malformed-object fallback.
   Malformed-file reconstruction now advances past successfully parsed objects
   and recovered streams so object-like bytes inside stream payloads are not
   mistaken for top-level indirect objects, while incomplete plain objects still
   leave the scanner in byte-wise recovery mode. When a candidate indirect
   object header is followed by malformed object syntax, reconstruction now
   skips forward to the next trimmed line that starts or ends with `endobj`,
   matching CamlPDF's malformed-object scan guard so nested object-looking bytes
   inside the bad object are not loaded as top-level objects.
   Public reads now also probe catalog/page-tree readability after strict
   loading and fall back to reconstruction when xref omissions leave the root
   catalog or `/Pages` references unresolved.
   Password-aware public read wrappers now also have revision-aware variants,
   and the public revision counter follows the same owned `Bytes` versus
   borrowed `BytesView` split as the rest of the reader surface.
   Password-aware reads now also decrypt `/ObjStm` streams just in time while
   expanding object-stream xref entries, including the implicit blank user
   password path, and embedded objects are marked as already decrypted so the
   later full-document decryption pass does not apply object crypt twice.
   Password-aware parsed ARC4/AESV2/AESV3 stream objects now also carry
   CamlPDF-style deferred decryption state on `ToGet`, so file-backed encrypted
   stream bytes remain lazy until `stream_bytes` or `get_stream` forces
   plaintext materialization and `/Length` correction.
   Remaining focus: broader malformed xref-table recovery and encrypted
   parser-state edge cases outside stream and object-stream data.

3. Filters, predictors, and codecs.
   Owner modules: `pdf_codec.mbt`, `pdf_flate.mbt`, `pdf_jpeg.mbt`.
   Status: ASCIIHex, ASCII85, RunLength, LZW decode, Flate decode/encode
   including stored, fixed-Huffman, and dynamic-Huffman output choices,
   predictors, filter arrays, document-aware stream decoding, document-wide
   stop-at-unknown stream decompression, and JPEG data extraction are started.
   Remaining focus: fuller zlib-style Flate tuning, CCITT/JBIG2 external-style
   decode parity, and actual JPEG pixel decoding.

4. Page and content layer.
   Owner modules: `pdf_content.mbt`, `pdf_page.mbt`, `pdf_dest.mbt`,
   `pdf_bookmark.mbt`, `pdf_annot.mbt`, `pdf_page_label.mbt`.
   Status: page tree read/write/change/extract flows, content operators,
   `pdfhello.ml`-style standard-font document round-trip fixtures,
   `pdftest.ml`-style content rewrite fixtures, inline images, destinations,
   bookmarks, annotations, page labels, duplicate annotation fixups, and
   destination pruning are started with direct tests. Inline-image parsing now
   consumes known encoded payload boundaries, treats DCT as a deferred JPEG
   stage, and can decode leading supported filters before preserving remaining
   deferred image filters such as DCT or CCITT. Malformed bookmark sets are
   dropped during page extraction and
   merge instead of aborting the
   document operation. Direct annotation dictionaries in `/Annots` arrays now
   participate in geometry transforms and
   `change_pages` link-destination matrix transforms; transformed annotation,
   GoTo action, and `/OpenAction` destinations are allocated as indirect
   destination objects like CamlPDF, while full-page `/Fit` and `/FitB`
   destinations plus integer page targets are left untransformed by matrix
   passes. Malformed annotation, `/OpenAction`, and catalog
   destination-definition matrix destinations keep renumbered page references
   without aborting `change_pages`; malformed merge `/OpenAction` entries are
   ignored so later valid actions can still be retained. Count-changing
   `change_pages` replacements keep CamlPDF's no-mapping behavior and bookmark
   matrix guard, while replacement preserves document metadata, trailer extras,
   and object-stream bookkeeping. Form XObject processing materializes deferred
   stream data before callbacks, matching CamlPDF's `Pdf.getstream` path.
   `pdf_of_pages` now materializes inherited page attributes before extraction
   so inherited `/CropBox` values and inherited indirect `/Resources`,
   `/MediaBox`, and `/Rotate` references are preserved with selected pages.
   Content parsing also follows CamlPDF's malformed color-operator fallback for
   bad `SC`/`sc`/`SCN`/`scn` operands and filters malformed `TJ` array
   members. Malformed numeric entries inside `d` dash arrays now raise instead
   of being preserved as unknown operations.
   Remaining focus: additional `change_pages` compatibility fixtures.

5. Text, font, color, function, and image layer.
   Owner modules: `pdf_text.mbt`, `pdf_space.mbt`, `pdf_fun.mbt`,
   `pdf_image.mbt`.
   Status: encodings, UTF-16BE/PDFDocEncoding, ToUnicode CMaps, Identity-H/V
   two-byte CID text extraction, CamlPDF-style whitespace-elided ToUnicode CMap
   section scanning, mixed multiline `bfrange` parsing, `/WMode` token parsing
   across PDF whitespace,
   standard-font extraction, color spaces,
   sampled/interpolation/stitching/calculator functions, and raw/encoded image
   extraction are started, including 1-, 2-, 4-, and 8-bit `/Indexed` raw
   image samples plus explicit `/Indexed` encoded-image `/Decode` metadata
   preservation. Native acceptance now exercises image extraction through
   compressed read/write boundaries for Flate-decoded raw `/Indexed` image
   XObjects, staged Flate-then-DCT encoded-image pass-through, and Flate
   inline-image content parsing.
   Remaining focus: broader predefined CMap semantics, JPEG pixel decode, and
   remaining image filter families.

6. Encryption.
   Owner modules: `pdf_crypt*.mbt`.
   Status: ARC4, hashes, AES primitives, R2/R3/R4/R5/R6 authentication,
   object/string/stream crypt, decryption, deterministic provider adapters,
   provider-backed encryption, deterministic recrypt paths, and a
   `pdfencrypt.ml`-style AES-128 acceptance fixture are started. Deterministic
   AES fixture providers now derive their Chacha seeds through SHA-256 so
   arbitrary seed/callsite byte lengths do not depend on MD5 padding behavior.
   Writer-facing encrypted output is now available through public
   `PdfWriteMode` dispatch plus direct encrypted-writer wrappers for ARC4,
   AESV2, AESV3, and AESV3 ISO, so callers no longer need to manually
   encrypt-then-write for the main CamlPDF-style output workflow.
   Native AESV2 and AESV3 convenience output now use a pdflite-owned OS
   random-byte FFI boundary for IVs, AESV3 file keys, salts, and permissions
   padding, with failure propagated as checked `PdfError`; the native async file
   package exposes the same default AES writer families.
   Parsed stream decryption now preserves CamlPDF's lazy stream state for
   ARC4/AESV2/AESV3 streams read from files, while already-owned stream data
   remains eager at the crypt boundary. Native acceptance now covers
   `/EncryptMetadata false` through compressed encrypted output, public password
   read, plaintext metadata inspection in the encrypted bytes, and saved-state
   AESV2 recrypt.
   Remaining focus: non-stream encrypted parser-state edges and broader
   encrypted malformed-reader compatibility.

7. Document-level features.
   Owner modules: `pdf_merge.mbt`, `pdf_ocg.mbt`, `pdf_date.mbt`, plus feature
   helpers in page/text modules.
   Status: merge, optional content groups, dates, page labels, bookmarks,
   duplicate-font paths, malformed named-destination merge fallback, the
   `pdfdecomp.ml` stream-decompression workflow, a `pdfmergeexample.ml`-style
   public workflow fixture, and a `pdfdraft.ml` image-replacement acceptance
   fixture are started. Page-label reads now preserve CamlPDF's tolerant range
   handling for malformed keys and odd trailing `/Nums` entries while rejecting
   empty malformed label trees.
   Remaining focus: more CamlPDF example-level acceptance fixtures and
   compatibility behavior for unusual real-world documents.

## Active Large Milestone

Native feature parity is the current focus. Work should advance through broad
public workflow gates instead of isolated parser quirks:

- core file lifecycle: read, write, reread, incremental update, revision reads,
  object streams, compressed xref streams, and encrypted documents;
- page/content lifecycle: page tree reads, content parse/rewrite, `change_pages`,
  merge, extraction, and object cleanup;
- document-feature lifecycle: page labels, bookmarks, annotations, old-style and
  name-tree destinations, open actions, optional content, and metadata surviving
  read/edit/write boundaries;
- media/text lifecycle: filters, predictors, text extraction, CMaps, images, and
  example workflows such as `pdfdecomp.ml`, `pdftest.ml`, and `pdfdraft.ml`.

An isolated recovery case belongs in the migration only when it is needed by one
of those gates. Native remains the only stabilization target until these broad
gates are solid; backend breadth follows after native feature parity.

## Prioritized Coverage Plan

Current estimate: native main-feature parity is about 72-76% complete. Full
CamlPDF parity, including deferred filter families, deeper malformed recovery,
and backend breadth, is about 61-66% complete.

### P0: Finish Native Main Workflows

- Covered: byte foundation; object model; classic xref, xref-stream, compressed
  xref-stream, object-stream, strict revision, and major reconstruction reads;
  full and incremental writer modes; lazy stream slices; public async native
  file wrappers.
- Covered: page tree construction, reading, writing, page extraction,
  `change_pages`, merge, object cleanup, inherited page attributes, page labels,
  bookmarks, annotations, old-style and name-tree destinations, `/OpenAction`,
  optional content, structure-tree merge/pruning basics, page resource
  renumbering/prefixing/content merge/Form XObject processing through native
  acceptance boundaries, and example workflows for `pdfdecomp.ml`,
  `pdftest.ml`, `pdfdraft.ml`, `pdfencrypt.ml`, and `pdfmergeexample.ml`.
- Covered: ARC4, AESV2, AESV3/AESV3 ISO authentication, encryption,
  decryption, native secure-random writer paths, saved-state recrypt,
  encrypted object streams, lazy encrypted stream forcing, and
  `/EncryptMetadata false`.
- Not covered enough: remaining `change_pages` compatibility fixtures involving
  resource-heavy pages, unusual inherited page data, and more destination/action
  combinations.
- Not covered enough: non-stream encrypted parser-state edges and encrypted
  malformed-reader recovery outside the object-stream and stream-data paths.

### P1: Deepen Format Parity

- Covered: ASCIIHex, ASCII85, RunLength, LZW decode, Flate decode/encode,
  predictors, filter arrays, stop-at-unknown stream decoding, raw/encoded image
  extraction basics, color spaces, functions, standard fonts, PDFDocEncoding,
  UTF-16BE, ToUnicode CMaps, and Identity-H/V CID text basics.
- Not covered enough: broader predefined CMap semantics, vertical-writing
  behavior beyond the current gates, Type3/TrueType edge coverage, and more
  real-world ToUnicode variations.
- Not covered enough: JPEG pixel decode, fuller zlib/Flate tuning parity,
  CCITT/JBIG2 external-style decode behavior, and remaining image filter
  families.
- Not covered enough: broader malformed xref-table/object recovery driven by
  realistic public workflows rather than isolated parser quirks.

### P2: Broaden Compatibility After Native

- Covered: native target checks, native acceptance, native async file IO, and
  full native test coverage.
- Deferred: all-backend stabilization. Native-only secure-random/encrypted
  writer APIs and `async_io` intentionally diverge from WasmGC today.
- Deferred: large real-world corpus testing, performance tuning, and optional
  external tool integration for filters that CamlPDF handled through C stubs or
  external binaries.

### Immediate Work Order

- Next: add one broader `change_pages` compatibility gate using resource-heavy
  pages and mixed destination/action references.
- Then: target encrypted parser-state gaps with one public password-read or
  recrypt workflow that exposes a non-stream encrypted-object edge.
- Then: deepen text/image parity with one predefined-CMap gate and one
  filter/image-family gate.
- Later: expand malformed-reader recovery from realistic documents and only
  then widen backend validation beyond native.

## Current High-Level Checklist

- Done: byte foundation, object model, writer, major reader paths, page tree,
  content parser/writer, standard filters, predictors, many encryption flows,
  text extraction basics, color spaces, functions, bookmarks, annotations,
  page labels, OCG, merge, strict revision-specific reads, and image extraction
  basics. Public writer mode dispatch now covers full writes and incremental
  update writes, and encrypted-writer wrappers cover CamlPDF-style
  encrypt-at-write workflows for ARC4, AESV2, AESV3, and AESV3 ISO while
  keeping AES randomness provider-driven. Native async file wrappers cover
  read/write, mode-dispatched full and incremental writes, encrypted writer
  file output, password reads, revision counting, revision reads, and
  incremental writes. A native black-box acceptance suite now covers
  classic/xref-stream/compressed-xref one-page read-write-reread, classic and
  xref-stream incremental revision reads, omitted page-tree xref reconstruction,
  object-stream page-tree normalization through the writer, partial stream
  filter decompression, mode-dispatched full and incremental writer APIs, and
  AES-128 password-wrapper reads plus a `pdfencrypt.ml`-style blank-user,
  owner-password encrypted writer workflow and AES-128 decrypt/recrypt
  incremental revision reads. Document-level merge and page extraction are also
  covered across a compressed xref-stream read boundary, including retained
  page labels and bookmark targets through a public merge/write/read workflow,
  a `pdfmergeexample.ml`-style manual merge workflow using public renumber,
  page-tree rebuild, and cleanup APIs, structure-tree pruning during page
  extraction with `process_struct_tree=true`, and a page resource lifecycle gate
  covering `process_xobjects`, `add_prefix`, split content merging, and
  `renumber_pages`. Native acceptance covers
  `pdfdecomp.ml`-style document-wide stream
  decompression, `pdftest.ml`-style split-content parse/rewrite, and
  `pdfdraft.ml`-style image-replacement workflows through compressed
  xref-stream write/read. Native async file wrappers cover encrypted
  incremental revision reads from disk and native secure-random AESV2/AESV3 file
  writes. Password-aware native reads now include
  encrypted object-stream fixtures for explicit passwords and the implicit blank
  user password, and password-aware parsed ARC4/AESV2/AESV3 stream reads now
  keep deferred decryption until forcing materializes plaintext and corrects
  `/Length`. Native acceptance also covers
  `change_pages` bookmark-reference and matrix rewriting after a compressed
  xref-stream read boundary; a document-feature lifecycle gate for page labels,
  link annotations, old-style destinations, name-tree destinations, and
  `/OpenAction`; a merge catalog-feature gate for AcroForm fields, optional
  content groups, structure trees with parent trees, and trailer `/Info`; a
  ToUnicode text-extraction gate using filtered CMap streams through compressed
  read/write boundaries; an `/Identity-H` Type0 CID text-extraction gate
  through compressed read/write boundaries; a Type0 `/Identity-H` plus filtered
  `/ToUnicode` CID text-extraction gate through compressed read/write
  boundaries; an image-extraction gate for Flate raw indexed image XObjects,
  Flate-to-DCT encoded images, and Flate inline images through compressed
  read/write and document-wide decompression boundaries; an AESV2
  `/EncryptMetadata false` gate through compressed encrypted output and
  saved-state recrypt; strict
  reading and writer normalization for
  CamlPDF-tolerated malformed classic xref rows; and password decryption after
  malformed-xref reconstruction of direct encrypted objects.
  Count-changing `change_pages` is covered through compressed reader and writer
  boundaries with explicit serial reference mapping, bookmark retargeting,
  transformed catalog `/OpenAction`, trailer `/ID`, and root metadata
  preservation. Page extraction now also has a native gate for reused annotation
  and popup objects, proving duplicated selected pages get distinct annotation
  pairs with repaired `/Popup` and `/Parent` links through write/reread.
  Native OS-random AESV2/AESV3 convenience writer output is covered with decrypt
  and output-variation checks, and AESV3 saved-state recrypt is covered through
  the default secure-random IV path.
- In progress: image/filter parity, Flate compression tuning, text CMap parity,
  remaining encryption edge cases, remaining malformed-reader recovery, and
  example-level integration fixtures.
- Deferred: CCITT/JBIG2 external-style decode, JPEG pixel decode, broader
  predefined CMap coverage, and broad real-world PDF recovery behavior.

## Working Rule

Pick one broad native workflow gate at a time, then make the smallest code
changes required for that gate to pass. Each slice should include:

- a named public workflow and the CamlPDF behavior it is meant to preserve;
- black-box native acceptance coverage plus focused unit tests for any new
  helper behavior;
- `CamlPDFMigrationPlan.md` status updates when project behavior changes;
- `OCaml2MoonBit.md` updates only when a reusable language/API fact is newly
  verified;
- native-target `moon check`/`moon test` during the inner loop, broader backend
  validation during stabilization or backend-sensitive work, coverage, and a
  regular commit.
