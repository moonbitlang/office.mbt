# CamlPDF Migration Todo

This is the progress tracker for the pdflite CamlPDF migration. Update this
file whenever a substantial migration slice lands. Keep `OCaml2MoonBit.md`
library-agnostic; project architecture details belong in
`CamlPDFArchitecturePlan.md` and `CamlPDFMigrationPlan.md`.

Current estimate:

- Native main-feature parity: 98.0%.
- Full CamlPDF parity across deferred filters, malformed recovery, and backend
  breadth: 85-90%.

Current backend snapshot:

- Native: full suite passing with complete source coverage.
- WasmGC and JavaScript: full non-native test suites pass.
- Wasm: backend smoke suite passes with 497 tests after keeping the largest
  corpus/text regression files on wasm-gc/js/native/llvm; full plain-Wasm suite
  is still deferred because the generated package-level module exceeds the
  runtime's maximum function-size limit.
- LLVM: blocked by the current toolchain's missing LLVM stdlib bundle.

## Tracking Rules

- [x] ~~Keep this file as the canonical migration checklist.~~
- [x] ~~Use checked, struck-through text for completed items so finished work
  remains visible in history.~~
- [x] ~~Update this file whenever a substantial migration slice lands, and keep
  project architecture details in `CamlPDFArchitecturePlan.md`; PDF-to-Markdown
  acceptance details live in `PdfMarkdownAcceptancePlan.md`.~~
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
- [x] ~~Expose `.repos/pdfread.mli`-referenced native async file helpers for
  `read_header` and `is_linearized`, with generated and checked-in fixture
  coverage.~~
- [x] ~~Expose `.repos/pdfspace.mli` and `.repos/pdfops.mli`-referenced
  standalone colour-space helpers for debug strings, names, read/write, and
  component counts over the existing typed document methods.~~
- [x] ~~Expose `.repos/pdfimage.mli`-referenced standalone image helpers for
  colour-space lookup, bits-per-component lookup, and 24bpp image extraction
  over the existing typed document methods.~~
- [x] ~~Expose `.repos/pdftransform.mli`-referenced standalone transform helpers
  for identity transforms, transform debug strings, matrix-of-transform,
  matrix application, inversion, decomposition, and scalar recomposition over
  the existing typed matrix API.~~
- [x] ~~Expose `.repos/pdfgenlex.mli` and `.repos/pdfread.mli`-referenced
  lexeme debug string helpers over byte-oriented `PdfLexeme` values, using
  explicit lossy ASCII decoding only for debug text.~~
- [x] ~~Expose `.repos/pdfdest.mli`, `.repos/pdfmarks.mli`, and
  `.repos/pdfpagelabels.mli`-referenced standalone document-feature helpers
  for destination read/transform, bookmark read/add/remove/transform, and page
  label read/write/remove over the existing typed document methods.~~
- [x] ~~Expose `.repos/pdfannot.mli` and `.repos/pdfocg.mli`-referenced
  standalone document-feature helpers for page annotation read/add/transform
  and optional-content read/write/remove over the existing typed document
  methods.~~
- [x] ~~Expose `.repos/pdfpage.mli`-referenced standalone page lifecycle
  helpers for page-tree read/write/rooting, page counts and target lookup,
  page extraction/replacement, resource renumbering, prefixing, and operator
  insertion over the existing typed document methods.~~
- [x] ~~Expose `.repos/pdfmerge.mli`-referenced standalone merge helpers for
  CamlPDF-shaped `merge_pdfs` flags/name/range arguments and duplicate-font
  removal over the existing typed merge and dedupe core.~~
- [x] ~~Expose `.repos/pdftext.mli`-referenced standalone text/font helpers for
  standard-font and font debug strings, font read/write, Identity-H detection,
  text extractors, text-to-codepoint/glyph extraction, and reverse charcode
  closures over the existing typed text API.~~
- [x] ~~Expose `.repos/pdfstandard14.mli`-referenced standalone standard-14
  helpers for CamlPDF-ordered text width, baseline adjustment, StemV, and
  flags over the existing standard-font methods.~~
- [x] ~~Expose `.repos/pdftree.mli`-referenced standalone name/number tree
  helpers for byte-key name-tree reads, decimal-byte number-tree reads,
  bool-selected tree building, and no-clash merges over the existing typed
  tree API.~~
- [x] ~~Expose `.repos/pdfst.mli`-referenced standalone structure-tree helpers
  for trim, parent-tree renumbering, structure-tree merge/root creation, and
  optional top-level `/Document` wrapping over the existing structure/merge
  core.~~
- [x] ~~Expose `.repos/pdffun.mli`-referenced standalone function helpers for
  parse, eval, PDF-object serialization, and debug printing over the existing
  typed function core.~~
- [x] ~~Expose `.repos/pdfcmap.mli`-referenced standalone CMap parse helper over
  the existing document-aware CMap stream parser.~~
- [x] ~~Expose `.repos/pdfcryptprimitives.mli`-referenced compatibility helpers
  for ARC4, AES-CBC decrypt/encrypt with explicit first block, AES-ECB
  encrypt/decrypt, object-key hashing, and stream-data crypt dispatch over the
  existing byte-oriented primitive core.~~
- [x] ~~Expose `.repos/pdfcrypt.mli`-referenced standalone encryption helpers
  for document decrypt, owner decrypt, encrypted-state introspection,
  encryption-value parsing, single-stream decrypt, permission-mask decoding,
  ARC4 encrypt/recrypt, explicit-provider AES encrypt/recrypt, and native
  secure-random AES convenience encrypt wrappers.~~
- [x] ~~Expose a `.repos/pdfwrite.mli`-shaped typed writer options wrapper for
  one-call byte output with optional ID generation, incremental update,
  xref-stream mode dispatch, optional encryption, explicit-provider AES
  workflows, and already-encrypted pass-through.~~
- [x] ~~Decide whether to emulate CamlPDF's `charcode_extractor` debug stderr
  output; MoonBit keeps the reverse lookup pure and ignores `debug` because
  adding async stdio or stdout side effects to this synchronous helper would be
  worse than preserving CamlPDF's diagnostic-only behavior.~~
- [x] ~~Evaluate CamlPDF's repeated-input `names` merge optimization; the
  wrapper now has a repeated-name destination gate documenting the current
  MoonBit choice to preserve per-inclusion destinations, while CamlPDF's
  object-reuse path remains performance-only unless repeated-name profiles show
  a real output-size regression.~~
