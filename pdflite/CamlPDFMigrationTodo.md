# CamlPDF Migration Todo

This is the progress tracker for the pdflite CamlPDF migration. Update this
file whenever a substantial migration slice lands. Keep `OCaml2MoonBit.md`
library-agnostic; project architecture details belong in
`CamlPDFArchitecturePlan.md` and `CamlPDFMigrationPlan.md`.

Current estimate:

- Native main-feature parity: 99.7%.
- Full CamlPDF parity across deferred filters, malformed recovery, and backend
  breadth: 85-90%.
- Warning 74 public documentation cleanup: complete; 0 native diagnostics
  remain. Covered the byte, object, document, reader, lexeme, lookup/tree,
  colour-space, transform, destination, merge-helper, standard-font, Flate, and
  text/font extraction, cryptography and primitive crypto, page-tree, writer,
  native async file I/O, codec, page-label, function, optional-content, and
  content-stream, annotation, native secure-random, bookmark, image, structure,
  renumbering, standard font-pack embedding, text-to-PDF instruction
  conversion, basic and tagged text-to-PDF document assembly, PDF/UA
  text-to-PDF subformat shaping, blank PDF/UA creation helpers, JPEG/JPEG2000,
  PNG, and JBIG2 image-to-PDF document assembly, Form XObject stamping,
  composition reporting, core metadata APIs, XMP metadata-date rewriting, XMP
  info synchronization, XMP metadata creation, XMP RDF list extraction,
  XMP/document info JSON reporting, redaction annotation bounding-box overlays,
  imposition transform/content/page-assembly/pattern-matrix kernels, cpdf page
  hard-box/removal/shift/scale/scale-to-fit/upright/set-mediabox/copy-box
  helpers, imposition make-space orchestration, border stamping, layout
  planning, and first public impose/twoup pipelines, and Markdown helper public
  APIs.

Current backend snapshot:

- Native: full suite passing; the latest coverage pass leaves no uncovered
  lines in `pdf_squeeze.mbt`, including stream compression, duplicate pruning,
  page content stream normalization, and Form XObject normalization, with
  historical defensive and edge-path coverage gaps still present in older files.
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

- [x] ~~Port the first `cpdfclip` polygon model slice:
  `PdfClipOperation`, `PdfClipVertex`, `PdfClipContour`, and `PdfClipPolygon`
  now cover cpdf/GPC operation codes, null polygons, box polygons, hole flags,
  checked construction from parallel arrays, copy-on-construction behavior, and
  JSON literal shape. The native GPC boolean operation remains a separate
  vendored-C binding slice because `.repos/` is ignored and cannot be used as a
  committed build dependency. `moon test --target native pdf_clip_test.mbt`
  reports 5/5 tests passing.~~
- [x] ~~Port the native `cpdfclip` GPC boolean-operation bridge:
  `pdf_clip_polygon_clip` and `PdfClipOperation::clip_polygons` now encode the
  MoonBit polygon model into a native byte payload, call the vendored
  Alan Murta GPC sources, and decode result contours back into `PdfClipPolygon`.
  Native coverage gates all four GPC operations across overlapping and
  disjoint-box cases. `moon test --target native pdf_clip_native_test.mbt`
  reports 5/5 tests passing.~~
- [x] ~~Port cpdf scale-to-fit and legacy `twoup`:
  `PdfDocument::scale_to_fit_pages` now preserves aspect ratio against
  page-indexed target sizes, rewrites known boxes to the target sheet,
  transforms content streams, annotations, pattern matrices, and destinations,
  and validates size-list and zero-sized-page corner cases. `PdfDocument::twoup`
  now composes cpdf's legacy scale, 2x1 centered impose, `-90` rotate/upright,
  and final diagonal scale-to-fit pipeline. Coverage pins centered fit
  transforms, box rewriting, wrapper behavior, validation failures, and final
  two-up sheet geometry. `moon test --target native pdf_page_scale_test.mbt`
  reports 7/7 tests passing, and `moon test --target native
  pdf_impose_wbtest.mbt` reports 26/26 tests passing.~~
- [x] ~~Port cpdf-style page scaling needed by legacy `twoup`:
  `PdfDocument::scale_pages` now applies per-page x/y scale factors from the
  origin, transforms known page boxes, content streams, annotations, pattern
  matrices, and destination coordinates, and validates scale-list lengths plus
  selected page ranges. Coverage pins box/content/destination scaling, wrapper
  behavior, mismatch rejection, and invalid-page rejection. `moon test --target
  native pdf_page_scale_test.mbt` reports 5/5 tests passing.~~
- [x] ~~Port legacy `cpdfimpose.twoup_stack` and page rotation helpers:
  `PdfDocument::rotate_pages`/`rotate_pages_by` now set absolute or relative
  `/Rotate` values for selected pages with page-range and right-angle
  validation, and `PdfDocument::twoup_stack` composes the cpdf pipeline of
  2x1 non-fit imposition, `-90` rotation, and upright rectification. Coverage
  pins absolute/relative rotation wrappers, invalid rotations/pages, twoup-stack
  output geometry, content transforms, and wrapper behavior. `moon test --target
  native pdf_page_rotate_test.mbt` reports 3/3 tests passing, and `moon test
  --target native pdf_impose_wbtest.mbt` reports 25/25 tests passing.~~
- [x] ~~Port structure-tree artifact marking for imposition:
  `PdfDocument::mark_all_as_artifact` now wraps every page content stream and
  referenced Form XObject stream in `/Artifact BMC ... EMC`; `pdf_impose` and
  `PdfDocument::impose` now honor `process_struct_tree=true` by applying that
  pass before crop removal, upright conversion, borders, spacing, and sheet
  assembly. Coverage pins the public artifact wrapper, Form XObject rewriting,
  and the imposition flag path. `moon test --target native
  pdf_page_artifact_test.mbt` reports 2/2 tests passing, and `moon test
  --target native pdf_impose_wbtest.mbt` reports 24/24 tests passing.~~
- [x] ~~Wire the first public `cpdfimpose.impose` pipeline:
  `PdfDocument::impose` now preprocesses pages with CropBox-to-MediaBox copy,
  crop removal, upright conversion, optional border stamping, and spacing; plans
  fit or non-fit layouts; renumbers each imposed page set; assembles sheets with
  the existing page core; updates page-reference changes; and applies cpdf's
  final non-fit margin shift. Coverage pins simple 2-up assembly including
  hard-box content, wrapper/margin behavior, fit-mode extra spacing,
  page-reference retargeting, and empty-document rejection.
  Legacy `twoup` remains a separate follow-up slice. `moon test --target
  native pdf_impose_wbtest.mbt` reports 23/23 tests passing.~~
- [x] ~~Port the layout-planning branch of `cpdfimpose.impose`: private
  `pdf_impose_layout` now calculates fit-mode sheets, horizontal/vertical
  fit spacing, non-fit zero-dimension stack layouts, margin-expanded output
  media boxes, and cpdf-compatible error cases before the full imposition
  pipeline is wired. White-box coverage pins fit layout spacing, too-small fit
  rejection, horizontal/vertical non-fit stacks, rectangular grids, and
  zero-dimension rejection. `moon test --target native pdf_impose_wbtest.mbt`
  reports 18/18 tests passing.~~
- [x] ~~Port the `Cpdfpage.upright` helper used by full imposition:
  `upright_pages` now removes selected page `/Rotate` values by transforming
  content, annotations, known page boxes, and destination matrices into an
  upright coordinate system, then rectifies non-zero `/MediaBox` origins back
  to `(0, 0)`. Coverage pins rotated page content/box/annotation transforms,
  non-zero-origin rectification, wrapper behavior, open-action destination
  updates, and invalid page rejection. `moon test --target native
  pdf_page_upright_test.mbt` reports 3/3 tests passing.~~
- [x] ~~Port the `Cpdfpage.copy_box` helper used by full imposition:
  `copy_page_box` now copies selected page-box values, updates the `PdfPage`
  `/MediaBox` field directly when the target is `/MediaBox`, copies `/MediaBox`
  into non-media targets, preserves cpdf's missing-source no-op behavior, and
  supports the `mediabox_if_missing` fallback. Coverage pins selected-page
  CropBox-to-MediaBox copies, MediaBox-to-rest copies through the wrapper,
  missing-source fallback/no-op behavior, and invalid page rejection. `moon
  test --target native pdf_page_box_test.mbt` reports 7/7 tests passing.~~
- [x] ~~Port the `cpdfimpose.add_border` helper: private
  `pdf_impose_add_border` now appends a cpdf-style black stroked rectangle just
  inside the first page's `/MediaBox`, wraps it in artifact and `/CPDFSTAMP`
  marked content, uses the existing safe append path in normal and fast modes,
  and treats zero line width as no border. White-box coverage pins both-page
  border stamping, protected normal append shape, and zero-width no-op behavior.
  `moon test --target native pdf_impose_wbtest.mbt` reports 16/16 tests
  passing.~~
- [x] ~~Port the `cpdfimpose.make_space` orchestration helper: private
  `pdf_impose_make_space` now hard-boxes pages to `/MediaBox`, preserves cpdf's
  zero-spacing hard-box behavior, expands non-fit output media boxes after
  shifting content by half-spacing, and fit-scales content from bottom-left
  before shifting it into the retained page size. White-box coverage pins the
  zero-spacing, non-fit, and fit operator/MediaBox shapes. `moon test --target
  native pdf_impose_wbtest.mbt` reports 14/14 tests passing.~~
- [x] ~~Port the `Cpdfpage.scale_contents` dependency used by imposition:
  `scale_contents` now uses `/CropBox` when present, otherwise `/MediaBox`, to
  calculate the cpdf-style transform origin and position offset, prepends the
  scale matrix in normal and fast modes, rewrites pattern matrices, transforms
  annotations, and passes matrices through `change_pages` so destinations/open
  actions move with scaled pages. Coverage pins crop-box positioning,
  annotation geometry, pattern matrix cloning, open-action destination updates,
  wrapper behavior, and invalid page rejection. `moon test --target native
  pdf_page_scale_test.mbt` reports 3/3 tests passing.~~
- [x] ~~Port the `Cpdfpage.set_mediabox` dependency used by imposition:
  `set_mediaboxes` now rewrites selected page `/MediaBox` entries from
  page-indexed `(x, y, width, height)` tuples, preserving cpdf's behavior that
  each selected page uses the rectangle for its absolute page number. Coverage
  pins selected-page behavior, wrapper behavior, full-document box-count
  validation, and invalid page rejection. `moon test --target native
  pdf_page_box_test.mbt` reports 5/5 tests passing.~~
- [x] ~~Port the `Cpdfpage.shift_pdf` dependency used by imposition: `shift_pages`
  now prepends translation matrices in normal and fast modes, rewrites pattern
  matrices before wrapping, transforms direct and indirect annotations, and
  passes page matrices through `change_pages` so destinations/open actions move
  with shifted pages. Coverage pins content operators, annotation coordinates,
  pattern matrix cloning, open-action destination updates, wrapper behavior, and
  invalid page/offset validation. `moon test --target native
  pdf_page_shift_test.mbt` reports 3/3 tests passing.~~
- [x] ~~Port the small page-box dependency slice used by imposition and
  `cpdfpage`: `hard_box` now prepends a clipping rectangle for `/MediaBox` or
  another selected page box with cpdf's missing-box fallback behavior, and the
  crop/trim/art/bleed removal helpers remove only the requested box from
  selected pages while preserving page references. Coverage pins normal and
  fast hard-box content, missing-box rejection/fallback, selected-page behavior,
  and crop/trim removal wrappers. `moon test --target native
  pdf_page_box_test.mbt` reports 3/3 tests passing.~~
- [x] ~~Port the pattern-matrix rewrite from `cpdfpage.change_pattern_matrices_page`
  used by `cpdfimpose`: private imposition helpers now detect `/Pattern`
  resources used by `scn`/`SCN` with no numeric operands, clone those pattern
  dictionaries with `transform_matrix_compose(transform, old /Matrix)`, preserve
  patterns used in other ways, and descend into indirect Form XObjects once per
  rewrite pass. `pdf_impose_pages_core` now runs this rewrite before combining
  resources. White-box coverage pins direct page resources, page-assembly
  integration, and nested Form XObject resources. `moon test --target native
  pdf_impose_wbtest.mbt` reports 11/11 tests passing.~~
- [x] ~~Port the safe page-assembly core from `cpdfimpose.impose_pages`:
  private `pdf_impose_pages_core` now assembles one imposed page from an
  already-renumbered page set, preserves the first page rotation, combines page
  resources and rest dictionaries, transforms direct and indirect annotation
  geometry, and concatenates transformed content streams through the existing
  fast/parsed content wrapper. The source pattern-matrix rewrite remains a
  separate deferred slice. `moon test --target native pdf_impose_wbtest.mbt`
  reports 8/8 tests passing.~~
- [x] ~~Port the content-wrapping kernel from `cpdfimpose.impose_pages`:
  private `pdf_impose_transform_content` now preserves CamlPDF's fast path
  shape (`q cm`, original streams, `Q`) and normal parsed path shape using
  `pdf_page_protect` before wrapping content in one transformed stream.
  White-box coverage pins both fast stream preservation and normal-mode
  protection for unbalanced graphics-state saves. `moon test --target native
  pdf_impose_wbtest.mbt` reports 6/6 tests passing.~~
