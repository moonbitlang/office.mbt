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
   `stream_bytes`, writer output, filter decoding, and crypt transforms; when
   `get_stream` forces materialization, the object model reuses a cached
   `/Length` key while correcting the stream dictionary. Malformed recovered
   streams remain eager `StreamGot` data because their boundaries come from a
   repair scan. Indirect stream-length providers are now
   classified by parsing the referenced object segment, so ordinary length
   objects containing the word `stream` in comments do not get mistaken for
   stream objects. Writer trailer, stream-length, and xref-stream dictionaries
   now reuse cached standard `PdfName` values while preserving existing public
   writer APIs. Incremental writer changed-object collection now uses a
   hash-backed seen set before sorting sparse xref entry numbers, preserving
   output order while avoiding repeated linear duplicate checks for large edit
   logs. Full and sparse xref-stream byte generation now consumes sorted xref
   tuples in one pass, preserving the writer's emitted bytes while avoiding
   repeated tuple scans over large object tables. Classic sparse incremental
   xref row generation carries the same sorted-cursor strategy across
   subsection runs.
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
   Password-aware public reads now also route malformed classic xref-entry
   errors through reconstruction, matching the non-password reader path for
   corrupted xref row markers before decryption.
   Document object selection now walks parsed object entries directly, matching
   the object iterators and avoiding false matches against parser-private
   deferred placeholders that `lookup_object_or_null` intentionally exposes as
   `null`. Standard reader keys used by xref, object-stream, trailer, and stream
   length handling are cached once, avoiding repeated ASCII `PdfName` rebuilding
   while loading large object tables. Object-stream extraction parses headers
   and embedded object slices from borrowed `BytesView` data instead of
   allocating temporary owned bytes. Object-stream expansion now builds one
   decoded `/ObjStm` context per containing stream and reuses it for all
   compressed xref entries from that stream, including password-aware and
   reconstructed xref-stream reads, avoiding repeated stream decode/decrypt work
   on compressed-object-heavy PDFs. Xref-stream type-2 entries are grouped by
   containing object stream before embedded expansion, avoiding a full xref scan
   per `/ObjStm` while preserving stream and entry order. Primitive integer
   lexing now also parses Int-range PDF number tokens directly from borrowed
   `BytesView` data, using an
   Int64 overflow guard before falling back to the existing real-number parser.
   Shared reader ASCII integer parsing also accumulates through Int64 and
   rejects values outside MoonBit `Int` range before they become xref offsets,
   subsection counts, or `startxref` pointers. Malformed reconstruction now
   reuses scan-local `ByteCursor` instances across candidate offsets for xref,
   object, trailer, and xref-stream discovery instead of allocating a fresh
   cursor for every candidate byte in large recovered files.
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
   levels 0 through 9, exposing CamlPDF's `flate_level` workflow without global
   mutable state; fast levels still fall back to stored blocks for
   incompressible data, while higher levels search deeper match chains for
   better compression on older repeated spans in the pure MoonBit fallback.
   On native, normal Flate encode/decode now routes through CamlPDF's vendored
   miniz-compatible C path, while the pure MoonBit codec remains available for
   non-native targets and parser prefix decoding where consumed-byte accounting
   is required. Owned `PdfBytes` Flate filter dispatch now calls the owned
   Flate APIs directly, avoiding an unnecessary `BytesView.to_owned()` copy on
   common filter encode/decode hot paths. The native miniz FFI now reports
   success through a borrowed `Ref[Int]` status output, so successful payload
   bytes are returned directly without a status-prefix stripping copy and valid
   empty decoded payloads remain distinguishable from failure. Owned public
   Flate decode also routes directly through the native bytes helper, avoiding
   the remaining owned-to-view-to-owned copy before the C boundary on common
   stream-filter decode paths. The pure Flate prefix decoder now reuses cached
   fixed-Huffman literal and distance tables and uses bounded Huffman-symbol
   table lookahead with exact-bit fallback, so inline images and other
   consumed-length parsing paths do not rebuild fixed tables or walk bits one
   at a time for each decodable symbol. Owned `/Crypt` identity filter encode/decode
   now returns the original immutable `Bytes` value instead of copying through a
   borrowed view, and owned predictor encode/decode returns the original bytes
   for identity predictor `1`. Standard stream-filter names are now cached once
   for dispatch,
   avoiding repeated ASCII `PdfName` rebuilding during filter comparisons, and
   standard stream dictionary keys such as `/Filter`, `/Length`, and
   `/DecodeParms` are cached for repeated stream transformations.
   Remaining focus: exact miniz block-spelling gaps only where they matter,
   broader large-file performance tuning, optional JBIG2 external-tool decode
   parity, broader CCITT corpus validation, and DCT/JPEG real-world payload
   coverage.