- [x] ~~Check the currently tracked CamlPDF fixture PDFs for image XObjects
  before expanding image corpus tests; `logo.pdf` and
  `introduction_to_camlpdf.pdf` do not currently provide image entries.~~
- [x] ~~Add deterministic writer/reader image-XObject fixture coverage for
  `/XObject` page resources and 24bpp extraction, so image handling is
  validated across document serialization before the licensed external corpus
  grows.~~
- [x] ~~Add licensed real-world image corpus fixtures, prioritizing CCITT and
  DCT/JPEG encoded payload compatibility before optional pixel decoders; the
  native optional fixture package now gates py-pdf sample-file DCT/JPEG,
  CCITT/FaxDecode, and indexed-CMYK image XObjects when downloads are
  present.~~
- [x] ~~Start the separate PDF-to-Markdown acceptance package described in
  `PdfMarkdownAcceptancePlan.md`, with deterministic in-memory extraction tests
  before generated or downloaded fixtures.~~
- [x] ~~Add Pandoc-generated Latin and CJK PDF fixtures for the Markdown
  converter once the in-memory converter API is stable.~~
- [x] ~~Preserve Pandoc-generated Latin word boundaries by treating large
  negative `TJ` numeric adjustments as word spacing while ignoring small
  kerning adjustments.~~
- [x] ~~Add a MarkItDown comparison report/script for selected local Pandoc
  fixtures; use differences to drive core extraction fixes.~~
- [x] ~~Add replacement-character and raw-control counters to the MarkItDown
  comparison summary so Markdown quality regressions are tracked directly in
  generated reports.~~
- [x] ~~Extend the MarkItDown comparison loop to downloaded real-world fixtures
  with documented redistribution terms and expected extraction contracts.~~
- [x] ~~Add download-only external Markdown acceptance fixtures for an Adobe
  PDF-spec supplement and a Unicode CJK chart, with SHA-256 lock metadata and
  checked-in comparison judgement.~~
- [x] ~~Decrypt blank/open user-password PDFs at the Markdown boundary before
  text extraction, fixing `InvalidFlateData` on encrypted external
  acceptance PDFs.~~
- [x] ~~Investigate why `unicode_cjk_unified_ideographs_u4e00.pdf` decrypts but
  produces only page headings in pdflite while MarkItDown extracts chart text;
  fix Markdown form-XObject traversal and cache shared font extractors so the
  chart extracts at practical speed.~~
- [x] ~~Sanitize non-text C0/C1 control scalars at the Markdown boundary so
  fallback glyph/control codes from real PDFs do not write raw control bytes to
  `.md` output; refreshed external comparison shows no raw controls in the
  Adobe supplement or Unicode CJK chart pdflite outputs.~~
- [x] ~~Add a first-pass positioned-text ordering path for Markdown pages with
  meaningful text coordinates, including form-XObject placement through `cm`
  transforms; the Unicode CJK chart now follows row/column order and extracts
  1,512,647 characters versus MarkItDown's 1,518,212.~~
- [x] ~~Add scalar-aware fullwidth chunk-width estimation for positioned
  Markdown extraction, preserving adjacent CJK glyph chunks without inserted
  spaces while keeping explicit wider gaps visible.~~
- [x] ~~Suppress unreliable `.notdef`/non-text-control glyph runs at the
  Markdown boundary, keeping CamlPDF-compatible core text fallback behavior
  while preventing custom no-ToUnicode metadata fonts from producing `u�`-style
  placeholder text; the Unicode CJK chart now extracts 1,451,941 characters
  with no raw controls or replacement characters.~~
- [x] ~~Make Markdown `TJ` word-spacing context-aware so large negative
  adjustments still preserve Latin and Hangul word boundaries, while synthetic
  separators are suppressed between Han/kana-style ToUnicode glyphs; the
  synthetic CJK and Hangul regressions are covered and the Unicode chart
  remains at 1,451,941 characters with no raw controls or replacement
  characters, indicating its visible CJK spaces are table/content layout rather
  than this `TJ` adjustment case.~~
- [x] ~~Add U+4E00-9FFF unique-glyph coverage to the MarkItDown comparison
  report; the Unicode chart records 20,963/20,963 pdflite/MarkItDown glyph
  coverage, matching a `pdftotext -layout` spot-check, so the remaining gap is
  layout/line joining rather than broad glyph loss.~~
- [x] ~~Add line-count and average-line-length metrics to the MarkItDown
  comparison report; the Unicode chart now records 52,933 pdflite lines at
  26.4 characters/line versus MarkItDown's 534 lines at 2,842.1
  characters/line, making the remaining layout/line-joining gap explicit.~~
- [x] ~~Gate external Markdown fixtures in MoonBit tests when downloads are
  present: the Adobe ISO 32000 supplement must retain title/version markers
  with no raw controls and the Unicode CJK chart must retain the full 20,963
  U+4E00-9FFF unique-glyph coverage with no raw controls or replacement
  characters.~~
- [x] ~~Review remaining Unicode CJK chart Markdown quality gaps against
  MarkItDown and pdftotext; optional `pdftotext -layout` metrics now run in
  the comparison script, all three extractors see 20,963 U+4E00-9FFF glyphs,
  and the remaining gap is table/layout-space reconstruction rather than
  missing chart cells.~~
- [x] ~~Add Type3 glyph-program/resource coverage where a CharProc consumes
  Type3 `/Resources` through an XObject and named inline-image color space.~~
- [x] ~~Add fixture-driven Type3 glyph-program coverage from a real PDF; the
  optional native font fixture now reads the iText Type3 logo sample, indirect
  CharProc streams, metrics, custom encoding differences, and page text.~~
- [x] ~~Add fixture-driven Type3 `/Resources` coverage from a real PDF; the
  optional native font fixture now gates the PDFium Type3 inline-image sample,
  preserves `/Resources`, and parses glyph inline-image programs with those
  resources.~~
- [x] ~~Add malformed xref-stream/object-stream recovery coverage where bad
  `startxref` reconstruction still resolves indirect `/ObjStm` `/N` and
  `/First` bounds before expanding embedded entries.~~
- [x] ~~Add CamlPDF malformed `/ObjStm` member compatibility for a direct
  stream object embedded inside an object stream, including `/Length` repair
  from the `endstream` marker and xref-stream extraction coverage.~~