- [x] ~~Port the pure transformation kernel from `cpdfimpose`: private
  `pdf_impose_transforms` now preserves row-major and column-major placement,
  right-to-left/bottom-to-top ordering, short-final-row centering, fit extra
  spacing, and fitted margin scaling/rejection ahead of the full page
  imposition pipeline. White-box coverage pins row and column ordering,
  right-to-left/bottom-to-top ordering, centered final rows, fit spacing/
  margins, and invalid grid/margin errors. `moon test --target native
  pdf_impose_wbtest.mbt` reports 5/5 tests
  passing.~~
- [x] ~~Port the implemented annotation-overlay part of `cpdfredact`:
  `show_annotation_bounding_boxes` now draws cpdf-style yellow/light-yellow
  annotation rectangles through the existing page-content rewrite path, handles
  direct and indirect annotations, selected pages, and the fast append mode, and
  includes a compatibility wrapper. Coverage pins exact generated content
  operators for normal and light/fast overlays. `moon test --target native
  pdf_redact_test.mbt` reports 2/2 tests passing.~~
- [x] ~~Port the JSON side of `cpdfmetadata.output_info` for in-memory
  documents: `info_json` now reports cpdf-style version/page counts, legacy
  `/Info` fields with UTF-8/raw/stripped encoding, trapped state, catalog page
  mode/layout, OpenAction JSON, viewer preferences, AcroForm/XFA/MarkInfo, and
  MediaBox/CropBox/BleedBox/TrimBox/ArtBox summaries with unit conversion and
  `"various"` detection. Coverage uses MoonBit JSON literals for the expected
  report, pins missing/malformed/varying page-box behavior, validates stripped
  metadata output, and checks the UTF-8 blob wrapper. `moon test --target
  native pdf_metadata_test.mbt` now reports 19/19 tests passing; full native
  validation reports 1627/1627 tests passing.~~
- [x] ~~Port the JSON side of `cpdfmetadata.output_xmp_info` for in-memory
  documents: `xmp_info_json` now reports subformats, language, and present XMP
  fields using cpdf's labels, including PDF/UA amendment/correction fields and
  RDF-list-backed DC values. A UTF-8 JSON blob wrapper is included for command
  surfaces. Coverage uses MoonBit JSON literals for the expected object and
  verifies no-metadata defaults plus wrapper serialization. `moon test --target
  native pdf_metadata_test.mbt` now reports 18/18 tests passing.~~
- [x] ~~Port cpdf's RDF list extraction behavior for simple XMP lookup:
  namespace-aware metadata scanning now recognizes nested `rdf:Alt`,
  `rdf:Seq`, and `rdf:Bag`-style `rdf:li` values and combines list items with
  cpdf's comma separator instead of returning raw nested XML. Coverage pins a
  `dc:title` fallback with two localized `rdf:li` values through
  `PdfDocument::xmp_info`. `moon test --target native pdf_metadata_test.mbt`
  remains 17/17 passing.~~
- [x] ~~Port `cpdfmetadata.create_metadata` for in-memory documents: metadata
  creation now fills the cpdf XMP template from `/Info`, converts creation and
  modification dates to XMP syntax, uses reproducible `"now"` for missing dates
  and metadata date, preserves the cpdf raw replacement model, and installs the
  generated metadata stream through the existing catalog setter. Coverage pins
  PDFDoc UTF-8 title replacement, creator replacement, missing-date fallback,
  explicit date offsets, default trapped state, and the wrapper function. `moon
  test --target native pdf_metadata_test.mbt` now reports 17/17 tests
  passing.~~
- [x] ~~Port `cpdfmetadata.set_pdf_info` XMP synchronization for existing
  metadata streams: `set_info_entry`/`pdf_set_pdf_info` now support explicit
  `xmp_also` and `xmp_just_set` modes, update Adobe/XMP/DC fields for legacy
  `/Info` keys, convert creation dates into XMP date syntax, preserve
  metadata-only updates without touching `/Info`, and reject non-string XMP
  values. Coverage includes UTF-8 PDFDoc strings, XML escaping, wrapper label
  order, booleans, date offsets, and bad value errors. `moon test --target
  native pdf_metadata_test.mbt` now reports 16/16 tests passing.~~
- [x] ~~Port `cpdfmetadata.set_metadata_date` for existing XMP streams:
  namespace-aware XML element rewriting now updates `xmp:MetadataDate` across
  declared prefixes, including self-closing tags with attributes, keeps PDF
  version bumps suppressed for metadata-only rewrites, preserves no-metadata
  behavior, and expands reproducible `"now"` through the existing cpdf
  strftime path. `moon test --target native pdf_metadata_test.mbt` now reports
  15/15 tests passing.~~
- [x] ~~Port `cpdfmetadata.get_xmp_info` for legacy `/Info` key equivalents:
  XMP lookup now maps title, author, subject, keywords, creator, producer,
  creation date, and modification date through the Adobe/XMP/DC namespaces and
  returns the first non-empty match. Coverage includes missing metadata,
  fallback creator/mod-date fields, producer lookup, and unknown-key behavior.
  `moon test --target native pdf_metadata_test.mbt` now reports 13/13 tests
  passing.~~
- [x] ~~Port `cpdfmetadata.determine_subformats` for in-memory documents:
  namespace-aware XMP scanning now detects PDF/E, PDF/UA, PDF/A part plus
  conformance, PDF/X, and PDF/VT markers in cpdf output order, including
  attribute and element forms, and preserves the `/Info /GTS_PDFXVersion`
  fallback when XMP lacks a PDF/X marker. `moon test --target native
  pdf_metadata_test.mbt` now reports 12/12 tests passing.~~
- [x] ~~Extend the `cpdfmetadata` reporting surface with cpdf-style catalog and
  viewer-preference wrappers, MarkInfo/XFA query helpers, OpenAction reporting
  that rewrites page indirect references back to one-based page numbers,
  JSON/PDF-syntax OpenAction output, PDF minor-version mutation, and language
  wrappers. Coverage uses MoonBit JSON literals for the OpenAction row shape
  and verifies wrapper argument order plus catalog-only report fields. `moon
  test --target native pdf_metadata_test.mbt` now reports 10/10 tests passing.~~
- [x] ~~Port the bounded core of `cpdfmetadata`: PDFDoc output encoding,
  trailer `/ID` copy with keep-version handling, `/Info` UTF-8 reporting,
  viewer preferences, catalog page layout/mode/open action controls,
  language getters/setters, and catalog metadata stream set/get/remove/remove-
  all. Coverage includes missing metadata removal, filtered metadata stream
  decoding, invalid layout/page arguments, original-document preservation, and
  compatibility wrapper argument order. XML/XMP synchronization and file
  extraction remain deferred to a later metadata slice. `moon test --target
  native` now reports 1616/1616 tests passing.~~
- [x] ~~Port `cpdfcomposition` as a native structured reporting API with
  cpdf-compatible buckets for images, fonts, content streams, structure info,
  attached files, xref tables, piece info, and unclassified bytes. Added JSON
  row output with MoonBit JSON literal coverage, object-stream xref accounting,
  and non-positive file-size rejection. `moon test --target native` now reports
  1608/1608 tests passing.~~
- [x] ~~Port `cpdfxobject.stamp_as_xobject` with overlay first-page Form XObject
  creation, resource prefixing, selected-page `/XObject` insertion, base
  bookmark retargeting after page-tree rebuild, trailer `/ID` preservation, and
  empty-overlay rejection coverage. `moon test --target native` now reports
  1604/1604 tests passing.~~
- [x] ~~Port the standalone `cpdfimage.obj_of_jbig2_data` branch with cpdf's
  byte-offset dimension extraction, `/JBIG2Decode` image dictionaries,
  optional `/JBIG2Globals` decode parameters, fixed object `10000` globals
  streams, JBIG2 single-page document assembly, and short-data error coverage.
  `moon test --target native` now reports 1601/1601 tests passing.~~
- [x] ~~Port the PNG branch of `cpdfimage.image_of_input` and `Cpdfpng.read_png`
  with IHDR parsing, split-IDAT concatenation, palette/interlace rejection,
  RGB Flate image dictionaries, alpha-channel `/SMask` splitting, 16-bit alpha
  rejection, and PNG single-page document assembly that preserves mask objects.
  `moon test --target native` now reports 1597/1597 tests passing.~~
- [x] ~~Port the first `cpdfimage.image_of_input` document assembly slice with
  JPEG and JPEG2000 image XObject builders, natural-size single-page image
  documents, optional figure structure trees, PDF/UA-2 `/Document` namespace
  wrapping, and PDF/UA title enforcement. `moon test --target native` now
  reports 1591/1591 tests passing.~~
- [x] ~~Port the `Cpdfua.create_pdfua1`/`create_pdfua2` blank-document
  creation slice with shared PDF/UA catalog metadata, PDF/UA-1 and PDF/UA-2
  XMP marker streams, XML-escaped metadata titles, and reuse from
  `pdf_texttopdf_typeset`. `moon test --target native` now reports 1586/1586
  tests passing.~~
- [x] ~~Complete the PDF/UA `cpdftexttopdf.typeset` subformat slice by adding
  `PDF/UA-1` and `PDF/UA-2` parsing, title enforcement, forced structure-tree
  processing, PDF/UA-1 catalog metadata, and PDF/UA-2 top-level `/Document`
  namespace wrapping. `moon test --target native` now reports 1584/1584 tests
  passing.~~
- [x] ~~Complete the tagged `cpdftexttopdf` standard-font document path by
  adding optional structure-tree processing to `pdf_texttopdf_typeset`,
  paragraph tagging, `/StructParents` page metadata, `/StructTreeRoot`
  structure elements, `/MCR` kids with page/MCID links, and number-tree
  `/ParentTree` entries. `moon test --target native` now reports 1580/1580
  tests passing.~~
- [x] ~~Port the basic non-PDF/UA `cpdftexttopdf.typeset` document assembly
  path for existing font packs: add the first-font/`BeginDocument` prelude,
  use CamlPDF's paper-width-derived margin, typeset pages, add a page tree and
  catalog root, and cover both text and empty-input documents. `moon test
  --target native` now reports 1579/1579 tests passing.~~
- [x] ~~Port the first `cpdftexttopdf` instruction-conversion slice with
  byte-based UTF-8 decoding, newline and carriage-return behavior, missing
  glyph skipping, font-run switching through `PdfFontPack`, invalid charcode
  rejection, and paragraph tagging around blank lines. `moon test --target
  native` now reports 1577/1577 tests passing.~~
- [x] ~~Port the first `cpdfembed` slice with cpdf-style standard-font
  `PdfFontPack` construction, Unicode codepoint lookup, duplicate mapping
  behavior, invalid font-index safety, and run collation by font index. `moon
  test --target native` now reports 1572/1572 tests passing.~~
- [x] ~~Continue the cpdftype port with byte-preserving element streams,
  CamlPDF-compatible split/layout/pagination helpers, and a first native
  `typeset` layer that emits page content streams, font resources, link
  annotations, marked-content tags, and per-page tag metadata. `moon test
  --target native` now reports 1569/1569 tests passing.~~
- [x] ~~Pre-refactor native hardening restored complete source coverage with
  focused white-box gates for Markdown table/layout edge cases, private
  simple-font text-width and malformed ToUnicode fallbacks, object-stream member
  parsing/repair, and reconstructed-reader edge paths. `moon test --target
  native` now reports 1252/1252 tests passing, and `moon coverage analyze`
  reports all source files fully covered.~~
- [x] ~~Continue native pre-refactor hardening by completing inherited
  `/CropBox` materialization in `pages_of_pagetree` and adding a compressed
  native `change_pages` gate for inherited page attributes, indirect GoTo
  actions, preserved URI actions, indirect old-style `/Dests`, indirect
  name-tree destinations, and bookmark resolution. `moon test --target native`
  now reports 1253/1253 tests passing, and `moon coverage analyze` reports all
  source files fully covered.~~
- [x] ~~Continue native pre-refactor hardening with encrypted incremental
  malformed-reader coverage: corrupt the final `startxref`, recover through the
  password-aware reconstruction path, prove the newest encrypted revision wins,
  saved-state AESV2 recrypt, compressed xref-stream write, and password reread.
  `moon test --target native` now reports 1254/1254 tests passing, and
  `moon coverage analyze` reports all source files fully covered.~~
- [x] ~~Continue native pre-refactor hardening with writer-generated compressed
  encrypted xref-stream recovery: corrupt the final `startxref` after public
  AESV2 compressed encrypted output, recover through password-aware
  reconstruction, saved-state recrypt, compressed write, and password reread.
  `moon test --target native` now reports 1255/1255 tests passing, and
  `moon coverage analyze` reports all source files fully covered.~~
- [x] ~~Continue native pre-refactor hardening with broader exact native miniz
  byte-output coverage: the native-only Flate parity gate now pins a 64-byte
  mixed stored-block payload at levels 1, 6, and 9 in addition to tiny stored
  streams and repeated compressed streams. `moon test --target native` remains
  1255/1255 passing, and `moon coverage analyze` reports all source files fully
  covered.~~
