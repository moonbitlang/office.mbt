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
   Remaining focus: broader malformed xref-table recovery and parser-state
   behavior around encrypted/deferred plain objects outside object streams.

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
   preservation.
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
   Remaining focus: selecting a true secure OS-entropy provider and deferred
   parser-state encryption/decryption edges.

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

Native reader compatibility is the current focus. Work should move through one
vertical acceptance path at a time instead of isolated edge polishing:

- maintain a black-box native acceptance suite that reads, writes, rereads, and
  checks stable invariants across classic xref, xref-stream, compressed
  xref-stream, incremental update, object-stream, partially decoded filter, and
  encrypted AES-128 workflows;
- fix failures exposed by that suite in reader/parser/deferred-encryption
  paths before moving to backend breadth;
- keep unrelated image/CMap/JPEG/CCITT work deferred unless it blocks a native
  acceptance case.

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
  and native acceptance covers `pdfdecomp.ml`-style document-wide stream
  decompression, `pdftest.ml`-style split-content parse/rewrite, and
  `pdfdraft.ml`-style image-replacement workflows through compressed
  xref-stream write/read. Native async file wrappers cover encrypted
  incremental revision reads from disk. Password-aware native reads now include
  encrypted object-stream fixtures for explicit passwords and the implicit blank
  user password. Native acceptance also covers
  `change_pages` bookmark-reference and matrix rewriting after a compressed
  xref-stream read boundary, plus strict reading and writer normalization for
  CamlPDF-tolerated malformed classic xref rows, and password decryption after
  malformed-xref reconstruction of direct encrypted objects.
- In progress: image/filter parity, Flate compression tuning, text CMap parity,
  encryption finishing edges, remaining malformed-reader recovery, and
  example-level integration fixtures.
- Deferred: CCITT/JBIG2 external-style decode, JPEG pixel decode, default AES
  random source, broader predefined CMap coverage, and broad real-world PDF
  recovery behavior.

## Working Rule

Pick one bounded compatibility slice at a time. Each slice should include:

- a narrow code change,
- focused black-box or white-box tests,
- `CamlPDFMigrationPlan.md` status updates when project behavior changes,
- `OCaml2MoonBit.md` updates only when a reusable language/API fact is newly
  verified,
- native-target `moon check`/`moon test` during the inner loop, broader backend
  validation during stabilization or backend-sensitive work, coverage, and a
  regular commit.
