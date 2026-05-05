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
   Reconstruction now also scans recoverable xref-stream sections when the
   `startxref` pointer is invalid, loads their ordinary entries, and expands
   object-stream entries before selecting a trailer/root. This covers modern
   files whose catalog or page tree only exists inside `/ObjStm` storage.
   Reconstructed xref-stream loading now skips xref-stream objects by exact
   `(object number, offset)` identity instead of by object number alone, so an
   incremental update can reuse an older xref-stream object number for ordinary
   payload data and still recover the newest revision.
   Hybrid classic trailers with `/XRefStm` are now covered on the same
   malformed-startxref path, so table objects and the pointed-to xref-stream
   entries are both recovered and trailer-only xref machinery is stripped.
   Classic multi-revision `/Prev` chains with a bad final `startxref` are also
   covered by reconstruction, selecting the newest body-scanned catalog and
   stripping `/Prev` from the recovered trailer.
   Password-aware reconstruction now retries xref-stream object-stream
   expansion after trailer selection, when `/Encrypt` and file IDs are
   available, so encrypted `/ObjStm` payloads can be materialized during
   malformed-startxref reads.
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
   parser-state edge cases beyond current object-stream coverage.

3. Filters, predictors, and codecs.
   Owner modules: `pdf_codec.mbt`, `pdf_flate.mbt`, `pdf_jpeg.mbt`.
   Status: ASCIIHex, ASCII85, RunLength, LZW decode, Flate decode/encode
   including stored, fixed-Huffman, and dynamic-Huffman output choices,
   predictors, filter arrays, CCITT Group 3 one-dimensional and Group 4 decode,
   typed CCITT Group 3 and Group 4 encode, document-aware stream decoding,
   document-wide stop-at-unknown stream decompression, and JPEG data extraction
   are started.
   CCITT decode honors CamlPDF-compatible `/DecodeParms` defaults, direct
   indirect parameters, and the `/CCF` alias; typed CCITT Group 3 and Group 4
   encoding writes `/DecodeParms` so encoded streams round-trip through
   pdflite's decoder.
   Direct Flate, filter, and stream encoding APIs now accept explicit zlib-style
   levels 0 through 9, keeping the default compact encoder unchanged while
   exposing CamlPDF's `flate_level` workflow without global mutable state; fast
   levels now still fall back to stored blocks for incompressible data.
   Remaining focus: byte-identical zlib strategy/performance tuning, optional
   JBIG2 external-tool decode parity, broader CCITT corpus validation, and
   DCT/JPEG real-world payload coverage.

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
   Remaining focus: additional `change_pages` compatibility fixtures for
   unusual inherited page data and real-world destination/action combinations.