4. Page and content layer.
   Owner modules: `pdf_content.mbt`, `pdf_page.mbt`, `pdf_dest.mbt`,
   `pdf_bookmark.mbt`, `pdf_annot.mbt`, `pdf_page_label.mbt`,
   `pdf_tree.mbt`.
   Status: page tree read/write/change/extract flows, content operators,
   `pdfhello.ml`-style standard-font document round-trip fixtures,
   `pdftest.ml`-style content rewrite fixtures, inline images, destinations,
   bookmarks, annotations, page labels, duplicate annotation fixups, and
   destination pruning are started with direct tests. Name/number tree support
   now includes read/build/merge helpers plus raw contents and typed lookup
   APIs with nested `/Kids` traversal and `/Limits` pruning. Inline-image
   parsing now
   consumes known encoded payload boundaries, treats DCT as a deferred JPEG
   stage, and can decode leading supported filters before preserving remaining
   deferred image filters such as DCT or CCITT. Inline-image dictionary, filter,
   and color-space names are cached as private `PdfName` values so parsing and
   inline-image rewriting reuse stable standard names. Single-stage ASCIIHex,
   ASCII85, RunLength, Flate, and LZW inline images without `/DecodeParms` now
   reuse prefix-decoded payloads instead of copying encoded bytes and decoding
   them again through stream-filter dispatch.
   Page-tree, page
   dictionary, resource dictionary, direct color-space, and resource
   prefix/renumbering names are also cached so page lifecycle operations reuse
   stable standard names. Malformed bookmark sets are
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
   Structure-tree trimming now uses hash-backed deleted-page and deletion sets
   for stable `/Pg` removal and ancestor `/K` pruning, avoiding repeated linear
   membership scans on large tagged documents.
   Content parsing also follows CamlPDF's malformed color-operator fallback for
   bad `SC`/`sc`/`SCN`/`scn` operands and filters malformed `TJ` array
   members. Operator tokens remain borrowed as `BytesView` through known
   operator dispatch, which pattern matches the operator bytes directly instead
   of decoding them to `String`; ownership is taken only when unknown
   operations must be preserved. Malformed numeric entries inside `d` dash
   arrays now raise instead of being preserved as unknown operations.
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
   derived-entry map/CID/notdef/metadata overrides, and hash-backed recursive
   seen-state for multi-hop stream inheritance. Inherited CMap map, CID, and
   notdef composition now uses hash-backed charcode sets while preserving
   derived-entry precedence. External CMap codepoint extraction now builds
   per-text-run hash lookup maps for explicit CID, notdef, and Unicode entries
   before falling through to inherited predefined CMaps, Identity fallback, and
   encoded glyph fallback, preserving duplicate first-match behavior while
   avoiding per-character scans of parsed maps. The external-CMap path still
   covers inherited Identity fallback, named predefined `/UseCMap` fallback for
   streams without explicit codespaces, and ToUnicode inheritance through text
   extraction and reverse Unicode lookup,
   CamlPDF-style whitespace-elided ToUnicode CMap section scanning, mixed
   multiline `bfrange` parsing, `/WMode` token parsing across PDF whitespace,
   comment-aware CMap metadata and mapping parsing,
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
   GBK2K-H predefined-CMap mixed 1/2/4-byte text extraction and reverse lookup
   through compressed read/write/reread boundaries,
   Type3 `/ToUnicode` text extraction with indirect CharProcs and custom
   metrics, plus a Type3 glyph-program resource gate where a CharProc uses
   its Type3 `/Resources` for an XObject invocation and named inline-image
   color space resolution. Embedded TrueType `FontFile2` plus `/ToUnicode`
   text extraction through compressed read/write boundaries, TrueType
   `/FontDescriptor` metadata preservation through native read/write/reread
   boundaries, Type3 no-`/ToUnicode` custom-encoding fallback through AGL glyph
   names and StandardEncoding fill-in, and Flate inline-image content parsing
   are also covered. Standard image dictionary keys and encoded-image filter
   names are cached once for repeated metadata lookups. Exact-size raw
   DeviceRGB/CalRGB 8bpp image extraction returns the owned RGB24 payload
   directly, preserving prefix-copy behavior only when trailing bytes are
   present. Standard font aliases,
   encoding names, font/CID/CMap dictionary keys, and ToUnicode writer keys are
   also cached as private `PdfName` values for repeated text read/write
   lookups. Generated Adobe-GB1, Adobe-CNS1, and Adobe-Japan1 CID-range
   reverse lookup now resolves Unicode to CID and then CID to charcode instead
   of scanning every character code in every range, preserving deterministic
   lowest packed-charcode behavior for duplicate mappings. CNS-EUC-H/V forward
   CID-range lookup now uses unsigned binary search over serialized byte-order
   packed charcodes instead of linear scans. Basic Latin glyph-name lookups now
   use package-private
   `FixedArray[PdfName?]` caches for StandardEncoding-style and plain quote
   variants, and Standard14 width fallback reuses the cached `/space` glyph
   name; the large non-ASCII AGL glyph-name tables remain generated on demand.
   Unit coverage also
   preserves direct Type3 `CharProcs`
   streams, parses their `d0`/`d1` glyph programs without allocating new
   indirect objects, and round-trips Type3 writer output for `/FontBBox`,
   `/FontMatrix`, `CharProcs`, `/Resources`, and width metrics. Stream decode
   now also covers CCITT `/K 0` and `/K < 0` data
   through `/CCITTFaxDecode` and `/CCF`.
   Remaining focus: remaining rare predefined CMap family tables when source
   tables or fixtures are available, real-world ToUnicode/CMap variation
   fixtures, plus JPEG pixel decode and remaining image filter families.

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
   Missing trailer file IDs now flow through the shared `pdf_id.mbt` generator
   for `change_id`, encryption, and merge. Ordinary generation uses the
   MoonBit `@env.now()` boundary, while `CAMLPDF_REPRODUCIBLE_IDS=true` forces
   the CamlPDF-compatible `md5("camlpdf")` seed; explicit `file_id=` values
   still take precedence.
   Public byte output and native async file output can now opt into
   CamlPDF-style generated trailer IDs with `pdf_write_document_with_generated_id`
   and `pdf_write_document_to_file_with_generated_id`; both paths write a copied
   document so the caller's in-memory object graph is not mutated by output.
   The same generated-ID behavior is available for incremental update output via
   `pdf_write_document_incremental_update_with_generated_id` and the native
   async file wrapper, so appended trailers can refresh `/ID` without mutating
   the caller's document.
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
   write/reread, plus classic malformed xref-entry marker reconstruction before
   password decryption. Standard encryption dictionary, crypt-filter,
   stream-policy, and AESV3 random-field names are cached as private `PdfName`
   values so encrypted reads/writes reuse stable byte-level names instead of
   rebuilding them at each lookup or dictionary construction.
   Remaining focus: broader real-world encrypted malformed-reader compatibility.