- [x] ~~Continue native pre-refactor hardening across the native async file
  boundary: encrypted incremental updates now corrupt the final `startxref`
  after compressed xref-stream file output, recover through password-aware file
  reads, preserve the newest encrypted revision, saved-state AESV2 recrypt, and
  compressed file reread. `moon test --target native` now reports 1256/1256
  tests passing.~~
- [x] ~~Continue native pre-refactor hardening for native async encrypted writer
  output: compressed AESV2 file output now corrupts the final `startxref`,
  recovers through password-aware file reads, preserves encrypted direct
  objects, saved-state AESV2 recrypts, and compressed-rereads from disk. `moon
  test --target native` now reports 1257/1257 tests passing.~~
- [x] ~~Continue native pre-refactor hardening for AESV3 at the native async
  file boundary: compressed AESV3 file output now corrupts the final
  `startxref`, recovers through password-aware file reads, preserves encrypted
  direct objects, saved-state AESV3 recrypts, and compressed-rereads from disk.
  `moon test --target native` now reports 1258/1258 tests passing.~~
- [x] ~~Continue native pre-refactor hardening for AESV3 ISO at the native async
  file boundary: compressed AESV3 ISO file output now corrupts the final
  `startxref`, recovers through password-aware file reads, preserves encrypted
  direct objects, saved-state AESV3 ISO recrypts, compressed-rereads from disk,
  and verifies the repaired output remains ISO AES-256. `moon test --target
  native` now reports 1259/1259 tests passing.~~
- [x] ~~Continue native pre-refactor hardening for ARC4/R4 at the native async
  file boundary: compressed ARC4 file output now corrupts the final
  `startxref`, recovers through password-aware file reads, preserves encrypted
  direct objects, saved-state ARC4 recrypts, compressed-rereads from disk, and
  verifies the repaired output remains 128-bit ARC4. `moon test --target native`
  now reports 1260/1260 tests passing.~~
- [x] ~~Continue native pre-refactor hardening for legacy ARC4 at the native
  async file boundary: compressed 40-bit and 128-bit non-R4 ARC4 file output now
  corrupts the final `startxref`, recovers through password-aware file reads,
  preserves encrypted direct objects, saved-state ARC4 recrypts, compressed-
  rereads from disk, and verifies the repaired outputs remain 40-bit and
  128-bit ARC4 respectively. `moon test --target native` now reports 1261/1261
  tests passing.~~
- [x] ~~Continue native pre-refactor hardening for encrypted object streams at
  the native async file boundary: file reads now gate AESV2 encrypted `/ObjStm`
  expansion for explicit owner passwords, bad-final-`startxref`
  password-aware reconstruction, and implicit blank-user password fallback.
  `moon test --target native` now reports 1262/1262 tests passing.~~
- [x] ~~Continue native pre-refactor hardening for encrypted object-stream
  recrypt at the native async file boundary: file reads now decrypt AESV2
  `/ObjStm` payloads, recrypt already-materialized non-stream objects, write a
  compressed xref stream back to disk, verify plaintext does not leak, and
  reread with the user password. `moon test --target native` now reports
  1263/1263 tests passing.~~
- [x] ~~Continue native pre-refactor hardening for malformed encrypted
  xref-stream metadata: a valid `startxref` now has acceptance coverage where a
  malformed `/Index` makes strict xref-stream parsing fail, password-aware
  reconstruction decrypts the physically scanned objects, saved-state AESV2
  recrypt writes a compressed xref stream, and the user password rereads the
  output. `moon test --target native` now reports 1264/1264 tests passing.~~
- [x] ~~Continue native pre-refactor hardening for malformed encrypted
  xref-stream metadata at the native async file boundary: compressed AESV2 file
  output now keeps the `startxref` valid, corrupts `/Index`, confirms strict
  xref-stream parsing fails, recovers through password-aware file reads,
  saved-state AESV2 recrypts, verifies plaintext does not leak, and rereads the
  repaired file with the user password. `moon test --target native` now
  reports 1265/1265 tests passing.~~
- [x] ~~Continue native pre-refactor hardening for malformed encrypted classic
  xref markers at the native async file boundary: classic AESV2 file output now
  keeps the `startxref` valid, corrupts the first in-use xref-row marker,
  confirms strict table parsing fails, recovers through password-aware file
  reads, saved-state AESV2 recrypts, verifies plaintext does not leak, and
  rereads the repaired compressed-xref file with the user password. `moon test
  --target native` now reports 1266/1266 tests passing.~~
- [x] ~~Continue native pre-refactor hardening for malformed encrypted classic
  xref offsets at the native async file boundary: classic AESV2 file output now
  keeps the `startxref` valid, corrupts the first in-use xref-row offset,
  confirms strict table parsing fails, recovers through password-aware file
  reads, saved-state AESV2 recrypts, verifies plaintext does not leak, and
  rereads the repaired compressed-xref file with the user password. `moon test
  --target native` now reports 1267/1267 tests passing.~~
- [x] ~~Continue native pre-refactor hardening for malformed encrypted
  xref-stream widths: compressed AESV2 output now keeps the `startxref` valid,
  injects a malformed `/W [1 4]` before the real xref-stream widths, confirms
  strict parsing fails, recovers through password-aware reads, saved-state
  AESV2 recrypts, verifies plaintext does not leak, and covers the same path at
  the native async file boundary. `moon test --target native` now reports
  1269/1269 tests passing.~~
- [x] ~~Continue native pre-refactor hardening for malformed encrypted
  xref-stream size metadata: compressed AESV2 output now keeps the `startxref`
  valid, injects a malformed `/Size /Bad` before the real xref-stream size,
  confirms strict default-range parsing fails, recovers through password-aware
  reads, saved-state AESV2 recrypts, verifies plaintext does not leak, and
  covers the same path at the native async file boundary. `moon test --target
  native` now reports 1271/1271 tests passing.~~
- [x] ~~Continue native pre-refactor hardening for malformed xref-stream filter
  metadata: strict reads now route xref-stream-only `FilterNotSupported`
  failures through reconstruction, compressed AESV2 output keeps the
  `startxref` valid while injecting `/Filter /BadXRefFilter`, password-aware
  recovery decrypts physically scanned objects, saved-state AESV2 recrypts,
  plaintext does not leak, the same path is covered at the native async file
  boundary, and unsupported object-stream filters still raise normally. `moon
  test --target native` now reports 1275/1275 tests passing.~~
- [x] ~~Continue native pre-refactor hardening for malformed xref-stream
  decode parameters: strict reads now route xref-stream-only
  `PredictorExpected`/`PredictorNotSupported` failures through reconstruction,
  compressed AESV2 output keeps the `startxref` valid while injecting
  `/DecodeParms /Bad`, password-aware recovery decrypts physically scanned
  objects, saved-state AESV2 recrypts, plaintext does not leak, the same path
  is covered at the native async file boundary, and malformed object-stream
  decode parameters still raise normally. `moon test --target native` now
  reports 1282/1282 tests passing.~~
- [x] ~~Continue native pre-refactor hardening for malformed object-stream
  bounds: valid-`startxref` reads now route `StreamDataExpected` through
  reconstruction, recover a physical page tree when the xref stream points the
  root at an object stream with an out-of-range `/First`, preserve the existing
  unrecoverable object-stream error, cover the same path at the native async
  file boundary, and round-trip the repaired document through compressed xref
  output. `moon test --target native` now reports 1286/1286 tests passing.~~
- [x] ~~Add the first pre-refactor correctness sentinel: a valid `startxref`
  pointing at malformed classic xref subsection metadata now has a strict
  `NumberExpected` gate plus public reconstruction back to the physically
  scanned catalog.~~
- [x] ~~Add the second pre-refactor correctness sentinel: a valid xref stream
  whose trailer root points into an object stream with a mismatched embedded
  object number now keeps raising `XRefEntryExpected`, even when a physical
  catalog and fallback trailer are present.~~
- [x] ~~Add the third pre-refactor correctness sentinel: the Markdown command
  helper now converts the checked-in CamlPDF introduction fixture through the
  native file-output boundary, preserving key text markers and raw-control
  hygiene. The pre-refactor native correctness gate now reports `moon test
  --target native` at 1289/1289 tests passing.~~
- [x] ~~Add the fourth pre-refactor correctness sentinel: encrypted classic
  xref documents with a valid `startxref` and malformed subsection count now
  have a strict `NumberExpected` gate, password-aware reconstruction back to
  decrypted physical objects, and AESV2 re-encrypted compressed-xref round-trip
  coverage. `moon test --target native` now reports 1290/1290 tests passing.~~
- [x] ~~Add the fifth pre-refactor correctness sentinel: the native async file
  wrappers now cover the encrypted malformed classic xref subsection path end to
  end, including strict `NumberExpected`, owner-password reconstruction, no
  plaintext leak in repaired output, and user-password round-trip. `moon test
  --target native` now reports 1291/1291 tests passing.~~
- [x] ~~Add the sixth pre-refactor correctness sentinel: encrypted classic
  documents with a valid `startxref` and malformed first trailer now have a
  strict `TrailerExpected` gate plus password-aware reconstruction to the later
  physical trailer, decrypted objects, and AESV2 compressed-xref re-encryption.
  `moon test --target native` now reports 1292/1292 tests passing.~~
- [x] ~~Add the seventh pre-refactor correctness sentinel: PDF MD5 derivation
  no longer uses the external helper's 56-byte preimage crash path, and now
  covers both the raw length-56 digest vector and a revision-4 `/U` entry with a
  24-byte file ID.~~
- [x] ~~Add the eighth pre-refactor correctness sentinel: native async file
  wrappers now cover encrypted malformed classic trailers end to end, including
  strict `TrailerExpected`, owner-password reconstruction, no plaintext leak in
  repaired output, and user-password round-trip. `moon test --target native`
  now reports 1294/1294 tests passing.~~
- [x] ~~Add the ninth pre-refactor correctness sentinel: encrypted classic
  documents with a valid `startxref` and a first trailer missing `/Root` now
  have a strict `RootExpected` gate plus password-aware reconstruction to the
  later physical trailer, decrypted objects, and AESV2 compressed-xref
  re-encryption. `moon test --target native` now reports 1295/1295 tests
  passing.~~
- [x] ~~Add the tenth pre-refactor correctness sentinel: native async file
  wrappers now cover encrypted missing-root classic trailers end to end,
  including strict `RootExpected`, owner-password reconstruction, no plaintext
  leak in repaired output, and user-password round-trip. `moon test --target
  native` now reports 1296/1296 tests passing.~~
- [x] ~~Add the eleventh pre-refactor correctness sentinel: encrypted classic
  documents whose trailer `/Root` object is physically present but marked free
  in a valid xref table now reconstruct through the password-aware probe path.
  Recovery no longer treats a trailer root's free xref entry as covering the
  physical object, still preserves deleted non-root free entries, and validates
  bad-password fallback. `moon test --target native` now reports 1297/1297 tests
  passing.~~
- [x] ~~Add the twelfth pre-refactor correctness sentinel: native async file
  wrappers now cover encrypted trailer-root objects that are physically present
  but marked free in the classic xref table, including bad-password fallback,
  owner-password reconstruction, no plaintext leak in repaired output, and
  user-password round-trip. `moon test --target native` now reports 1298/1298
  tests passing.~~
- [x] ~~Add the thirteenth pre-refactor correctness sentinel: encrypted classic
  documents whose catalog is reachable but page-tree objects are physically
  present and omitted from a valid xref table now reconstruct through the
  password-aware page-tree probe path, preserve bad-password fallback,
  decrypted physical objects, and AESV2 compressed-xref re-encryption. `moon
  test --target native` now reports 1299/1299 tests passing.~~
- [x] ~~Add the fourteenth pre-refactor correctness sentinel: native async file
  wrappers now cover encrypted page-tree objects that are physically present
  but omitted from the classic xref table, including strict page-tree failure,
  bad-password fallback, owner-password reconstruction, no plaintext leak in
  repaired output, and user-password round-trip. `moon test --target native`
  now reports 1300/1300 tests passing.~~
- [x] ~~Add the fifteenth pre-refactor correctness sentinel: native async file
  wrappers now preserve the byte-reader's unrecoverable error path for encrypted
  xref-stream compressed entries whose referenced object stream is missing,
  including header validation and `XRefEntryExpected` propagation. `moon test
  --target native` now reports 1301/1301 tests passing.~~
- [x] ~~Add the sixteenth pre-refactor correctness sentinel: native async file
  wrappers now preserve the byte-reader's unrecoverable error path for
  mismatched object-stream roots, refusing to reconstruct from a later physical
  catalog when the valid xref-stream root entry points to the wrong embedded
  object number. `moon test --target native` now reports 1302/1302 tests
  passing.~~
- [x] ~~Add the seventeenth pre-refactor correctness sentinel: native async file
  wrappers now preserve the byte-reader's unrecoverable `StreamDataExpected`
  path for valid xref streams whose compressed object entry points into an
  object stream with an invalid `/First` data slice. `moon test --target
  native` now reports 1303/1303 tests passing.~~