- [x] ~~Add malformed xref-stream recovery coverage for unknown entry types:
  physical objects whose xref-stream kind is outside 0/1/2 are skipped rather
  than loaded, matching CamlPDF's null-entry treatment.~~
- [x] ~~Add strict and reconstructed xref-stream coverage for `/W [0 ... ...]`
  omitted type fields, validating PDF-spec default in-use entries through
  bad-startxref recovery.~~
- [x] ~~Add reconstructed filtered xref-stream coverage where a bad
  `startxref` forces recovery of an `/ASCIIHexDecode` xref stream and sanitizes
  stream-only trailer keys.~~
- [ ] Add more malformed xref-table/xref-stream/object-stream recovery cases
  from real-world PDFs.
- [x] ~~Add a native reader-boundary gate for the next available predefined CMap
  source-table slice: GBK2K-H mixed 1/2/4-byte text extraction and reverse
  charcode lookup.~~
- [x] ~~Add a native reader-boundary gate for the HKSCS Adobe-CNS1 source-table
  slice, including supplementary scalars, single-byte `0x80`, and reverse
  charcode lookup through compressed write/read/reread boundaries.~~
- [x] ~~Add a native reader-boundary gate for CNS-EUC-H/V Adobe-CNS1
  source-table fallback, including one/two/four-byte segmentation, vertical
  override, and reverse charcode lookup through compressed write/read/reread
  boundaries.~~
- [x] ~~Add a native reader-boundary gate for Adobe-Korea1 predefined CMap
  source-table fallbacks, covering KSCms-UHC-H, KSC-EUC-H, and KSCpc-EUC-H
  extraction plus reverse charcode lookup through compressed write/read/reread
  boundaries.~~
- [x] ~~Add a native reader-boundary gate for Adobe-GB1 predefined CMap
  source-table fallbacks, covering GB-EUC-H, GBpc-EUC-H, and GBK-EUC-H
  extraction plus reverse charcode lookup through compressed write/read/reread
  boundaries.~~
- [x] ~~Add a native reader-boundary gate for remaining Adobe-CNS1 Big5-family
  predefined CMap variants, covering B5pc-H, ETenms-B5-H, HKdla-B5-H,
  HKdlb-B5-H, HKgccs-B5-H, HKm314-B5-H, and HKm471-B5-H through compressed
  write/read/reread boundaries.~~
- [x] ~~Add a native reader-boundary gate for Adobe-Japan1 predefined CMap
  fallbacks, covering 90ms-RKSJ-H, 90pv-RKSJ-H, JIS H, EUC-H, and Hojo-EUC-H
  extraction plus reverse lookup through compressed write/read/reread
  boundaries.~~
- [ ] Decide any further rare predefined CMap source-table slices only when
  useful source tables or fixtures are available.
- [x] ~~Route native normal Flate encode/decode through CamlPDF's vendored
  miniz-compatible C path, while keeping the pure MoonBit codec for non-native
  targets and prefix decoding.~~
- [x] ~~Expose `.repos/pdfcodec.mli`-referenced direct CCITT Group 3 and Group
  4 byte encoder helpers with `BytesView` variants, and validate them through
  normal `/CCITTFaxDecode` stream decoding.~~
- [x] ~~Avoid the extra owned-byte copy on `PdfBytes` Flate filter
  encode/decode dispatch by routing owned byte paths directly to Flate APIs.~~
- [x] ~~Return native miniz Flate encode/decode payloads directly through a
  borrowed FFI status `Ref[Int]`, avoiding the extra status-prefix stripping
  copy while preserving empty-payload success handling.~~
- [x] ~~Route owned `PdfBytes` Flate decode directly through the native miniz
  bytes helper, avoiding the owned-to-view-to-owned copy that remained on the
  public decode path.~~
- [x] ~~Gate native Flate byte-output parity against CamlPDF's vendored miniz
  spelling for small stored streams and compressed repeated streams across
  representative zlib levels.~~
- [x] ~~Cache fixed-Huffman DEFLATE literal and distance tables so pure prefix
  Flate decoding no longer rebuilds them for every fixed block.~~
- [x] ~~Decode pure MoonBit DEFLATE Huffman symbols through bounded lookup-table
  lookahead with exact-bit fallback, reducing per-symbol bit reads for inline
  image prefix decoding and non-native Flate fallback while preserving consumed
  byte accounting.~~
- [x] ~~Reuse prefix-decoded payloads for single-stage Flate inline images
  without `/DecodeParms`, avoiding an encoded-byte copy and a second stream
  decode.~~
- [x] ~~Reuse prefix-decoded payloads for single-stage LZW inline images
  without `/DecodeParms`, avoiding an encoded-byte copy and a second stream
  decode.~~
- [x] ~~Reuse decoded payloads for single-stage ASCIIHex, ASCII85, and
  RunLength inline images without `/DecodeParms`, avoiding encoded-byte copies
  and second stream decodes.~~
- [x] ~~Return owned predictor encode/decode bytes unchanged for identity
  predictor `1`, avoiding unnecessary immutable `Bytes` copies.~~
- [x] ~~Reuse PNG predictor decode row buffers, push fixed-predictor encode rows
  directly, and score Optimum predictor candidates without row arrays, avoiding
  per-row scratch allocation on common predictor filter paths while preserving
  exact bytes.~~
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
- [x] ~~Return exact-size raw DeviceRGB/CalRGB 8bpp image extraction payloads
  unchanged, avoiding a copy when the decoded stream is already RGB24 while
  preserving prefix-copy behavior for trailing bytes.~~
- [x] ~~Cache standard reader keys used by xref, object-stream, trailer, and
  stream-length handling so large object-table loads avoid rebuilding names.~~
- [x] ~~Parse object-stream headers and embedded object slices from borrowed
  `BytesView` data instead of allocating temporary owned `Bytes`.~~
- [x] ~~Decode each `/ObjStm` once per reader pass and reuse the parsed
  object-stream context for all compressed entries from that stream, including
  encrypted and reconstructed xref-stream reads.~~
- [x] ~~Cache standard encryption dictionary, crypt-filter, stream-policy, and
  AESV3 random-field names so encrypted reads/writes avoid rebuilding stable
  ASCII `PdfName` values.~~
- [x] ~~Cache writer xref-stream/trailer names and inline-image
  dictionary/filter/color names so write and content-parse hot paths reuse
  stable `PdfName` values.~~