5. Text, font, color, function, and image layer.
   Owner modules: `pdf_text.mbt`, `pdf_space.mbt`, `pdf_fun.mbt`,
   `pdf_image.mbt`.
   Status: encodings, UTF-16BE/PDFDocEncoding, ToUnicode CMaps, Identity-H/V
   and predefined UCS2 horizontal/vertical two-byte CID text extraction plus
   direct Unicode predefined CMap segmentation for UTF8, UTF16, and UTF32,
   common mixed-byte predefined CMap charcode segmentation for `/ToUnicode`
   extraction, RKSJ predefined-CMap ASCII and half-width Katakana built-in
   fallback, generated GB-EUC/GB2312, GBpc-EUC, Big5, UHC/CP949,
   GBK-EUC-UCS2, GBK2K/Adobe-GB1, B5pc, ETenms-B5, HKSCS/Adobe-CNS1,
   CNS-EUC-H/V Adobe-CNS1 CID-range fallbacks, Hong Kong Big5 CID-range
   fallbacks, and KSC-EUC/Adobe-Korea1-UCS2 mapping-table fallbacks, plus
   KSCpc-EUC multi-codepoint fallback and generated vertical
   predefined-CMap override fallbacks for supported Adobe-GB1, Adobe-CNS1, and
   Adobe-Korea1 families when `/ToUnicode` is absent, and generated
   Adobe-Japan1 fallbacks for 90ms/90pv RKSJ direct Unicode maps, JIS two-byte
   CMaps, EUC-H, and Hojo-EUC three-byte charcodes, external CMap stream
   parsing for codespaces plus `begincidchar`/`begincidrange` and
   `beginnotdefchar`/`beginnotdefrange` Type0 `/Encoding` streams with
   variable-length text segmentation, CID fallback, applied notdef maps,
   encoding-side `bfchar`/`bfrange` Unicode fallback for otherwise unmapped
   charcodes, and parsed CMap program and stream-dictionary header metadata for
   `/WMode`, `/CMapName`, `/CMapType`, `/CIDSystemInfo`, and name `/UseCMap`,
   including indirect dictionary values,
   plus `/UseCMap` name parsing from CMap programs and stream dictionaries
   with Identity-H/V inherited segmentation and CID fallback, plus recursive
   stream `/UseCMap` composition with cycle protection, inherited codespaces,
   derived-entry map/CID/notdef/metadata overrides, inherited Identity
   fallback, named predefined `/UseCMap` fallback for streams without explicit
   codespaces, and ToUnicode inheritance through text extraction and reverse
   Unicode lookup,
   CamlPDF-style whitespace-elided ToUnicode CMap section scanning, mixed
   multiline `bfrange` parsing, `/WMode` token parsing across PDF whitespace,
   standard-font extraction, color spaces,
   sampled/interpolation/stitching/calculator functions, and raw/encoded image
   extraction are started, including 1-, 2-, 4-, and 8-bit `/Indexed` raw
   image samples plus explicit `/Indexed` encoded-image `/Decode` metadata
   preservation. Native acceptance now exercises Identity-H and Identity-V
   predefined CMap extraction through compressed read/write boundaries,
   including Identity-V vertical width metadata, plus image extraction through
   compressed read/write boundaries for Flate-decoded raw `/Indexed` image
   XObjects, structured DCT/JPEG marker payloads through staged Flate-then-DCT
   XObjects and DCT inline-image parsing, direct JPX encoded-image preservation,
   staged Flate-then-JBIG2 encoded-image preservation with `/JBIG2Globals`,
   Type3 `/ToUnicode` text extraction with indirect CharProcs and custom
   metrics, embedded TrueType `FontFile2` plus `/ToUnicode` text extraction
   through compressed read/write boundaries, and Flate inline-image content
   parsing. Unit coverage also preserves direct Type3 `CharProcs` streams,
   parses their `d0`/`d1` glyph programs without allocating new indirect
   objects, and round-trips Type3 writer output for `/FontBBox`,
   `/FontMatrix`, `CharProcs`, `/Resources`, and width metrics. Stream decode
   now also covers CCITT `/K 0` and `/K < 0` data
   through `/CCITTFaxDecode` and `/CCF`.
   Remaining focus: broader built-in non-UCS2 predefined CMap mapping tables
   beyond the current Adobe-GB1, Adobe-CNS1, Adobe-Japan1, and Adobe-Korea1
   fallbacks, broader external/general CMap parsing beyond the current
   codespace/CID/notdef sections, encoding-side Unicode map fallback, notdef
   lookup, program and stream-dictionary header metadata, Identity and named
   predefined `/UseCMap` fallbacks, and stream `/UseCMap` composition subset,
   plus JPEG pixel decode and remaining image filter families.

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
   read, plaintext metadata inspection in the encrypted bytes, saved-state
   AESV2 recrypt, and recrypting non-stream payload objects extracted from
   encrypted object streams. Encrypted malformed-reader acceptance now covers
   bad-startxref reconstruction followed by saved-state recrypt and compressed
   write/reread.
   Remaining focus: broader real-world encrypted malformed-reader compatibility.

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

Current estimate: native main-feature parity is about 94-95% complete. Full
CamlPDF parity, including deferred filter families, deeper malformed recovery,
and backend breadth, is about 83-88% complete.

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
  acceptance boundaries, resource-heavy page replacement with mixed
  destination/action references, and example workflows for `pdfdecomp.ml`,
  `pdftest.ml`, `pdfdraft.ml`, `pdfencrypt.ml`, and `pdfmergeexample.ml`.
- Covered: ARC4, AESV2, AESV3/AESV3 ISO authentication, encryption,
  decryption, native secure-random writer paths, saved-state recrypt,
  encrypted object streams, lazy encrypted stream forcing, non-stream
  object-stream payload recrypt, bad-startxref encrypted reconstruction with
  recrypt, feature-rich classic malformed-xref reconstruction through labels,
  annotations, destinations, name-tree destinations, catalog actions,
  `change_pages`, and compressed rewrite/reread, and `/EncryptMetadata false`.
- Not covered enough: remaining `change_pages` compatibility fixtures involving
  unusual inherited page data and broader real-world destination/action
  combinations.
- Not covered enough: broader real-world encrypted malformed-reader recovery.

### P1: Deepen Format Parity

