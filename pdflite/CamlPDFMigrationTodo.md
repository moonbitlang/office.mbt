# CamlPDF Migration Todo

This is the progress tracker for the pdflite CamlPDF migration. Update this
file whenever a substantial migration slice lands. Keep `OCaml2MoonBit.md`
library-agnostic; project architecture details belong in
`CamlPDFArchitecturePlan.md` and `CamlPDFMigrationPlan.md`.

Current estimate:

- Native main-feature parity: 96%.
- Full CamlPDF parity across deferred filters, malformed recovery, and backend
  breadth: 84-89%.

## Tracking Rules

- [x] ~~Keep this file as the canonical migration checklist.~~
- [x] ~~Use checked, struck-through text for completed items so finished work
  remains visible in history.~~
- [x] ~~Update this file whenever a substantial migration slice lands, and keep
  project architecture details in `CamlPDFArchitecturePlan.md`.~~
- [x] ~~When a remaining item becomes too broad, split it into a fixture- or
  feature-sized checklist entry before implementing it.~~

## Current Priority Checklist

- [x] ~~Stabilize native-first core architecture and main workflows.~~
- [x] ~~Share CamlPDF-style trailer `/ID` generation across `change_id`,
  encryption, and merge.~~
- [x] ~~Add CamlPDF-style generated trailer `/ID` writer output for byte and
  async file writes without mutating the source document.~~
- [x] ~~Add CamlPDF-style generated trailer `/ID` incremental-update output for
  byte and async file writes without mutating the source document.~~
- [x] ~~Check the currently tracked CamlPDF fixture PDFs for image XObjects
  before expanding image corpus tests; `logo.pdf` and
  `introduction_to_camlpdf.pdf` do not currently provide image entries.~~
- [ ] Add licensed real-world image corpus fixtures, prioritizing CCITT and
  DCT/JPEG encoded payload compatibility before optional pixel decoders.
- [x] ~~Add Type3 glyph-program/resource coverage where a CharProc consumes
  Type3 `/Resources` through an XObject and named inline-image color space.~~
- [ ] Add fixture-driven Type3 glyph-program/resource coverage from real PDFs
  when suitable fixtures are available.
- [ ] Add more malformed xref-table/xref-stream/object-stream recovery cases
  from real-world PDFs.
- [x] ~~Add a native reader-boundary gate for the next available predefined CMap
  source-table slice: GBK2K-H mixed 1/2/4-byte text extraction and reverse
  charcode lookup.~~
- [ ] Decide any further rare predefined CMap source-table slices only when
  useful source tables or fixtures are available.
- [x] ~~Route native normal Flate encode/decode through CamlPDF's vendored
  miniz-compatible C path, while keeping the pure MoonBit codec for non-native
  targets and prefix decoding.~~
- [x] ~~Avoid the extra owned-byte copy on `PdfBytes` Flate filter
  encode/decode dispatch by routing owned byte paths directly to Flate APIs.~~
- [x] ~~Return native miniz Flate encode/decode payloads directly through a
  borrowed FFI status `Ref[Int]`, avoiding the extra status-prefix stripping
  copy while preserving empty-payload success handling.~~
- [x] ~~Route owned `PdfBytes` Flate decode directly through the native miniz
  bytes helper, avoiding the owned-to-view-to-owned copy that remained on the
  public decode path.~~
- [x] ~~Return owned bytes unchanged for `/Crypt` identity filter encode/decode,
  avoiding unnecessary immutable `Bytes` copies on stream filter dispatch.~~
- [x] ~~Cache standard stream-filter names so encode/decode dispatch no longer
  rebuilds ASCII `PdfName` values for every filter comparison.~~
- [x] ~~Cache standard stream dictionary keys such as `/Filter`, `/Length`, and
  `/DecodeParms` so repeated stream transformations avoid rebuilding them.~~
- [x] ~~Cache the core object-model `/Length` key used when forced deferred
  stream materialization refreshes stream dictionaries.~~
- [x] ~~Cache standard image extraction dictionary and encoded-image filter
  names so repeated image inspection avoids rebuilding ASCII `PdfName` values.~~