- [x] ~~Add the eighteenth pre-refactor correctness sentinel: native async file
  wrappers now reconstruct bad-startxref xref-stream documents whose object
  stream `/N` and `/First` bounds are indirect objects, then rewrite and reread
  the recovered document through compressed xref output. `moon test --target
  native` now reports 1304/1304 tests passing.~~
- [x] ~~Add the nineteenth pre-refactor correctness sentinel: native async file
  wrappers now reconstruct bad-startxref xref-stream documents whose object
  stream `/Filter` is an indirect object, preserve the retained object-stream
  filter reference, and rewrite/reread the recovered compressed object. `moon
  test --target native` now reports 1305/1305 tests passing.~~
- [x] ~~Add the twentieth pre-refactor correctness sentinel: native async file
  wrappers now preserve `XRefExpected` rejection when `startxref` points at a
  non-stream object, a non-xref stream, an explicit non-xref `/Type`, or a
  non-name xref-stream `/Type`. `moon test --target native` now reports
  1306/1306 tests passing.~~
- [x] ~~Add the twenty-first pre-refactor correctness sentinel: native async
  file wrappers now reconstruct missing-`startxref` PDFs by scanning physical
  objects and selecting the sane trailer, then rewrite/reread the recovered
  document through compressed xref output. `moon test --target native` now
  reports 1307/1307 tests passing.~~
- [x] ~~Add the twenty-second pre-refactor correctness sentinel: native async
  file wrappers now preserve `pdf_revisions_from_file` malformed metadata
  failures for missing `startxref`, malformed `/Prev`, and cyclic `/Prev`
  chains. `moon test --target native` now reports 1308/1308 tests passing.~~
- [x] ~~Add the twenty-third pre-refactor correctness sentinel: native async
  file wrappers now preserve `XRefExpected` for full document reads with cyclic
  classic `/Prev` chains. `moon test --target native` now reports 1309/1309
  tests passing.~~