- Covered: ASCIIHex, ASCII85, RunLength, LZW decode, Flate decode/encode,
  predictors, filter arrays, stop-at-unknown stream decoding, raw/encoded image
  extraction basics, color spaces, functions, standard fonts, PDFDocEncoding,
  UTF-16BE, ToUnicode CMaps, Identity-H/V CID text basics, predefined UCS2
  and UTF16 horizontal/vertical extraction plus direct UTF8/UTF16/UTF32
  predefined Unicode CMap segmentation and reverse lookup, mixed-byte predefined CMap
  charcode segmentation for `/ToUnicode` extraction, RKSJ predefined-CMap
  single-byte fallback, GB-EUC predefined-CMap GB2312 mapping fallback when
  `/ToUnicode` is absent, GBpc-EUC predefined-CMap mapping fallback with PC
  single-byte handling and one multi-codepoint expansion when `/ToUnicode` is
  absent, Big5 predefined-CMap mapping fallback when `/ToUnicode` is absent,
  B5pc predefined-CMap mapping fallback with PC single-byte handling when
  `/ToUnicode` is absent, ETenms-B5 predefined-CMap CID-range fallback
  including its ETen-B5 base when `/ToUnicode` is absent, HKSCS
  predefined-CMap mapping fallback composed through Adobe-CNS1 with
  supplementary Unicode scalar coverage when `/ToUnicode` is absent, Hong Kong
  Big5 predefined-CMap CID-range fallbacks sharing Adobe-CNS1 Unicode data
  when `/ToUnicode` is absent, UHC predefined-CMap CP949 mapping fallback when
  `/ToUnicode` is absent, GBK predefined-CMap GBK-EUC-UCS2 mapping fallback
  when `/ToUnicode` is absent, GBK2K predefined-CMap Adobe-GB1 CID-range
  fallback with packed four-byte signed-`Int` charcodes when `/ToUnicode` is
  absent, CNS-EUC-H/V predefined-CMap Adobe-CNS1 CID-range fallback with
  one/two/four-byte segmentation and shorter duplicate reverse-lookup
  preference when `/ToUnicode` is absent, KSC-EUC predefined-CMap mapping
  fallback composed through Adobe-Korea1-UCS2 when `/ToUnicode` is absent, and
  a KSCpc-EUC predefined-CMap fallback with multi-codepoint expansion when
  `/ToUnicode` is absent, vertical predefined-CMap override fallbacks for
  supported Adobe-GB1, Adobe-CNS1, and Adobe-Korea1 families when `/ToUnicode`
  is absent, Japanese
  Adobe-Japan1 predefined-CMap fallbacks for 90ms/90pv RKSJ, JIS `/H`, EUC-H,
  and Hojo-EUC when `/ToUnicode` is absent, external CMap stream parsing for
  codespaces plus `begincidchar`/`begincidrange` Type0 `/Encoding` streams,
  variable-length text segmentation, CID fallback, reverse CID lookup, and
  Identity-H/V `/UseCMap` base-name inheritance plus recursive stream
  `/UseCMap` composition, notdef-map extraction and reverse lookup before
  inherited predefined/Identity fallbacks, encoding-side `bfchar`/`bfrange`
  Unicode fallback for otherwise unmapped charcodes, ToUnicode stream
  inheritance through extraction, and an Identity-V native gate with vertical
  width metadata.
  Native image acceptance now also covers
  structured DCT/JPEG marker payloads through staged Flate-to-DCT image
  XObjects and DCT inline images, JPX encoded images, staged Flate-to-JBIG2
  images with `/JBIG2Globals`, and CCITT image XObjects through raw RGB
  extraction; native font acceptance covers Type3 `/ToUnicode` text with
  indirect CharProcs and embedded TrueType `FontFile2` with generated
  `/ToUnicode` text extraction, while focused font tests preserve direct Type3
  `CharProcs` streams, parse `d0`/`d1` glyph programs, and round-trip Type3
  writer output without dropping bbox, matrix, resources, CharProcs, or width
  metrics.
  Stream decode now covers CCITT `/K 0` and `/K < 0` with `/DecodeParms`
  defaults and direct indirect params. Typed stream encoding now covers CCITT
  Group 3 `/K 0` and Group 4 `/K < 0` and round-trips through decode.