- [x] ~~Cache standard reader keys used by xref, object-stream, trailer, and
  stream-length handling so large object-table loads avoid rebuilding names.~~
- [x] ~~Parse object-stream headers and embedded object slices from borrowed
  `BytesView` data instead of allocating temporary owned `Bytes`.~~
- [x] ~~Cache standard encryption dictionary, crypt-filter, stream-policy, and
  AESV3 random-field names so encrypted reads/writes avoid rebuilding stable
  ASCII `PdfName` values.~~
- [x] ~~Cache writer xref-stream/trailer names and inline-image
  dictionary/filter/color names so write and content-parse hot paths reuse
  stable `PdfName` values.~~
- [x] ~~Cache standard font aliases, encoding names, font/CID/CMap dictionary
  keys, and ToUnicode writer keys so text read/write hot paths reuse stable
  `PdfName` values.~~
- [x] ~~Cache Basic Latin glyph names, StandardEncoding control glyph names, and
  the Standard14 `/space` fallback so common text extraction and width
  calculations avoid rebuilding stable ASCII `PdfName` values.~~
- [x] ~~Cache page-tree, page/resource dictionary, direct color-space, and
  resource-renumbering names so page lifecycle hot paths reuse stable
  `PdfName` values.~~
- [x] ~~Cache standard annotation, bookmark, destination, optional-content, and
  structure-tree names so document-feature lifecycle paths reuse stable
  `PdfName` values.~~
- [x] ~~Cache standard color-space family names and function dictionary keys so
  format-layer read/write paths reuse stable `PdfName` values.~~
- [x] ~~Cache standard merge catalog, destination, name-dictionary, AcroForm,
  and structure-tree names so public merge/extraction workflows reuse stable
  `PdfName` values.~~
- [x] ~~Cache name-tree, number-tree, page-label, and document-root names so
  document metadata helpers reuse stable `PdfName` values.~~
- [ ] Continue zlib byte-output/performance parity work where exact miniz block
  spelling or large-file profiles expose remaining gaps.
- [ ] Profile and tune remaining large-file hot paths for object streams,
  filters, image extraction, and non-ASCII text paths.
- [ ] Revisit all-backend validation after native parity is stable.

## Big Picture Checklist

- [x] ~~P0 native core workflows: object graph, reader/writer, page tree,
  merge/extract, encryption, async file wrappers, and main CamlPDF-style example
  gates.~~
- [x] ~~Core format layer: filters, predictors, text encodings, color spaces,
  functions, raw/encoded image extraction, and primary font workflows.~~
- [x] ~~Native real-file gates for the checked-in CamlPDF `logo.pdf` and
  `introduction_to_camlpdf.pdf` fixtures, including compressed rewrites,
  malformed `startxref` recovery, and incremental update recovery.~~
- [x] ~~CJK text parity for the currently generated Adobe-GB1, Adobe-CNS1,
  Adobe-Japan1, and Adobe-Korea1 predefined CMap fallbacks, plus external CMap
  codespace/CID parsing and `/UseCMap` stream composition through ToUnicode.~~
- [x] ~~Finish broader external/general CMap parsing for codespace/CID/notdef
  sections, encoding-side Unicode maps, notdef text/reverse lookup, program
  and stream-dictionary header metadata, Identity and named predefined
  `/UseCMap` fallbacks, parsed stream `/UseCMap` composition, and PDF comments
  in CMap programs.~~
- [x] ~~Native predefined CMap reader-boundary gate for GBK2K-H mixed-byte
  extraction and reverse lookup through compressed read/write/reread
  boundaries.~~
- [ ] Add remaining rare predefined CMap family coverage when useful source
  tables or fixtures are available.
- [ ] Add further real-world Type3 glyph-program/resource coverage when
  suitable fixtures are available.
- [ ] Add licensed real-world DCT/JPEG and CCITT image corpus coverage; keep
  optional JBIG2/JPEG pixel-decoder decisions explicit.
- [x] ~~Native normal Flate encode/decode now uses the vendored miniz-compatible
  C path, with pure MoonBit fallback preserved for non-native targets and
  parser prefix decoding.~~
- [x] ~~Native miniz Flate output now uses a side-channel status `Ref[Int]`
  instead of status-prefixed bytes, so successful native payloads no longer need
  an extra owned-byte copy to strip the prefix.~~