- [x] ~~Keep content-stream operator tokens borrowed as `BytesView` during
  parsing, allocating only when unknown operators must be preserved.~~
- [x] ~~Dispatch known content-stream operators by direct `BytesView` byte
  patterns instead of decoding operator tokens to MoonBit `String`.~~
- [x] ~~Parse common integer PDF lexemes directly from borrowed `BytesView`
  data, with Int64 overflow guards and existing real-number fallback
  behavior.~~
- [x] ~~Guard shared reader ASCII integer parsing with Int64 bounds before
  converting to `Int`, so overflowing xref offsets and `startxref` pointers
  enter malformed-reader recovery instead of wrapping.~~
- [x] ~~Reuse `ByteCursor` instances across malformed reconstruction xref,
  object, trailer, and xref-stream scans, avoiding per-candidate cursor
  allocation on large recovered files.~~
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
- [x] ~~Use a hash-backed dictionary builder for merged structure and AcroForm
  dictionaries, preserving first-key order and last-value replacement while
  avoiding repeated key scans.~~
- [x] ~~Track retained merge catalog-extra keys with a hash-backed name set,
  preserving first-seen catalog-entry precedence while avoiding repeated
  duplicate-name scans across merged documents.~~
- [x] ~~Detect merge destination-name collisions with hash-backed byte/name
  sets, preserving collision suffix behavior while avoiding repeated scans when
  merging large name-tree and old-style catalog destination lists.~~
- [x] ~~Cache merge destination-name rewrite lookups with hash-backed
  local/global maps, preserving document-local precedence and global fallback
  while avoiding repeated change-list scans across object graph traversal.~~
- [x] ~~Cache name-tree, number-tree, page-label, and document-root names so
  document metadata helpers reuse stable `PdfName` values.~~
- [ ] Continue zlib byte-output/performance parity work where exact miniz block
  spelling or large-file profiles expose remaining gaps.
- [ ] Profile and tune remaining large-file hot paths for object streams,
  filters, image extraction, and non-ASCII text paths.
- [x] ~~Group xref-stream type-2 entries by containing object stream before
  embedded object expansion, avoiding a full xref scan per `/ObjStm` while
  preserving first-seen stream order and per-stream entry order.~~
- [x] ~~Accumulate newer-first classic/xref-stream entries with a hash-backed
  object-number set, preserving first-entry precedence while avoiding repeated
  duplicate scans across revision chains.~~
- [x] ~~Cache exact xref-stream object/offset skip checks with nested
  hash-backed number sets, avoiding repeated scans when loading strict and
  reconstructed xref-stream sections.~~
- [x] ~~Deduplicate incremental-writer changed object numbers with a
  `HashMap` before sorting sparse xref entries, avoiding quadratic event-log
  scans for repeatedly edited objects.~~
- [x] ~~Emit full and sparse xref-stream data with a single pass over sorted
  xref tuples, avoiding repeated tuple scans across large object-number
  ranges.~~
- [x] ~~Emit classic sparse incremental xref rows with a carried sorted xref
  index across subsections, avoiding repeated tuple scans for changed/deleted
  object ranges.~~
- [x] ~~Track recursive external/ToUnicode stream `/UseCMap` cycle protection
  with a hash-backed seen set, avoiding per-hop seen-array copies and linear
  membership scans on multi-hop CMap inheritance chains.~~
- [x] ~~Compose inherited external/ToUnicode CMap maps with hash-backed
  charcode sets, preserving current-entry precedence while avoiding repeated
  scans of growing map/CID/notdef outputs.~~
- [x] ~~Extract external CMap text with per-text-run hash lookup maps for
  CID, notdef, and Unicode entries, preserving CID/notdef/Unicode/predefined/
  Identity/fallback precedence and first-entry duplicate behavior.~~
- [x] ~~Trim structure trees with hash-backed deleted-page and deletion sets,
  preserving CamlPDF-style stable `/Pg` removal and `/K` pruning while avoiding
  repeated membership scans on large tagged documents.~~
- [x] ~~Cache duplicate-stream comparison candidates during font deduplication
  and group them by byte length before exact dictionary/data comparison,
  preserving canonical-first renumbering while reducing merge hot-path scans.~~
- [x] ~~Build hash-backed structure parent-tree renumber maps once per document,
  preserving first-change precedence while avoiding repeated scans during
  recursive `/StructParent` and `/StructParents` rewriting.~~
- [x] ~~Share a package-local hash-backed `PdfNumberSet` for page/bookmark and
  structure-tree membership checks, avoiding repeated linear scans during
  extraction bookmark filtering, duplicate annotation repair, deleted-page
  reference cleanup, and structure trimming.~~
- [x] ~~Cache destination page-object to page-number lookups during bookmark
  extraction, preserving first page-reference match behavior while avoiding a
  repeated page-tree scan for each bookmark target.~~
- [x] ~~Use the shared hash-backed `PdfNumberSet` for annotation popup-parent
  filtering, avoiding repeated linear parent scans when reading pages with
  many annotations.~~
- [x] ~~Build a hash-backed page-reference change map once for `change_pages`
  and object-renumbering passes, preserving first-change precedence while
  avoiding repeated old-to-new page-reference scans across large object graphs.~~
- [x] ~~Cache page-number and matrix lookups during `change_pages` destination
  transformations, preserving first matrix/page-reference precedence while
  avoiding repeated scans across bookmarks, annotations, open actions, and
  named destination trees.~~
- [x] ~~Replace generated Adobe-GB1, Adobe-CNS1, and Adobe-Japan1 CID-range
  CMap reverse lookup nested charcode scans with Unicode/CID-to-charcode
  helpers, preserving deterministic lowest packed-charcode selection for
  duplicate mappings and four-byte GBK2K charcodes.~~
- [x] ~~Replace CNS-EUC generated CID-range forward lookup linear scans with
  unsigned binary range lookup, preserving serialized byte-order table
  semantics for mixed two-byte and high-bit four-byte packed charcodes.~~
- [x] ~~Run all-target type checking with `moon check --target all --warn-list
  +73`; native remains the test-validation target.~~
- [x] ~~Close the May 6 native coverage gap for identity filter/predictor
  `BytesView` copy boundaries, inline-image encoded/error branches, borrowed
  raw RGB image helpers, lexeme empty/sign-only integer parsing, and
  reconstructed object-stream expansion recovery.~~