7. Document-level features.
   Owner modules: `pdf_merge.mbt`, `pdf_ocg.mbt`, `pdf_date.mbt`, plus feature
   helpers in page/text modules.
   Status: merge, optional content groups, dates, page labels, bookmarks,
   duplicate-font paths, env-aware trailer file-ID installation, malformed
   named-destination merge fallback, the `pdfdecomp.ml` stream-decompression
   workflow, a `pdfmergeexample.ml`-style public workflow fixture, and a
   `pdfdraft.ml` image-replacement acceptance fixture are started. Page-label
   reads now preserve CamlPDF's tolerant range
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

Current estimate: native main-feature parity is about 96% complete. Full
CamlPDF parity, including deferred filter families, deeper malformed recovery,
and backend breadth, is about 84-89% complete.

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
  acceptance boundaries, cached standard page/resource names for page lifecycle
  hot paths, cached standard annotation, bookmark, destination,
  optional-content, and structure-tree names for document-feature lifecycle hot
  paths, resource-heavy page replacement with mixed destination/action
  references, cached standard merge catalog, destination, name-dictionary,
  AcroForm, and structure-tree names for public merge/extraction workflows, and
  cached standard name-tree, number-tree, page-label, and document-root names
  for document metadata helpers, and example workflows for `pdfdecomp.ml`,
  `pdftest.ml`, `pdfdraft.ml`, `pdfencrypt.ml`, and `pdfmergeexample.ml`.
- Covered: ARC4, AESV2, AESV3/AESV3 ISO authentication, encryption,
  decryption, shared env-aware file-ID generation for missing encryption and
  merge IDs, native secure-random writer paths, saved-state recrypt, encrypted
  object streams, lazy encrypted stream forcing, non-stream object-stream
  payload recrypt, cached standard encryption dictionary and crypt-filter
  names, bad-startxref encrypted reconstruction with recrypt, feature-rich
  classic malformed-xref reconstruction through labels, annotations,
  destinations, name-tree destinations, catalog actions, `change_pages`, and
  compressed rewrite/reread, and `/EncryptMetadata false`.
- Not covered enough: remaining `change_pages` compatibility fixtures involving
  unusual inherited page data and broader real-world destination/action
  combinations.
- Not covered enough: broader real-world encrypted malformed-reader recovery.

### P1: Deepen Format Parity