- [x] ~~Owned public Flate decode now calls the native miniz bytes helper
  directly, so Flate stream filter decoding no longer re-owns already-owned
  compressed bytes before the C boundary.~~
- [x] ~~Owned `/Crypt` identity filter encode/decode now returns the original
  immutable `Bytes` object and is covered by physical-identity assertions.~~
- [x] ~~Deferred stream `get_stream` materialization now reuses the cached
  object-model `/Length` key when correcting stream dictionaries.~~
- [x] ~~Encryption dictionary and crypt-filter lookups/builders now share cached
  `PdfName` values for stable standard keys and name objects.~~
- [x] ~~Writer trailer/xref-stream keys and inline-image metadata/filter names
  now share cached `PdfName` values in the remaining large-file hot paths.~~
- [x] ~~Text/font parsing and writing now share cached standard font,
  encoding, font dictionary, CID, CMap, and ToUnicode names in the main text
  hot paths.~~
- [x] ~~Basic Latin text extraction and Standard14 explicit-encoding width
  lookup now share cached glyph `PdfName` values for ASCII letters, digits,
  punctuation, StandardEncoding control names, and `/space` fallback.~~
- [x] ~~Page-tree traversal, page dictionaries, resource dictionaries, and
  resource prefix/renumber logic now share cached standard `PdfName` values.~~
- [x] ~~Annotation, bookmark, destination, optional-content, and
  structure-tree helpers now share cached standard `PdfName` values across
  document-feature lifecycle paths.~~
- [x] ~~Color-space readers/writers and function dictionary helpers now share
  cached standard `PdfName` values in format-layer hot paths.~~
- [x] ~~Merge catalog assembly, destination rewriting, name-dictionary merging,
  AcroForm merging, and structure-tree helpers now share cached standard
  `PdfName` values.~~
- [x] ~~Name-tree/number-tree builders and lookups, page-label helpers, and the
  document root key now share cached standard `PdfName` values.~~
- [ ] Improve byte-identical zlib output strategy and broader performance
  parity beyond the explicit Flate level API.
- [ ] Broaden malformed xref-table/xref-stream/object-stream recovery with more
  real-world corpus cases.
- [ ] Revisit all-backend validation after native feature parity is stable.
- [ ] Tune remaining performance for large files, object streams, filters,
  image extraction, and non-ASCII text paths.

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
- [x] ~~Name/number tree API parity for raw contents and typed lookup helpers,
  including nested `/Kids` traversal and `/Limits` pruning.~~
- [x] ~~`change_pages` bookmark/destination matrix rewriting and count-changing
  replacement with explicit reference mapping.~~
- [x] ~~ARC4/AESV2/AESV3 authentication, encryption, decryption, native
  secure-random writer paths, saved-state recrypt, encrypted object streams,
  lazy encrypted streams, and `/EncryptMetadata false`.~~
- [x] ~~Shared CamlPDF-style file-ID generation across `change_id`, encryption,
  and merge missing-ID paths, honoring `CAMLPDF_REPRODUCIBLE_IDS` while
  preserving explicit `file_id=` overrides.~~
- [x] ~~CamlPDF-style generated trailer `/ID` writer path for bytes and native
  async file output, preserving the original document object graph.~~
- [x] ~~CamlPDF-style generated trailer `/ID` incremental writer path for bytes
  and native async file output, preserving the original document object graph.~~
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
- [x] ~~Checked-in CamlPDF fixture image discovery: current `logo.pdf` and
  `introduction_to_camlpdf.pdf` fixtures have no extractable image XObjects, so
  broader real-world image corpus coverage needs additional licensed fixtures.~~
- [x] ~~Embedded TrueType `FontFile2` plus `/ToUnicode` native text gate through
  compressed read/write/reread boundaries.~~
- [x] ~~Embedded TrueType `/FontDescriptor` metadata preservation for `/Flags`,
  `/ItalicAngle`, `/CapHeight`, `/XHeight`, and `/StemV` through reader and
  native read/write/reread boundaries.~~
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
- [x] ~~Direct Unicode predefined CMap extraction for UCS2, UTF8, UTF16, and
  UTF32 CMap names, including UTF8 variable-length segmentation, UTF16
  surrogate-pair charcodes, UTF32 scalar validation, reverse lookup, and
  malformed Unicode sequence coverage.~~