- [ ] Revisit all-backend validation after native parity is stable.

## Big Picture Checklist

- [x] ~~P0 native core workflows: object graph, reader/writer, page tree,
  merge/extract, encryption, async file wrappers, and main CamlPDF-style example
  gates.~~
- [x] ~~Core format layer: filters, predictors, text encodings, color spaces,
  functions, raw/encoded image extraction, and primary font workflows.~~
- [x] ~~Standalone `.repos/pdfspace.mli`-style colour-space helper surface over
  the typed MoonBit model and document methods.~~
- [x] ~~Standalone `.repos/pdfimage.mli`-style image helper surface over the
  typed MoonBit document methods.~~
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
- [x] ~~Native predefined CMap reader-boundary gate for ETen-B5-H Big5 text,
  exercising Adobe-CNS1 mapping and reverse lookup through compressed
  read/write/reread boundaries.~~
- [x] ~~Native predefined CMap reader-boundary gate for HKscs-B5-H HKSCS text,
  exercising Adobe-CNS1 supplementary scalars, single-byte `0x80`, and reverse
  lookup through compressed read/write/reread boundaries.~~
- [ ] Add remaining rare predefined CMap family coverage when useful source
  tables or fixtures are available.
- [x] ~~Add further real-world Type3 glyph-program coverage; the optional native
  font fixture gates the iText Type3 logo sample.~~
- [x] ~~Add further real-world Type3 `/Resources` coverage; the optional native
  font fixture gates the PDFium Type3 inline-image sample.~~
- [x] ~~Add licensed real-world DCT/JPEG and CCITT image corpus coverage; the
  optional native image fixture package gates py-pdf sample-file JPEG,
  CCITT/FaxDecode, and indexed-CMYK image XObjects while keeping optional
  JBIG2/JPEG pixel-decoder decisions explicit.~~
- [x] ~~Native normal Flate encode/decode now uses the vendored miniz-compatible
  C path, with pure MoonBit fallback preserved for non-native targets and
  parser prefix decoding.~~
- [x] ~~Native miniz Flate output now uses a side-channel status `Ref[Int]`
  instead of status-prefixed bytes, so successful native payloads no longer need
  an extra owned-byte copy to strip the prefix.~~
- [x] ~~Owned public Flate decode now calls the native miniz bytes helper
  directly, so Flate stream filter decoding no longer re-owns already-owned
  compressed bytes before the C boundary.~~
- [x] ~~Pure Flate prefix decoding now reuses cached fixed-Huffman tables,
  reducing repeated setup work for inline images and other consumed-length
  parsing paths that cannot use native miniz.~~
- [x] ~~Pure Flate prefix decoding now uses bounded Huffman-symbol lookahead
  over the existing decode tables, with bit-by-bit fallback when a short raw
  DEFLATE tail cannot satisfy the full table width.~~
- [x] ~~The refreshed native coverage pass reports all source files fully
  covered after exercising codec identity view copies, inline-image
  decode-parameter branches, raw RGB borrowed helpers, lexeme integer
  boundaries, and reconstructed object-stream recovery helpers.~~
- [x] ~~Single-stage Flate inline-image parsing now keeps the prefix-decoded
  payload when no `/DecodeParms` are present, instead of re-owning encoded data
  and decoding it again through the stream-filter path.~~
- [x] ~~Single-stage LZW inline-image parsing now keeps the prefix-decoded
  payload when no `/DecodeParms` are present, instead of re-owning encoded data
  and decoding it again through the stream-filter path.~~
- [x] ~~Single-stage ASCIIHex, ASCII85, and RunLength inline-image parsing now
  decodes while consuming the encoded boundary when no `/DecodeParms` are
  present, instead of re-owning encoded data and decoding it again through the
  stream-filter path.~~
- [x] ~~Exact-size raw DeviceRGB/CalRGB 8bpp image extraction now keeps the
  owned RGB24 stream bytes and only allocates for trailing-byte prefix slices.~~
- [x] ~~Owned predictor encode/decode now returns the original immutable
  `Bytes` for identity predictor `1` and is covered by physical-identity
  assertions.~~
- [x] ~~PNG predictor decode now reuses two row buffers; fixed-predictor encode
  paths append directly to the output array; and Optimum predictor scoring no
  longer allocates candidate row arrays for every scanline.~~
- [x] ~~Owned `/Crypt` identity filter encode/decode now returns the original
  immutable `Bytes` object and is covered by physical-identity assertions.~~
- [x] ~~Deferred stream `get_stream` materialization now reuses the cached
  object-model `/Length` key when correcting stream dictionaries.~~
- [x] ~~Encryption dictionary and crypt-filter lookups/builders now share cached
  `PdfName` values for stable standard keys and name objects.~~
- [x] ~~Writer trailer/xref-stream keys and inline-image metadata/filter names
  now share cached `PdfName` values in the remaining large-file hot paths.~~
- [x] ~~Content-stream parsing now keeps operator tokens borrowed through known
  operator dispatch and only owns bytes for preserved unknown operations.~~
- [x] ~~Known content-stream operator dispatch now pattern matches borrowed
  operator bytes directly and avoids per-operator ASCII string decoding.~~
- [x] ~~PDF integer lexing now parses Int-range tokens directly from borrowed
  `BytesView` data, preserving oversized-token fallback to real-number
  parsing.~~
- [x] ~~Reader ASCII integer parsing now rejects values outside MoonBit `Int`
  range with an Int64 guard, including public recovery coverage for an
  overflowing `startxref` pointer.~~
- [x] ~~Malformed reconstruction now reuses scan-local `ByteCursor` instances
  across candidate offsets for xref, object, trailer, and xref-stream
  discovery instead of allocating a cursor for every candidate byte.~~
- [x] ~~Object-stream expansion now materializes one decoded `/ObjStm` context
  per containing stream and reuses it for all compressed xref entries, avoiding
  repeated decode/decrypt work on compressed-object-heavy PDFs.~~
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
- [x] ~~Structure-tree trimming now builds hash-backed deleted-page and deletion
  sets once per trim pass, avoiding repeated linear membership scans while
  preserving stable pruning behavior.~~
- [x] ~~Duplicate stream/font removal now caches stream comparison candidates and
  groups them by byte length before exact comparison, avoiding repeated stream
  view materialization during merge deduplication.~~