- Covered: ASCIIHex, ASCII85, RunLength, LZW decode, Flate decode/encode,
  including native miniz-compatible normal Flate encode/decode plus the pure
  MoonBit fallback/prefix decoder, predictors, filter arrays,
  stop-at-unknown stream decoding, raw/encoded image extraction basics, color
  spaces, functions, standard fonts, PDFDocEncoding, UTF-16BE, ToUnicode CMaps,
  Identity-H/V CID text basics, predefined UCS2
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
  inheritance through extraction, comment-aware CMap parsing, an Identity-V
  native gate with vertical width metadata, and a native GBK2K-H gate for mixed
  1/2/4-byte predefined-CMap extraction and reverse lookup.
  Native image acceptance now also covers
  structured DCT/JPEG marker payloads through staged Flate-to-DCT image
  XObjects and DCT inline images, JPX encoded images, staged Flate-to-JBIG2
  images with `/JBIG2Globals`, and CCITT image XObjects through raw RGB
  extraction; native font acceptance covers Type3 `/ToUnicode` text with
  indirect CharProcs, resource-consuming Type3 glyph programs, and embedded
  TrueType `FontFile2` with generated `/ToUnicode` text extraction, while
  focused font tests preserve direct Type3 `CharProcs` streams, parse
  `d0`/`d1` glyph programs, and round-trip Type3 writer output without dropping
  bbox, matrix, resources, CharProcs, or width metrics. Standard text/font
  dictionary, encoding, CID, CMap, and ToUnicode names are cached for repeated
  read/write hot paths, and generated CID-range CMap reverse lookup avoids
  per-charcode range scans for Adobe-GB1, Adobe-CNS1, and Adobe-Japan1, while
  CNS-EUC forward CID lookup uses unsigned binary range search. Recursive
  stream `/UseCMap` parsing also carries a hash-backed seen set instead of
  copying a visited-array at each base-CMap hop, and inherited CMap map/CID/
  notdef composition uses hash-backed charcode sets instead of repeated output
  scans. External CMap text extraction now builds per-run lookup maps instead
  of scanning CID, notdef, and Unicode arrays for each character code.
  Standard color-space family names and PDF function
  dictionary keys are cached for repeated format-layer read/write hot paths.
  Pure Flate prefix decoding now uses bounded Huffman-symbol table lookahead,
  with fallback to exact bit reads at short raw DEFLATE tails.
  Stream decode now covers CCITT `/K 0` and `/K < 0` with `/DecodeParms`
  defaults and direct indirect params. Typed stream encoding now covers CCITT
  Group 3 `/K 0` and Group 4 `/K < 0` and round-trips through decode.
- Not covered enough: remaining rare predefined CMap family tables when source
  tables or fixtures are available, real-world fixture-driven Type3
  resource/glyph-program coverage, more real-world ToUnicode variations, and
  broader real-world DCT/JPEG image payload corpus files. The current checked-in
  CamlPDF `logo.pdf` and `introduction_to_camlpdf.pdf` fixtures do not contain
  extractable image entries, so image corpus expansion needs additional
  licensed fixtures.
- Not covered enough: exact zlib/Flate block identity where downstream tooling
  depends on byte spelling, broader DCT/JPEG and CCITT corpus validation, and
  optional external JBIG2 decoder integration.
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
  coverage. A May 6, 2026 `moon coverage analyze` pass reports all source
  files fully covered after closing the remaining codec, content, image,
  lexeme, reconstructed object-stream, and generated CMap reverse-lookup helper
  branches plus the CNS-EUC unsigned range lookup and grouped object-stream
  expansion helper.
- Covered: checked-in CamlPDF logo fixture bad-`startxref` reconstruction
  through native async file wrappers, compressed rewrite, and reread.
- Covered: checked-in CamlPDF intro fixture compressed-xref incremental update
  recovery after corrupting the final `startxref`, including reused
  object-number payload recovery, compressed rewrite/reread, and multi-page
  text extraction.
- Covered: all-target `moon check --target all --warn-list +73` type-checks
  cleanly after native stabilization.
- Deferred: full all-backend test stabilization. Native-only
  secure-random/encrypted writer APIs and `async_io` intentionally diverge from
  WasmGC today.
- Deferred: larger real-world corpus testing, performance tuning, and optional
  external tool integration for filters that CamlPDF handled through C stubs or
  external binaries.

### Immediate Work Order

- Next: prioritize broad native acceptance gates over isolated parser quirks:
  real-file corpus expansion beyond the checked-in CamlPDF intro/logo fixtures,
  fixture-driven Type3 resource/glyph-program behavior, or real CCITT/DCT
  fixture coverage when suitable files are available. Keep JPEG/JBIG2 decoder
  decisions separate from encoded image pass-through.
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
- In progress: image/filter corpus parity, remaining exact Flate block-identity
  and remaining large-file tuning for object streams, filters, image
  extraction, and non-ASCII text paths, non-UCS2 text CMap parity, remaining
  encryption edge cases, remaining malformed-reader recovery, and example-level
  integration fixtures.
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