- Not covered enough: broader built-in non-UCS2 predefined CMap mapping tables
  beyond the current Adobe-GB1, Adobe-CNS1, Adobe-Japan1, and Adobe-Korea1
  fallbacks, broader external/general CMap parsing beyond the current
  codespace/CID-char/CID-range/notdef lookup, encoding-side Unicode map
  fallback, Identity `/UseCMap`, and stream `/UseCMap` composition subset,
  additional TrueType and Type3 glyph-program edge coverage beyond the current
  Type3 reader/writer gates, more real-world ToUnicode variations, and broader
  real-world DCT/JPEG image payload corpus files.
- Not covered enough: fuller zlib/Flate byte-identity and tuning parity,
  broader DCT/JPEG and CCITT corpus validation, and optional external JBIG2
  decoder integration.
  Actual JPEG pixel decoding is
  optional beyond CamlPDF image-extraction parity, which returns encoded JPEG
  payloads.
- Not covered enough: broader malformed xref-table/xref-stream/object-stream
  recovery driven by real-world corpus files.

### P2: Broaden Compatibility After Native

- Covered: native target checks, native acceptance, native async file IO,
  checked-in CamlPDF fixture PDF read/multi-page text-extract/write/stream
  decompression/reread plus compressed incremental update/newest-versus-older
  revision reads through native async file wrappers, and full native test
  coverage.
- Covered: checked-in CamlPDF logo fixture bad-`startxref` reconstruction
  through native async file wrappers, compressed rewrite, and reread.
- Covered: checked-in CamlPDF intro fixture compressed-xref incremental update
  recovery after corrupting the final `startxref`, including reused
  object-number payload recovery, compressed rewrite/reread, and multi-page
  text extraction.
- Deferred: all-backend stabilization. Native-only secure-random/encrypted
  writer APIs and `async_io` intentionally diverge from WasmGC today.
- Deferred: larger real-world corpus testing, performance tuning, and optional
  external tool integration for filters that CamlPDF handled through C stubs or
  external binaries.

### Immediate Work Order

- Next: prioritize broad native acceptance gates over isolated parser quirks:
  real-file corpus expansion beyond the checked-in CamlPDF intro/logo fixtures,
  additional Type3/TrueType glyph-program behavior, or real CCITT/DCT fixture
  coverage when suitable files are available. Keep JPEG/JBIG2 decoder decisions
  separate from encoded image pass-through.
- Later: widen backend validation beyond native after native parity stabilizes.

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
  user password, saved-state recrypt of non-stream payloads extracted from
  encrypted object streams, and password-aware parsed ARC4/AESV2/AESV3 stream
  reads now keep deferred decryption until forcing materializes plaintext and
  corrects `/Length`. Native acceptance also covers
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
  structured Flate-to-DCT encoded images, DCT inline images, and Flate inline
  images through compressed read/write and document-wide decompression
  boundaries; native CCITT `/K 0` and `/K < 0` stream decode plus typed Group 3
  and Group 4 stream encode with `/DecodeParms`; an AESV2
  `/EncryptMetadata false` gate through compressed encrypted output and
  saved-state recrypt; strict
  reading and writer normalization for
  CamlPDF-tolerated malformed classic xref rows; feature-rich classic malformed
  xref reconstruction through `change_pages` and compressed rewrite/reread; and
  password decryption after malformed-xref reconstruction of direct encrypted
  objects.
  Count-changing `change_pages` is covered through compressed reader and writer
  boundaries with explicit serial reference mapping, bookmark retargeting,
  transformed catalog `/OpenAction`, trailer `/ID`, and root metadata
  preservation. Page extraction now also has a native gate for reused annotation
  and popup objects, proving duplicated selected pages get distinct annotation
  pairs with repaired `/Popup` and `/Parent` links through write/reread.
  Native OS-random AESV2/AESV3 convenience writer output is covered with decrypt
  and output-variation checks, and AESV3 saved-state recrypt is covered through
  the default secure-random IV path. Resource-heavy `change_pages` replacement
  is also covered after a compressed read boundary for preserved page resources,
  direct and indirect link annotations, GoTo action annotations, catalog
  `/OpenAction`, old-style `/Dests`, name-tree destinations, and bookmark
  resolution through write/reread. Encrypted malformed-reader coverage now also
  includes bad-startxref reconstruction followed by password read,
  saved-state AESV2 recrypt, compressed write, and password reread.
- In progress: image/filter parity, Flate compression tuning, non-UCS2 text
  CMap parity, remaining encryption edge cases, remaining malformed-reader
  recovery, and example-level integration fixtures.
- Deferred: optional JBIG2 external-style decode, optional JPEG pixel decode
  beyond CamlPDF parity, broader non-UCS2 predefined CMap coverage, broader
  CCITT corpus validation, and broad
  real-world PDF recovery behavior.

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