- [x] ~~Merged structure and AcroForm dictionaries now use a hash-backed
  name-index builder, preserving existing order/replacement semantics while
  avoiding repeated linear dictionary-key replacement scans.~~
- [x] ~~Merge catalog-extra retention now uses a hash-backed name set for
  first-seen safe catalog entries, avoiding repeated duplicate-key scans across
  merged input catalogs.~~
- [x] ~~Merge destination collision detection now uses hash-backed sets for
  byte-string and catalog-name destination keys, preserving suffix allocation
  while avoiding repeated duplicate scans.~~
- [x] ~~Merge destination callsite rewriting now uses hash-backed local/global
  destination-name lookup maps, preserving local precedence plus global
  fallback while avoiding repeated change-list scans.~~
- [x] ~~Structure parent-tree renumbering now uses hash-backed old-key to new-key
  maps for recursive structure-object rewrites instead of scanning the change
  list at every integer key.~~
- [x] ~~Page, bookmark, and structure helpers now share `PdfNumberSet` for
  repeated integer-membership checks on extraction and cleanup hot paths.~~
- [ ] Improve byte-identical zlib output strategy and broader performance
  parity beyond the explicit Flate level API.
- [x] ~~Malformed xref-stream/object-stream recovery now covers bad-final
  `startxref` reconstruction with indirect `/ObjStm` `/N` and `/First`
  bounds.~~
- [x] ~~Malformed object-stream recovery now tolerates a direct stream object
  stored as an `/ObjStm` member, matching CamlPDF's explicit malformed-reader
  compatibility path.~~
- [x] ~~Malformed xref-stream recovery now covers unknown entry types, leaving
  physically present objects unloaded when their xref entry is neither free,
  in-use, nor compressed.~~
- [x] ~~Malformed classic-xref recovery now scans valid classic xref sections
  after a bad final `startxref`, loads verified in-use objects, and keeps their
  free entries from resurrecting deleted physical objects.~~
- [x] ~~Malformed classic-xref free-entry coverage is offset-aware, so a free
  row hides older objects but does not hide a later physical incremental object
  for the same object number.~~
- [ ] Broaden malformed xref-table/xref-stream/object-stream recovery with more
  real-world corpus cases.
- [ ] Revisit all-backend validation after native feature parity is stable.
- [ ] Tune remaining performance for large files, object streams, filters,
  image extraction, and non-ASCII text paths.
- [x] ~~Object-stream embedded-object loading now groups compressed xref entries
  by `/ObjStm`, so compressed-object-heavy reads do not rescan the full xref
  table for each object stream.~~
- [x] ~~Newer-first xref entry accumulation now tracks seen object numbers with
  `PdfNumberSet`, avoiding repeated duplicate scans while preserving the newest
  entry for each object number.~~
- [x] ~~Exact xref-stream object/offset skip checks now use a nested
  hash-backed lookup while loading plain objects, preserving object-number and
  offset identity semantics without repeated ref-list scans.~~
- [x] ~~Object-stream contexts now precompute member end offsets once, so
  loading many embedded objects from one `/ObjStm` no longer scans every header
  pair for every object reference.~~
- [x] ~~Malformed reconstruction trailer scanning now probes xref-stream
  trailers only at indirect-object headers instead of every digit byte in the
  file, avoiding repeated failed parses on large damaged inputs.~~
- [x] ~~Bad-startxref xref-stream reconstruction now has explicit coverage for
  unknown entry types, preserving the skip semantics already used by strict
  xref-stream reads.~~
- [x] ~~Unknown xref-stream entry types are retained internally as non-loadable
  markers, so malformed reconstruction does not resurrect physically present
  objects that a recovered xref stream marks with an unsupported entry kind.~~
- [x] ~~Recovered xref-stream skip markers are offset-aware, so they hide older
  physical objects covered by the stream without hiding later physical
  incremental objects for the same object number.~~
- [x] ~~Incremental writer changed-object detection now uses a hash-backed
  seen set before sorting sparse classic/xref-stream entry numbers, so large
  event logs with repeated edits avoid repeated linear duplicate checks.~~
- [x] ~~Full and sparse xref-stream byte generation now walks sorted xref
  tuples once, preserving emitted bytes while removing repeated lookup scans
  for large object tables and sparse incremental updates.~~
- [x] ~~Classic sparse incremental xref output now carries one sorted xref
  cursor across contiguous subsections, preserving row bytes while removing
  repeated tuple scans.~~
- [x] ~~Recursive stream `/UseCMap` parsing now uses a hash-backed seen set
  instead of copying an array at each base-CMap hop, preserving cycle handling
  and inherited ToUnicode composition.~~
- [x] ~~External/ToUnicode CMap inheritance now composes map, CID, and notdef
  entries with hash-backed charcode sets instead of repeatedly scanning the
  growing output arrays.~~
- [x] ~~External CMap text extraction now builds per-run hash lookup maps for
  explicit CID, notdef, and Unicode entries instead of scanning parsed maps for
  every character code.~~
- [x] ~~Plain `/ToUnicode` codepoint extraction now builds a per-run hash lookup
  map instead of scanning the ToUnicode table for every character code, while
  preserving duplicate first-entry decoding and malformed UTF-16 fallback.~~
- [x] ~~Regular text `codepoints_of_text` now flattens charcode glyph results
  directly instead of allocating an intermediate glyph-record array when callers
  only need codepoints.~~
- [x] ~~Regular text `glyphnames_of_text` now resolves glyph names directly from
  charcodes instead of allocating full glyph-record/codepoint arrays when callers
  only need glyph names.~~
- [x] ~~Generated CID-range CMap reverse lookup for Adobe-GB1, Adobe-CNS1, and
  Adobe-Japan1 now maps Unicode to CID and CID to charcode instead of scanning
  every character code in every range.~~
- [x] ~~CNS-EUC predefined-CMap forward lookup now uses unsigned binary range
  search instead of a linear scan over generated CID ranges.~~

## P0: Native Main Workflows

- [x] ~~Byte foundation with `Bytes`/`BytesView` ownership boundaries.~~
- [x] ~~Core PDF object graph, dictionaries, indirect refs, streams, lazy stream
  slices, document state, traversal, and renumbering.~~
- [x] ~~Classic xref, xref-stream, compressed xref-stream, object-stream,
  revision-specific, and major reconstructed read paths.~~