- [x] ~~Mixed-byte predefined CMap charcode segmentation for common EUC, RKSJ,
  Big5, UHC, and GBK families through `/ToUnicode` text extraction.~~
- [x] ~~RKSJ predefined CMap built-in ASCII and half-width Katakana fallback
  when `/ToUnicode` is absent, including reverse charcode lookup.~~
- [x] ~~GB-EUC predefined CMap built-in GB2312 mapping table when
  `/ToUnicode` is absent, including reverse charcode lookup.~~
- [x] ~~Big5 predefined CMap built-in mapping table when `/ToUnicode` is
  absent, including reverse charcode lookup.~~
- [x] ~~UHC predefined CMap built-in CP949 mapping table when `/ToUnicode` is
  absent, including reverse charcode lookup.~~
- [x] ~~GBK predefined CMap built-in Adobe GBK-EUC-UCS2 mapping table when
  `/ToUnicode` is absent, including reverse charcode lookup and the CMap's
  single-byte `0x80`/`0xFF` behavior.~~
- [x] ~~KSC-EUC predefined CMap built-in mapping table composed from
  `KSC-EUC-H` and `Adobe-Korea1-UCS2` when `/ToUnicode` is absent, including
  reverse charcode lookup.~~
- [x] ~~KSCpc-EUC predefined CMap built-in mapping table from
  `KSCpc-EUC-UCS2`, including multi-codepoint expansion and single-codepoint
  reverse lookup.~~
- [x] ~~GBpc-EUC predefined CMap built-in mapping table from
  `GBpc-EUC-UCS2`, including PC single-byte handling, one multi-codepoint
  expansion, and single-codepoint reverse lookup.~~
- [x] ~~B5pc predefined CMap built-in mapping table from `B5pc-UCS2`,
  including PC single-byte handling and reverse lookup.~~
- [x] ~~HKSCS predefined CMap built-in mapping table composed from
  `HKscs-B5-H` and `cidToUnicode/Adobe-CNS1`, including supplementary
  Unicode scalar handling and reverse lookup.~~
- [x] ~~Hong Kong Big5 predefined CMap built-in CID-range fallbacks for
  `HKdla-B5`, `HKdlb-B5`, `HKgccs-B5`, `HKm314-B5`, and `HKm471-B5`,
  sharing Adobe-CNS1 CID-to-Unicode data, supplementary scalar handling, and
  reverse lookup.~~
- [x] ~~ETenms-B5 predefined CMap built-in CID-range fallback, including its
  ETen-B5 base, Adobe-CNS1 symbol/Cyrillic differences, single-byte `0x80`
  behavior, and reverse lookup.~~
- [x] ~~GBK2K predefined CMap built-in CID-range fallback using packed
  four-byte signed-`Int` charcodes, shared Adobe-GB1 CID-to-Unicode data,
  supplementary scalar handling, and reverse lookup.~~
- [x] ~~CNS-EUC-H/V predefined CMap built-in CID-range fallback using
  Adobe-CNS1 CID-to-Unicode data, one/two/four-byte segmentation, vertical
  mapping, reverse lookup with shorter duplicate charcode preference, and
  truncated four-byte error coverage.~~
- [x] ~~Vertical predefined CMap override fallbacks for supported Adobe-GB1,
  Adobe-CNS1, and Adobe-Korea1 families when `/ToUnicode` is absent, including
  reverse lookup.~~
- [x] ~~Japanese Adobe-Japan1 predefined-CMap fallback when `/ToUnicode` is
  absent, including generated 90ms/90pv RKSJ direct Unicode tables, JIS
  two-byte CMaps, EUC-H, Hojo-EUC three-byte charcodes, multi-scalar expansion,
  and reverse lookup for single-scalar entries.~~
- [x] ~~External CMap stream parsing for `begincodespacerange`,
  `begincidchar`, and `begincidrange`, including parsed indirect `/Encoding`
  streams, variable-length text segmentation, CID fallback, reverse CID lookup,
  and `/ToUnicode` coexistence by character code.~~