- [x] ~~Add the twenty-fourth pre-refactor correctness sentinel: native async
  file wrappers now gate hand-built classic `/Prev` revision reads, including
  newest/older revision selection, sanitized `/Prev`, object deletion by older
  revision view, and the password wrapper's empty-permission result. `moon test
  --target native` now reports 1310/1310 tests passing.~~
- [x] ~~Add the twenty-fifth pre-refactor correctness sentinel: native async
  file wrappers now preserve `BadRevision` for revision `0` and missing
  revisions beyond a hand-built classic `/Prev` chain, including the password
  wrapper path. `moon test --target native` now reports 1311/1311 tests
  passing.~~
- [x] ~~Add the twenty-sixth pre-refactor correctness sentinel: native async
  file wrappers now gate strict classic xref-row tolerance for blank xref lines,
  malformed zero-offset rows, marker suffixes, and repeated xref section
  markers without falling back to reconstruction. `moon test --target native`
  now reports 1312/1312 tests passing.~~
- [x] ~~Add the twenty-seventh pre-refactor correctness sentinel: native async
  file wrappers now gate strict classic xref layout tolerance for fixed-width
  separators, CR-only xref lines, tokenized unpadded rows, inline xref section
  headers, and glued trailer dictionaries without falling back to
  reconstruction. `moon test --target native` now reports 1313/1313 tests
  passing.~~
- [x] ~~Add the twenty-eighth pre-refactor correctness sentinel: native async
  file wrappers now gate classic `startxref` pointer tolerance for trailing
  junk after EOF, non-digit prefixes before the numeric pointer, and inline
  numeric pointers across both document reads and revision metadata reads.
  `moon test --target native` now reports 1314/1314 tests passing.~~
- [x] ~~Add the twenty-ninth pre-refactor correctness sentinel: native async
  file wrappers now gate malformed classic xref reconstruction for bad xref
  rows, bad subsection counts, malformed trailers, missing trailer roots, and
  bad object offsets, checking the strict parse failures before public
  reconstruction. `moon test --target native` now reports 1315/1315 tests
  passing.~~
- [x] ~~Add the thirtieth pre-refactor correctness sentinel: native async file
  wrappers now gate unreadable stream-length recovery for missing indirect
  length objects, non-integer length objects, stream length objects, negative
  direct lengths, and unparseable indirect lengths, preserving strict xref reads
  where possible and reconstructing only the unparseable case. `moon test
  --target native` now reports 1316/1316 tests passing.~~
- [x] ~~Add the thirty-first pre-refactor correctness sentinel: native async
  file wrappers now gate malformed stream-marker reconstruction for bad
  `stream` keywords, bad `endstream` markers, bad `endobj` markers, and
  truncated stream data, checking strict failures before public reconstruction
  drops the malformed stream and preserves the catalog. `moon test --target
  native` now reports 1317/1317 tests passing.~~
- [x] ~~Add the thirty-second pre-refactor correctness sentinel: native async
  file wrappers now gate malformed object reconstruction for bad object bodies,
  malformed name hex escapes, nested object headers inside malformed objects,
  and object-looking bytes inside stream data, preserving deferred file-backed
  stream reads while avoiding false physical objects. `moon test --target
  native` now reports 1318/1318 tests passing.~~
- [x] ~~Add the thirty-third pre-refactor correctness sentinel: native async
  file wrappers now gate xref-stream `/Prev` revision handling for updated and
  deleted newest entries, including revision counts, full reads, sanitized
  trailers, and older revision reads from disk. `moon test --target native` now
  reports 1319/1319 tests passing.~~
- [x] ~~Add the thirty-fourth pre-refactor correctness sentinel: native async
  file wrappers now gate compressed Flate predictor xref-stream `/Prev`
  revision handling, including full disk reads, older revision reads, sanitized
  trailers, and bad-final-`startxref` reconstruction. `moon test --target
  native` now reports 1320/1320 tests passing.~~
- [x] ~~Add the thirty-fifth pre-refactor correctness sentinel: native async
  file wrappers now gate direct `/ObjStm` extraction from disk for multiple
  compressed entries and embedded stream-object members, including compressed
  xref-stream write/reread preservation. `moon test --target native` now
  reports 1321/1321 tests passing.~~
- [x] ~~Add the thirty-sixth pre-refactor correctness sentinel: native async
  file wrappers now reconstruct bad-final-`startxref` multi-revision xref-stream
  documents whose newest `/Root` lives inside an `/ObjStm`, sanitize `/Prev`,
  and preserve the reconstructed root through compressed xref write/reread.
  `moon test --target native` now reports 1322/1322 tests passing.~~
- [x] ~~Add the thirty-seventh pre-refactor correctness sentinel: native async
  file wrappers now preserve unrecoverable object-stream decode failures from
  disk for unsupported `/ObjStm` filters, malformed `/DecodeParms`, and
  unsupported predictors instead of reconstructing partial documents. `moon
  test --target native` now reports 1323/1323 tests passing.~~
- [x] ~~Add the thirty-eighth pre-refactor correctness sentinel: native async
  file wrappers now reject truncated xref-stream entry data from disk with
  `XRefEntryExpected`, preserving the byte-reader's unrecoverable short-stream
  path. `moon test --target native` now reports 1324/1324 tests passing.~~
- [x] ~~Add the thirty-ninth pre-refactor correctness sentinel: native async
  file wrappers now reconstruct out-of-range classic `startxref` pointers from
  disk after preserving strict `InvalidCursorPosition(999999)`. `moon test
  --target native` now reports 1325/1325 tests passing.~~
- [x] ~~Add the fortieth pre-refactor correctness sentinel: native async file
  wrappers now reconstruct malformed and overflowing classic `startxref`
  numbers from disk after preserving strict `NumberExpected`. `moon test
  --target native` now reports 1326/1326 tests passing.~~
- [x] ~~Add the forty-first pre-refactor correctness sentinel: native async
  file wrappers now preserve classic free xref entries during bad-`startxref`
  reconstruction while still keeping later physical updates for the same object
  number. `moon test --target native` now reports 1327/1327 tests passing.~~
- [x] ~~Add the forty-second pre-refactor correctness sentinel: native async
  file wrappers now reconstruct classic `/Prev` chains with a bad final
  `startxref`, preserving the newest revision and sanitizing `/Prev`.
  `moon test --target native` now reports 1328/1328 tests passing.~~
- [x] ~~Add the forty-third pre-refactor correctness sentinel: native async file
  wrappers now reconstruct literal string values containing `endobj` text from
  disk without splitting the catalog object during physical scanning. `moon test
  --target native` now reports 1329/1329 tests passing.~~
- [x] ~~Add the forty-fourth pre-refactor correctness sentinel: native async file
  wrappers now reconstruct in-range but non-xref classic `startxref` pointers
  from disk after preserving strict `XRefExpected`. `moon test --target native`
  now reports 1330/1330 tests passing.~~
- [x] ~~Add the forty-fifth pre-refactor correctness sentinel: native async file
  wrappers now reconstruct glued malformed trailer markers from disk, including
  `trailer <<` and `trailer<<` forms, after preserving strict
  `StartXRefExpected`. `moon test --target native` now reports 1331/1331 tests
  passing.~~
- [x] ~~Add the forty-sixth pre-refactor correctness sentinel: native async file
  wrappers now reconstruct no-`startxref` PDFs with indirect stream lengths,
  preserving deferred data for resolvable lengths and materializing streams
  whose length references cannot be resolved. `moon test --target native` now
  reports 1332/1332 tests passing.~~
- [x] ~~Add the forty-seventh pre-refactor correctness sentinel: native async
  file wrappers now preserve unreconstructable malformed read errors from disk,
  keeping rootless physical scans as `RootExpected` and malformed `startxref`
  files with no recovery root as `NumberExpected`. `moon test --target native`
  now reports 1333/1333 tests passing.~~
- [x] ~~Add the forty-eighth pre-refactor correctness sentinel: native async file
  wrappers now reconstruct valid classic xref tables that omit page-tree or
  catalog objects, preserving strict `PageTreeExpected`/`RootExpected` gates
  before public recovery scans the missing physical objects. `moon test --target
  native` now reports 1334/1334 tests passing.~~
- [x] ~~Add the forty-ninth pre-refactor correctness sentinel: native async file
  wrappers now preserve linearized first-object markers from disk, including
  numeric vs non-numeric `/Linearized` values, `pdf_is_linearized_file`, and
  revision counting for linearized `/Prev` fixtures. `moon test --target native`
  now reports 1335/1335 tests passing.~~
- [x] ~~Add the fiftieth pre-refactor correctness sentinel: native async file
  wrappers now read and reconstruct hybrid classic `/XRefStm` trailers from
  disk, including compressed predictor xref streams, bad-final-`startxref`
  recovery, and sanitized `/XRefStm`/`DecodeParms` trailer metadata. `moon test
  --target native` now reports 1336/1336 tests passing.~~
- [x] ~~Add the fifty-first pre-refactor correctness sentinel: native async file
  wrappers now resolve commented indirect stream lengths from disk, preserving
  deferred stream data while ignoring `stream` tokens that appear only in length
  object comments. `moon test --target native` now reports 1337/1337 tests
  passing.~~
- [x] ~~Add the fifty-second pre-refactor correctness sentinel: native async file
  fixtures now preserve strict classic xref object mismatch errors from disk,
  distinguishing wrong object numbers (`XRefEntryExpected`) from unparseable
  xref targets (`ParseIndirectObjectExpected`). `moon test --target native` now
  reports 1338/1338 tests passing.~~
- [x] ~~Add the fifty-third pre-refactor correctness sentinel: native async file
  fixtures now preserve strict classic missing-xref/trailerless-xref failures
  from disk, distinguishing missing xref markers (`XRefExpected`) from xref
  sections with no trailer (`TrailerExpected`). `moon test --target native` now
  reports 1339/1339 tests passing.~~
- [x] ~~Add the fifty-fourth pre-refactor correctness sentinel: native async
  file fixtures now preserve strict malformed classic xref-row failures from
  disk, including short rows, bad row markers, and fixed-width digit/marker
  corruption, while public reads still reconstruct the physical catalog.
  `moon test --target native` now reports 1340/1340 tests passing.~~
- [x] ~~Add the fifty-fifth pre-refactor correctness sentinel: native async file
  fixtures now preserve strict malformed classic `/Prev` trailer failures from
  disk for negative and non-numeric values, while public reads still reconstruct
  the physical catalog. `moon test --target native` now reports 1341/1341 tests
  passing.~~
- [x] ~~Add the fifty-sixth pre-refactor correctness sentinel: native async file
  fixtures now preserve the strict classic reader's missing-plain-`endobj`
  tolerance from disk, proving both strict and public file reads keep the
  catalog object intact. `moon test --target native` now reports 1342/1342
  tests passing.~~
- [x] ~~Add the fifty-seventh pre-refactor correctness sentinel: native async
  file fixtures now preserve missing-plain-`endobj` continuation from disk,
  proving strict and public file reads still separate the following indirect
  object. `moon test --target native` now reports 1343/1343 tests passing.~~
- [x] ~~Add the fifty-eighth pre-refactor correctness sentinel: native async
  file fixtures now preserve direct-length stream object boundaries from disk,
  proving strict and public file reads keep the following indirect object
  separate. `moon test --target native` now reports 1344/1344 tests passing.~~
- [x] ~~Finish warning 74 public API documentation with useful API-level
  behavior, ownership, error, target, and compatibility notes rather than
  placeholder warning fixes.~~
  - [x] ~~Document byte foundations, byte cursors, byte output, PDF byte
    primitives, bitstreams, units, dates, transforms, helper entry points,
    destinations, standard-font helpers, lookup/tree helpers, colour spaces,
    core object/document models, lexemes, readers, and Flate compression.~~
  - [x] ~~Document text/font extraction APIs, including encoding fallback,
    CMap/ToUnicode behavior, glyph/codepoint differences, and reverse lookup.~~
  - [x] ~~Document cryptography APIs, including ownership/password flow,
    permission semantics, object-key derivation, stream crypt dispatch, and
    secure-random target limits.~~
  - [x] ~~Document page/writer/file I/O APIs, including page-tree lifecycle,
    write modes, incremental update behavior, trailer IDs, and native async
    boundaries.~~
  - [x] ~~Document page-label APIs, including 1-based public page numbers,
    byte-preserving prefixes, range coalescing, immutable document updates, and
    zero-based PDF number-tree keys.~~
  - [x] ~~Document function APIs, including PDF function type coverage,
    domain/range pair semantics, calculator stack behavior, evaluation
    clamping, parsing errors, and current serialization limits.~~
  - [x] ~~Document optional-content APIs, including raw PDF string/name
    preservation, configuration semantics, indirect object-number ownership,
    copy-on-write updates, and already-renumbered merge expectations.~~
  - [x] ~~Document content-stream APIs, including raw byte text handling,
    operator serialization, inline-image filter behavior, stream concatenation,
    document/resource-aware parsing, and compatibility wrappers.~~
  - [x] ~~Document annotation APIs, including raw annotation strings, required
    rectangles, popup parent handling, preserved dictionary entries, add-page
    semantics, and geometry transform mutation.~~
  - [x] ~~Document native secure-random AES convenience APIs, including native
    target RNG sources, error behavior, file-id fallback, recrypt requirements,
    and encrypted writer modes.~~
  - [x] ~~Document bookmark APIs, including flattened preorder levels, raw title
    bytes, action-preservation mode, copy-on-write outline replacement, and
    destination transforms.~~
  - [x] ~~Document image APIs, including encoded-versus-raw extraction,
    image-mask defaults, colour-space/resource lookup, BPC preservation, decode
    application, and 24bpp RGB output layout.~~
  - [x] ~~Document structure, renumbering, and Markdown helper APIs, including
    parent-tree mutation, selected-page trimming, object-number copy semantics,
    non-overlapping merge renumbering, and best-effort Markdown extraction.~~
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
- [x] ~~Gate the downloaded DCT/JPEG, CCITT/FaxDecode, and indexed-CMYK image
  fixtures through compressed writer/read boundaries, so real image extraction
  is checked both before and after serialization.~~
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
- [x] ~~Extend the default local MarkItDown comparison loop to checked-in
  CamlPDF real PDFs, covering the tutorial text fixture and image-heavy logo
  fixture with quality metrics.~~
- [x] ~~Add replacement-character and raw-control counters to the MarkItDown
  comparison summary so Markdown quality regressions are tracked directly in
  generated reports.~~
- [x] ~~Extend the MarkItDown comparison loop to downloaded real-world fixtures
  with documented redistribution terms and expected extraction contracts.~~
- [x] ~~Add download-only external Markdown acceptance fixtures for an Adobe
  PDF-spec supplement and a Unicode CJK chart, with SHA-256 lock metadata and
  checked-in comparison judgement.~~
- [x] ~~Add a malformed-reader Markdown acceptance gate for the optional
  downloaded Adobe PDF-spec supplement, corrupting the final `startxref` before
  extraction and preserving real-world output markers plus raw-control and
  replacement-character quality counters.~~
- [x] ~~Add a native command-package Markdown conversion gate, writing a
  generated PDF fixture to a UTF-8 `.md` file through the executable helper and
  checking stable markers in the file output.~~
- [x] ~~Extend the Markdown command-package gate to an optional downloaded
  Adobe PDF-spec supplement fixture, checking real-world file output markers
  and raw-control hygiene when the fixture is present.~~
- [x] ~~Extend the Markdown command-package gate to the optional downloaded
  Unicode CJK chart fixture, checking real-world file output markers, raw
  control/replacement hygiene, and full U+4E00-9FFF unique-glyph coverage when
  present.~~
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
- [x] ~~Add strict and reconstructed Flate xref-stream coverage where a bad
  `startxref` forces recovery of a common `/FlateDecode` xref stream and
  sanitizes stream-only trailer keys.~~
- [x] ~~Add bad-`startxref` reconstruction coverage for sparse xref-stream
  `/Index` ranges, preserving non-contiguous object entries while sanitizing
  stream-only trailer keys.~~
- [x] ~~Add strict and bad-`startxref` reconstruction coverage for Flate
  xref streams with PNG predictor `/DecodeParms`, preserving common compressed
  xref-stream rows while sanitizing stream-only trailer keys.~~
- [x] ~~Add strict and bad-`startxref` reconstruction coverage for abbreviated
  Flate predictor xref streams using `/Fl` and `/DP`, keeping short stream
  metadata out of reconstructed trailers.~~
- [x] ~~Add strict and reconstructed staged-filter xref-stream coverage for
  direct `/Filter [/ASCIIHexDecode /RunLengthDecode]` arrays through
  bad-startxref recovery.~~
- [x] ~~Add strict and bad-`startxref` reconstruction coverage for xref-stream
  filter arrays with aligned `/DecodeParms` arrays, preserving predictor
  parameters on the Flate stage while sanitizing stream metadata.~~
- [x] ~~Add compressed xref-stream `/Prev` chain coverage where the newest
  Flate predictor xref stream points back to a classic xref section, including
  normal revision reads and bad-final-`startxref` reconstruction.~~
- [x] ~~Add compressed hybrid `/XRefStm` coverage where a classic trailer
  points to a Flate predictor xref stream, including strict hybrid reads and
  bad-final-`startxref` reconstruction.~~
- [x] ~~Malformed object-stream recovery now covers reconstructed xref-stream
  documents whose `/ObjStm` uses an indirect `/Filter`, preserving embedded
  object expansion after bad-final-`startxref` recovery.~~
- [x] ~~Add a real-world image xref-stream malformed-startxref gate for the
  optional py-pdf DCT/JPEG fixture, requiring strict-reader failure,
  malformed-reader reconstruction, JPEG extraction, and compressed
  rewrite/reread preservation.~~
- [x] ~~Add a real-world Type3 font malformed-startxref gate for the optional
  PDFium resource fixture, requiring strict-reader failure, malformed-reader
  reconstruction, Type3 resource/CharProc parsing, text extraction, and
  compressed rewrite/reread preservation.~~
- [x] ~~Add a real-world Type3 glyph-program malformed-startxref gate for the
  optional iText logo fixture, requiring strict-reader failure,
  malformed-reader reconstruction, Type3 metrics/CharProc text extraction, and
  compressed rewrite/reread preservation.~~
- [x] ~~Add a real-world CCITT image malformed-startxref gate for the optional
  py-pdf ImageMagick fixture, requiring strict-reader failure,
  malformed-reader reconstruction, CCITT-to-RGB24 extraction, and compressed
  rewrite/reread preservation.~~
- [x] ~~Add checked-in CamlPDF real-world malformed-startxref fixture gates:
  the native-only `fixture_acceptance` package now corrupts the final
  `startxref` pointer for the linearized classic-xref `logo.pdf` fixture and
  the xref/object-stream `introduction_to_camlpdf.pdf` fixture, requires strict
  reader failure, reconstructs through the public recovery reader, and verifies
  compressed-xref rewrite/reread page counts. `moon test --target native
  fixture_acceptance` reports 3/3 tests passing.~~
- [x] ~~Add checked-in Pandoc real-world malformed-startxref fixture gates:
  `fixture_acceptance` now also corrupts the object-stream-backed
  `pandoc_latin.pdf` and `pandoc_cjk.pdf` fixtures, requires strict-reader
  failure, reconstructs through the public recovery reader, and verifies
  compressed-xref rewrite/reread page counts. `moon test --target native
  fixture_acceptance` reports 5/5 tests passing.~~
- [ ] Add further malformed xref-table/xref-stream/object-stream recovery cases
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
- [x] ~~The optional py-pdf DCT/JPEG image fixture now gates a real-world
  xref-stream malformed-startxref recovery path, checking that strict reads
  fail, public reconstruction succeeds, JPEG extraction survives, and a
  compressed rewrite rereads with the same encoded image payload.~~
- [x] ~~The optional PDFium Type3 resource fixture now gates a real-world
  malformed-startxref recovery path, checking that strict reads fail, public
  reconstruction succeeds, Type3 resource/CharProc parsing survives, and a
  compressed rewrite rereads with the same text and glyph-program behavior.~~
- [x] ~~The optional iText Type3 logo fixture now gates a real-world
  malformed-startxref recovery path, checking that strict reads fail, public
  reconstruction succeeds, Type3 metrics/CharProc text extraction survives,
  and a compressed rewrite rereads with the same logo glyph behavior.~~
- [x] ~~The optional py-pdf ImageMagick CCITT fixture now gates a real-world
  malformed-startxref recovery path, checking that strict reads fail, public
  reconstruction succeeds, CCITT image decoding survives, and a compressed
  rewrite rereads with the same RGB24 payload shape.~~
- [x] ~~Bad-startxref xref-stream reconstruction now has explicit coverage for
  unknown entry types, preserving the skip semantics already used by strict
  xref-stream reads.~~
- [x] ~~Unknown xref-stream entry types are retained internally as non-loadable
  markers, so malformed reconstruction does not resurrect physically present
  objects that a recovered xref stream marks with an unsupported entry kind.~~
- [x] ~~Recovered xref-stream skip markers are offset-aware, so they hide older
  physical objects covered by the stream without hiding later physical
  incremental objects for the same object number.~~
- [x] ~~Password-aware malformed-reader reconstruction now has a native
  encrypted xref-stream metadata gate where a malformed `/Index` triggers
  strict `XRefEntryExpected`, reconstruction recovers from physically scanned
  encrypted objects, and saved-state AESV2 recrypt/reread stays encrypted.~~
- [x] ~~Password-aware malformed-reader reconstruction now also has a native
  encrypted xref-stream width gate where a malformed `/W` triggers strict
  `XRefEntryExpected`, reconstruction recovers from physically scanned
  encrypted objects, and saved-state AESV2 recrypt/reread stays encrypted.~~
- [x] ~~Password-aware malformed-reader reconstruction now also has a native
  encrypted xref-stream size gate where a malformed `/Size` triggers strict
  `XRefEntryExpected`, reconstruction recovers from physically scanned
  encrypted objects, and saved-state AESV2 recrypt/reread stays encrypted.~~
- [x] ~~Malformed-reader reconstruction now has native xref-stream filter gates
  where a malformed `/Filter` triggers strict `FilterNotSupported`,
  reconstruction recovers from physically scanned objects, and encrypted
  saved-state AESV2 recrypt/reread stays encrypted.~~
- [x] ~~Malformed-reader reconstruction now has native xref-stream
  decode-parameter gates where malformed `/DecodeParms` triggers strict
  `PredictorExpected`, reconstruction recovers from physically scanned objects,
  encrypted saved-state AESV2 recrypt/reread stays encrypted, and malformed
  object-stream `/DecodeParms` still raises normally.~~
- [x] ~~Malformed-reader reconstruction now has native object-stream bounds
  gates where a valid xref stream points the root at an object stream with an
  out-of-range `/First`, strict parsing raises `StreamDataExpected`,
  reconstruction recovers the physically scanned page tree, and unrecoverable
  object-stream slice errors still raise normally.~~
- [x] ~~Native async file wrappers now gate the same malformed encrypted
  xref-stream metadata path from disk, including strict failure,
  password-aware recovery, saved-state AESV2 recrypt, plaintext-leak check, and
  user-password reread.~~
- [x] ~~Native async file wrappers now gate the same malformed encrypted
  xref-stream `/W` path from disk, including strict failure, password-aware
  recovery, saved-state AESV2 recrypt, plaintext-leak check, and user-password
  reread.~~
- [x] ~~Native async file wrappers now gate the same malformed encrypted
  xref-stream `/Size` path from disk, including strict failure, password-aware
  recovery, saved-state AESV2 recrypt, plaintext-leak check, and user-password
  reread.~~
- [x] ~~Native async file wrappers now gate the same malformed encrypted
  xref-stream `/Filter` path from disk, including strict `FilterNotSupported`,
  password-aware recovery, saved-state AESV2 recrypt, plaintext-leak check, and
  user-password reread.~~
- [x] ~~Native async file wrappers now gate the same malformed encrypted
  xref-stream `/DecodeParms` path from disk, including strict
  `PredictorExpected`, password-aware recovery, saved-state AESV2 recrypt,
  plaintext-leak check, and user-password reread.~~
- [x] ~~Native async file wrappers now gate malformed encrypted classic xref-row
  marker recovery from disk, including strict `XRefEntryExpected`,
  password-aware recovery, saved-state AESV2 recrypt, plaintext-leak check, and
  user-password reread.~~
- [x] ~~Native async file wrappers now gate malformed encrypted classic xref-row
  offset recovery from disk, including strict failure, password-aware recovery,
  saved-state AESV2 recrypt, plaintext-leak check, and user-password reread.~~
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
- [x] ~~Standalone `cpdfportfolio.ml`-style portfolio assembly now exposes
  in-memory entry APIs plus native async file wrappers, with embedded-file name
  tree, collection dictionary, metadata, and file-path tests.~~
- [x] ~~Standalone `cpdfdraft.ml`-style draft image removal now exposes
  `PdfDocument::draft` and `pdf_draft`, covering image XObjects, inline images,
  named-only removal, recursive Form XObjects, malformed resources, unselected
  pages, and compressed write/read roundtrips.~~
- [x] ~~Standalone `cpdfchop.ml`-style page chopping now exposes
  `PdfDocument::chop`, `PdfDocument::chop_hv`, and compatibility wrappers,
  covering crop-box preference, grid ordering, horizontal/vertical splits,
  page-box and annotation erasure, unselected pages, and validation errors.~~
- [x] ~~Core `cpdfattach.ml`-style attachment operations now expose in-memory
  `PdfDocument::attach_file`, `list_attached_files`, `remove_attached_files`,
  `size_attached_files`, and compatibility wrappers, covering document-level
  embedded-file name trees, page-level `/FileAttachment` annotations, version
  bump/keep-version behavior, unsafe filename filtering, checksum metadata,
  malformed attachment dictionaries, and preservation of unrelated name-tree
  and annotation entries. Native async file-path attach/dump wrappers now read
  source paths, write sanitized attachment names, and reject malformed
  no-data attachments; native full-suite validation reports 1498/1498 tests
  passing.~~
- [x] ~~Standalone `cpdfsqueeze.ml` stream compression/decompression and
  conservative squeeze slices now expose `PdfDocument::recompress`,
  `PdfDocument::decompress`, `PdfDocument::squeeze`, `recompress_pdf`,
  `decompress_pdf`, and `squeeze`, covering unfiltered streams, legacy lossless
  filters and abbreviations, short `/F` aliases, filter arrays, metadata
  skipping, encrypted no-op behavior, malformed filter metadata, malformed
  old-filter payloads, duplicate object pruning/rewrite, fixed-point squeezing,
  page/annotation duplicate preservation, duplicate stream pruning before
  recompressing, deferred object-table entry preservation, original-document
  preservation, already-decrypted object-table state preservation, optional
  page content stream normalization, shared page-content preservation, direct
  content streams without resources, all parsed page objects outside the page
  tree, Form XObject normalization, malformed XObject resource errors, and
  non-stream Form XObject errors. Native full-suite validation reports
  1519/1519 tests passing, and coverage reports
  no uncovered lines in `pdf_squeeze.mbt`.~~
- [x] ~~Standalone `cpdftweak.ml` reveal-hidden-text slice now exposes
  `PdfDocument::reveal_hidden_text`, `pdf_reveal_hidden_text`, and
  `pdf_reveal_hidden_text_ops`, covering pure operator filtering, selected
  page-only rewriting, original-document preservation, unselected page
  preservation, and selected page Form XObject rewriting. Native focused
  validation reports `moon test --target native pdf_tweak_test.mbt` at 3/3
  tests passing; native full-suite validation reports 1522/1522 tests
  passing; coverage analysis reports no uncovered lines in `pdf_tweak.mbt`.~~
- [x] ~~Standalone `cpdftweak.ml` thin-lines slice now exposes
  `PdfDocument::thin_lines`, `pdf_thin_lines`, and `pdf_thin_lines_ops`,
  covering positive minimum thresholds, negative maximum thresholds, CTM scale
  adjustment across `cm`, unbalanced graphics-state restore errors, `/ExtGState`
  `/LW` insertion, malformed `/LW` ignoring, selected page-only rewriting, and
  original-document preservation. Native focused validation reports
  `moon test --target native pdf_tweak_test.mbt` at 7/7 tests passing; native
  full-suite validation reports 1526/1526 tests passing; coverage analysis
  reports no uncovered lines in `pdf_tweak.mbt`.~~
- [x] ~~Standalone `cpdftweak.ml` remove-clipping slice now exposes
  `PdfDocument::remove_clipping`, `pdf_remove_clipping`, and
  `pdf_remove_clipping_ops`, covering exact `W n` rewriting, `W* n`
  preservation, selected page-only rewriting, original-document preservation,
  and selected page Form XObject rewriting. Native focused validation reports
  `moon test --target native pdf_tweak_test.mbt` at 10/10 tests passing;
  native full-suite validation reports 1529/1529 tests passing; coverage
  analysis reports no uncovered lines in `pdf_tweak.mbt`.~~
- [x] ~~Standalone `cpdftweak.ml` append-page-content slice now exposes
  `PdfDocument::append_page_content`, `append_page_content_ops`,
  `append_page_content_multiple`, `append_page_content_multiple_ops`, and
  compatibility wrappers, covering byte-content parsing with page resources,
  operator-list input, prepend and append modes, fast append wrapping, selected
  page-only rewriting, empty payload no-ops, per-page payloads, count-mismatch
  errors, and original-document preservation. Native focused validation
  reports `moon test --target native pdf_tweak_test.mbt` at 15/15 tests
  passing; native full-suite validation reports 1534/1534 tests passing;
  coverage analysis reports no uncovered lines in `pdf_tweak.mbt`.~~
- [x] ~~Standalone `cpdftweak.ml` object-spec finder slice now exposes
  `PdfDocument::find_object_by_spec` and `pdf_find_object`, covering trailer
  selection, trailer-rooted chains, numbered object specs, array pseudo-key
  traversal, page object specs, empty and non-slash suffix chains, malformed
  specs, missing chains, and out-of-range page specs. Native focused
  validation reports `moon test --target native pdf_tweak_test.mbt` at 18/18
  tests passing; native full-suite validation reports 1537/1537 tests passing;
  coverage analysis reports no uncovered lines in `pdf_tweak.mbt`.~~
- [x] ~~Standalone `cpdftweak.ml` object mutation slice now exposes
  `PdfDocument::replace_object_by_spec`, `remove_object_by_spec`,
  `replace_stream_by_spec`, and compatibility wrappers, covering trailer,
  numbered-object, page-object, nested dictionary, array pseudo-key, direct and
  indirect array target replacement, decimal object removal, malformed remove
  specs, stream byte replacement with `/Length` correction, preserved stream
  dictionary entries, non-stream replacement errors, missing chains, malformed
  array pseudo-keys, direct array index bounds, non-array keys in array
  contexts, and out-of-range page specs. Native focused validation reports
  `moon test --target native pdf_tweak_test.mbt` at 21/21 tests passing;
  native full-suite validation reports 1540/1540 tests passing; coverage
  analysis reports no uncovered lines in `pdf_tweak.mbt`.~~
- [x] ~~Standalone `cpdftweak.ml` colour-rewrite slice now exposes
  `PdfContentColour`, `pdf_content_black`, `PdfDocument::black_text`,
  `black_lines`, `black_fills`, pure operator transforms, and compatibility
  wrappers, covering text-block colour insertion, colour and graphics-state
  movement after `ET`, non-text operator copying, selected page-only rewriting,
  selected Form XObject rewriting, original-document preservation, stroke and
  fill colour-space normalization to `/DeviceRGB`, RGB/grey/CMYK colour
  variants, and preservation of unrelated stroke/fill operators. Native
  focused validation reports `moon test --target native pdf_tweak_test.mbt` at
  27/27 tests passing; native full-suite validation reports 1546/1546 tests
  passing; coverage analysis reports no uncovered lines in `pdf_tweak.mbt`.~~
- [x] ~~Standalone `cpdftweak.ml` dictionary-entry reporting slice now exposes
  `PdfDocument::dict_entry_values`, `dict_entry_rendered_values`,
  `dict_entries_json`, `pdf_dict_entry_values`, `pdf_print_dict_entry`, and
  `pdf_get_dict_entries`, covering nested dictionaries, arrays, stream
  dictionaries, trailer traversal, indirect value resolution, PDF-syntax
  rendering, cpdf-style JSON wrappers for null/boolean/integer/real/name/array/
  stream/indirect values, UTF-8 string wrappers, malformed string/name byte
  fallback escaping, malformed stream dictionaries, and existing remove-wrapper
  behavior. Native focused validation reports
  `moon test --target native pdf_util_test.mbt` at 10/10 tests passing; native
  full-suite validation reports 1552/1552 tests passing; coverage analysis
  reports only three defensive unreachable `InvalidUTF8` branches in
  `pdf_util.mbt`.~~
- [x] ~~Standalone utility ports for `cpdfdebug.ml`, `cpdfprinttree.ml`, and
  `cpdfstrftime.ml` expose `PdfDocument::debug_objects`,
  `pdf_print_tree_to_string`, explicit-time and native-current-time strftime
  helpers, and compatibility wrappers where applicable. Coverage pins cpdf's
  trailer/catalog/pages dump spelling, missing-root and no-pages diagnostics,
  Unicode tree-line rendering with line prefixes, strftime replacement order,
  field quirks, invalid-field fallback names, and native local-time field
  ranges. Native focused validation reports `moon test --target native
  pdf_debug_test.mbt` at 3/3, `pdf_print_tree_test.mbt` at 2/2,
  `pdf_strftime_test.mbt` at 3/3, and `pdf_strftime_native_test.mbt` at 2/2;
  native full-suite validation reports 1717/1717 tests passing.~~
- [x] ~~Standalone `cpdfjson.ml` single-object output slice now exposes
  `PdfDocument::json_of_object` and `pdf_json_of_object`, covering CPDFJSON
  dictionary, array, stream, name, integer, real, indirect, boolean, null, and
  UTF-8 string-wrapper shapes without claiming full document import/export or
  parsed content-stream encoding. Native focused validation reports
  `moon test --target native pdf_util_test.mbt` at 12/12 tests passing; native
  full-suite validation reports 1697/1697 tests passing.~~
- [x] ~~Standalone `cpdfjson.ml` single-object input slice now exposes
  `pdf_object_of_json`, covering CPDFJSON primitive values, indirect
  references, integer/real/name/string wrappers, dictionaries, arrays,
  UTF-8 string wrappers via PDFDocString encoding, and stream string-data
  reconstruction with `/Length` correction while leaving parsed content-stream
  operation arrays to a later full-document slice. Native focused validation
  reports `moon test --target native pdf_util_test.mbt` at 14/14 tests
  passing; native full-suite validation reports 1699/1699 tests passing.~~
- [x] ~~Standalone `cpdfjson.ml` parsed content-operation stream input slice
  now extends `pdf_object_of_json` for `{"S": [dict, [ops...]]}` streams,
  covering cpdf operator-array shapes for graphics/text/color/marked-content
  operations, variable-length color operators, nested JSON PDF objects,
  corrected `/Length` reconstruction, malformed numeric wrappers, and malformed
  operator arrays. Native focused validation reports
  `moon test --target native pdf_util_test.mbt` at 16/16 tests passing; native
  full-suite validation reports 1703/1703 tests passing.~~
- [x] ~~Standalone `cpdfjson.ml` full-document input slice now exposes
  `pdf_document_of_json`, covering top-level CPDFJSON arrays, object `-1`
  parameters, object `0` trailer import, positive object-table entries, ignored
  negative object numbers, version/root restoration, parsed stream arrays,
  mutation-log-free object loading, omitted stream-data rejection, missing-root
  rejection, and malformed top-level JSON errors. Native focused validation
  reports `moon test --target native pdf_util_test.mbt` at 18/18 tests passing;
  native full-suite validation reports 1705/1705 tests passing.~~
- [x] ~~Standalone `cpdfjson.ml` full-document output slice now exposes
  `PdfDocument::json_of_document` and `pdf_json_of_document`, covering cpdf's
  top-level CPDFJSON array shape with object `-1` parameters, object `0`
  trailer output, sorted positive object entries, stream-data-included unparsed
  content output, wrapper parity, and round-tripping through
  `pdf_document_of_json`. Native focused validation reports
  `moon test --target native pdf_util_test.mbt` at 19/19 tests passing; native
  full-suite validation reports 1706/1706 tests passing.~~
- [x] ~~Standalone `cpdfjson.ml` parsed content-stream output slice now extends
  `PdfDocument::json_of_document` and `pdf_json_of_document` with
  `parse_content=true`, covering CPDFJSON contentparsed metadata, page
  `/Contents` stream selection, operation-array output, `/Length` omission for
  parsed stream dictionaries, wrapper parity, and round-tripping through
  `pdf_document_of_json`. Native focused validation reports
  `moon test --target native pdf_util_test.mbt` at 20/20 tests passing; native
  full-suite validation reports 1707/1707 tests passing.~~
- [x] ~~Standalone `cpdfjson.ml` clean-string output slice now extends
  `PdfDocument::json_of_object`, `pdf_json_of_object`,
  `PdfDocument::json_of_document`, and `pdf_json_of_document` with
  `clean_strings=true`, covering explicit UTF-16BE simplification for non-UTF8
  CPDFJSON strings, default raw-byte preservation, UTF8 precedence,
  compatibility-wrapper parity, and cpdf's full-document trailer skip for
  clean-string preprocessing. Native focused validation reports
  `moon test --target native pdf_util_test.mbt` at 21/21 tests passing; native
  full-suite validation reports 1708/1708 tests passing.~~
- [x] ~~Standalone `cpdfjson.ml` stream-data omission output slice now extends
  `PdfDocument::json_of_object`, `pdf_json_of_object`,
  `PdfDocument::json_of_document`, and `pdf_json_of_document` with
  `no_stream_data=true`, covering cpdf's stream-data elision placeholder,
  `/CPDFJSONstreamdataincluded=false` metadata, compatibility-wrapper parity,
  and the `parse_content=true` interaction where selected content streams
  still serialize as operation arrays. Native focused validation reports
  `moon test --target native pdf_util_test.mbt` at 22/22 tests passing; native
  full-suite validation reports 1709/1709 tests passing.~~
- [x] ~~Standalone `cpdfjson.ml` forced stream decompression output slice now
  extends `PdfDocument::json_of_document` and `pdf_json_of_document` with
  `decompress_streams=true`, covering supported-filter stream decoding,
  `/Filter` removal, `/Length` refresh, wrapper parity, and the
  `no_stream_data=true` interaction where decoded dictionaries are still
  emitted with stream bytes elided. Native focused validation reports
  `moon test --target native pdf_util_test.mbt` at 23/23 tests passing; native
  full-suite validation reports 1710/1710 tests passing.~~
- [x] ~~Standalone `cpdfjson.ml` document reachability output slice now makes
  `PdfDocument::json_of_document` and `pdf_json_of_document` omit positive
  objects unreachable from the trailer or stored root, matching cpdf's
  document-output pruning while preserving the source document. Coverage pins
  wrapper parity, detached-object omission, original object-table preservation,
  and round-tripping through `pdf_document_of_json`. Native focused validation
  reports `moon test --target native pdf_util_test.mbt` at 24/24 tests passing;
  native full-suite validation reports 1711/1711 tests passing.~~
- [x] ~~Standalone `cpdfjson.ml` parsed-content precombine output slice now
  prepares a non-mutating document copy for `parse_content=true`, combining
  multi-stream page contents before emitting CPDFJSON operation arrays. Coverage
  pins split-operator content streams, omission of the original detached stream
  objects from output, wrapper parity, original object preservation, and
  round-tripping through `pdf_document_of_json`. Native focused validation
  reports `moon test --target native pdf_util_test.mbt` at 25/25 tests passing;
  native full-suite validation reports 1712/1712 tests passing.~~
- [x] ~~Standalone `cpdfjs.ml` JavaScript scrub/detect slice exposes
  `PdfDocument::contains_javascript`, `remove_javascript`, and compatibility
  wrappers, covering cpdf's string-only `/S /JavaScript` detection, lowercase
  `javascript:` URI detection, stream dictionaries, root JavaScript name trees,
  recursive `/JS` and `/URI` blanking, name-tree removal, and wrapper parity.
  Native focused validation reports `moon test --target native
  pdf_javascript_test.mbt` at 5/5 tests passing; native full-suite validation
  reports 1717/1717 tests passing.~~
- [x] ~~Standalone `cpdfpad.ml` padding slice exposes `PdfDocument::pad_after`,
  `pad_before`, `pad_to_multiple`, and compatibility wrappers, covering blank
  page insertion before/after selected pages, annotation removal from generated
  blanks, duplicate selected-page handling, padding with another document once
  per unique selected page, wrapper parity, invalid-page rejection, and
  positive/negative multiple padding. Native focused validation reports
  `moon test --target native pdf_pad_test.mbt` at 8/8 tests passing; native
  full-suite validation reports 1714/1714 tests passing.~~
- [x] ~~Standalone `cpdfposition.ml` position helper slice exposes the
  `PdfPosition` model, `pdf_string_of_position`, and
  `pdf_calculate_position`, covering every cpdf debug spelling, centered and
  absolute placements, edge placements with and without ignored distances, and
  diagonal/reverse-diagonal rotation math. Native focused validation reports
  `moon test --target native pdf_position_test.mbt` at 5/5 tests passing;
  native full-suite validation reports 1715/1715 tests passing.~~
- [x] ~~Standalone `cpdfremovetext.ml` removal slice exposes
  `pdf_remove_added_text_ops`, `pdf_remove_all_text_ops`,
  `PdfDocument::remove_added_text`, `remove_all_text`, and compatibility
  wrappers, covering nested and unterminated `/CPDFSTAMP` removal,
  text-showing operator filtering, selected-page rewrites, Form XObject text
  removal, wrapper parity, and source-document preservation. Native focused
  validation reports `moon test --target native pdf_remove_text_test.mbt` at
  7/7 tests passing; native full-suite validation reports 1719/1719 tests
  passing.~~
- [x] ~~Standalone `cpdfpagelabels.ml` JSON adapter slice now exposes
  `PdfDocument::add_page_labels_json` and `pdf_add_page_labels_json`, covering
  cpdf's page-label JSON array shape, UTF-8 prefix-to-PDFDocString encoding,
  nullable prefixes, method and compatibility-wrapper paths, malformed JSON
  errors, and invalid style propagation. Native focused validation reports
  `moon test --target native pdf_page_label_test.mbt` at 25/25 tests passing;
  native full-suite validation reports 1701/1701 tests passing.~~
- [x] ~~Standalone `cpdfimpose.ml` rest-dictionary merge slice now exposes
  `PdfDocument::combine_pdf_rests`, covering preservation of unknown page-rest
  entries, `/Annots` array concatenation, indirect annotation-array resolution,
  malformed annotation values, and non-dictionary rest inputs. Native focused
  validation reports `moon test --target native pdf_page_test.mbt` at 80/80
  tests passing; native full-suite validation reports 1555/1555 tests
  passing.~~
- [x] ~~Standalone `cpdftype.ml` artifact-wrapping slice now exposes
  `pdf_content_add_artifacts`, covering unmarked operator runs, empty inputs,
  content sections entered by `BDC`, automatic artifact closure before real
  marked content, and cpdftype back-channel `/BeginArtifact`/`/EndArtifact`
  markers. Native focused validation reports
  `moon test --target native pdf_content_test.mbt` at 58/58 tests passing;
  native full-suite validation reports 1558/1558 tests passing.~~
- [x] ~~Standalone `cpdftype.ml` element/debug/width-helper slice now exposes
  `PdfTypeElement`, `pdf_string_of_type_element`, `pdf_string_of_type`,
  `pdf_type_font_widths`, and `pdf_type_width_of_bytes`, covering raw byte text
  rendering, CamlPDF leading-newline element-stream formatting, OCaml-style
  float spelling, standard-font width scaling, simple-font explicit metrics,
  direct byte/charcode summation, missing simple-font metrics, and short
  width-table failures. Native focused validation reports
  `moon test --target native pdf_type_test.mbt` at 5/5 tests passing; native
  full-suite validation reports 1563/1563 tests passing.~~
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
- [x] ~~Rare predefined CMap regression coverage now gates direct Unicode
  Adobe-KR `/UniAKR-UTF8-H`, `/UniAKR-UTF16-H`, and `/UniAKR-UTF32-H`
  extraction/reverse lookup plus `/KSCms-UHC-HW-H` and `/KSCms-UHC-HW-V`
  half-width Korean predefined maps. `moon test --target native
  pdf_text_test.mbt` reports 152/152 tests passing.~~
- [x] ~~Direct Unicode predefined CMap coverage now includes the cpdf-listed
  `/UniGB-UCS32-H`, `/UniGB-UCS32-V`, `/UniGB-UTF16-H`, `/UniGB-UTF16-V`,
  `/UniKS-UCS2-H`, `/UniKS-UCS2-V`, `/UniJIS-UCS2-HW-H`, and
  `/UniJIS-UCS2-HW-V` names. `/UCS32/` CMaps now use the UTF-32 text
  segmentation and reverse-lookup path, and the native reader-boundary gate
  covers these names through compressed write/read/reread.
  `moon test --target native pdf_text_test.mbt` reports 152/152 tests passing,
  and `moon test --target native pdf_native_acceptance_test.mbt` reports 88/88
  tests passing.~~
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
- [x] ~~The download-only iText Type3 logo fixture now also covers real-world
  malformed-startxref reconstruction through Type3 metrics, custom encoding,
  CharProc text extraction, and compressed rewrite/reread boundaries.~~
- [x] ~~Further real-world Type3 `/Resources` coverage using the download-only
  PDFium Type3 inline-image fixture.~~
- [x] ~~The download-only PDFium Type3 resource fixture now also covers
  real-world malformed-startxref reconstruction through Type3 resource,
  CharProc, text extraction, and compressed rewrite/reread boundaries.~~
- [x] ~~TrueType descriptor metadata survives read_font_descriptor and embedded
  TrueType native read/write/reread gates.~~
- [x] ~~Structured DCT/JPEG marker payload native gate for Flate-to-DCT image
  XObjects and DCT inline images with embedded `EI` bytes before EOI.~~
- [x] ~~Additional real-world DCT/JPEG encoded-payload corpus coverage through
  the download-only py-pdf pdflatex image fixture.~~
- [x] ~~The download-only py-pdf DCT/JPEG image fixture now also covers
  real-world xref-stream malformed-startxref reconstruction through image
  extraction and compressed rewrite/reread boundaries.~~
- [x] ~~The download-only py-pdf ImageMagick CCITT image fixture now also
  covers real-world malformed-startxref reconstruction through CCITT decoding
  and compressed rewrite/reread boundaries.~~
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
  representative small stored streams, mixed larger stored-block payloads, and
  compressed repeated streams at multiple zlib levels.~~
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
- [x] ~~Flate xref-stream bad-startxref reconstruction now has explicit
  coverage for common compressed xref streams and sanitized trailer metadata.~~
- [x] ~~Sparse xref-stream `/Index` ranges now have explicit bad-startxref
  reconstruction coverage, preserving non-contiguous object entries while
  sanitizing trailer metadata.~~
- [x] ~~Flate xref streams with PNG predictor `/DecodeParms` now have strict
  and bad-startxref reconstruction coverage, preserving common compressed
  xref-stream rows while sanitizing trailer metadata.~~
- [x] ~~Abbreviated Flate predictor xref streams using `/Fl` and `/DP` now have
  strict and bad-startxref reconstruction coverage, keeping short stream
  metadata out of reconstructed trailers.~~
- [x] ~~Staged-filter xref streams now have strict and reconstructed coverage
  for direct ASCIIHex-plus-RunLength filter arrays.~~
- [x] ~~Xref-stream filter arrays with aligned `/DecodeParms` arrays now have
  strict and bad-startxref reconstruction coverage, preserving predictor
  parameters on the Flate stage while sanitizing stream metadata.~~
- [x] ~~Compressed xref-stream `/Prev` chains now have coverage where the newest
  Flate predictor xref stream points back to a classic xref section, including
  normal revision reads and bad-final-startxref reconstruction.~~
- [x] ~~Compressed hybrid `/XRefStm` reads now have coverage where a classic
  trailer points to a Flate predictor xref stream, including strict hybrid
  reads and bad-final-startxref reconstruction.~~
- [x] ~~Writer-generated compressed xref-stream incremental updates now have a
  public native bad-startxref acceptance gate, preserving revision markers
  through recovery, compressed rewrite, and reread.~~
- [x] ~~Encrypted incremental updates now have a public native bad-final
  `startxref` acceptance gate, preserving the newest encrypted revision through
  password-aware reconstruction, saved-state AESV2 recrypt, compressed
  xref-stream write, and password reread.~~
- [x] ~~Native async file wrappers now gate encrypted incremental bad-final
  `startxref` recovery through compressed xref-stream file output,
  password-aware file reconstruction, saved-state AESV2 recrypt, compressed file
  write, and password reread.~~
- [x] ~~Writer-generated compressed encrypted xref-stream output now has a
  public native bad-final `startxref` acceptance gate, preserving encrypted
  direct objects through password-aware reconstruction, saved-state AESV2
  recrypt, compressed xref-stream write, and password reread.~~
- [x] ~~Native async file wrappers now gate writer-generated compressed AESV2
  encrypted output with bad-final `startxref` recovery, saved-state recrypt,
  compressed file write, and password reread.~~
- [x] ~~Native async file wrappers now gate writer-generated compressed AESV3
  encrypted output with bad-final `startxref` recovery, saved-state recrypt,
  compressed file write, and password reread.~~
- [x] ~~Native async file wrappers now gate writer-generated compressed AESV3 ISO
  encrypted output with bad-final `startxref` recovery, saved-state recrypt,
  compressed file write, and password reread.~~
- [x] ~~Native async file wrappers now gate writer-generated compressed ARC4/R4
  encrypted output with bad-final `startxref` recovery, saved-state recrypt,
  compressed file write, and password reread.~~
- [x] ~~Native async file wrappers now gate writer-generated compressed legacy
  ARC4 40-bit and 128-bit encrypted output with bad-final `startxref` recovery,
  saved-state recrypt, compressed file write, and password reread.~~
- [x] ~~Native async file wrappers now gate encrypted `/ObjStm` reads for
  explicit passwords, bad-final `startxref` reconstruction, and implicit blank
  user password fallback.~~
- [x] ~~Native async file wrappers now gate saved-state recrypt for non-stream
  payloads extracted from encrypted `/ObjStm` storage, including compressed
  xref-stream file write and password reread.~~
- [x] ~~Bad-startxref acceptance helpers now corrupt the final `startxref`
  marker, so multi-revision and incremental fixtures exercise the intended
  newest-revision malformed-reader path.~~
- [x] ~~Reconstructed object-stream expansion now has a regression gate for
  indirect `/Filter` metadata on `/ObjStm`, matching the already-covered strict
  read path after a bad final `startxref`.~~
- [x] ~~Native async file wrappers now gate malformed encrypted xref-stream
  metadata recovery with a valid `startxref`, including strict failure,
  password-aware file recovery, saved-state AESV2 recrypt, compressed file
  write, plaintext-leak check, and user-password reread.~~
- [x] ~~Native async file wrappers now gate malformed encrypted xref-stream
  width recovery with a valid `startxref`, including strict failure,
  password-aware file recovery, saved-state AESV2 recrypt, compressed file
  write, plaintext-leak check, and user-password reread.~~
- [x] ~~Native async file wrappers now gate malformed encrypted xref-stream
  size recovery with a valid `startxref`, including strict failure,
  password-aware file recovery, saved-state AESV2 recrypt, compressed file
  write, plaintext-leak check, and user-password reread.~~
- [x] ~~Native async file wrappers now gate malformed encrypted xref-stream
  filter recovery with a valid `startxref`, including strict
  `FilterNotSupported`, password-aware file recovery, saved-state AESV2
  recrypt, compressed file write, plaintext-leak check, and user-password
  reread.~~
- [x] ~~Native async file wrappers now gate malformed encrypted xref-stream
  decode-parameter recovery with a valid `startxref`, including strict
  `PredictorExpected`, password-aware file recovery, saved-state AESV2 recrypt,
  compressed file write, plaintext-leak check, and user-password reread.~~
- [x] ~~Native async file wrappers now gate malformed object-stream bounds
  recovery with a valid `startxref`, including strict `StreamDataExpected`,
  physical page-tree reconstruction, and page-reference verification from disk.~~
- [x] ~~Native async file wrappers now gate malformed encrypted classic xref-row
  marker recovery with a valid `startxref`, including strict failure,
  password-aware file recovery, saved-state AESV2 recrypt, compressed file
  write, plaintext-leak check, and user-password reread.~~
- [x] ~~Native async file wrappers now gate malformed encrypted classic xref-row
  offset recovery with a valid `startxref`, including strict failure,
  password-aware file recovery, saved-state AESV2 recrypt, compressed file
  write, plaintext-leak check, and user-password reread.~~
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
- [x] ~~Checked-in CamlPDF introduction PDF now has a malformed-reader Markdown
  acceptance gate, corrupting `startxref` before extraction and preserving
  tutorial text with no raw controls or replacement characters.~~
- [x] ~~The optional downloaded Adobe PDF-spec supplement now has a
  malformed-reader Markdown acceptance gate, corrupting the final `startxref`
  and preserving key output markers plus raw-control/replacement counters.~~
- [x] ~~Checked-in CamlPDF logo PDF now has a Markdown acceptance gate over the
  separate Markdown package, covering a real image-heavy fixture that emits
  stable page structure with no raw controls or replacement characters.~~
- [x] ~~Markdown extraction now uses a hash-backed indirect font extractor
  cache, avoiding linear cache scans for repeated `Tf` operators across large
  pages and nested form XObjects.~~
- [x] ~~Markdown normalization now trims the synthetic space before a terminal
  hyphen at extracted line breaks, matching common PDF text baselines for
  wrapped words such as `soft-` without joining the physical lines.~~
- [x] ~~The Markdown executable package now has a native file I/O gate over a
  generated PDF fixture, verifying the command helper writes UTF-8 Markdown
  output with stable page/text markers.~~
- [x] ~~The Markdown executable package now also gates an optional downloaded
  Adobe PDF-spec supplement through file output when present, covering
  real-world CLI-style Markdown conversion and raw-control hygiene.~~
- [x] ~~The Markdown executable package now also gates the optional downloaded
  Unicode CJK chart through file output when present, preserving full
  U+4E00-9FFF unique-glyph coverage with no raw controls or replacement
  characters.~~
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
- [x] ~~Malformed reconstruction now prefilters physical object scans with the
  same indirect-object header recognizer, avoiding parser attempts at unrelated
  digit runs while preserving recovered object semantics.~~
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
- [x] ~~Add the fifty-ninth pre-refactor correctness sentinel: native async
  file fixtures now preserve direct stream line-break and CamlPDF padding
  tolerance from disk, covering CR, CRLF, padded line breaks, and inline padding
  across strict and public file reads. `moon test --target native` now reports
  1345/1345 tests passing.~~
- [x] ~~Add the sixtieth pre-refactor correctness sentinel: native compressed
  reader boundaries now preserve ToUnicode variation mappings for
  supplementary-plane bfchar entries, bfrange-array multi-codepoint entries,
  sequential bfrange entries, fallback unmapped bytes, and reverse lookup
  behavior. `moon test --target native` now reports 1346/1346 tests passing.~~
- [x] ~~Add the sixty-first pre-refactor correctness sentinel: native compressed
  reader boundaries now preserve vertical predefined CMap extraction and
  reverse lookup for GB1, CNS1, and Korea1 variants including GBK2K, Big5,
  HKSCS, CNS1 Big5 variants, KSC-EUC, KSCpc-EUC, and KSCms-UHC. `moon test
  --target native` now reports 1347/1347 tests passing.~~
- [x] ~~Add the sixty-second pre-refactor correctness sentinel: native
  compressed reader boundaries now preserve Type3 CharProc resource chains
  through nested Form XObjects, including form-local image resources, indexed
  image decode, glyph-name extraction, and reread stability. `moon test
  --target native` now reports 1348/1348 tests passing.~~
- [x] ~~Add the sixty-third pre-refactor correctness sentinel: native compressed
  reader boundaries now preserve named image resource color spaces, `/CS`
  aliases, raw decode arrays, image masks, and indexed palettes through
  decompression and reread stability. `moon test --target native` now reports
  1349/1349 tests passing.~~
- [x] ~~Add the sixty-fourth pre-refactor correctness sentinel: native
  compressed reader boundaries now preserve Unicode predefined CMap extraction
  for UCS2, UTF16, UTF8, UTF32, vertical variants, malformed text rejection, and
  multibyte UTF8 `/ToUnicode` overrides. `moon test --target native` now reports
  1350/1350 tests passing.~~
- [x] ~~Add the sixty-fifth pre-refactor correctness sentinel: native
  compressed reader boundaries now preserve ToUnicode parser corner cases for
  split bfchar entries, multiline bfrange arrays, PDF comments, whitespace and
  odd-nibble hex strings, supplementary-plane mappings, multi-codepoint entries,
  and unmapped fallback bytes. `moon test --target native` now reports 1351/1351
  tests passing.~~
- [x] ~~Add the sixty-sixth pre-refactor correctness sentinel: native compressed
  reader boundaries now preserve fixture-shaped Type3 glyph programs with
  low-code custom encodings, indirect CharProc streams, sparse metrics with
  `/MissingWidth`, inline-image glyph content, glyph-name extraction, and
  reread stability. `moon test --target native` now reports 1352/1352 tests
  passing.~~
- [x] ~~Add the sixty-seventh pre-refactor correctness sentinel: native
  compressed reader boundaries now preserve CMYK image conversion for named
  `/CS` resources, explicit CMYK `/Decode` arrays, indexed DeviceCMYK palettes,
  stream decompression, and reread stability. `moon test --target native` now
  reports 1353/1353 tests passing.~~
- [x] ~~Add the sixty-eighth pre-refactor correctness sentinel: native
  compressed reader boundaries now preserve alternate image color spaces for
  ICCBased gray profiles, Separation Type 2 CMYK tint functions, DeviceN
  indexed palettes, indexed Lab palettes, stream decompression, and reread
  stability. `moon test --target native` now reports 1354/1354 tests passing.~~
- [x] ~~Add the sixty-ninth pre-refactor correctness sentinel: native compressed
  reader boundaries now preserve rare Adobe-Japan1 `/90msp-RKSJ-H` and
  `/90msp-RKSJ-V` predefined CMap extraction, proportional ASCII yen mapping,
  vertical kana charcode lookup, malformed reverse lookup misses, and reread
  stability. `moon test --target native` now reports 1355/1355 tests passing.~~
- [x] ~~Add the seventieth pre-refactor correctness sentinel: native compressed
  reader boundaries now preserve legacy Adobe-Japan1 predefined CMaps for
  `/78-H`, `/78-V`, `/78-RKSJ-H`, `/78-RKSJ-V`, `/78ms-RKSJ-H`,
  `/78ms-RKSJ-V`, `/83pv-RKSJ-H`, vertical `/90ms-RKSJ-V`,
  `/90pv-RKSJ-V`, and generic `/RKSJ-H`/`/RKSJ-V` extraction and reverse
  lookup through reread stability. `moon test --target native` now reports
  1356/1356 tests passing.~~
- [x] ~~Add the seventy-first pre-refactor correctness sentinel: native
  compressed reader boundaries now preserve supplemental Adobe-Japan1
  predefined CMaps for `/78-EUC-H`/`-V`, `/EUC-V`, Add, Ext, Hojo,
  Hojo-EUC-V, and NWP variants, including extension-row extraction, vertical
  kana mappings, three-byte Hojo EUC extraction, reverse lookup misses, and
  reread stability. `moon test --target native` now reports 1357/1357 tests
  passing.~~
- [x] ~~Add the seventy-second pre-refactor correctness sentinel: native
  compressed reader boundaries now preserve Type0 `/ToUnicode` sequence CMaps
  shaped like real generated PDFs, including ligature expansion, decomposed
  accents, ideographic variation selectors, bfrange carry across `00FF` to
  `0100`, emoji surrogate pairs, ZWJ emoji sequences, unmapped CID fallback,
  single-codepoint reverse lookup, and reread stability. `moon test --target
  native` now reports 1358/1358 tests passing.~~
- [x] ~~Add the seventy-third pre-refactor correctness sentinel: native
  compressed reader boundaries now preserve encoded image XObject aliases from
  real-world PDFs, including short `/F` filters, short `/W`/`/H` dimensions, Lab
  DCT decode defaults through named resources, JPX explicit decode arrays,
  JBIG2 short `/DP` globals, document-wide stream-decode passes, and reread
  stability. `moon test --target native` now reports 1359/1359 tests
  passing.~~
- [x] ~~Add the seventy-fourth pre-refactor correctness sentinel: native
  malformed-startxref reconstruction now preserves xref-stream page trees stored
  in object streams with indirect `/N`, `/First`, and `/Filter` metadata,
  including strict-reader failure, object-stream expansion, compressed
  xref-stream rewrite, decoded payload checks, and reread stability. `moon test
  --target native` now reports 1360/1360 tests passing.~~
- [x] ~~Add the seventy-fifth pre-refactor correctness sentinel: native
  malformed final `startxref` recovery now follows xref-stream `/Prev` chains
  whose newest revision replaces the catalog and page tree from an object
  stream, including older-revision sanitization, expanded page traversal,
  compressed xref-stream rewrite, retained object-stream payload checks, and
  reread stability. `moon test --target native` now reports 1361/1361 tests
  passing.~~
- [x] ~~Add the seventy-sixth pre-refactor correctness sentinel: native
  object-stream recovery now rejects mismatched xref-stream entries whose
  embedded object number disagrees with the requested root, including strict
  failure, public-reader failure, and protection against accepting a later
  physical fallback object when xref metadata is available. `moon test --target
  native` now reports 1362/1362 tests passing.~~
- [x] ~~Add the seventy-seventh pre-refactor correctness sentinel: native
  object-stream root recovery now rejects unusable object-stream filter
  metadata instead of reconstructing through it, including unsupported filters,
  malformed `/DecodeParms`, unsupported predictors, and exact propagated
  filter/predictor errors. `moon test --target native` now reports 1363/1363
  tests passing.~~
- [x] ~~Add the seventy-eighth pre-refactor correctness sentinel: native
  object-stream loading now rejects invalid member data slices where `/First`
  points beyond the encoded member table, including strict and public reader
  failures before any partial document is accepted. `moon test --target native`
  now reports 1364/1364 tests passing.~~
- [x] ~~Add the seventy-ninth pre-refactor correctness sentinel: native readers
  now reject invalid `startxref` targets that point at non-xref indirect
  objects, streams without `/Type /XRef`, xref streams with an explicit wrong
  type, and xref streams with non-name `/Type` values. `moon test --target
  native` now reports 1365/1365 tests passing.~~
- [x] ~~Add the eightieth pre-refactor correctness sentinel: native classic
  xref parsing now preserves tokenized/unpadded xref rows and CR-only line
  endings through strict reads, public reads, normalized writes, and reread
  stability. `moon test --target native` now reports 1366/1366 tests
  passing.~~
- [ ] Add the next remaining format parity slice: remaining rare predefined
  CMap families, real-world ToUnicode variation coverage, fixture-driven Type3
  resource/glyph-program behavior, or real-world image corpus coverage.
- [ ] Revisit non-native backend validation after native parity is stable.