- [x] ~~Full and incremental writer modes, including public `PdfWriteMode`
  dispatch.~~
- [x] ~~Native async file read/write wrappers for core, encrypted, incremental,
  header-read, and linearized-file-probe workflows.~~
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
- [x] ~~Direct `.repos/pdfcodec.mli` CCITT Group 3 and Group 4 byte helpers,
  including borrowed `BytesView` inputs and decode round-trip tests.~~
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
- [x] ~~Generated Adobe-GB1, Adobe-CNS1, and Adobe-Japan1 CID-range predefined
  CMap reverse lookup now uses direct Unicode/CID-to-charcode helpers rather
  than per-charcode range scans.~~
- [x] ~~CNS-EUC predefined-CMap CID-range lookup now uses unsigned binary
  search for mixed two-byte and four-byte packed charcodes.~~
- [x] ~~ETen-B5-H predefined-CMap extraction now has a native compressed
  reader-boundary gate across Adobe-CNS1 Big5 forward and reverse lookup.~~
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
- [x] ~~Further real-world Type3 glyph-program coverage using the download-only
  iText Type3 logo fixture.~~
- [x] ~~Further real-world Type3 `/Resources` coverage using the download-only
  PDFium Type3 inline-image fixture.~~
- [x] ~~TrueType descriptor metadata survives read_font_descriptor and embedded
  TrueType native read/write/reread gates.~~
- [x] ~~Structured DCT/JPEG marker payload native gate for Flate-to-DCT image
  XObjects and DCT inline images with embedded `EI` bytes before EOI.~~
- [x] ~~Additional real-world DCT/JPEG encoded-payload corpus coverage through
  the download-only py-pdf pdflatex image fixture.~~
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
- [x] ~~Pure Flate prefix decoding reuses cached fixed-Huffman tables instead
  of rebuilding literal/distance tables for each fixed block.~~
- [x] ~~Single-stage Flate inline images without `/DecodeParms` reuse the
  prefix-decoded bytes and skip the encoded-copy/second-decode path.~~
- [x] ~~Single-stage LZW inline images without `/DecodeParms` reuse the
  prefix-decoded bytes and skip the encoded-copy/second-decode path.~~
- [x] ~~Single-stage ASCIIHex, ASCII85, and RunLength inline images without
  `/DecodeParms` decode at boundary-consumption time and skip the
  encoded-copy/second-decode path.~~
- [x] ~~Owned predictor encode/decode returns the original immutable `Bytes`
  for identity predictor `1`.~~
- [x] ~~Owned `/Crypt` identity filter encode/decode bypasses `BytesView.to_owned()`
  and returns the existing immutable `Bytes`.~~
- [x] ~~Standard stream-filter dispatch names are cached once instead of
  rebuilding ASCII `PdfName` values on every comparison.~~
- [x] ~~Standard stream dictionary keys are cached once instead of rebuilding
  ASCII `PdfName` values across stream decode/encode stages.~~
- [x] ~~Standard image extraction keys and encoded-image filter names are cached
  once instead of rebuilt on every image metadata lookup.~~
- [x] ~~Exact-size raw DeviceRGB/CalRGB 8bpp image extraction returns the
  decoded RGB24 bytes unchanged, with prefix-copy coverage for trailing data.~~
- [x] ~~Standard reader/xref/object-stream keys are cached once instead of
  rebuilt on repeated strict and reconstructed read paths.~~
- [x] ~~Object-stream extraction parses header and embedded object slices from
  borrowed views instead of temporary owned byte copies.~~
- [x] ~~Object-stream expansion decodes/decrypts each containing `/ObjStm` once
  per reader pass and reuses the parsed context for all embedded entries.~~
- [ ] Byte-identical zlib output strategy and broader performance parity beyond
  explicit Flate level selection.
- [x] ~~Native miniz byte-output parity now has exact fixture coverage for
  representative small stored streams and compressed repeated streams at
  multiple zlib levels.~~
- [x] ~~Malformed xref-stream/object-stream recovery covers reconstructed
  indirect object-stream bounds after a bad final `startxref`.~~
- [x] ~~Malformed xref-stream recovery covers unknown entry types after a bad
  final `startxref`, verifying reconstruction skips non-free/non-in-use/non-
  compressed entries just like strict xref-stream parsing.~~
- [x] ~~Malformed classic-xref recovery covers valid classic xref sections after
  a bad final `startxref`, preserving verified in-use entries and deleted/free
  entry semantics instead of relying only on physical object scanning.~~
- [x] ~~Malformed classic-xref recovery covers the offset boundary for free
  entries, preserving later physical incremental objects after a recovered xref
  section.~~
- [x] ~~Malformed object-stream recovery tolerates direct stream members inside
  `/ObjStm` data and repairs their stream length from `endstream`.~~
- [x] ~~Xref-stream reads and bad-startxref reconstruction now have explicit
  coverage for omitted type fields (`/W [0 4 2]`) defaulting to in-use entries.~~
- [x] ~~Filtered xref-stream bad-startxref reconstruction now has explicit
  coverage for ASCIIHex decoding and sanitized trailer metadata.~~
- [ ] Broader malformed xref-table/xref-stream/object-stream recovery beyond
  the current bad-startxref real-corpus, multi-revision, and encrypted
  object-stream gates.

## P2: Backend Breadth And Compatibility

- [x] ~~Native target is the stabilization target.~~
- [x] ~~Full native test suite is passing with coverage currently complete.~~
- [x] ~~Known native-only interface divergence is documented for secure-random
  AES helpers and `async_io`.~~
- [x] ~~All-target type checking passes with `moon check --target all
  --warn-list +73`; full non-native test validation remains deferred.~~
- [x] ~~WasmGC and JavaScript backend test suites pass after native
  stabilization, each with 1101 tests.~~
- [x] ~~Plain Wasm backend build-only validation passes for the package and
  generated tests.~~
- [x] ~~Plain Wasm backend smoke validation passes with 497 tests after
  excluding the largest corpus/text regression files from plain Wasm while
  retaining them on wasm-gc, JavaScript, native, and future LLVM.~~
- [ ] Split or otherwise reduce the largest regression suites so full
  plain-Wasm package-level tests can instantiate under the runtime's maximum
  function-size limit without target exclusions.
- [ ] Revisit LLVM backend validation once the installed MoonBit toolchain has
  the LLVM stdlib bundle available.