- [x] ~~External CMap `/UseCMap` name parsing from CMap programs and stream
  dictionaries, including Identity-H/V inherited two-byte segmentation,
  explicit CID-map override behavior, CID fallback, and reverse CID lookup.~~
- [x] ~~External CMap stream `/UseCMap` composition, including recursive parsed
  stream bases, cycle protection, inherited codespaces, map/CID inheritance,
  key-based derived-entry override behavior, inherited Identity fallback, and
  reverse CID lookup.~~
- [x] ~~ToUnicode CMap stream `/UseCMap` composition through font text
  extraction and reverse Unicode lookup, including derived-entry override of
  inherited Unicode mappings.~~
- [x] ~~External/general CMap `beginnotdefchar` and `beginnotdefrange`
  parsing, including compact-section recovery and `/UseCMap` composition
  inheritance with derived-entry override behavior.~~
- [x] ~~External/general CMap notdef maps applied in Type0 text extraction and
  reverse lookup after explicit CID mappings and before inherited
  predefined/Identity fallbacks.~~
- [x] ~~External/general CMap header metadata parsing for `/CMapName`,
  `/CMapType`, and `/CIDSystemInfo`, including dictionary-style and
  `dict dup begin` CID system syntax plus `/UseCMap` composition inheritance
  and override behavior.~~
- [x] ~~External CMap named predefined `/UseCMap` fallback for streams without
  explicit codespaces, including inherited mixed-byte and two-byte text
  segmentation, built-in Unicode fallback, reverse lookup, and explicit
  CID-entry override behavior.~~
- [x] ~~External CMap stream-dictionary metadata fallback for `/WMode`,
  `/CMapName`, `/CMapType`, `/CIDSystemInfo`, and name `/UseCMap`, with CMap
  program metadata taking precedence, indirect dictionary values resolved, and
  malformed dictionary metadata ignored.~~
- [x] ~~External/general CMap `bfchar`/`bfrange` Unicode maps are applied for
  otherwise unmapped Type0 `/Encoding` charcodes before inherited predefined or
  Identity fallbacks, including reverse lookup, CID/notdef shadowing, and
  malformed UTF-16BE fallback coverage.~~
- [x] ~~External/general CMap program parsing ignores PDF comments while
  preserving literal-string `%` bytes, preventing commented fake metadata,
  section markers, and mappings from affecting ToUnicode and Type0 external
  CMap extraction.~~
- [ ] Broader built-in non-UCS2 predefined CMap mapping tables beyond the
  current Adobe-GB1, Adobe-CNS1, Adobe-Japan1, and Adobe-Korea1 fallbacks,
  plus more real-world ToUnicode/CMap variation fixtures.
- [x] ~~Type3 font `/ToUnicode` native text gate with indirect CharProcs,
  custom encoding, metrics, compressed rewrite, and reread.~~
- [x] ~~Direct Type3 CharProc stream reader coverage for preserved `d0`/`d1`
  glyph programs and expanded Type3 metrics.~~
- [x] ~~Type3 writer round-trip fidelity for `/FontBBox`, `/FontMatrix`,
  actual `CharProcs` stream objects, `/Resources`, and non-empty
  `FirstChar`/`LastChar`/`Widths` metrics.~~
- [x] ~~Type3 no-`/ToUnicode` custom-encoding fallback through AGL glyph names,
  StandardEncoding fill-in, reverse lookup, and preserved CharProc streams
  through native compressed read/write/reread boundaries.~~
- [ ] Further real-world Type3 glyph-program/resource coverage when suitable
  fixtures are available.
- [x] ~~TrueType descriptor metadata survives read_font_descriptor and embedded
  TrueType native read/write/reread gates.~~
- [x] ~~Structured DCT/JPEG marker payload native gate for Flate-to-DCT image
  XObjects and DCT inline images with embedded `EI` bytes before EOI.~~
- [ ] Additional real-world DCT/JPEG encoded-payload corpus coverage.
- [ ] Optional external JBIG2 decoder integration and broader CCITT corpus
  validation.
- [x] ~~Explicit zlib-style Flate level API across direct Flate, filter, and
  stream encoding surfaces.~~
- [x] ~~Fast explicit Flate levels fall back to stored blocks for incompressible
  data instead of forcing larger fixed-Huffman output.~~
- [x] ~~Explicit Flate levels now influence match-chain search depth, so fast
  levels use a smaller search budget and high levels can find older repeated
  spans.~~
- [x] ~~Native normal Flate encode/decode uses a vendored miniz-compatible C
  path for CamlPDF-style zlib behavior and faster native stream handling, while
  preserving the pure MoonBit implementation as fallback/non-native code.~~
- [x] ~~Owned `PdfBytes` Flate filter dispatch avoids an unnecessary
  `BytesView.to_owned()` copy on encode/decode hot paths.~~
- [x] ~~Native miniz Flate FFI returns payload bytes directly and reports status
  through a borrowed `Ref[Int]`, preserving valid empty decode results without a
  status-byte payload copy.~~
- [x] ~~Owned public Flate decode now bypasses `BytesView.to_owned()` on native
  by calling the native miniz bytes helper directly.~~
- [x] ~~Owned `/Crypt` identity filter encode/decode bypasses `BytesView.to_owned()`
  and returns the existing immutable `Bytes`.~~
- [x] ~~Standard stream-filter dispatch names are cached once instead of
  rebuilding ASCII `PdfName` values on every comparison.~~
- [x] ~~Standard stream dictionary keys are cached once instead of rebuilding
  ASCII `PdfName` values across stream decode/encode stages.~~
- [x] ~~Standard image extraction keys and encoded-image filter names are cached
  once instead of rebuilt on every image metadata lookup.~~
- [x] ~~Standard reader/xref/object-stream keys are cached once instead of
  rebuilt on repeated strict and reconstructed read paths.~~
- [x] ~~Object-stream extraction parses header and embedded object slices from
  borrowed views instead of temporary owned byte copies.~~
- [ ] Byte-identical zlib output strategy and broader performance parity beyond
  explicit Flate level selection.
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
- [x] ~~Preserve TrueType descriptor metadata through the embedded TrueType
  native acceptance gate.~~
- [x] ~~Add a Type3 no-`/ToUnicode` custom-encoding fallback native acceptance
  gate.~~
- [x] ~~Add a structured DCT/JPEG marker payload native gate.~~
- [x] ~~Add mixed-byte predefined CMap `/ToUnicode` extraction coverage.~~
- [x] ~~Add RKSJ no-`/ToUnicode` predefined-CMap single-byte fallback
  coverage.~~
- [x] ~~Add one broader non-UCS2 predefined-CMap mapping table beyond the RKSJ
  single-byte fallback.~~
- [x] ~~Add another non-UCS2 predefined-CMap mapping table beyond RKSJ and
  GB-EUC.~~
- [x] ~~Add UHC or another remaining non-UCS2 predefined-CMap mapping table.~~
- [x] ~~Add GBK or another remaining non-UCS2 predefined-CMap mapping table.~~
- [x] ~~Add another remaining non-UCS2 predefined-CMap mapping table, such as
  KSC-EUC, HKSCS, or GBK2K, or a vertical no-`/ToUnicode` predefined-CMap
  gate.~~
- [x] ~~Add the next remaining non-UCS2 predefined-CMap table, such as HKSCS,
  KSCpc-EUC, GBK2K, or a vertical no-`/ToUnicode` predefined-CMap gate.~~
- [x] ~~Add the next remaining non-UCS2 predefined-CMap table, such as HKSCS,
  GBpc-EUC, GBK2K, or a vertical no-`/ToUnicode` predefined-CMap gate.~~
- [x] ~~Add the next remaining non-UCS2 predefined-CMap table, such as HKSCS,
  GBK2K, B5pc, or a vertical no-`/ToUnicode` predefined-CMap gate.~~
- [x] ~~Add the next remaining non-UCS2 predefined-CMap table, such as HKSCS,
  GBK2K, ETenms-B5, or a vertical no-`/ToUnicode` predefined-CMap gate.~~