- [x] ~~Checked-in CamlPDF fixture PDFs read, multi-page text-extract,
  header-probe, linearized-probe, compressed-write, document-wide
  stream-decompress, and reread through native async file wrappers.~~
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
- [x] ~~External Markdown corpus fixtures are now gated by optional native tests
  when downloads are present, covering Adobe PDF-spec supplement extraction and
  Unicode CJK chart unique-glyph coverage.~~
- [x] ~~Checked-in CamlPDF introduction PDF now has a Markdown acceptance gate
  over the separate Markdown package, covering real multi-page text extraction,
  core API examples, and raw-control/replacement-character quality counters.~~
- [x] ~~Markdown extraction now uses a hash-backed indirect font extractor
  cache, avoiding linear cache scans for repeated `Tf` operators across large
  pages and nested form XObjects.~~
- [x] ~~Markdown normalization now trims the synthetic space before a terminal
  hyphen at extracted line breaks, matching common PDF text baselines for
  wrapped words such as `soft-` without joining the physical lines.~~
- [ ] Broader real-world PDF corpus testing, including PDF-to-Markdown
  comparison fixtures after the local Pandoc gates are stable.
- [ ] Performance tuning for large files, object streams, filters, and text/image
  extraction.
- [x] ~~Object-stream member slicing now uses precomputed end offsets in each
  object-stream context, improving large `/ObjStm` expansion without changing
  recovered object semantics.~~
- [x] ~~Malformed reconstruction now skips xref-stream trailer parse attempts
  unless the current byte begins an indirect-object header, reducing large-file
  recovery work without changing accepted damaged xref-stream PDFs.~~
- [x] ~~Glyph-name extraction now skips the intermediate glyph-record array,
  reducing allocation on metadata/debug text extraction paths while preserving
  existing glyph-name semantics.~~
- [x] ~~Incremental writer changed-object collection now deduplicates object
  numbers with a hash set before sparse xref sorting, improving large repeated
  update event logs without changing writer output.~~
- [x] ~~Xref-stream byte generation now uses sorted single-pass xref scans for
  full and sparse writer paths, improving large object-table writes without
  changing output bytes.~~
- [x] ~~Classic sparse incremental xref rows now use a carried sorted xref cursor
  across subsections, improving changed-object update writes without changing
  output bytes.~~
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
- [x] ~~Expose direct CCITT Group 3 and Group 4 byte encoder parity from
  `.repos/pdfcodec.mli`.~~
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
- [x] ~~Add real-world CCITT image corpus coverage through the download-only
  py-pdf ImageMagick CCITTFaxDecode fixture.~~
- [x] ~~Add a multi-revision malformed xref-stream/object-stream recovery gate.~~
- [x] ~~Add a real-file malformed compressed-xref incremental update recovery
  gate.~~
- [x] ~~Add an unknown-entry-type xref-stream recovery gate.~~
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
- [x] ~~Tune generated CID-range predefined-CMap reverse lookup for
  Adobe-GB1, Adobe-CNS1, and Adobe-Japan1 without changing public text
  behavior.~~
- [x] ~~Tune CNS-EUC predefined-CMap forward CID-range lookup with unsigned
  binary search while preserving packed-byte ordering.~~
- [x] ~~Add native Big5 predefined-CMap acceptance coverage through compressed
  write/read/reread boundaries.~~
- [x] ~~Add native HKSCS predefined-CMap acceptance coverage through compressed
  write/read/reread boundaries.~~
- [x] ~~Add native CNS-EUC-H/V predefined-CMap acceptance coverage through
  compressed write/read/reread boundaries.~~
- [x] ~~Add native Adobe-Korea1 predefined-CMap acceptance coverage for
  KSCms-UHC-H, KSC-EUC-H, and KSCpc-EUC-H through compressed write/read/reread
  boundaries.~~
- [x] ~~Add native Adobe-GB1 predefined-CMap acceptance coverage for GB-EUC-H,
  GBpc-EUC-H, and GBK-EUC-H through compressed write/read/reread boundaries.~~
- [x] ~~Add native Adobe-CNS1 Big5 variant predefined-CMap acceptance coverage
  for B5pc-H, ETenms-B5-H, HKdla-B5-H, HKdlb-B5-H, HKgccs-B5-H, HKm314-B5-H,
  and HKm471-B5-H through compressed write/read/reread boundaries.~~
- [x] ~~Add native Adobe-Japan1 predefined-CMap acceptance coverage for
  90ms-RKSJ-H, 90pv-RKSJ-H, JIS H, EUC-H, and Hojo-EUC-H through compressed
  write/read/reread boundaries.~~
- [x] ~~Tune object-stream expansion by grouping xref-stream type-2 entries
  before strict, reconstructed, and password-aware embedded-object loading.~~
- [x] ~~Tune incremental writer changed-object collection with a hash-backed
  seen set while preserving sorted sparse xref output.~~
- [x] ~~Tune full and sparse xref-stream data generation with sorted single-pass
  xref scans while preserving exact xref-entry bytes.~~
- [x] ~~Tune classic sparse incremental xref subsection output with a carried
  sorted xref cursor while preserving exact xref-row bytes.~~
- [x] ~~Tune recursive stream `/UseCMap` parsing with a hash-backed seen set
  while preserving multi-hop ToUnicode inheritance and cycle fallback.~~
- [x] ~~Tune inherited external/ToUnicode CMap composition with hash-backed
  charcode sets while preserving current-over-inherited precedence.~~
- [x] ~~Tune external CMap codepoint extraction with per-text-run hash lookup
  maps, keeping duplicate first-match behavior and malformed UTF-16 fallback
  covered.~~
- [x] ~~Tune plain `/ToUnicode` codepoint extraction with a per-run hash lookup
  map, keeping duplicate first-match behavior and malformed UTF-16 fallback
  covered.~~
- [x] ~~Tune regular text codepoint extraction by skipping the intermediate
  glyph-record array when callers only request codepoints.~~
- [x] ~~Tune pure Flate Huffman symbol decoding with bounded lookup-table
  lookahead and cached bit masks while preserving prefix consumed-length
  behavior.~~
- [ ] Add the next remaining format parity slice: remaining rare predefined
  CMap families, real-world ToUnicode variation coverage, fixture-driven Type3
  resource/glyph-program behavior, or real-world image corpus coverage.
- [ ] Revisit non-native backend validation after native parity is stable.