- [x] ~~Add the next remaining non-UCS2 predefined-CMap table, such as GBK2K,
  ETenms-B5, HKdla/HKdlb/HKgccs/HKm, or a vertical no-`/ToUnicode`
  predefined-CMap gate.~~
- [x] ~~Add the next remaining non-UCS2 predefined-CMap table, such as
  ETenms-B5 exact coverage, vertical no-`/ToUnicode` behavior, or GBK2K after
  the four-byte charcode representation is made explicit.~~
- [x] ~~Add the next remaining text parity slice: vertical no-`/ToUnicode`
  behavior or GBK2K after the four-byte charcode representation is made
  explicit.~~
- [x] ~~Add the next remaining text parity slice: vertical no-`/ToUnicode`
  behavior, broader external predefined/general CMap parsing, or real-world
  ToUnicode variation coverage.~~
- [x] ~~Add the next remaining text parity slice: Japanese multi-byte
  predefined-CMap fallback, broader external predefined/general CMap parsing,
  or real-world ToUnicode variation coverage.~~
- [x] ~~Add the next remaining text parity slice: external CMap stream
  codespace/CID mapping for indirect Type0 `/Encoding` streams, remaining rare
  predefined CMap families, or real-world ToUnicode variation coverage.~~
- [x] ~~Add the next remaining text parity slice: external CMap Identity
  `/UseCMap` parsing and inherited segmentation/CID fallback.~~
- [x] ~~Add the next remaining text parity slice: external CMap stream
  `/UseCMap` composition with derived-entry overrides and cycle protection.~~
- [x] ~~Add the next remaining text parity slice: ToUnicode stream `/UseCMap`
  composition through extractor and reverse lookup.~~
- [x] ~~Add the next remaining text parity slice: apply parsed external CMap
  notdef sections during Type0 extraction and reverse lookup.~~
- [x] ~~Add the next remaining text parity slice: apply parsed external CMap
  `bfchar`/`bfrange` Unicode maps for otherwise unmapped Type0 `/Encoding`
  charcodes before inherited fallbacks.~~
- [x] ~~Add the next remaining text parity slice: CNS-EUC-H/V rare predefined
  CMap fallback with one/two/four-byte segmentation, Adobe-CNS1 Unicode
  fallback, vertical mapping, reverse lookup, and signed-`Int` packed-key
  lookup coverage.~~
- [x] ~~Add the next remaining text parity slice: direct Unicode predefined
  CMap handling for UTF8/UTF16/UTF32 names, including variable-length
  segmentation, supplementary-plane reverse lookup, and malformed scalar
  coverage.~~
- [x] ~~Add the next remaining format parity slice: comment-aware CMap parsing
  for metadata, `/UseCMap`, ToUnicode maps, CID maps, notdef maps, and
  codespaces.~~
- [x] ~~Add the next remaining API parity slice: name/number tree contents and
  lookup helpers.~~
- [x] ~~Add the next remaining performance parity slice: level-sensitive Flate
  match-chain search depth.~~
- [x] ~~Harden object-selection traversal so deferred parser placeholders are
  not treated as selectable `null` objects.~~
- [x] ~~Route password-aware malformed classic xref-entry errors through
  reconstruction before decryption.~~
- [x] ~~Route encryption and merge missing file IDs through the shared
  env-aware CamlPDF-style ID generator.~~
- [x] ~~Add generated trailer `/ID` write helpers for byte and async file
  output.~~
- [x] ~~Add generated trailer `/ID` incremental-update helpers for byte and
  async file output.~~
- [x] ~~Add a Type3 CharProc resource-use gate covering `/XObject` lookup and
  named inline-image `/ColorSpace` resolution from the Type3 resource
  dictionary.~~
- [x] ~~Add a native GBK2K-H predefined-CMap reader-boundary gate for mixed
  1/2/4-byte extraction and reverse lookup.~~
- [x] ~~Add native miniz-backed normal Flate encode/decode while preserving pure
  MoonBit fallback behavior.~~
- [ ] Add the next remaining format parity slice: remaining rare predefined
  CMap families, real-world ToUnicode variation coverage, fixture-driven Type3
  resource/glyph-program behavior, or real-world image corpus coverage.
- [ ] Revisit non-native backend validation after native parity is stable.
