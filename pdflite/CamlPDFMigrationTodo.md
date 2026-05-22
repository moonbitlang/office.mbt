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
  renumbering, standard and TrueType font-pack embedding, text-to-PDF
  instruction conversion, basic and tagged text-to-PDF document assembly, PDF/UA
  text-to-PDF subformat shaping, blank PDF/UA creation helpers, PDF/UA XMP
  marker insertion/removal helpers, PDF/UA structure-tree JSON
  import/export helpers, JPEG/JPEG2000, PNG, and JBIG2 image-to-PDF document
  assembly, image XObject JSON listing, image-resolution reporting,
  cpdfimage single-image and multi-image extraction file payloads/native write
  wrappers,
  cpdf draw-control colour parsing, role-map/auto-artifact state, and cpdfdraw
  structured role-map output with fresh-structure-tree preservation,
  Form XObject stamping,
  composition reporting, core metadata APIs, XMP metadata-date rewriting, XMP
  info synchronization, XMP metadata creation, XMP RDF list extraction,
  XMP/document info JSON reporting, cpdfmetadata namespace/get-data/XML-tree
  helper parity, native metadata file set/write/extract wrappers, and XML
  entity/whitespace decoding, redaction annotation bounding-box overlays,
  cpdfua Matterhorn content/role-map/XMP/viewer-preference/optional-content/
  media-clip/file-attachment/PrinterMark/reference-XObject/MCID Form XObject/
  Type0 CIDSystemInfo/CIDToGIDMap/CMap-name/WMode/font-file no-op/TrueType
  encoding/cmap/ToUnicode validation, TrueType cmap glyph mapping plus
  table/metric/descriptor/loca/composite-glyph parsing foundations,
  subset `glyf`/`loca`/format-6 `cmap` table writers, subset-font
  table-directory assembly, width/subset partition helpers, higher-subset
  ToUnicode mapping, and integrated parsed-subset orchestration, imposition
  transform/content/page-assembly/
  pattern-matrix kernels, cpdf page
  hard-box/removal/shift/scale/scale-to-fit/upright/set-mediabox/copy-box
  helpers, page-info report wrappers, and source-order compatibility aliases,
  imposition make-space orchestration, border stamping, layout planning, and
  first public impose/twoup pipelines, and Markdown helper public APIs.

Current backend snapshot:

- Native: full suite passes on MoonBit 0.9.3, currently 2403/2403 tests.
- WasmGC and JavaScript: full portable non-native test suites pass on MoonBit
  0.9.3, currently 2063/2063 on each backend after the latest TrueType
  embedding integration.
- Wasm: current plain-Wasm smoke validation passes at 41/41 tests after
  filtering root's heavy package-level test files and the Markdown package
  generated test module from plain Wasm while retaining them on
  wasm-gc/js/native/llvm; broader plain-Wasm root/Markdown test validation is
  still deferred because those generated modules exceed the runtime's maximum
  function-size limit.
- LLVM: still blocked by the current toolchain: `moon test --target llvm`
  warns that LLVM is experimental and then fails because the LLVM core bundle
  lacks `prelude/prelude.mi`.

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

- [x] ~~Continue `cpdfpage` source/API parity with the page-info reporting
  surface from `.repos/cpdf-source/cpdfpage.mli`: added
  `pdf_json_page_info`, `PdfDocument::output_page_info`, and
  source-order `pdf_output_page_info` wrappers over the existing page-info
  JSON/text implementation. The stdout-oriented source function is exposed as
  deterministic bytes, matching the port's existing `print_fonts` and
  `show_composition` pattern; `raisejson` is accepted for source-shape
  compatibility while `json=true` returns JSON bytes directly. Coverage pins
  the source-name JSON wrapper, JSON output bytes including the `raisejson`
  compatibility flag, and plain-text output bytes. Validation on MoonBit 0.9.3:
  `moon check --target native --warn-list +73` passes with the known
  `markdown/cmd` future notice; `moon test --target native
  pdf_page_info_test.mbt` reports 3/3; `moon fmt`, `moon info`, and
  `moon check --target all --warn-list +73` pass with only the existing
  `markdown/cmd` future notice; full native `moon test --target native`
  reports 2403/2403.~~
- [x] ~~Port the `cpdfembed` TrueType embedding integration:
  `PdfDocument::embed_truetype` and `pdf_embed_truetype` now mirror
  `Cpdfembed.embed_truetype` over the ported `pdf_truetype_parse` surface.
  Empty codepoint lists return an empty font pack without parsing invalid font
  bytes, non-empty inputs add one `/FontFile2` stream per parsed subset with
  `/Length` and `/Length1`, construct cpdf-style TrueType simple fonts with
  descriptor metrics, subset-prefix base font names, widths, font metrics, and
  higher-subset `/ToUnicode`, and build the font-pack codepoint lookup table
  through the same text-extractor reverse lookup used by standard font packs.
  Focused coverage pins the empty-codepoint guard, a synthetic TrueType split
  across a main WinAnsi character and a higher Unicode character, descriptor
  metadata, stream dictionaries, font-pack lookup entries, and writer
  compatibility for the generated `/ToUnicode` font. Validation on MoonBit
  0.9.3: `moon test --target native pdf_embed_test.mbt` reports 8/8;
  `moon fmt`, `moon info`, and `moon check --target all --warn-list +73` pass
  with only the existing `markdown/cmd` future notice; full backend tests
  report native 2403/2403, wasm-gc 2063/2063, js 2063/2063, and plain-wasm
  smoke 41/41.~~
- [x] ~~Port the integrated `cpdftruetype.parse` subset-record surface:
  `PdfTrueTypeParsedSubset` and `pdf_truetype_parse` now assemble the source
  `Cpdftruetype.t` fields from the already-ported table readers, descriptor
  metrics, subset partitioning, width calculation, subset font-file generation,
  and higher-subset ToUnicode helpers. The parser returns the main
  non-symbolic subset first, followed by symbolic implicit-font-file higher
  subsets, preserves cpdf first/last character semantics, and refuses subsets
  with no main encoding characters using the source error text. This closes the
  MoonBit cpdftruetype parser/subsetter surface; remaining work is downstream
  integration/source-audit hardening rather than missing `cpdftruetype.ml`
  helper prerequisites. Validation on MoonBit 0.9.3:
  `moon test --target native pdf_truetype_test.mbt` reports 27/27;
  `moon fmt`, `moon info`, and `moon check --target all --warn-list +73` pass
  with only the existing `markdown/cmd` warning; full backend tests report
  native 2401/2401, wasm-gc 2061/2061, and js 2061/2061.~~
- [x] ~~Port the next `cpdftruetype` higher-subset ToUnicode slice:
  `pdf_truetype_higher_tounicode` now covers the source
  `seconds_tounicodes` helper, mapping each higher subset position to character
  codes starting at `33` and storing UTF-16BE bytes without the PDF Unicode
  string BOM. Coverage includes BMP and supplementary-plane codepoints plus
  the empty-subset `None` case. This still does not complete the final parsed
  `Cpdftruetype.t` record surface or full `Cpdftruetype.parse`. Validation on
  MoonBit 0.9.3: `moon test --target native pdf_truetype_test.mbt` reports
  25/25; `moon fmt`, `moon info`, and
  `moon check --target all --warn-list +73` pass with only the existing
  `markdown/cmd` warning; full backend tests report native 2399/2399,
  wasm-gc 2059/2059, and js 2059/2059.~~
- [x] ~~Port the next `cpdftruetype` width/subset partition slice:
  `PdfTrueTypeSubsetPartition`, `pdf_truetype_partition_subsets`,
  `pdf_truetype_widths`, and `pdf_truetype_widths_higher` now cover the source
  `find_main`, `calculate_widths`, and `calculate_width_higher` prerequisites.
  The port preserves source ordering, chunks higher subsets at 224 codepoints,
  maps selected-encoding PDF codes through glyph names to Unicode before cmap
  lookup, emits zero widths for non-subset main codes, uses the final hmtx entry
  for out-of-range glyph indexes, and preserves the source raw-first-hmtx
  fallback for missing cmap mappings. This still does not complete ToUnicode
  generation, the final parsed `Cpdftruetype.t` record surface, or full
  `Cpdftruetype.parse`. Validation on MoonBit 0.9.3:
  `moon test --target native pdf_truetype_test.mbt` reports 24/24;
  `moon fmt`, `moon info`, and `moon check --target all --warn-list +73`
  pass with only the existing `markdown/cmd` warning; full backend tests report
  native 2398/2398, wasm-gc 2058/2058, and js 2058/2058.~~
- [x] ~~Port the next `cpdftruetype` subset-font assembly slice:
  `pdf_truetype_subset_font` now wraps the already-ported `loca`, `glyf`, and
  format-6 `cmap` writers with source-style `subset_font` table-directory
  construction. Non-required TrueType tables are removed, original checksums
  are preserved, source-compatible `searchRange`/`entrySelector`/`rangeShift`
  header values are emitted, offsets are reduced for removed header/data spans
  and rewritten table sizes, original table spans are copied for untouched
  tables, and `rewrite_cmap=true` covers the source `ImplicitInFontFile`
  higher-subset path. This still does not complete width calculation from
  selected encodings, `find_main` subset partitioning, `tounicode` generation,
  the final parsed `Cpdftruetype.t` record surface, or full
  `Cpdftruetype.parse`. Validation on MoonBit 0.9.3:
  `moon check --target native --warn-list +73` passes with only the existing
  `markdown/cmd` warning; `moon test --target native pdf_truetype_test.mbt`
  reports 21/21; `moon info` and `moon check --target all --warn-list +73`
  pass; full backend tests report native 2395/2395, wasm-gc 2055/2055, and js
  2055/2055.~~
- [x] ~~Port the next `cpdftruetype` subset-table writer slice:
  `PdfTrueTypeSubsetTable`, `pdf_truetype_subset_glyph_indices`,
  `pdf_truetype_subset_loca_table`, `pdf_truetype_subset_glyf_table`, and
  `pdf_truetype_subset_cmap_table` now cover the source
  `write_loca_table`, `write_glyf_table`, and implicit-font-file
  `write_cmap_table` prerequisites. The port includes `.notdef` glyph
  retention, Unicode-subset-to-glyph lookup with missing mappings ignored or
  written as glyph `0` for format-6 cmaps, recursive composite expansion,
  original glyph-index preservation through rewritten `loca` gaps, short and
  long `loca` emission, selected `glyf` byte copying, unpadded table lengths,
  and 4-byte table padding. This still does not complete the full
  `subset_font` table-directory rebuild, header offset/size-reduction pass,
  width calculation from selected encodings, `tounicode` generation, or full
  `Cpdftruetype.parse`. Validation on MoonBit 0.9.3:
  `moon check --target native --warn-list +73` passes with only the existing
  `markdown/cmd` warning; `moon test --target native pdf_truetype_test.mbt`
  reports 19/19; `moon info` and `moon check --target all --warn-list +73`
  pass; full backend tests report native 2393/2393, wasm-gc 2053/2053, and js
  2053/2053.~~
- [x] ~~Port the `cpdftruetype` composite-glyph expansion prerequisite:
  `pdf_truetype_expand_composite_glyphs`, `PdfTrueTypeGlyphByteRange`, and
  `pdf_truetype_glyph_byte_ranges` now mirror the source
  `expand_composites`/`expand_composites_one` behavior used before subset
  `loca` and `glyf` table writing. Composite glyphs are detected from negative
  `numberOfContours`, component flags drive argument/transform-byte skipping,
  nested components expand to a stable sorted/deduplicated glyph-index set, and
  byte ranges are reported relative to the `glyf` table start. This still does
  not complete rewritten `loca` emission, actual subset `glyf` byte copying,
  width calculation from selected encodings, subset font writing, or full
  `Cpdftruetype.parse`. Validation on MoonBit 0.9.3:
  `moon check --target native --warn-list +73` passes with only the existing
  `markdown/cmd` warning; `moon test --target native pdf_truetype_test.mbt`
  reports 16/16; `moon check --target all --warn-list +73` passes; full
  backend tests report native 2390/2390, wasm-gc 2050/2050, and js 2050/2050;
  and `moon fmt`, `moon info`, and `git diff --check` are clean.~~
- [x] ~~Port the next `cpdftruetype` parser prerequisites: `PdfTrueTypeDescriptorMetrics`,
  `pdf_truetype_descriptor_metrics`, and `pdf_truetype_loca_offsets` now cover
  the source `OS/2` and `post` descriptor metric reads, source symbolic and
  non-symbolic flag derivation, the required-`OS/2` parser error, optional
  missing-`post` italic-angle default, and `loca` short/long offset decoding
  from `indexToLocFormat` and `numGlyphs`. This moves the remaining parser
  closer to glyph rewriting but still does not complete `glyf` byte extraction,
  composite expansion, width calculation from selected encodings, subset font
  writing, or full `Cpdftruetype.parse`. Validation on MoonBit 0.9.3:
  `moon check --target native --warn-list +73` passes with only the existing
  `markdown/cmd` warning; `moon test --target native pdf_truetype_test.mbt`
  reports 13/13; `moon check --target all --warn-list +73` passes; full
  backend tests report native 2387/2387, wasm-gc 2047/2047, and js 2047/2047;
  and `moon fmt`, `moon info`, and `git diff --check` are clean.~~
- [x] ~~Port the `cpdftruetype` table and metric reader foundation needed by
  later full TrueType parsing/subsetting: `PdfTrueTypeTableRecord`,
  `PdfTrueTypeMetrics`, `pdf_truetype_tables`, `pdf_truetype_table`, and
  `pdf_truetype_metrics` now expose the source table-directory pass including
  checksums plus the `head`, `maxp`, optional `hhea`, and `hmtx` reads used
  before width and glyph rewriting. The reader scales bounding boxes and max
  advance width to PDF units with the source rounding rule, keeps raw advance
  widths for later width calculation, preserves the source optional-`hhea`
  zero-count behavior, and reports missing required tables with `SoftError`.
  This does not complete
  `Cpdftruetype.parse`, `loca`/`glyf` handling, OS/2/post metrics, composite
  expansion, or font subsetting. Validation on MoonBit 0.9.3:
  `moon check --target native --warn-list +73` passes with only the existing
  `markdown/cmd` warning; `moon test --target native pdf_truetype_test.mbt`
  reports 9/9; `moon check --target all --warn-list +73` passes; full backend
  tests report native 2383/2383, wasm-gc 2043/2043, and js 2043/2043; and
  `moon fmt`, `moon info`, and `git diff --check` are clean.~~
- [x] ~~Port the `cpdftruetype` cmap glyph-mapping foundation needed by later
  TrueType subsetting: `PdfTrueTypeCMapGlyph`,
  `pdf_truetype_cmap_glyphs`, and `pdf_truetype_cmap_glyph` now decode the
  source-supported cmap formats 0, 4, and 6, including format-4
  `idRangeOffset` glyph arrays, later-subtable replacement of earlier mappings,
  and the source no-cmap fallback mapping byte codes `0..255` to matching glyph
  indexes. This does not complete `Cpdftruetype.parse` or font-file
  subsetting, but moves the actual cmap reader dependency into MoonBit with a
  public inspection API. Validation on MoonBit 0.9.3: `moon check --target
  native --warn-list +73` passes with only the existing `markdown/cmd`
  warning; `moon test --target native pdf_truetype_test.mbt` reports 6/6;
  `moon check --target all --warn-list +73` passes; full backend tests report
  native 2380/2380, wasm-gc 2040/2040, and js 2040/2040; and `moon fmt`,
  `moon info`, and `git diff --check` are clean.~~
- [x] ~~Port the `cpdfimage.extract_images` file-emission slice:
  `PdfDocument::extract_images_files` and `pdf_image_extract_images_files`
  now emit cpdf-style files for selected page image XObjects, indirect soft
  masks, recursively nested Form XObject images, optional inline images, JBIG2
  globals, cpdf filename expansion, and cpdf's global/per-page indirect-image
  deduplication modes. Native async I/O exposes
  `pdf_extract_images_to_files` plus the source-order `pdf_extract_images`
  wrapper; external PNM-to-PNG conversion and ImageMagick mask composition
  remain deferred with the same source-style missing ImageMagick `SoftError`
  after files are written. Validation on MoonBit 0.9.3: `moon check --target
  native --warn-list +73` passes with only the existing `markdown/cmd`
  warning; focused native tests report 3/3 for
  `pdf_image_test.mbt --filter '*extract_images_files*'` and 2/2 for
  `async_io --filter '*extract *image*'`; `moon check --target all --warn-list
  +73` passes; full native `moon test --target native` reports 2377/2377; and
  `moon fmt`, `moon info`, and `git diff --check` are clean.~~
- [x] ~~Port the `cpdfimage.extract_single_image` file-emission slice:
  `PdfExtractedImageFile`, `PdfDocument::extract_single_image_files`, and
  `pdf_image_extract_single_image_files` now return the cpdf-style files for
  JPEG (`.jpg`), JPEG2000 (`.jpx`), JBIG2 (`.jbig2`, `.jbig2__N`, and
  per-directory `N.jbig2global`), and decoded RGB PNM (`.pnm`) payloads.
  Indirect `/SMask` streams are extracted with the `-smask` stem, injectable
  output names use the existing cpdf guard, and native async I/O exposes
  `pdf_extract_single_image_to_files` plus the source-order
  `pdf_extract_single_image` wrapper. External PNM-to-PNG conversion and actual
  ImageMagick mask composition remain deferred; requesting `merge_masks` with a
  present mask reports the source-style missing ImageMagick `SoftError` after
  writing the extracted files. Validation on MoonBit 0.9.3: `moon check
  --target native --warn-list +73` passes with only the existing
  `markdown/cmd` warning; focused native tests report 2/2 for
  `pdf_image_test.mbt --filter '*extract_single_image_files*'` and 1/1 for
  `async_io --filter '*extract single image*'`; `moon check --target all
  --warn-list +73` passes; `moon test --target native` reports 2373/2373; and
  `moon fmt`, `moon info`, and `git diff --check` are clean.~~
- [x] ~~Continue `cpdfembed` source-surface parity with `.repos/cpdf-source`:
  added `PdfEmbedFontSource` to preserve the source `cpdffont` choice shape,
  `pdf_embed_get_char` as the cpdf-style fontpack lookup alias, and generic
  `pdf_embed_collate_runs` over triples grouped by their middle value. The
  existing concrete `pdf_fontpack_collate_runs` now delegates to the generic
  helper. Full TrueType subsetting/embedding remains a separate implementation
  slice. Validation on MoonBit 0.9.3: `moon check --target native --warn-list
  +73` passes with only the existing `markdown/cmd` warning; `moon test
  --target native pdf_embed_test.mbt` reports 6/6; `moon check --target all
  --warn-list +73` passes; and full native `moon test --target native` reports
  2370/2370.~~
- [x] ~~Port the `cpdfpage` source-order wrapper alias slice:
  `pdf_set_mediabox`, `pdf_shift_boxes_cpdf_order`,
  `pdf_change_boxes_cpdf_order`, `pdf_scale_contents_cpdf_order`, and
  `pdf_upright` now expose cpdf-style argument ordering where existing
  document-first wrappers could not match source order; `PdfDocument` also has
  singular `set_mediabox` and `upright` method aliases. Coverage exercises the
  aliases in the page-box, page-scale, and upright test files. Validation on
  MoonBit 0.9.3 reports `moon check --target native --warn-list +73` passing
  with only the existing `markdown/cmd` warning, targeted native tests at
  `16/16`, `19/19`, and `4/4`, `moon check --target all --warn-list +73`
  passing, and full native `moon test --target native` at 2369/2369.~~
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
- [x] ~~Port the implemented page-content overlay part of `cpdfredact`:
  `show_bounding_boxes` now first applies annotation boxes, then draws
  cpdf-style content-object bounding boxes with source colour choices and an
  optional rectangle filter, including the compatibility wrapper
  `pdf_show_bounding_boxes`. Coverage pins exact generated path-content box
  operators, selected-page behavior, wrapper invocation, light/fast mode, and
  shape filtering that suppresses non-matching boxes. Focused native validation
  reports `moon test --target native pdf_redact_test.mbt --filter '*page content
  rectangles*'` at 1/1 test passing; widened native validation reports `moon
  test --target native pdf_redact_test.mbt` at 5/5 tests passing. Native check
  validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at the
  known 10-warning baseline. Full native suite validation is deferred to the
  next batch.~~
- [x] ~~Port the first bounded `cpdfua` Matterhorn validation slice:
  `test_matterhorn_json`, `test_matterhorn_text`, and compatibility wrappers
  now cover source checks `01-003`, `01-004`, `01-005`, and `01-007`,
  including page and Form XObject content-marker scanning, unmarked real
  content detection with cpdf's clipping-path filter, malformed empty `EMC`
  reporting, `/MarkInfo /Suspects true`, and explicit soft errors for
  unsupported individual Matterhorn names until the rest of the protocol is
  ported. Focused native validation reports `moon test --target native
  pdf_ua_matterhorn_test.mbt --filter '*test_matterhorn*'` at 5/5 tests passing;
  widened native validation reports `moon test --target native
  pdf_ua_matterhorn_test.mbt` at 5/5 tests passing. Native check validation
  reports `moon check --target native` passing with the known `markdown/cmd`
  warning and `moon check --target native --warn-list +73` at the known
  10-warning baseline; `moon info` and `moon fmt` were run to update the public
  interface summary and formatting. Full native suite validation is deferred to
  the next batch.~~
- [x] ~~Port the `cpdfua` Matterhorn XMP metadata and viewer-preference slice:
  the public Matterhorn JSON/text surface now also covers source checks
  `06-001`, `06-002`, `06-003`, `07-001`, and `07-002`, preserving cpdf's
  behavior that missing metadata reports only `06-001` while missing
  `pdfuaid:part` and `dc:title` are reported only when an XMP metadata stream
  exists. ViewerPreferences checks now distinguish absent `/DisplayDocTitle`
  from explicit `false`, and the covered `""` subset includes the new checks in
  source order. Focused native validation reports `moon test --target native
  pdf_ua_matterhorn_test.mbt --filter '*metadata*'` at 2/2 tests passing;
  widened native validation reports `moon test --target native
  pdf_ua_matterhorn_test.mbt` at 9/9 tests passing. Native check validation
  reports `moon check --target native` passing with the known `markdown/cmd`
  warning and `moon check --target native --warn-list +73` at the known
  10-warning baseline; `moon info` and `moon fmt` were run to update generated
  interfaces and formatting. Batched full native validation reports `moon test
  --target native` at 1991/1991 tests passing.~~
- [x] ~~Port the `cpdfua` Matterhorn role-map slice:
  the covered Matterhorn surface now includes source checks `02-001`,
  `02-003`, and `02-004`, including non-standard mappings that fail to
  terminate at a PDF/UA-1 standard structure type, circular role-map detection,
  and standard structure types remapped as keys. The cpdf runner's circularity
  precheck is preserved: any implemented Matterhorn request on a document with
  a circular role map returns the `02-003` stop failure before running the
  selected checks. Text output now emits Matterhorn error strings as UTF-8 so
  the source `02-001` diagnostic is preserved. Focused native validation
  reports `moon test --target native pdf_ua_matterhorn_test.mbt --filter
  '*role map*'` at 2/2 tests passing and `moon test --target native
  pdf_ua_matterhorn_test.mbt --filter '*remapping*'` at 1/1 test passing;
  widened native validation reports `moon test --target native
  pdf_ua_matterhorn_test.mbt` at 12/12 tests passing. Native check validation
  reports `moon check --target native` passing with the known `markdown/cmd`
  warning and `moon check --target native --warn-list +73` at the known
  10-warning baseline; `moon info` and `moon fmt` were run to update generated
  interfaces and formatting. Full native suite validation is deferred to the
  next batch.~~
- [x] ~~Port the `cpdfua` Matterhorn optional-content configuration slice:
  the covered Matterhorn surface now includes source checks `20-001`,
  `20-002`, and `20-003`, preserving cpdf's direct catalog inspection of
  `/OCProperties /Configs` and `/OCProperties /D`. Coverage pins missing and
  empty config `/Name` entries, missing versus empty default configuration
  `/Name` diagnostics, and forbidden `/AS` entries in both default and alternate
  optional-content configuration dictionaries. Focused native validation reports
  `moon test --target native pdf_ua_matterhorn_test.mbt --filter '*optional
  content*'` at 3/3 tests passing; widened native validation reports `moon test
  --target native pdf_ua_matterhorn_test.mbt` at 15/15 tests passing. Native
  check validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at
  the known 10-warning baseline; `moon info` and `moon fmt` were run to update
  generated interfaces and formatting. Full native suite validation is deferred
  to the next batch.~~
- [x] ~~Port the `cpdfua` Matterhorn reference-XObject slice:
  the covered Matterhorn surface now includes source check `30-001`, detecting
  parsed Form XObjects with a `/Ref` entry while ignoring non-Form objects and
  ordinary Form XObjects without `/Ref`. Focused native validation reports
  `moon test --target native pdf_ua_matterhorn_test.mbt --filter '*reference
  XObjects*'` at 1/1 test passing; widened native validation reports `moon test
  --target native pdf_ua_matterhorn_test.mbt` at 16/16 tests passing. Native
  check validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at
  the known 10-warning baseline; `moon info` and `moon fmt` were run to update
  generated interfaces and formatting. Batched full native validation reports
  `moon test --target native` at 1998/1998 tests passing.~~
- [x] ~~Port the `cpdfua` Matterhorn media-clip and PrinterMark slice:
  the covered Matterhorn surface now includes source checks `28-014`,
  `28-015`, `28-016`, and `28-017`, preserving cpdf's object traversal for
  media clip data dictionaries and PrinterMark annotations. Check `28-015`
  intentionally matches the source implementation by testing the same missing
  `/CT` condition as `28-014`, despite its Matterhorn label mentioning `/Alt`;
  check `28-016` remains the source no-op covered elsewhere. Coverage pins both
  `28-014` and `28-015` on `/Type /MediaClip` plus `/S /MCD` without `/CT`,
  verifies adding `/CT` clears both failures, confirms `28-016` returns no
  failures, and detects `/Subtype /PrinterMark` only when `/StructParent` is
  present. Focused native validation reports
  `moon test --target native pdf_ua_matterhorn_test.mbt --filter '*media
  clip*'`, `moon test --target native pdf_ua_matterhorn_test.mbt --filter
  '*PrinterMark*'`, and `moon test --target native pdf_ua_matterhorn_test.mbt
  --filter '*file attachment*'` at 1/1 test passing each; widened native
  validation reports `moon test --target native pdf_ua_matterhorn_test.mbt` at
  19/19 tests passing. Native check validation reports
  `moon check --target native` passing with the known `markdown/cmd` warning
  and `moon check --target native --warn-list +73` at the known 10-warning
  baseline. Batched full native validation after the next two Matterhorn slices
  reports `moon test --target native` at 2003/2003 tests passing.~~
- [x] ~~Port the `cpdfua` Matterhorn PrinterMark appearance slice:
  the covered Matterhorn surface now includes source check `28-018`, following
  `/AP /N` from PrinterMark annotations and scanning both direct normal
  appearance streams and dictionary-valued normal appearances. The port
  preserves cpdf's exact `Cpdftype.add_artifacts ops <> ops` comparison rather
  than replacing it with a separate artifact predicate. Coverage pins an
  unmarked direct `/N` appearance stream, an unmarked dictionary `/N`
  appearance stream, and a marked-content appearance stream that remains
  unchanged by the source comparison. Focused native validation reports
  `moon test --target native pdf_ua_matterhorn_test.mbt --filter '*PrinterMark
  appearance*'` at 1/1 test passing; widened native validation reports `moon
  test --target native pdf_ua_matterhorn_test.mbt` at 20/20 tests passing.
  Native check validation reports `moon check --target native` passing with the
  known `markdown/cmd` warning and `moon check --target native --warn-list +73`
  at the known 10-warning baseline. Batched full native validation after the
  following Matterhorn slice reports `moon test --target native` at 2003/2003
  tests passing.~~
- [x] ~~Port the `cpdfua` Matterhorn repeated Form XObject MCID slice:
  the covered Matterhorn surface now includes source check `30-002`, parsing
  Form XObject content streams to find marked-content dictionaries with `/MCID`,
  materializing inherited page resources via `replace_inherit`, and failing when
  an MCID-bearing Form XObject is referenced more than once from page or Form
  XObject `/Resources /XObject` dictionaries. Coverage pins a page-plus-Form
  repeated indirect reference failure, a single-reference pass, and a repeated
  non-MCID Form XObject pass. Focused native validation reports `moon test
  --target native pdf_ua_matterhorn_test.mbt --filter '*multiply referenced*'`
  at 1/1 test passing; widened native validation reports `moon test --target
  native pdf_ua_matterhorn_test.mbt` at 21/21 tests passing. Native check
  validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at
  the known 10-warning baseline. Batched full native validation reports `moon
  test --target native` at 2003/2003 tests passing.~~
- [x] ~~Port the `cpdfua` Matterhorn Type 0 CIDSystemInfo registry/ordering
  slice: the covered Matterhorn surface now includes source checks `31-001`,
  `31-002`, and `31-003`, preserving cpdf's indirect-CMap-only path and its
  skip for `/Identity-H` and `/Identity-V` encodings. Coverage pins registry
  mismatch and ordering mismatch failures, identity encoding bypass behavior,
  a matching CIDSystemInfo pass, and the source `31-003` behavior comparing
  the CMap `/Registry` against the descendant CIDFont `/Ordering` despite its
  Supplement-label diagnostic. Focused native validation reports `moon test
  --target native pdf_ua_matterhorn_test.mbt --filter '*CIDSystemInfo*'` at
  1/1 test passing; widened native validation reports `moon test --target
  native pdf_ua_matterhorn_test.mbt` at 22/22 tests passing. Native check
  validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at
  the known 10-warning baseline. Full native suite validation is deferred to
  the next batch.~~
- [x] ~~Port the `cpdfua` Matterhorn Type 2 CIDToGIDMap slice: the covered
  Matterhorn surface now includes source checks `31-004` and `31-005`,
  preserving cpdf's object traversal over `/CIDFontType2` dictionaries and its
  acceptance of either `/CIDToGIDMap /Identity` or a stream object. Coverage
  pins the source `31-004` serialized-object extra for missing and invalid map
  values, the separate `31-005` missing-entry failure, valid identity and stream
  map passes, and non-Type2 bypass behavior. Focused native validation reports
  `moon test --target native pdf_ua_matterhorn_test.mbt --filter
  '*CIDToGIDMap*'` at 1/1 test passing; widened native validation reports
  `moon test --target native pdf_ua_matterhorn_test.mbt` at 23/23 tests passing.
  Native check validation reports `moon check --target native` passing with the
  known `markdown/cmd` warning and `moon check --target native --warn-list +73`
  at the known 10-warning baseline. Batched full native validation reports
  `moon test --target native` at 2005/2005 tests passing.~~
- [x] ~~Port the `cpdfua` Matterhorn CMap-name validation slice: the covered
  Matterhorn surface now includes source checks `31-006` and `31-008`,
  preserving cpdf's Table 118 predefined CMap name list, its Type0-only named
  `/Encoding` path for `31-006`, its document-wide `/UseCMap` name scan for
  `31-008`, and the source behavior that embedded/non-name CMap references
  pass these checks. Coverage pins unlisted-name failures with the offending
  name as extra JSON, listed-name passes, embedded/non-name passes, and
  non-Type0 bypass behavior. Focused native validation reports `moon test
  --target native pdf_ua_matterhorn_test.mbt --filter '*CMap names*'` at 1/1
  test passing; widened native validation reports `moon test --target native
  pdf_ua_matterhorn_test.mbt` at 24/24 tests passing. Native check validation
  reports `moon check --target native` passing with the known `markdown/cmd`
  warning and `moon check --target native --warn-list +73` at the known
  10-warning baseline. Full native suite validation is deferred to the next
  batch.~~
- [x] ~~Port the `cpdfua` Matterhorn CMap WMode slice: the covered Matterhorn
  surface now includes source check `31-007`, comparing the `/WMode` integer in
  a CMap stream dictionary against the WMode value parsed from the stream body
  without using the higher-level parser's dictionary-metadata merge. Coverage
  pins mismatch failures, matching WMode passes, the source-compatible stream
  default of `0` when the body omits WMode, and the no-dictionary-WMode bypass.
  Focused native validation reports `moon test --target native
  pdf_ua_matterhorn_test.mbt --filter '*WMode*'` at 1/1 test passing; widened
  native validation reports `moon test --target native
  pdf_ua_matterhorn_test.mbt` at 25/25 tests passing. Native check validation
  reports `moon check --target native` passing with the known `markdown/cmd`
  warning and `moon check --target native --warn-list +73` at the known
  10-warning baseline. Full native suite validation is deferred to the next
  batch.~~
- [x] ~~Port the source-unimplemented `cpdfua` Matterhorn font-file checks:
  source-listed checks `31-011`, `31-012`, `31-013`, `31-014`, `31-015`,
  `31-016`, `31-018`, and `31-030` now behave like cpdf's caught
  `MatterhornUnimplemented` cases by returning no failures instead of raising
  an unsupported-test soft error. Coverage pins individual requests for each
  check returning an empty JSON array. Focused native validation reports `moon
  test --target native pdf_ua_matterhorn_test.mbt --filter '*no-op font-file*'`
  at 1/1 test passing; widened native validation reports `moon test --target
  native pdf_ua_matterhorn_test.mbt` at 26/26 tests passing. Native check
  validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at
  the known 10-warning baseline. Batched full native validation reports `moon
  test --target native` at 2008/2008 tests passing.~~
- [x] ~~Pin the cpdf source spelling edge in Matterhorn CMap-name checks:
  source-listed `/KSCms-UHS-HW-V` remains accepted by `31-006` and `31-008`,
  while the corrected-looking `/KSCms-UHC-HW-V` remains rejected, matching the
  literal `cpdfua.ml` `cmap_names` table. Focused native validation reports
  `moon test --target native --package bobzhang/pdflite --file
  pdf_ua_matterhorn_test.mbt --filter '*CMap names*'` at 1/1 tests passing;
  widened native validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_ua_matterhorn_test.mbt` at 48/48 tests passing;
  native full-suite validation reports 2143/2143 tests passing.~~
- [x] ~~Port the `cpdfua` Matterhorn non-symbolic TrueType encoding dictionary
  slice: the covered Matterhorn surface now includes source checks `31-019`,
  `31-020`, `31-021`, and `31-022`, preserving cpdf's `/Flags & 4`
  non-symbolic test and its missing-flag/missing-descriptor non-symbolic
  fallback. Coverage pins missing `/Encoding`, symbolic bypass, missing
  `/BaseEncoding`, valid MacRoman/WinAnsi base encodings, invalid named and
  dictionary base encodings, and `/Differences` glyph names checked against the
  existing exact Adobe Glyph List resolver. Focused native validation reports `moon
  test --target native pdf_ua_matterhorn_test.mbt --filter '*TrueType
  encoding*'` at 1/1 test passing; widened native validation reports `moon test
  --target native pdf_ua_matterhorn_test.mbt` at 27/27 tests passing. Native
  check validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at
  the known 10-warning baseline. Full native suite validation is deferred to the
  next batch.~~
- [x] ~~Port the `cpdfua` Matterhorn TrueType cmap and symbolic-font slice: the
  covered Matterhorn surface now includes source checks `31-017`, `31-023`,
  `31-024`, `31-025`, and `31-026`, using decoded `/FontFile2` bytes with the
  existing `pdf_truetype_cmaps` parser. The source quirk in `31-017` is
  preserved: despite its non-symbolic diagnostic, cpdf checks symbolic TrueType
  fonts and reports non-symbolic cmap entries. Coverage pins missing `(3,1)`
  Microsoft Unicode cmap failures, font-file absence bypass behavior, symbolic
  `/Encoding` failures, no-cmap symbolic font failures, symbolic-only cmap
  passes, and multi-cmap symbolic fonts without `(3,0)` failures. Focused
  native validation reports `moon test --target native
  pdf_ua_matterhorn_test.mbt --filter '*TrueType cmap*'` at 1/1 test passing;
  widened native validation reports `moon test --target native
  pdf_ua_matterhorn_test.mbt` at 28/28 tests passing. Native check validation
  reports `moon check --target native` passing with the known `markdown/cmd`
  warning and `moon check --target native --warn-list +73` at the known
  10-warning baseline. Full native suite validation is deferred to the next
  batch.~~
- [x] ~~Port the `cpdfua` Matterhorn ToUnicode forbidden-value slice: the
  covered Matterhorn surface now includes source checks `31-028` and `31-029`,
  preserving cpdf's indirect-only `/ToUnicode` object scan before parsing CMap
  UTF-16BE mappings. Coverage pins zero-codepoint failures, `U+FEFF` and
  `U+FFFE` failures, normal Unicode passes, and the source-compatible direct
  `/ToUnicode` stream bypass. Focused native validation reports `moon test
  --target native pdf_ua_matterhorn_test.mbt --filter '*ToUnicode value*'` at
  1/1 test passing; widened native validation reports `moon test --target
  native pdf_ua_matterhorn_test.mbt` at 29/29 tests passing. Native check
  validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at
  the known 10-warning baseline. Batched full native validation reports `moon
  test --target native` at 2011/2011 tests passing.~~
- [x] ~~Port the `cpdfua` Matterhorn missing-font embedding slice: the covered
  Matterhorn surface now includes source check `31-009`, reusing the existing
  cpdf-compatible `missing_fonts` page-resource scan over all document pages
  and preserving cpdf's space-separated list entries in the Matterhorn `extra`
  array. Coverage pins unembedded Type 1 fonts, descriptor-without-font-file
  failures, Type 3 exclusion, embedded `/FontFile2` passes, Built-in encoding
  fallback, and named encoding output. Focused native validation reports `moon
  test --target native pdf_ua_matterhorn_test.mbt --filter '*missing fonts*'`
  at 1/1 test passing; widened native validation reports `moon test --target
  native pdf_ua_matterhorn_test.mbt` at 30/30 tests passing. Native check
  validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at
  the known 10-warning baseline. Full native suite validation is deferred to
  the next batch.~~
- [x] ~~Port the `cpdfua` Matterhorn missing-ToUnicode exemption slice: the
  covered Matterhorn surface now includes source check `31-027`, preserving
  cpdf's named-encoding exemption, Type 0 Adobe-GB1/CNS1/Japan1/Korea1
  descendant exemption, broad non-symbolic-font exemption, CID-font silent
  branch, and caught Type1/Type3 referenced-glyph unimplemented branch.
  Coverage pins a symbolic TrueType missing-ToUnicode failure with serialized
  object `extra`, direct `/ToUnicode` pass, WinAnsi pass, Type 0 collection
  pass, CID-font silent pass, and source-compatible Type 1 no-failure behavior.
  Focused native validation reports `moon test --target native pdf_ua_matterhorn_test.mbt
  --filter '*missing ToUnicode*'` at 1/1 test passing; widened native
  validation reports `moon test --target native pdf_ua_matterhorn_test.mbt` at
  31/31 tests passing. Native check validation reports `moon check --target
  native` passing with the known `markdown/cmd` warning and `moon check
  --target native --warn-list +73` at the known 10-warning baseline. Full
  native suite validation is deferred to the next batch.~~
- [x] ~~Port the `cpdfua` Matterhorn embedded file-spec slice: the covered
  Matterhorn surface now includes source check `21-001`, checking document name
  tree embedded file specs and page `/FileAttachment` annotation `/FS`
  dictionaries for both `/F` and `/UF` entries while preserving cpdf's no-failure
  behavior for file-attachment annotations without `/FS`. Coverage pins missing
  `/UF` failures from both the `/EmbeddedFiles` name tree and page annotations,
  valid `/F` plus `/UF` passes, and no-`/FS` annotation passes. Focused native
  validation reports `moon test --target native pdf_ua_matterhorn_test.mbt
  --filter '*embedded file specs*'` at 1/1 test passing; widened native
  validation reports `moon test --target native pdf_ua_matterhorn_test.mbt` at
  32/32 tests passing. Native check validation reports `moon check --target
  native` passing with the known `markdown/cmd` warning and `moon check
  --target native --warn-list +73` at the known 10-warning baseline. Batched
  full native validation reports `moon test --target native` at 2014/2014 tests
  passing.~~
- [x] ~~Port the `cpdfua` Matterhorn encryption-permission slice: the covered
  Matterhorn surface now includes source checks `26-001` and `26-002`,
  preserving cpdf's no-op behavior for missing `/P` and checking decrypted
  documents' saved encryption permission mask for denied extraction
  (`PdfNoExtract`). Coverage pins plain-document passes, the `26-001` no-op,
  `PdfNoExtract` failure after decryption, and unrelated denied permissions
  passing. Focused native validation reports `moon test --target native
  pdf_ua_matterhorn_test.mbt --filter '*encryption permissions*'` at 1/1 test
  passing; widened native validation reports `moon test --target native
  pdf_ua_matterhorn_test.mbt` at 33/33 tests passing. Native check validation
  reports `moon check --target native` passing with the known `markdown/cmd`
  warning and `moon check --target native --warn-list +73` at the known
  10-warning baseline. Full native suite validation is deferred to the next
  batch.~~
- [x] ~~Port the `cpdfua` Matterhorn XFA dynamicRender slice: the covered
  Matterhorn surface now includes source check `25-001`, scanning the single
  `/AcroForm /XFA` `config` packet stream for a `dynamicRender` element whose
  direct text is exactly `required`, including namespace-prefixed tags.
  Coverage pins direct and prefixed failures, non-required and whitespace-padded
  text passes, duplicate `config` packet and non-array `/XFA` no-failure
  behavior, and non-stream config passes. Focused native validation reports
  `moon test --target native
  pdf_ua_matterhorn_test.mbt --filter '*dynamicRender*'` at 1/1 test passing;
  widened native validation reports `moon test --target native
  pdf_ua_matterhorn_test.mbt` at 34/34 tests passing. Native check validation
  reports `moon check --target native` passing with the known `markdown/cmd`
  warning and `moon check --target native --warn-list +73` at the known
  10-warning baseline. Full native suite validation is deferred to the next
  batch.~~
- [x] ~~Port the `cpdfua` Matterhorn basic annotation slice: the covered
  Matterhorn surface now includes source checks `28-006` through `28-009`,
  reusing the parsed page-annotation path to detect undefined annotation
  subtypes and `/TrapNet`, and checking pages with annotations for missing
  `/Tabs` or `/Tabs` values other than `/S`. Coverage pins custom subtype
  failures, valid `/Link` passes, `/TrapNet` failures, missing `/Tabs`
  failures, no-annotation passes, `/Tabs /R` failures, `/Tabs /S` passes, and
  source-compatible no-failure behavior for `28-009` when `/Tabs` is absent.
  Focused native validation reports `moon test --target native
  pdf_ua_matterhorn_test.mbt --filter '*annotation subtype and tabs*'` at 1/1
  test passing; widened native validation reports `moon test --target native
  pdf_ua_matterhorn_test.mbt` at 35/35 tests passing. Native check validation
  reports `moon check --target native` passing with the known `markdown/cmd`
  warning and `moon check --target native --warn-list +73` at the known
  10-warning baseline. Batched full native validation reports `moon test
  --target native` at 2017/2017 tests passing.~~
- [x] ~~Port the `cpdfua` Matterhorn link-annotation contents slice: the
  covered Matterhorn surface now includes source check `28-012`, reusing parsed
  page annotations and failing only for `/Link` annotations without a
  `/Contents` alternate description. Coverage pins missing-contents failures,
  `/Contents` passes, and non-link no-failure behavior. Focused native
  validation reports `moon test --target native pdf_ua_matterhorn_test.mbt
  --filter '*link annotation contents*'` at 1/1 test passing; widened native
  validation reports `moon test --target native pdf_ua_matterhorn_test.mbt` at
  36/36 tests passing. Native check validation reports `moon check --target
  native` passing with the known `markdown/cmd` warning and `moon check
  --target native --warn-list +73` at the known 10-warning baseline. Full
  native suite validation is deferred to the next batch.~~
- [x] ~~Port the `cpdfua` Matterhorn annotation structure-parent slice: the
  covered Matterhorn surface now includes source checks `28-010` and `28-011`,
  scanning parsed objects for `/Widget` and `/Link` annotations, reading the
  catalog `/StructTreeRoot` `/ParentTree` number tree, requiring widgets to
  resolve to `/S /Form`, and requiring linked structure entries to resolve to
  `/S /Link` while preserving source-compatible no-failure behavior for links
  without `/StructParent`. Coverage pins widget missing-`/StructParent`
  failures, wrong parent structure types, missing parent-tree entries, valid
  widget parents, link no-`/StructParent` passes, wrong link parent structure
  types, valid link parents, and missing link parent-tree entries with the
  source `merror_str` extras. Focused native validation reports `moon test
  --target native pdf_ua_matterhorn_test.mbt --filter '*annotation structure
  parents*'` at 1/1 test passing; widened native validation reports `moon test
  --target native pdf_ua_matterhorn_test.mbt` at 37/37 tests passing. Native
  check validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at
  the known 10-warning baseline. Full native suite validation is deferred to the
  next batch.~~
- [x] ~~Port the `cpdfua` Matterhorn annotation `/Annot` parent slice: the
  covered Matterhorn surface now includes source check `28-002`, scanning
  parsed annotation objects for the source subtype set and requiring matching
  annotations to resolve through `/StructParent` and the catalog parent tree to
  a structure element with `/S /Annot`. Coverage pins missing `/StructParent`
  failures, wrong structure types, missing parent-tree entries, valid `/Annot`
  parents, the `/Link`/`/Widget`/`/PrinterMark` exemptions, and the
  source-compatible `/Square` no-failure behavior from cpdf's exact subtype
  pattern. Focused native validation reports `moon test --target native
  pdf_ua_matterhorn_test.mbt --filter '*annotation Annot parents*'` at 1/1 test
  passing; widened native validation reports `moon test --target native
  pdf_ua_matterhorn_test.mbt` at 38/38 tests passing. Batched full native
  validation reports `moon test --target native` at 2020/2020 tests passing.
  Native check validation reports `moon check --target native` passing with the
  known `markdown/cmd` warning and `moon check --target native --warn-list +73`
  at the known 10-warning baseline.~~
- [x] ~~Port the `cpdfua` Matterhorn annotation Contents-or-Alt slice: the
  covered Matterhorn surface now includes source check `28-004`, scanning
  parsed annotation objects for cpdf's exact source subtype set plus `/Link`
  and `/PrinterMark`, accepting any direct `/Contents`, accepting structured
  annotations only when the enclosing parent-tree element has `/Alt`, and
  preserving source-compatible no-failure behavior for unstructured annotations,
  `/Widget`, and `/Square`. Coverage pins unstructured passes, missing `/Alt`
  failures, missing parent-tree entry failures, direct `/Contents` passes,
  structure `/Alt` passes, `/Link` missing-`/Alt` failures, `/Widget`
  exemptions, and the source `/Square` pattern behavior. Focused native
  validation reports `moon test --target native pdf_ua_matterhorn_test.mbt
  --filter '*annotation Contents or Alt*'` at 1/1 test passing; widened native
  validation reports `moon test --target native pdf_ua_matterhorn_test.mbt` at
  39/39 tests passing. Native check validation reports `moon check --target
  native` passing with the known `markdown/cmd` warning and `moon check
  --target native --warn-list +73` at the known 10-warning baseline. Full
  native suite validation is deferred to the next batch.~~
- [x] ~~Port the `cpdfua` Matterhorn form-field TU slice: the covered
  Matterhorn surface now includes source check `28-005` as an explicit
  source-compatible no-op, preserving cpdf's current unreachable failure path
  where field object numbers are first filtered to objects with `/T` and then
  checked for missing `/T`. Coverage pins a real AcroForm field with `/T`,
  missing `/TU`, and a structure parent without `/Alt` as a no-failure case.
  Focused native validation reports `moon test --target native
  pdf_ua_matterhorn_test.mbt --filter '*source no-op form field TU*'` at 1/1
  test passing; widened native validation reports `moon test --target native
  pdf_ua_matterhorn_test.mbt` at 40/40 tests passing. Native check validation
  reports `moon check --target native` passing with the known `markdown/cmd`
  warning and `moon check --target native --warn-list +73` at the known
  10-warning baseline. Full native suite validation is deferred to the next
  batch.~~
- [x] ~~Port the `cpdfua` Matterhorn natural-language slice: the covered
  Matterhorn surface now includes source check `11-001`, matching cpdf's
  top-level catalog `/Lang` behavior and `merror_str` extras for missing and
  empty language strings, plus source-compatible no-op handling for
  `MatterhornUnimplemented` checks `11-002` through `11-006`. Coverage pins
  missing `/Lang`, empty `/Lang`, valid `/Lang`, aggregate `""` failure ordering
  after adding the language check, and individual no-failure behavior for
  `11-002` through `11-006`. Focused native validation reports `moon test
  --target native pdf_ua_matterhorn_test.mbt --filter '*language*'` at 2/2
  tests passing; widened native validation reports `moon test --target native
  pdf_ua_matterhorn_test.mbt` at 42/42 tests passing. Batched full native
  validation reports `moon test --target native` at 2024/2024 tests passing.
  Native check validation reports `moon check --target native` passing with the
  known `markdown/cmd` warning and `moon check --target native --warn-list +73`
  at the known 10-warning baseline.~~
- [x] ~~Port the current stub/no-op redaction APIs from `cpdfredact`: `redact`
  is exposed as `redact_path`/`pdf_redact` and preserves page content while
  validating the selected page range, while `apply` and `apply_type` are
  exposed as explicit no-op `apply_redactions`/`pdf_apply_redactions` and
  `apply_redaction_type`/`pdf_apply_redaction_type` helpers. Coverage pins
  no-op content preservation, wrapper parity, invalid-page diagnostics for
  `redact_path`, and no-op apply calls. `moon test --target native --package
  bobzhang/pdflite --file pdf_redact_test.mbt` reports 4/4 tests passing;
  native full-suite validation reports 1760/1760 tests passing.~~
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
- [x] ~~Replacement-scope port note for vendored `cpdfyojson.ml` and
  `cpdfxmlm.ml`: pdflite does not clone the general Yojson/Xmlm libraries;
  their cpdf call sites are covered by MoonBit `Json` plus targeted CPDFJSON
  and XMP/XML helpers. Coverage pins single-object and document CPDFJSON
  import/export, parsed content-stream JSON arrays, stream-data elision,
  clean/UTF-8 string wrappers, metadata/XMP report JSON, namespace-aware XMP
  field extraction and rewrite, RDF list extraction, XML escaping, and PDF/UA
  metadata generation. Native focused validation reports `moon test --target
  native pdf_util_test.mbt` at 25/25 tests passing,
  `moon test --target native pdf_metadata_test.mbt` at 19/19 tests passing,
  and `moon test --target native pdf_create_test.mbt` at 5/5 tests passing;
  native full-suite validation reports 1724/1724 tests passing.~~
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
- [x] ~~`cpdfcomposition` bucket classification now also has a native compressed
  reader-boundary gate using a source-shaped document with image, font
  descriptor, page content, form XObject content, structure tree, and piece-info
  objects. The gate verifies cpdf bucket order, byte accounting, JSON blob
  parity, and stable write/read/reread behavior. `moon test --target native
  pdf_native_acceptance_test.mbt` reports 91/91 tests passing, `moon test
  --target native` reports 2203/2203 tests passing, and `moon check --target all
  --warn-list +73` completes with the known warning-73/main-package warnings and
  no errors.~~
- [x] ~~Port `cpdfxobject.stamp_as_xobject` with overlay first-page Form XObject
  creation, resource prefixing, selected-page `/XObject` insertion, base
  bookmark retargeting after page-tree rebuild, trailer `/ID` preservation, and
  empty-overlay rejection coverage. `moon test --target native` now reports
  1604/1604 tests passing.~~
- [x] ~~Port `cpdfimage.images` selected-page JSON listing with image XObject
  rows, soft/explicit mask discovery, CCITT/JBIG2 filter-name normalization,
  optional inline-image rows, UTF-8 JSON byte output, and compatibility
  wrappers. Coverage pins soft-mask rows, wrapper/blob parity, invalid-page
  handling, and Form XObject inline gating. Native focused validation reports
  `moon test --target native --package bobzhang/pdflite --file
  pdf_image_test.mbt` at 41/41 tests passing; native full-suite validation
  reports 1766/1766 tests passing.~~
- [x] ~~Port `cpdfimage.image_resolution` and JSON reporting with selected-page
  XObject DPI rows, CTM/q/Q tracking, Form XObject recursion, optional inline
  image reporting, threshold filtering, JSON/UTF-8 byte output, and
  compatibility wrappers. Coverage pins direct image DPI, threshold filtering,
  inline opt-in behavior, JSON/blob parity, and nested Form XObject transforms.
  Native focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_image_test.mbt` at 44/44 tests passing; native
  full-suite validation reports 1769/1769 tests passing.~~
- [x] ~~Port the standalone `cpdfimage.obj_of_jbig2_data` branch with cpdf's
  byte-offset dimension extraction, `/JBIG2Decode` image dictionaries,
  optional `/JBIG2Globals` decode parameters, fixed object `10000` globals
  streams, JBIG2 single-page document assembly, and short-data error coverage.
  `moon test --target native` now reports 1601/1601 tests passing.~~
- [x] ~~Port the standalone image metadata modules `cpdfjpeg.ml`,
  `cpdfjpeg2000.ml`, and `cpdfpng.ml` as in-memory parsers exposing
  JPEG/JPEG2000 dimension readers and PNG IHDR/IDAT parsing. Coverage pins
  JFIF and Exif APP headers, SOF0 scanning over intermediate JPEG segments,
  progressive/malformed/truncated JPEG errors, JP2 signature validation,
  byte-by-byte JPEG2000 `ihdr` scanning, missing/truncated JPEG2000 errors,
  PNG IHDR parsing, split-IDAT concatenation, palette/interlace rejection, and
  image XObject reuse. Native focused validation reports `moon test --target
  native pdf_jpeg_test.mbt` at 7/7 tests passing,
  `moon test --target native pdf_jpeg2000_test.mbt` at 3/3 tests passing, and
  `moon test --target native pdf_image_test.mbt` at 39/39 tests passing; native
  full-suite validation reports 1724/1724 tests passing. The ImageMagick
  `cpdfjpeg.backup_jpeg_dimensions` path remains covered by the optional
  external-tool integration backlog.~~
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
- [x] ~~Port the PDF/UA XMP marker helpers from `cpdfua`: `mark`,
  `mark2`, and `remove_mark` are exposed as copy-returning
  `mark_pdfua1`, `mark_pdfua2`, and `remove_pdfua_mark` methods plus
  cpdf-style wrappers. The implementation creates missing metadata,
  removes existing PDF/UA `part`/`rev`/`amd`/`corr` fields before inserting a
  fresh RDF description marker, preserves source documents, and keeps metadata
  streams when removing markers. `moon test --target native --package
  bobzhang/pdflite --file pdf_create_test.mbt` reports 7/7 tests passing;
  native full-suite validation reports 1762/1762 tests passing.~~
- [x] ~~Port the JSON structure-tree helpers from `cpdfua`:
  `extract_struct_tree` exports the cpdf header row plus referenced structure
  objects while avoiding `/Pg`, `/Obj`, `/Stm`, and `/StmOwn` edges, and
  `replace_struct_tree` imports positive object replacements plus nonpositive
  new-object rows with indirect-reference rewriting. UTF-8 JSON byte wrappers
  and cpdf-style compatibility wrappers are included. `moon test --target
  native --package bobzhang/pdflite --file pdf_structure_test.mbt` reports
  11/11 tests passing; native full-suite validation reports 1764/1764 tests
  passing.~~
- [x] ~~Port `cpdfua.print_struct_tree` as byte-returning structure-tree text
  rendering: the MoonBit API now follows `/StructTreeRoot` `/K` children,
  applies `/RoleMap` rewriting, prunes empty marked-content leaves, appends
  page numbers from `/Pg`, and emits the same tree branch glyphs as
  `Cpdfprinttree`. Focused native structure tests report 12/12 passing; native
  full-suite validation reports 1770/1770 tests passing.~~
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
- [x] ~~Port the `cpdfembed.load_substitute` Standard 14 filename table as pure
  helpers: `pdf_standard_font_substitute_filenames` and
  `pdf_standard_font_substitute_font_name` now expose cpdf's URW substitute
  filename mapping and extension-stripped font names, leaving filesystem loading
  to a later file-IO/native boundary. Focused validation reports `moon test
  --target native --package bobzhang/pdflite --file pdf_embed_test.mbt` at
  5/5 tests passing; native full-suite validation reports 1887/1887 tests
  passing.~~
- [x] ~~Close the `cpdfembed.load_substitute` file-IO boundary: native
  `async_io` now exposes `pdf_load_standard_font_substitute_file`, joining the
  requested directory with cpdf's URW substitute filename, reading the font
  bytes, and returning the extension-stripped font name. Focused validation
  reports `moon test --target native async_io --filter 'async file wrappers load
  Standard 14 substitute font files'` at 1/1 test passing, and native full-suite
  validation reports 2205/2205 tests passing.~~
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
- [x] ~~Add optional `.repos/cpdf-source` raw PNG input coverage: the native
  image fixture now reads `manualimages/sheet.png`, verifies the 400x294 RGB
  PNG metadata, creates a single-page PDF image document from the source bytes,
  extracts RGB24 pixels, and preserves the image through compressed
  rewrite/reread boundaries. `moon test --target native
  image/fixture_acceptance` reports 12/12 tests passing, and `moon test
  --target native` reports 2188/2188 tests passing.~~
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
- [x] ~~Add optional `.repos/cpdf-source` manual-image gates for
  `manualimages/png.pdf`: the native image fixture package now decodes the
  source PNG XObject's Flate PNG predictor payload to RGB24, verifies
  compressed-xref rewrite/reread preservation, and corrupts `startxref` to
  require malformed reconstruction before extracting the same 400x294 image.
  `moon test --target native image/fixture_acceptance` reports 11/11 tests
  passing; native full-suite validation reports 2151/2151 tests passing.~~
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
- [x] ~~Add a checked-in CamlPDF real-world malformed classic xref-row gate:
  `fixture_acceptance` now corrupts the first in-use xref marker in the
  linearized classic-xref `logo.pdf` fixture while keeping `startxref` valid,
  requires strict-reader failure, reconstructs through the public recovery
  reader, and verifies compressed-xref rewrite/reread page counts. `moon test
  --target native fixture_acceptance` reports 6/6 tests passing.~~
- [x] ~~Add a checked-in CamlPDF real-world malformed classic xref-offset gate:
  `fixture_acceptance` now corrupts the first in-use xref offset in the
  linearized classic-xref `logo.pdf` fixture while keeping `startxref` valid,
  requires strict-reader failure, reconstructs through the public recovery
  reader, and verifies compressed-xref rewrite/reread page counts. `moon test
  --target native fixture_acceptance` reports 12/12 tests passing; native
  full-suite validation reports 2144/2144 tests passing.~~
- [x] ~~Add a checked-in CamlPDF real-world malformed classic xref-generation
  gate: `fixture_acceptance` now corrupts the first in-use xref row generation
  field in the linearized classic-xref `logo.pdf` fixture while keeping
  `startxref` valid, requires strict-reader failure, reconstructs through the
  public recovery reader, and verifies compressed-xref rewrite/reread page
  counts. `moon test --target native fixture_acceptance` reports 15/15 tests
  passing; native full-suite validation reports 2147/2147 tests passing.~~
- [x] ~~Add a checked-in CamlPDF real-world malformed classic xref-count gate:
  `fixture_acceptance` now corrupts the first classic xref subsection count in
  the linearized classic-xref `logo.pdf` fixture while keeping `startxref`
  valid, requires strict-reader failure, reconstructs through the public
  recovery reader, and verifies compressed-xref rewrite/reread page counts.
  `moon test --target native fixture_acceptance` reports 13/13 tests passing;
  native full-suite validation reports 2145/2145 tests passing.~~
- [x] ~~Add a checked-in CamlPDF real-world malformed classic xref object-number
  gate: `fixture_acceptance` now corrupts the first classic xref subsection's
  starting object-number token in the linearized classic-xref `logo.pdf`
  fixture while keeping `startxref` valid, requires strict-reader failure,
  reconstructs through the public recovery reader, and verifies
  compressed-xref rewrite/reread page counts. `moon test --target native
  fixture_acceptance` reports 14/14 tests passing; native full-suite validation
  reports 2146/2146 tests passing.~~
- [x] ~~Add a checked-in CamlPDF real-world malformed xref-stream width gate:
  `fixture_acceptance` now corrupts the `/W` entry in the xref-stream-backed
  `introduction_to_camlpdf.pdf` fixture while keeping `startxref` valid,
  public reconstruction expands physically present object streams when xref
  stream entries are unavailable, and compressed-xref rewrite/reread preserves
  all pages. `moon test --target native fixture_acceptance` reports 7/7 tests
  passing.~~
- [x] ~~Add checked-in CamlPDF real-world malformed xref-stream `/Index` and
  `/Filter` gates: `fixture_acceptance` now mutates only metadata after the
  xref-stream anchor in `introduction_to_camlpdf.pdf`, requires strict reader
  failure, reconstructs through the public reader, and verifies compressed-xref
  rewrite/reread page counts. `moon test --target native fixture_acceptance`
  reports 9/9 tests passing.~~
- [x] ~~Add a checked-in CamlPDF real-world malformed xref-stream
  `/DecodeParms` gate: `fixture_acceptance` now replaces the xref stream
  dictionary's `/ID` entry in `introduction_to_camlpdf.pdf` with a padded
  `/DecodeParms /Bad` entry while preserving offsets, requires strict
  `PredictorExpected` failure, reconstructs through the public recovery reader,
  and verifies compressed-xref rewrite/reread page counts. `moon test --target
  native fixture_acceptance` reports 16/16 tests passing; native full-suite
  validation reports 2148/2148 tests passing.~~
- [x] ~~Add a checked-in CamlPDF real-world unsupported xref-stream
  `/DecodeParms` predictor gate: `fixture_acceptance` now replaces the same
  xref-stream dictionary span in `introduction_to_camlpdf.pdf` with
  `/DecodeParms << /Predictor 9 >>`, requires strict
  `PredictorNotSupported(9)`, reconstructs through the public recovery reader,
  and verifies compressed-xref rewrite/reread page counts. `moon test --target
  native fixture_acceptance` reports 17/17 tests passing; native full-suite
  validation reports 2149/2149 tests passing.~~
- [x] ~~Add checked-in Pandoc real-world malformed compact xref-stream width
  gates: `fixture_acceptance` now corrupts `/W[1 2 2]` in the object-stream
  backed `pandoc_latin.pdf` and `pandoc_cjk.pdf` fixtures, covering xref
  streams identified by `/W` without an explicit `/Type /XRef`, and verifies
  public reconstruction plus compressed-xref reread page counts. `moon test
  --target native fixture_acceptance` reports 11/11 tests passing.~~
- [x] ~~Add an optional `.repos/cpdf-source` cpdf manual core reader/recovery
  gate: `fixture_acceptance` now reads the 175-page `cpdfmanual.pdf` source
  corpus fixture when the ignored checkout is present, rewrites/rereads it with
  compressed xref streams, and corrupts the final `startxref` to require public
  reconstruction before another compressed rewrite/reread. `moon test --target
  native fixture_acceptance` reports 19/19 tests passing; native full-suite
  validation reports 2164/2164 tests passing.~~
- [x] ~~Broaden the optional `.repos/cpdf-source` cpdf manual xref-stream
  recovery gate: `fixture_acceptance` now also corrupts the 175-page manual's
  `/W [1 3 1]` xref-stream widths and `/Filter /FlateDecode` entry, requiring
  strict-reader failure, public reconstruction, and compressed-xref
  rewrite/reread preservation. `moon test --target native fixture_acceptance`
  reports 21/21 tests passing; native full-suite validation reports 2166/2166
  tests passing.~~
- [x] ~~Broaden the optional `.repos/cpdf-source` cpdf manual xref-stream
  recovery gate again: `fixture_acceptance` now corrupts the 175-page manual's
  large `/Index [0 1844]` xref-stream entry, requiring strict
  `XRefEntryExpected`, public reconstruction, and compressed-xref
  rewrite/reread preservation. `moon test --target native fixture_acceptance`
  reports 22/22 tests passing; native full-suite validation reports 2167/2167
  tests passing.~~
- [x] ~~Broaden optional `.repos/cpdf-source` cpdf manual xref-stream metadata
  tolerance: `fixture_acceptance` now corrupts the 175-page manual's redundant
  `/Size 1844` xref-stream entry to `/Size /Bad` while preserving its explicit
  `/Index [0 1844]` ranges, verifies the strict reader still accepts the real
  source fixture without falling back to reconstruction, verifies public reads
  stay on the xref-stream path, and checks compressed rewrite/reread
  preservation. `moon check --target native fixture_acceptance --warn-list
  +73` passes, `moon test --target native fixture_acceptance --filter
  'optional cpdf source manual fixture tolerates malformed indexed xref stream
  size'` reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 107/107 tests passing, `moon test --target
  native` reports 2279/2279 tests passing, `moon info && moon fmt` reports no
  pending interface or formatting work, and `moon check --target all
  --warn-list +73` reports the known warning-73/main-package baseline with
  10 warnings and 0 errors.~~
- [x] ~~Broaden optional `.repos/cpdf-source` cpdf manual xref-stream metadata
  recovery for combined damage: `fixture_acceptance` now corrupts both the
  175-page manual's explicit `/Index [0 1844]` ranges and its `/Size 1844`
  xref-stream entry, verifies strict reading fails with `XRefEntryExpected`,
  reconstructs through the public physical-recovery reader, preserves all 175
  pages, and checks compressed rewrite/reread preservation. `moon check
  --target native fixture_acceptance --warn-list +73` passes, `moon test
  --target native fixture_acceptance --filter 'optional cpdf source manual
  fixture reconstructs malformed xref stream index and size'` reports 1/1 test
  passing, `moon test --target native fixture_acceptance` reports 108/108 tests
  passing, `moon test --target native` reports 2280/2280 tests passing, `moon
  info && moon fmt` reports no pending interface or formatting work, and `moon
  check --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 10 warnings and 0 errors.~~
- [x] ~~Add an optional `.repos/cpdf-source/hello.pdf` source-corpus gate:
  `fixture_acceptance` now reads the unique top-level PDF 1.1 hello fixture,
  rewrites/rereads it with compressed xref streams, corrupts its final
  `startxref`, and corrupts its first in-use classic xref marker to require
  public reconstruction. `moon test --target native fixture_acceptance` reports
  25/25 tests passing; native full-suite validation reports 2170/2170 tests
  passing.~~
- [x] ~~Broaden optional `.repos/cpdf-source` source-corpus coverage for the
  cpdf manual image PDFs: `fixture_acceptance` now reads, compressed-rewrites,
  corrupts the final `startxref`, and reconstructs all 21 one-page
  `manualimages/*.pdf` fixtures. Focused native validation reports
  `moon test --target native fixture_acceptance` at 26/26 tests passing;
  native full-suite validation reports 2178/2178 tests passing.~~
- [x] ~~Broaden optional `.repos/cpdf-source` manual-image xref recovery again:
  `fixture_acceptance` now corrupts the classic xref row marker, offset,
  generation, subsection object number, and subsection count across all 21
  one-page `manualimages/*.pdf` fixtures, requiring strict failure, public
  reconstruction, and compressed rewrite/reread preservation for each case.
  Focused native validation reports `moon test --target native
  fixture_acceptance` at 27/27 tests passing; native full-suite validation
  reports 2179/2179 tests passing.~~
- [x] ~~Broaden optional `.repos/cpdf-source` manual-image xref recovery for
  damaged classic xref headers: `fixture_acceptance` now corrupts the
  `startxref` target's `xref` keyword across all 21 one-page
  `manualimages/*.pdf` fixtures, requiring strict `XRefExpected`, public
  reconstruction, and compressed rewrite/reread preservation. Focused native
  validation reports `moon test --target native fixture_acceptance` at 28/28
  tests passing; native full-suite validation reports 2180/2180 tests
  passing.~~
- [x] ~~Broaden optional `.repos/cpdf-source` manual-image trailer recovery:
  reconstruction now synthesizes a minimal trailer root from a loaded
  `/Type /Catalog` object when no trailer dictionary survives scanning, and
  `fixture_acceptance` now corrupts the classic `trailer` keyword across all
  21 one-page `manualimages/*.pdf` fixtures. Focused native validation reports
  `moon test --target native fixture_acceptance` at 29/29 tests passing;
  native full-suite validation reports 2181/2181 tests passing.~~
- [x] ~~Broaden optional `.repos/cpdf-source` cpdf manual xref-stream root
  recovery: `fixture_acceptance` now corrupts the 175-page manual's
  `/Root 1841 0 R` xref-stream trailer entry, requiring strict
  `RootExpected`, public reconstruction through scanned catalog-root inference
  with xref-stream object entries available, and compressed rewrite/reread page
  preservation. Focused native validation reports `moon test --target native
  fixture_acceptance` at 30/30 tests passing; native full-suite validation
  reports 2182/2182 tests passing.~~
- [x] ~~Broaden optional `.repos/cpdf-source` cpdf manual object-stream
  recovery: `fixture_acceptance` now corrupts the first `/ObjStm` `/N 100`
  entry in the 175-page manual, requiring strict `XRefEntryExpected`, public
  reconstruction that still rejects unusable/mismatched root object streams but
  tolerates unrelated malformed object streams, and compressed rewrite/reread
  page preservation. Focused native validation reports `moon test --target
  native fixture_acceptance` at 31/31 tests passing; native full-suite
  validation reports 2183/2183 tests passing.~~
- [x] ~~Broaden optional `.repos/cpdf-source` cpdf manual object-stream bounds
  recovery: `fixture_acceptance` now corrupts the first `/ObjStm` `/First 832`
  entry in the 175-page manual, requiring strict `XRefEntryExpected`, public
  reconstruction that tolerates the unrelated malformed object-stream bound,
  and compressed rewrite/reread page preservation. Focused native validation
  reports `moon test --target native fixture_acceptance` at 32/32 tests
  passing; native full-suite validation reports 2184/2184 tests passing.~~
- [x] ~~Broaden optional `.repos/cpdf-source` cpdf manual object-stream filter
  recovery: `fixture_acceptance` now corrupts the first `/ObjStm`
  `/Filter /FlateDecode` entry in the 175-page manual, requiring strict
  `FilterNotSupported`, public reconstruction that still rejects unusable
  root object streams, and compressed rewrite/reread page preservation. Focused
  native validation reports `moon test --target native fixture_acceptance` at
  33/33 tests passing; native full-suite validation reports 2185/2185 tests
  passing.~~
- [x] ~~Broaden optional `.repos/cpdf-source` cpdf manual xref-stream decode
  parameter recovery: `fixture_acceptance` now replaces the 175-page manual's
  xref-stream `/ID` entry with malformed `/DecodeParms /Bad` and unsupported
  `/DecodeParms << /Predictor 9 >>` metadata, requiring strict
  `PredictorExpected`/`PredictorNotSupported`, public reconstruction, and
  compressed rewrite/reread page preservation. Focused native validation
  reports `moon test --target native fixture_acceptance` at 35/35 tests
  passing; native full-suite validation reports 2187/2187 tests passing.~~
- [x] ~~Broaden optional `.repos/cpdf-source` cpdf manual xref-stream type
  recovery: `fixture_acceptance` now replaces the 175-page manual's
  startxref-targeted `/Type /XRef` entry with `/Type /Bad`, requiring strict
  `XRefExpected`, public reconstruction, and compressed rewrite/reread page
  preservation. Focused native validation reports `moon test --target native
  fixture_acceptance` at 36/36 tests passing; native full-suite validation
  reports 2189/2189 tests passing.~~
- [x] ~~Broaden optional `.repos/cpdf-source` cpdf manual xref-stream stream
  marker recovery: `fixture_acceptance` now replaces the 175-page manual's
  startxref-targeted xref stream `stream` marker with `stramx`, requiring
  strict `ParseStreamExpected`, public reconstruction using the xref-stream
  trailer prefix, and compressed rewrite/reread page preservation. Focused
  native validation reports `moon test --target native fixture_acceptance` at
  37/37 tests passing; native full-suite validation reports 2191/2191 tests
  passing.~~
- [x] ~~Broaden optional `.repos/cpdf-source` cpdf manual xref-stream terminator
  recovery: `fixture_acceptance` now replaces the 175-page manual's
  startxref-targeted xref stream `endstream` and `endobj` markers, requiring
  strict `ParseEndStreamExpected`/`ParseEndObjectExpected`, public
  reconstruction using the xref-stream trailer prefix, and compressed
  rewrite/reread page preservation. Focused native validation reports `moon
  test --target native fixture_acceptance` at 38/38 tests passing; native
  full-suite validation reports 2194/2194 tests passing.~~
- [x] ~~Broaden optional `.repos/cpdf-source` cpdf manual object-stream token
  handling: `fixture_acceptance` now replaces the first `/ObjStm` `stream`
  marker, its direct-`/Length`-derived physical `endstream`, and its physical
  `endobj` marker in the 175-page manual, requiring strict
  `ParseStreamExpected` plus public reconstruction for the stream marker, strict
  length-repair plus compressed rewrite/reread for the shifted `endstream`, and
  strict `ParseEndObjectExpected` plus public reconstruction for the `endobj`
  marker. Focused native validation reports `moon test --target native
  fixture_acceptance` at 41/41 tests passing; native full-suite validation
  reports 2197/2197 tests passing.~~
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
- [x] ~~Add package-local `PdfTextExtractor` coverage for rare Adobe-Japan1
  predefined CMap aliases, mirroring the reader-boundary gates for 78, 78ms,
  83pv, 90ms/90msp/90pv vertical, generic RKSJ, 78-EUC, Add, Ext, Hojo,
  Hojo-EUC-V, and NWP extraction plus reverse lookup. `moon test --target
  native pdf_text_test.mbt --filter 'PdfTextExtractor reads identity CMap text
  as two-byte character codes'` reports 1/1 tests passing; native full-suite
  validation reports 2172/2172 tests passing.~~
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
- [x] ~~Refresh non-native backend validation after the cpdf source-corpus
  gates: `moon test --target wasm-gc` reports 2012/2012 tests passing,
  `moon test --target js` reports 2012/2012 tests passing, and `moon check
  --target all --warn-list +73` completes with the known warning baseline and
  no errors. Full plain-Wasm `moon test --target wasm` remains blocked by the
  known runtime maximum-function-size limit, now observed in
  `markdown.blackbox_test.wasm`, while `moon test --target wasm .` also exceeds
  the same limit in `pdflite.blackbox_test.wasm`.~~
- [x] ~~Refresh compiler-0.9.3 backend readiness after the latest native
  cpdf-source parity gates: `moon test --target wasm-gc` and `moon test
  --target js` each report 2016/2016 tests passing, `moon check --target all
  --warn-list +73` completes with no errors aside from the known
  `markdown/cmd` future main-package blackbox-test notice, full `moon test
  --target wasm` still hits the runtime maximum-function-size limit in
  `markdown.blackbox_test.wasm`, root-package `moon test --target wasm .`
  hits the same limit in `pdflite.blackbox_test.wasm`, and `moon test --target
  llvm` remains blocked by the installed toolchain's missing LLVM core bundle
  (`prelude/prelude.mi`).~~
- [x] ~~Revisit all-backend validation after native parity is stable: MoonBit
  0.9.3 validates wasm-gc/js at 2016/2016 each and confirms the remaining
  backend blockers are plain-Wasm generated-test function size and the missing
  LLVM core bundle, not newly failing portable pdflite behavior.~~

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
- [x] ~~Revisit all-backend validation after native feature parity is stable:
  MoonBit 0.9.3 validates wasm-gc/js at 2016/2016 each and confirms the
  remaining backend blockers are plain-Wasm generated-test function size and
  the missing LLVM core bundle, not newly failing portable pdflite behavior.~~
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
- [x] ~~`cpdfattach.ml` document-level embedded-file name trees and page-level
  `/FileAttachment` annotations now have compressed native read/write/reread
  boundary coverage for payload data, names, page numbers, descriptions,
  `/AFRelationship` values, raw size accounting, annotation `/FS` links, and
  removal of both attachment forms. `moon test --target native` reports
  2204/2204 tests passing.~~
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
- [x] ~~Standalone `cpdfcoord.ml` coordinate parser slice exposes unit
  conversion, page-box characteristics, coordinate/rectangle parsers, document
  page-dependent variants, single-number parsing, paper-size literals, arithmetic
  updates, and compatibility wrappers, covering point/mm/cm/in units,
  portrait paper sizes, media/crop/art/trim/bleed box values, absolute rectangle
  syntax, scale-to-fit `*` preprocessing, arity errors, and wrapper rectangle
  parsing. Native focused validation reports `moon test --target native
  pdf_coord_test.mbt` at 6/6 tests passing; native full-suite validation
  reports 1722/1722 tests passing.~~
- [x] ~~Standalone `cpdfcoord.ml` compact-unit tokenization slice now mirrors the
  source `space_units` preprocessing, accepting adjacent unit-suffixed coordinate
  arguments such as `10mm20mm` and `1in2in3in4in` before lexical parsing. Native
  focused validation reports `moon test --target native pdf_coord_test.mbt` at
  7/7 tests passing; native full-suite validation reports 2198/2198 tests
  passing.~~
- [x] ~~Standalone `cpdfcolours.ml` CSS colour table slice exposes
  `pdf_css_colours` and `pdf_css_colour_value`, covering the complete 148-entry
  lowercased table, first/last entry order, alias preservation, case-insensitive
  lookup, and missing-colour lookup. Native focused validation reports `moon
  test --target native pdf_colour_test.mbt` at 2/2 tests passing; native
  full-suite validation reports 1724/1724 tests passing.~~
- [x] ~~Standalone `cpdfdrawcontrol.ml` colour parser slice now exposes
  `pdf_parse_content_colour`, reusing `PdfContentColour` for cpdf draw/add-text
  colour arguments. Coverage pins case-insensitive CSS colour conversion to
  normalized RGB, one/three/four numeric arities for gray/RGB/CMYK, PDF lexical
  integer/real token handling, and malformed arities/tokens. Native focused
  validation reports `moon test --target native --package bobzhang/pdflite
  --file pdf_colour_test.mbt` at 4/4 tests passing; native full-suite
  validation reports 1772/1772 tests passing.~~
- [x] ~~Standalone `cpdfdraw.ml`/`cpdfdrawcontrol.ml` role-map slice now lets
  structured draw output attach a cpdf-style `/RoleMap` dictionary to the
  generated `/StructTreeRoot` via `role_map`, and lets `PdfDrawControl` carry
  the same role-map body for callers building draw scripts through the control
  API. Coverage pins parsed `/RoleMap` entries and verifies the control setting
  does not add spurious draw operations. Focused native validation reports
  `moon test --target native pdf_draw_test.mbt` at 49/49 tests passing; native
  check validation reports `moon check --target native --warn-list +73`
  passing with the known markdown main-package warning and 10-warning baseline.
  Full native suite validation is deferred to the next batch.~~
- [x] ~~`cpdfdraw.ml` fresh-structure-tree guard is now ported: requested
  structured drawing writes a new `/StructTreeRoot` only when the document has
  cpdf's fresh placeholder dictionary, and otherwise artifact-wraps the drawn
  content without replacing an existing real structure tree or fabricating one
  for an ordinary unstructured document. Coverage pins fresh-placeholder
  structure generation, preservation of an existing non-fresh tree, ignored
  role maps on the preservation path, and artifact wrapping for the no-placeholder
  branch. Focused native validation reports `moon test --target native
  pdf_draw_test.mbt` at 51/51 tests passing; native check validation reports
  `moon check --target native --warn-list +73` passing with the known markdown
  main-package warning and 10-warning baseline. Full native suite validation is
  deferred to the next batch.~~
- [x] ~~`cpdfdrawcontrol.ml` automatic artifact state is now exposed on
  `PdfDrawControl`, matching cpdf's `autoartifacts` control knob so callers can
  carry the setting alongside generated draw operations and pass it through to
  `PdfDocument::draw(add_artifacts=...)`. Coverage pins the default enabled
  state, explicit disable, and that toggling the setting does not append draw
  operations. Focused native validation reports `moon test --target native
  pdf_draw_test.mbt` at 51/51 tests passing; full native validation is due at
  the next batch gate.~~
- [x] ~~`cpdfdrawcontrol.ml` supplied-image insertion is now exposed through
  `PdfDrawControl::add_jpeg_data`, `add_png_data`, and `add_jpeg2000_data`,
  matching the `addjpeg ?data`, `addpng pdf ?data`, and `addjpeg2000 ?data`
  branches by converting supplied image bytes into `PdfDrawImageXObject`
  operations. Coverage pins JPEG `/DCTDecode`, PNG `/FlateDecode`, JPEG2000
  `/JPXDecode`, image dimensions, payload preservation, and parser error
  propagation. Focused native validation reports `moon test --target native
  pdf_draw_test.mbt` at 53/53 tests passing; native check validation reports
  `moon check --target native --warn-list +73` passing with the known markdown
  main-package warning and 10-warning baseline. Full native suite validation is
  deferred to the next batch.~~
- [x] ~~`cpdfdrawcontrol.ml` image file-spec branches are now covered by the
  native `async_io` wrappers `pdf_draw_control_add_jpeg_file`,
  `pdf_draw_control_add_png_file`, and
  `pdf_draw_control_add_jpeg2000_file`, matching cpdf's `Name=filename` parsing
  while keeping filesystem reads outside the pure root package. Coverage pins
  JPEG `/DCTDecode`, PNG `/FlateDecode`, JPEG2000 `/JPXDecode`, dimensions,
  payload preservation, and malformed file-spec diagnostics. Focused native
  validation reports `moon test --target native async_io` at 87/87 tests
  passing; native check validation reports `moon check --target native
  --warn-list +73` passing with the known markdown main-package warning and
  10-warning baseline. Full native suite validation is deferred to the next
  batch.~~
- [x] ~~`cpdfdrawcontrol.ml` XObject bounding-box parsing is now exposed via
  `PdfDrawControl::set_xobject_bbox_from_string`, matching `xobjbbox s` by
  parsing cpdf rectangle text through the coordinate parser before the next
  `FormXObject` is closed. Coverage pins parsed bbox coordinates on the
  generated form operation and propagation of malformed rectangle diagnostics.
  Focused native validation reports `moon test --target native
  pdf_draw_test.mbt` at 54/54 tests passing; native check validation reports
  `moon check --target native --warn-list +73` passing with the known markdown
  main-package warning and 10-warning baseline. Full native suite validation is
  deferred to the next batch.~~
- [x] ~~`cpdfdrawcontrol.ml`'s explicit `add_default_fontpack fontname`
  helper is now public on `PdfDrawControl`, appending the configured font pack
  once under the supplied font name and resetting that one-shot state when
  `set_fontpack` changes the configured pack. Coverage pins one-shot insertion,
  ignored duplicate calls, and re-emission after a fontpack reset. Focused
  native validation reports `moon test --target native pdf_draw_test.mbt` at
  55/55 tests passing; native check validation reports `moon check --target
  native --warn-list +73` passing with the known markdown main-package warning
  and 10-warning baseline. Full native suite validation is due at this batch
  gate.~~
- [x] ~~`cpdfdrawcontrol.ml` font-state readers are now exposed as
  per-instance `PdfDrawControl` methods: `font_name`, `font_size`,
  `paragraph_indent`, and `fontpack_initialized`, covering the state carried by
  cpdf's `getfontname`, `getfontsize`, `getindent`, and
  `fontpack_initialised` refs. Coverage pins defaults, setter updates, and the
  fontpack one-shot state transition. Focused native validation reports `moon
  test --target native pdf_draw_test.mbt` at 56/56 tests passing; native check
  validation reports `moon check --target native --warn-list +73` passing with
  the known markdown main-package warning and 10-warning baseline. Full native
  suite validation is deferred to the next batch.~~
- [x] ~~Add optional `.repos/cpdf-source` manual drawing fixture coverage:
  the new native-only `draw/fixture_acceptance` package reads
  `manualimages/capjoins.pdf`, `dash.pdf`, and `text.pdf` when the ignored
  source checkout is present, then verifies the MoonBit reader/content parser
  sees cpdf-generated line-cap/join, dash-pattern, matrix, font, and text-show
  operators. `moon test --target native draw/fixture_acceptance` reports 3/3
  tests passing; native full-suite validation reports 2154/2154 tests
  passing.~~
- [x] ~~Broaden optional `.repos/cpdf-source` manual drawing fixture coverage:
  `draw/fixture_acceptance` now also reads `manualimages/xobj.pdf`,
  `trans.pdf`, and `fontparams.pdf` when the ignored source checkout is
  present, verifying cpdf-generated Form XObject resources and reuse,
  `/ExtGState` transparency resources, fill operators, and text-state
  font-parameter operators. Focused native validation reports `moon test
  --target native draw/fixture_acceptance` at 6/6 tests passing; native
  full-suite validation reports 2157/2157 tests passing.~~
- [x] ~~Broaden optional `.repos/cpdf-source` manual drawing fixture coverage
  across the remaining non-image manual PDFs: `draw/fixture_acceptance` now
  parses all non-PNG `manualimages/*.pdf` fixtures when the ignored source
  checkout is present and rejects any unknown content operators, with focused
  checks for Bezier curves, closepath stroke/fill, clipping, gray/RGB colour
  paint, graphics-state save/restore matrix transforms, and text clipping mode.
  Focused native validation reports `moon test --target native
  draw/fixture_acceptance` at 11/11 tests passing; native full-suite
  validation reports 2162/2162 tests passing.~~
- [x] ~~Standalone `cpdfcreate.ml` blank-document slice exposes
  `pdf_blank_document` and `pdf_blank_document_paper`, covering point-sized
  pages, named paper sizes, zero-page documents, page-tree/root creation, and
  generated trailer `/ID` arrays. Native focused validation reports `moon test
  --target native pdf_create_test.mbt` at 5/5 tests passing; native full-suite
  validation reports 1721/1721 tests passing.~~
- [x] ~~Standalone `cpdferror.ml` exception-helper slice exposes
  `PdfError::SoftError`, `PdfError::HardError`, `pdf_error`,
  `pdf_soft_error`, and `pdf_hard_error`, covering cpdf's soft-error default
  and distinct hard-error helper while updating generated interfaces. Native
  focused validation reports `moon test --target native pdf_error_test.mbt` at
  2/2 tests passing; native full-suite validation reports 1724/1724 tests
  passing.~~
- [x] ~~Standalone `cpdfutil.ml` helper slice exposes cpdf-style progress
  toggles/fragments, recursive dictionary-entry removal and replacement,
  dictionary-entry reporting helpers, and the injectible path guard. Coverage
  pins disabled progress no-ops, line/page/endpage/done fragment ordering,
  recursive trailer/object/array/stream dictionary rewrites, resolved search
  matching, malformed stream dictionary preservation, rendered/JSON dictionary
  reporting, and shell metacharacter rejection without process exit. Native
  focused validation reports `moon test --target native pdf_util_test.mbt` at
  26/26 tests passing; native full-suite validation reports 1725/1725 tests
  passing.~~
- [x] ~~Extend bookmark compatibility helpers with cpdf-style title bookmark
  insertion, open-to-level rewriting, and page-object destination renumbering.
  Coverage pins basename title selection, page-one XYZ title targets, existing
  bookmark indentation, leaf open-state round-tripping, wrapper parity, FitR
  destination renumbering, the cpdf FitB-to-Fit compatibility quirk, and
  preservation of unmapped and page-number destinations. Native focused
  validation reports `moon test --target native pdf_bookmark_test.mbt` at
  19/19 tests passing; native full-suite validation reports 1728/1728 tests
  passing.~~
- [x] ~~Bookmark output helper slice exposes cpdf-style selected-page bookmark
  listing, full-document bookmark JSON rows, UTF-8 JSON bytes, and compatibility
  wrappers; bookmark-file parsing/import is covered by the later import slice.
  Coverage pins text line formatting, title escaping, page-number target
  rewriting, selected-page filtering, named-destination retention, invalid-range
  diagnostics, JSON row fields, colour/flag projection, wrapper parity, and JSON
  filtered listing output. Native focused validation reports `moon test --target
  native pdf_bookmark_test.mbt` at 21/21 tests passing; native full-suite
  validation reports 1738/1738 tests passing.~~
- [x] ~~Follow-up `cpdfbookmarks.ml` listing parity gate pins
  `process_string` backslash escaping before plain text bookmark output, with
  compatibility wrapper parity for `pdf_list_bookmarks`. Current focused
  validation reports `moon test --target native pdf_bookmark_test.mbt` at
  27/27 tests passing; native full-suite validation reports 2200/2200 tests
  passing.~~
- [x] ~~Bookmark filename-spec helper slice exposes cpdf-style `name_of_spec`
  expansion for already-read bookmark lists; bookmark-file parsing and import are
  covered by the later import slice. Coverage pins percent sequence substitution,
  `@F`, `@N`, `@S`, `@E`, `@B`, and `@b...@` expansion, unsafe bookmark-title
  character filtering, UTF-8-safe truncation, wrapper parity, and over-wide
  field diagnostics. Native focused validation reports `moon test --target
  native pdf_bookmark_test.mbt` at 22/22 tests passing; native full-suite
  validation reports 1739/1739 tests passing.~~
- [x] ~~Bookmark import helper slice exposes cpdf plain-text and JSON bookmark
  import through `PdfDocument::parse_bookmark_text`, `add_bookmarks_from_text`,
  `parse_bookmark_json`, `add_bookmarks_from_json`, and compatibility wrappers.
  Coverage pins quoted title escaping, open-state parsing, page-object and
  named destinations, bookmark structure validation, JSON row shape, colour and
  style flags, malformed-row diagnostics, and add-wrapper behavior. Current
  native focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_bookmark_test.mbt` at 26/26 tests passing.~~
- [x] ~~Optional-content group management helper slice exposes cpdf-style raw
  OCG name listing, rename, order-all, and same-name coalescing wrappers.
  Coverage pins raw layer-name listing, copy-on-write rename behavior, wrapper
  parity, default `/Order` population from `/OCGs`, duplicate-name coalescing,
  metadata reference de-duplication, ordinary indirect-reference rewriting, and
  duplicate OCG object removal. Native focused validation reports `moon test
  --target native pdf_ocg_test.mbt` at 13/13 tests passing; native full-suite
  validation reports 1732/1732 tests passing.~~
- [x] ~~Optional-content group JSON round-trip slice exposes cpdf-style OCG JSON
  listing, UTF-8 JSON bytes, strict `pdf_ocg_read_json` import, and
  `ocg_replace_json` replacement wrappers. Coverage pins exact exported field
  shape, `null` no-OCG handling, export-to-import round-tripping through
  `PdfOptionalContent`, page-element subtype preservation, replacement through
  the writer, wrapper parity, and malformed JSON soft errors. Native focused
  validation reports `moon test --target native pdf_ocg_test.mbt` at 17/17
  tests passing; native full-suite validation reports 1747/1747 tests
  passing.~~
- [x] ~~Annotation old-style helper slice exposes encoded `(page, contents)`
  extraction, cpdf-style listing rendering, and selected-page annotation removal
  wrappers. Coverage pins direct and indirect `/Contents` lookup, empty-content
  preservation, listing line format, selected-page filtering, empty-line
  suppression, encoding-wrapper parity, copy-on-write selected-page `/Annots`
  removal, original-document preservation, wrapper parity, and out-of-range page
  diagnostics. Native focused validation reports `moon test --target native
  pdf_annotation_test.mbt` at 11/11 tests passing; native full-suite validation
  reports 1735/1735 tests passing.~~
- [x] ~~Annotation JSON export helper slice exposes selected-page cpdf
  annotation JSON rows and UTF-8 JSON bytes. Coverage pins the format-version
  header, indirect
  annotation-only row emission, `/P`, `/Dest`, and action `/D` page-reference
  rewriting for annotations without `/Dest`, direct annotation skipping,
  ancillary object collection, `/Popup`/`/Parent` ancillary exclusion, wrapper
  parity, empty selected-page output, and out-of-range diagnostics. Native
  focused validation reports `moon test --target native pdf_annotation_test.mbt`
  at 12/12 tests passing; native full-suite validation reports 1736/1736 tests
  passing.~~
- [x] ~~Annotation JSON import/copy helper slice exposes
  `set_annotations_json`, `pdf_set_annotations_json`,
  `copy_annotations_from`, and `pdf_copy_annotations`. Imported cpdf
  annotation rows now renumber the target document out of the imported object
  range, preserve positive ancillary objects, append selected page annotations,
  rewrite JSON page numbers in `/P`, `/Dest`, and action `/D` back to page
  object references, and keep existing target annotations. Coverage pins
  collision renumbering, extra-object preservation, wrapper parity, copy parity,
  original-document preservation, and malformed JSON soft errors. Native
  focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_annotation_test.mbt` at 14/14 tests passing;
  native full-suite validation reports 1758/1758 tests passing.~~
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
- [x] ~~Optional `.repos/cpdf-source` debug-object dump gate now runs
  `PdfDocument::debug_objects` and `pdf_debug_objects` against the 175-page
  `cpdfmanual.pdf` fixture, pinning trailer/root/catalog/pages spelling plus
  real catalog/page object markers through direct read, compressed xref-stream
  rewrite/reread, and malformed-startxref public reconstruction. Focused
  native validation reports `moon test --target native fixture_acceptance
  --filter '*debug objects*'` at 1/1 tests passing; package validation reports
  `moon test --target native fixture_acceptance` at 121/121 tests passing;
  native full-suite validation reports 2344/2344 tests passing.~~
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
- [x] ~~Standalone `cpdfjson.ml` function-stream parse-content output slice now
  extends `PdfDocument::json_of_object` and `pdf_json_of_object` with
  `parse_content=true`, and threads that flag through `json_of_document` for
  reachable non-content `/FunctionType` streams. Coverage pins cpdf's behavior
  where parsed function streams are decoded even when `no_stream_data=true`,
  while ordinary stream-data elision and parsed page-content arrays remain
  unchanged. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_util_test.mbt` at 27/27 tests passing;
  native full-suite validation reports 2140/2140 tests passing.~~
- [x] ~~Standalone `cpdfjson.ml` full-document byte-output slice now exposes
  `PdfDocument::json_of_document_blob` and `pdf_json_of_document_blob` as the
  side-effect-free counterpart of `Cpdfjson.to_output`, preserving all
  `json_of_document` flags while returning UTF-8 CPDFJSON bytes. Coverage pins
  wrapper parity on synthetic parsed-content documents and gates optional
  `.repos/cpdf-source/hello.pdf` through UTF-8 parsed CPDFJSON output,
  operation-token spelling, `Hello, World!` round-trip import, compressed
  xref-stream rewrite/reread, and malformed-`startxref` public reconstruction.
  `moon check --target native --warn-list +73` passes with the known warning
  baseline, focused validation reports `moon test --target native
  pdf_util_test.mbt --filter '*json_of_document_blob*'` at 1/1 and `moon test
  --target native fixture_acceptance --filter '*CPDFJSON document output*'` at
  1/1 tests passing, `moon test --target native fixture_acceptance` reports
  123/123 tests passing, and `moon test --target native` reports 2347/2347
  tests passing. `moon info` updates `pkg.generated.mbti` with the two
  intended public entries, `moon fmt` reports no pending formatting work, and
  `moon check --target all --warn-list +73` reports the known warning-73/main
  package baseline with 10 warnings and 0 errors.~~
- [x] ~~Standalone `cpdfjson.ml` full-document byte-input slice now exposes
  `pdf_document_of_json_blob` as the in-memory counterpart of
  `Cpdfjson.of_input`, decoding UTF-8 CPDFJSON bytes, parsing JSON with
  `moonbitlang/core/json`, and reusing the existing `pdf_document_of_json`
  importer. Coverage pins parsed-content byte-output/import round-trips,
  restored version/root/object-table state, reconstructed content stream
  operations, and `BadText` mapping for non-UTF8 bytes and malformed JSON.
  The optional `.repos/cpdf-source/hello.pdf` CPDFJSON source gate now also
  imports the emitted blob before checking retained `Hello, World!` text.
  `moon check --target native --warn-list +73` passes with the known warning
  baseline, focused validation reports `moon test --target native
  pdf_util_test.mbt --filter '*pdf_document_of_json_blob*'` at 1/1 and `moon
  test --target native fixture_acceptance --filter '*CPDFJSON document
  output*'` at 1/1 tests passing, `moon test --target native
  fixture_acceptance` reports 123/123 tests passing, and `moon test --target
  native` reports 2348/2348 tests passing. `moon info` updates
  `pkg.generated.mbti` with the intended new public entry, `moon fmt` reports
  no pending formatting work, and `moon check --target all --warn-list +73`
  reports the known warning-73/main package baseline with 10 warnings and 0
  errors.~~
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
- [x] ~~Standalone `cpdfpagespec.ml` page-spec parser/formatter slice exposes
  count-only, document-backed, and compatibility parser APIs plus pagespec
  formatting, covering ranges, `end`, negative `~n` indices, reverse/empty/all,
  odd/even suffix filters, `NOT`, `DUP`, out-of-bounds filtering,
  malformed-syntax errors, portrait/landscape/annotated document filters, page
  label resolution, and compact range formatting. Native focused validation
  reports `moon test --target native pdf_page_spec_test.mbt` at 6/6 tests
  passing; native full-suite validation reports 1724/1724 tests passing.~~
- [x] ~~Standalone `cpdfpagespec.ml` escaped page-label selector coverage now gates
  cpdf's `resolve_pagelabels` behavior for bracket characters inside labels,
  including `[A\\]1]`/`[B\\[2]` resolution and rejection of unescaped closing
  brackets. Native focused validation reports `moon test --target native
  pdf_page_spec_test.mbt` at 7/7 tests passing; native full-suite validation
  reports 2199/2199 tests passing.~~
- [x] ~~Standalone `cpdfpresent.ml` presentation-transition slice exposes
  `PdfDocument::presentation` and `pdf_presentation`, covering accepted cpdf
  transition names, transition-specific `/Dm`, `/M`, and `/Di` entries, delay
  insertion/removal, selected-page application with out-of-range pages ignored,
  no-transition dictionaries, unknown-name errors, wrapper parity, and
  source-document preservation. Native focused validation reports `moon test
  --target native pdf_presentation_test.mbt` at 6/6 tests passing; native
  full-suite validation reports 1720/1720 tests passing.~~
- [x] ~~`cpdfpresent.ml` unknown-transition parity refinement now routes
  unsupported transition names through the cpdf-style `Cpdferror.error` path as
  `PdfError::SoftError("Unknown presentation type")`, replacing the local typed
  placeholder branch while preserving the public presentation API. Native
  focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_presentation_test.mbt` at 6/6 tests passing;
  native full-suite validation reports 2143/2143 tests passing.~~
- [x] ~~Standalone `cpdfposition.ml` position helper slice exposes the
  `PdfPosition` model, `pdf_string_of_position`, and
  `pdf_calculate_position`, covering every cpdf debug spelling, centered and
  absolute placements, edge placements with and without ignored distances, and
  diagonal/reverse-diagonal rotation math. Native focused validation reports
  `moon test --target native pdf_position_test.mbt` at 5/5 tests passing;
  native full-suite validation reports 1715/1715 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` justification-offset helper slice exposes
  `PdfAddTextRotation`, `PdfAddTextJustification`, and
  `pdf_addtext_justification_offset`, covering cpdf's horizontal and vertical
  position groups, 180/270-degree justification swaps, centered/right/left
  offsets, and diagonal no-op behavior. Native focused validation reports
  `moon test --target native --package bobzhang/pdflite --file
  pdf_addtext_test.mbt` at 5/5 tests passing; native full-suite validation
  reports 1777/1777 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` URL marker helper slice exposes
  `PdfAddTextUrl`, `PdfAddTextUrlLine`, and
  `pdf_addtext_get_urls_line`, covering `%URL[text|url]` stripping, multiple
  ordered URL spans, byte-offset parity for UTF-8 text, and malformed-marker
  soft errors. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_addtext_test.mbt` at 9/9 tests
  passing; native full-suite validation reports 1781/1781 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` replacement processing slice exposes
  `pdf_addtext_process_text_with_time`, covering lazy callback evaluation,
  left-to-right ordered marker replacement, empty-marker no-op behavior, and the
  final cpdf strftime pass. Native focused validation reports `moon test
  --target native --package bobzhang/pdflite --file pdf_addtext_test.mbt` at
  12/12 tests passing; native full-suite validation reports 1784/1784 tests
  passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` line expansion slice exposes
  `pdf_addtext_expand_lines_with_time`, covering replacement expansion,
  post-expansion URL stripping for line measurement, strftime integration, and
  malformed URL propagation. Native focused validation reports `moon test
  --target native --package bobzhang/pdflite --file pdf_addtext_test.mbt` at
  14/14 tests passing; native full-suite validation reports 1786/1786 tests
  passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` replacement-pair slice exposes
  `PdfAddTextReplacementValues`, `pdf_addtext_bates_number`, and
  `pdf_addtext_replacement_pairs`, covering `%PageDiv2`, `%Page`, roman page
  markers, filename, labels, bookmark levels 0-4, and `%Bates` zero-padding.
  Native focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_addtext_test.mbt` at 16/16 tests passing; native
  full-suite validation reports 1788/1788 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` page-label helper slice exposes
  `PdfDocument::addtext_page_label` and `pdf_addtext_page_label`, covering
  decimal fallback labels, existing roman/prefixed labels, the compatibility
  wrapper, and PDFDocString prefix decoding for UTF-8 add-text output. Native
  focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_addtext_test.mbt` at 19/19 tests passing; native
  full-suite validation reports 1791/1791 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` bookmark lookup helper slice exposes
  `PdfDocument::addtext_bookmark_for_page` and
  `pdf_addtext_bookmark_for_page`, covering current-branch bookmark selection,
  exact page hits, fallback to the last prior bookmark at the requested level,
  chapter-boundary reset behavior, wrapper parity, and PDFDocString title
  decoding. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_addtext_test.mbt` at 21/21 tests
  passing; native full-suite validation reports 1793/1793 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` document replacement-values slice exposes
  `PdfDocument::addtext_replacement_values` and
  `pdf_addtext_replacement_values`, covering document-derived `%Label`,
  `%EndLabel`, `%Bookmark0`-`%Bookmark4`, Bates inputs, wrapper parity, and
  integration with `pdf_addtext_replacement_pairs`. Native focused validation
  reports `moon test --target native --package bobzhang/pdflite --file
  pdf_addtext_test.mbt` at 23/23 tests passing; native full-suite validation
  reports 1795/1795 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` cap-height helper slice exposes
  `pdf_addtext_cap_height`, covering explicit simple-font descriptor
  cap-height, Standard 14 AFM fallback lookup, missing/unknown standard-font
  behavior, and cpdf's slashless font-name convention. Native focused
  validation reports `moon test --target native --package bobzhang/pdflite
  --file pdf_addtext_test.mbt` at 25/25 tests passing; native full-suite
  validation reports 1797/1797 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` input preprocessing slice exposes
  `pdf_addtext_split_at_newline` and `pdf_addtext_unescape_string`, covering
  literal `\n` line splitting, escaped `\\n` preservation, real-newline
  non-splitting, UTF-8 byte preservation, octal byte escapes, doubled-backslash
  collapse, non-newline backslash escapes, and out-of-range octal soft errors.
  Native focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_addtext_test.mbt` at 28/28 tests passing; native
  full-suite validation reports 1800/1800 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` colour-operator slice exposes
  `pdf_addtext_colour_op` and `pdf_addtext_colour_op_stroke`, reusing
  `PdfContentColour` for cpdf add-text colours and covering gray/RGB/CMYK fill
  mappings to `g`/`rg`/`k` plus stroke mappings to `G`/`RG`/`K`. Native focused
  validation reports `moon test --target native --package bobzhang/pdflite
  --file pdf_addtext_test.mbt` at 30/30 tests passing; native full-suite
  validation reports 1802/1802 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` opacity-resource slice exposes
  `PdfDocument::addtext_opacity_resources` and
  `pdf_addtext_opacity_resources`, covering cpdf's `/ExtGState` resource
  update, unique `/gs*` allocation, fill/stroke alpha dictionary entries,
  existing resource preservation, opaque no-op behavior, and wrapper parity.
  Native focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_addtext_test.mbt` at 86/86 tests passing; native
  full-suite validation reports 1858/1858 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` UTF-8 charcode helper slice exposes
  `pdf_addtext_charcodes_of_utf8`, covering cpdf's charcode-string byte output
  as `PdfBytes`, WinAnsi byte mapping for representable codepoints, and
  missing-font-codepoint skipping. Native focused validation reports `moon test
  --target native --package bobzhang/pdflite --file pdf_addtext_test.mbt` at
  34/34 tests passing; native full-suite validation reports 1806/1806 tests
  passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` text-width helper slice exposes
  `pdf_addtext_width_of_text`, covering cpdf's simple-font-only metric
  summation over charcode bytes plus zero fallbacks for missing metrics,
  out-of-range charcodes, and non-simple fonts. Native focused validation
  reports `moon test --target native --package bobzhang/pdflite --file
  pdf_addtext_test.mbt` at 32/32 tests passing; native full-suite validation
  reports 1804/1804 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` add-rectangle operator slice exposes
  `pdf_addtext_rectangle_ops`, covering cpdf's `/CPDFSTAMP` artifact-wrapped
  rectangle content ordering, fill/stroke colour operators, filled versus
  outlined paint operators, optional line width, and optional ExtGState
  selection. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_addtext_test.mbt` at 36/36 tests
  passing; native full-suite validation reports 1808/1808 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` add-rectangle origin slice exposes
  `pdf_addtext_rectangle_origin`, covering cpdf's `calculate_position false`
  placement for rectangle width, top-position y lowering by rectangle height,
  centre/`PosCentre` y lowering by half height, and unchanged bottom/edge
  positions. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_addtext_test.mbt` at 38/38 tests
  passing; native full-suite validation reports 1810/1810 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` add-rectangle document slice exposes
  `PdfDocument::addtext_rectangle` and `pdf_addtext_rectangle`, covering
  selected-page rectangle stamping, cpdf coordinate parsing, relative page-box
  placement with MediaBox fallback, optional opacity `/ExtGState` resources,
  outline/fill behavior, underneath fast insertion, wrapper parity, and invalid
  coordinate/page diagnostics. Native focused validation reports `moon test
  --target native --package bobzhang/pdflite --file pdf_addtext_test.mbt` at
  42/42 tests passing; native full-suite validation reports 1814/1814 tests
  passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` text-operator helper slice exposes
  `pdf_addtext_text_ops`, covering cpdf's `/CPDFSTAMP` artifact-wrapped text
  content ordering, translate/rotate placement matrix, outline rendering mode,
  fill/stroke colour operators, optional opacity graphics state, simple-font
  UTF-8-to-charcode conversion with missing-codepoint skipping, and fontpack
  run switching. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_addtext_test.mbt` at 44/44 tests
  passing; native full-suite validation reports 1816/1816 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` text-placement helper slice exposes
  `pdf_addtext_rotation_radians`, `pdf_addtext_rotation_offsets`, and
  `pdf_addtext_diagonal_offsets`, covering cpdf's explicit rotation-to-radians
  mapping, position-specific rotated text origin offsets, diagonal/reverse
  diagonal vertical-offset projection, Rot180 text-width backoff, and unchanged
  non-diagonal offsets. Native focused validation reports `moon test --target
  native --package bobzhang/pdflite --file pdf_addtext_test.mbt` at 47/47
  tests passing; native full-suite validation reports 1819/1819 tests
  passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` multiline text-offset helper slice exposes
  `pdf_addtext_initial_line_offsets`, `pdf_addtext_line_advance`, and
  `pdf_addtext_baseline_offsets`, covering cpdf's paragraph alignment offsets
  for bottom/side/diagonal positions, rotation-dependent line advancement,
  midline/topline Standard 14 baseline adjustment, simple-font cap-height
  adjustment, diagonal topline behavior, midline precedence, and no-op missing
  font metrics. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_addtext_test.mbt` at 51/51 tests
  passing; native full-suite validation reports 1823/1823 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` line-preparation and encoding helper slice
  exposes `pdf_addtext_lines_for_rotation` and
  `pdf_addtext_effective_encoding`, covering cpdf's split-then-unescape line
  preparation, Rot180/Rot270 line reversal, Rot0/Rot90 order preservation,
  selected Standard/simple font encodings, and the missing-font WinAnsi
  fallback. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_addtext_test.mbt` at 54/54 tests
  passing; native full-suite validation reports 1826/1826 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` page font-dictionary setup slice exposes
  `PdfDocument::addtext_page_font_dictionary` and
  `pdf_addtext_page_font_dictionary`, covering cpdf's page `/Font` resource
  lookup, empty dictionary fallback for missing resources, indirect resource
  resolution, malformed present value preservation, and wrapper parity. Native
  focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_addtext_test.mbt` at 89/89 tests passing; native
  full-suite validation reports 1861/1861 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` font-resource helper slice exposes
  `pdf_addtext_allocate_font_names` and
  `pdf_addtext_fontpack_resource_dictionary`, covering cpdf's `/F*` unique-name
  scan, non-fontpack fallback name selection, fontpack placeholder reservation,
  embedded-font indirect resource installation, existing dictionary
  preservation, and mismatched fontpack resource diagnostics. Native focused
  validation reports `moon test --target native --package bobzhang/pdflite
  --file pdf_addtext_test.mbt` at 57/57 tests passing; native full-suite
  validation reports 1829/1829 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` text-width calculation slice exposes
  `pdf_addtext_width_of_selected_font` and
  `pdf_addtext_width_of_fontpack`, covering cpdf's Standard 14 implicit-font
  width branch, simple-font metric scaling, missing simple metrics as zero,
  fontpack width-table summation, missing fontpack codepoint skipping, and
  fontpack missing-metric diagnostics. Native focused validation reports `moon
  test --target native --package bobzhang/pdflite --file pdf_addtext_test.mbt`
  at 59/59 tests passing; native full-suite validation reports 1831/1831 tests
  passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` local `calc_textwidth` slice exposes
  `PdfDocument::addtext_calc_textwidth` and `pdf_addtext_calc_textwidth`,
  covering cpdf's selected parsed-font branch, fontpack UTF-8/codepoint branch,
  existing page-font branch, malformed fontpack UTF-8 diagnostics, wrapper
  parity, and byte-level PDF text measurement semantics. Native focused
  validation reports `moon test --target native --package bobzhang/pdflite
  --file pdf_addtext_test.mbt` at 92/92 tests passing; native full-suite
  validation reports 1864/1864 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` local line-width aggregation slice exposes
  `PdfAddTextLineWidths`, `PdfDocument::addtext_line_widths`, and
  `pdf_addtext_line_widths`, covering cpdf's current-line width measurement,
  expanded paragraph width list, longest-width selection, selected-font and
  fontpack branches, empty expanded-line diagnostics, and wrapper parity.
  Native focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_addtext_test.mbt` at 97/97 tests passing; native
  full-suite validation reports 1869/1869 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` prepared-line integration slice exposes
  `PdfAddTextPreparedLine`, `pdf_addtext_measurement_bytes`,
  `PdfDocument::addtext_prepare_line`, and `pdf_addtext_prepare_line`,
  covering replacement expansion, URL stripping and span preservation,
  selected-font/raw/fontpack measurement bytes, expanded-line byte
  materialization, relative-box placement, width aggregation, and wrapper
  parity. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_addtext_test.mbt` at 100/100 tests
  passing; native full-suite validation reports 1872/1872 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` resource-setup integration slice exposes
  `PdfAddTextResourceSetup`, `PdfDocument::addtext_resource_setup`, and
  `pdf_addtext_resource_setup`, covering selected-font `/Font` installation,
  fontpack resource installation, unique font-name reporting, opacity
  `/ExtGState` setup, placeholder font dictionaries, wrapper parity, and
  cpdf's existing-font branch that preserves page resources and suppresses
  opacity selection. Native focused validation reports `moon test --target
  native --package bobzhang/pdflite --file pdf_addtext_test.mbt` at 103/103
  tests passing; native full-suite validation reports 1875/1875 tests
  passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` single-page line emitter slice exposes
  `PdfDocument::addtext_line_page` and `pdf_addtext_line_page`, covering
  prepared-line placement, resource installation, text operator emission,
  selected-font URL annotation insertion, shifted text content, wrapper parity,
  prepend/fast insertion, and cpdf's existing-font opacity suppression. Native
  focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_addtext_test.mbt` at 105/105 tests passing;
  native full-suite validation reports 1877/1877 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` page-lines integration slice exposes
  `PdfDocument::addtext_page_lines` and `pdf_addtext_page_lines`, covering
  cpdf's initial multiline paragraph offsets, midline baseline adjustment,
  rotation-dependent line advancement via repeated single-line emission,
  resource accumulation across lines, content isolation wrappers when appending
  to non-empty pages, and wrapper parity. Native focused validation reports
  `moon test --target native --package bobzhang/pdflite --file
  pdf_addtext_test.mbt` at 107/107 tests passing; native full-suite validation
  reports 1879/1879 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` selected-page add-text integration slice
  exposes `PdfDocument::addtext_pages_with_font` and
  `pdf_addtext_pages_with_font`, covering empty-selection no-op behavior,
  one-based page validation, cpdf shift-coordinate parsing, page-local
  replacement values, selected page rewrites through `change_pages`, and
  wrapper parity for already resolved font/fontpack inputs. Native focused
  validation reports `moon test --target native --package bobzhang/pdflite
  --file pdf_addtext_test.mbt` at 109/109 tests passing; native full-suite
  validation reports 1881/1881 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` existing-font effective-name slice covers
  cpdf's `/BaseFont` fallback after existing page font lookup, so
  `PdfDocument::addtext_line_page` emits the resolved page resource key while
  preserving existing font dictionaries and leaving selected-font/fontpack
  resource names unchanged. Native focused validation reports `moon test
  --target native --package bobzhang/pdflite --file pdf_addtext_test.mbt` at
  110/110 tests passing; native full-suite validation reports 1882/1882 tests
  passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` existing-font text encoding slice covers
  cpdf's non-raw conversion of existing-font add-text through the resolved page
  font before width measurement, URL prefix measurement, and text-operator
  emission, while keeping fontpack/raw UTF-8 paths unchanged. Native focused
  validation reports `moon test --target native --package bobzhang/pdflite
  --file pdf_addtext_test.mbt` at 111/111 tests passing; native full-suite
  validation reports 1883/1883 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` outer resolved-font add-text slice exposes
  `PdfDocument::addtexts_with_font` and `pdf_addtexts_with_font`, covering
  split/unescape/rotation line preparation, selected-page visible-codepoint
  scanning, cpdf's empty-visible-text no-op before font writing, selected/fontpack
  font-object writing, and delegation to the selected-page add-text pipeline.
  Native focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_addtext_test.mbt` at 113/113 tests passing;
  native full-suite validation reports 1885/1885 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` non-embedding font-source slice exposes
  `PdfAddTextFontSource`, `PdfDocument::addtexts_with_source`, and
  `pdf_addtexts_with_source`, covering cpdf `PreMadeFontPack` first-font
  behavior, `ExistingNamedFont` delegation, empty-visible-text no-op before
  source resolution, and empty premade fontpack diagnostics while leaving
  TrueType `EmbedInfo` embedding for a separate slice. Native focused validation
  reports `moon test --target native --package bobzhang/pdflite --file
  pdf_addtext_test.mbt` at 117/117 tests passing; native full-suite validation
  reports 1891/1891 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` line-width selection and justification
  application slice exposes `pdf_addtext_longest_width` and
  `pdf_addtext_apply_justification_offset`, covering cpdf's widest expanded
  line selection, empty-width diagnostics, horizontal-rotation justification
  addition to `hoffset`, and vertical-rotation justification subtraction from
  `voffset`. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_addtext_test.mbt` at 61/61 tests
  passing; native full-suite validation reports 1833/1833 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` line-placement composition slice exposes
  `PdfAddTextLinePlacement` and `pdf_addtext_line_placement`, covering cpdf's
  `calculate_position` integration, diagonal offset correction hook,
  justification offset application, explicit text rotation, rotation-origin
  offsets, and horizontal/vertical rotation branches for one resolved add-text
  line. Native focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_addtext_test.mbt` at 94/94 tests passing; native
  full-suite validation reports 1866/1866 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` font resource installation slice exposes
  `pdf_addtext_install_font_resource` and
  `pdf_addtext_install_fontpack_resources`, covering cpdf's `/Font` resource
  dictionary insertion for selected-font and fontpack paths, existing resource
  preservation, embedded font indirect references, existing font dictionary
  preservation, and the missing-font no-op branch. Native focused validation
  reports `moon test --target native --package bobzhang/pdflite --file
  pdf_addtext_test.mbt` at 63/63 tests passing; native full-suite validation
  reports 1835/1835 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` selected-font object slice exposes
  `PdfDocument::addtext_selected_font_object` and
  `pdf_addtext_selected_font_object`, covering cpdf's selected parsed-font
  write path, indirect font object references, existing-named-font no-op mode,
  wrapper parity, and writer-error propagation for unsupported local font
  shapes. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_addtext_test.mbt` at 84/84 tests
  passing; native full-suite validation reports 1856/1856 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` URL annotation object slice exposes
  `pdf_addtext_url_annotation`, covering cpdf's `/Link` subtype dictionary,
  QuadPoints ordering, rectangle serialization, URI action dictionary, and
  URL-border width toggle. Native focused validation reports `moon test
  --target native --package bobzhang/pdflite --file pdf_addtext_test.mbt` at
  64/64 tests passing; native full-suite validation reports 1836/1836 tests
  passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` page annotation update slice exposes
  `PdfDocument::addtext_page_rest_with_annotations` and
  `pdf_addtext_page_rest_with_annotations`, covering cpdf's empty-annotation
  no-op, direct writeback to `/Annots`, prepending new annotation references
  before resolved existing arrays, and malformed existing annotation handling.
  Native focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_addtext_test.mbt` at 67/67 tests passing; native
  full-suite validation reports 1839/1839 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` URL annotation geometry slice exposes
  `PdfAddTextUrlAnnotationGeometry`,
  `pdf_addtext_url_annotation_height`, and
  `pdf_addtext_url_annotation_geometry`, covering cpdf's cap-height-to-font-size
  fallback, span rectangle construction from measured prefix widths,
  rotate-before-translation transform ordering, quad point ordering, and final
  axis-aligned annotation bounds. Native focused validation reports `moon test
  --target native --package bobzhang/pdflite --file pdf_addtext_test.mbt` at
  70/70 tests passing; native full-suite validation reports 1842/1842 tests
  passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` URL annotation prefix-width slice exposes
  `pdf_addtext_url_annotation_widths`, covering cpdf's `annot_coord` behavior
  for start/end URL span offsets, caller-provided text measurement, UTF-8 byte
  offset handling, and malformed span-boundary errors. Native focused validation
  reports `moon test --target native --package bobzhang/pdflite --file
  pdf_addtext_test.mbt` at 72/72 tests passing; native full-suite validation
  reports 1844/1844 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` used-codepoint scan slice exposes
  `pdf_addtext_used_codepoints`, covering cpdf's pre-embedding scan over
  expanded visible add-text lines, URL-stripped text, duplicate suppression,
  UTF-8 codepoints, and empty-line behavior. Native focused validation reports
  `moon test --target native --package bobzhang/pdflite --file
  pdf_addtext_test.mbt` at 74/74 tests passing; native full-suite validation
  reports 1846/1846 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` existing-font resource lookup slice exposes
  `PdfDocument::addtext_existing_font_resource` and
  `pdf_addtext_existing_font_resource`, covering cpdf's existing named font
  branch, direct `/Font` resource-key lookup, `/BaseFont` fallback with returned
  real resource name, indirect font preservation, wrapper parity, and missing
  font errors. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_addtext_test.mbt` at 77/77 tests
  passing; native full-suite validation reports 1849/1849 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` existing-font width slice exposes
  `PdfDocument::addtext_width_of_existing_font_resource` and
  `pdf_addtext_width_of_existing_font_resource`, covering cpdf's existing-font
  measurement path, direct resource-key lookup, `/BaseFont` fallback resource
  names, parsed font reading, Standard 14 width scaling, and wrapper parity.
  Native focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_addtext_test.mbt` at 79/79 tests passing; native
  full-suite validation reports 1851/1851 tests passing.~~
- [x] ~~Standalone `cpdfaddtext.ml` URL annotation reference slice exposes
  `PdfDocument::addtext_url_annotation_references` and
  `pdf_addtext_url_annotation_references`, covering cpdf's URL-span annotation
  construction path, visible-line prefix measurement, cap-height/font-size
  rectangle height, transformed quad/rect creation, indirect annotation object
  insertion, wrapper parity, and typed measurement-error propagation. Native
  focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_addtext_test.mbt` at 81/81 tests passing; native
  full-suite validation reports 1853/1853 tests passing.~~
- [x] ~~Standalone `cpdfremovetext.ml` removal slice exposes
  `pdf_remove_added_text_ops`, `pdf_remove_all_text_ops`,
  `PdfDocument::remove_added_text`, `remove_all_text`, and compatibility
  wrappers, covering nested and unterminated `/CPDFSTAMP` removal,
  text-showing operator filtering, selected-page rewrites, Form XObject text
  removal, wrapper parity, and source-document preservation. Native focused
  validation reports `moon test --target native pdf_remove_text_test.mbt` at
  7/7 tests passing; native full-suite validation reports 1719/1719 tests
  passing.~~
- [x] ~~Standalone `cpdfshape.ml` shape helper slice exposes the cpdf path
  model, `pdf_shape_kappa`, `pdf_restrict_angle`, `pdf_shape_circle`, and
  `pdf_shape_rectangle`, covering kappa parity, `restrict_angle` rounding and
  source edge semantics, rectangle path construction, circle Bezier quarter
  arcs, and segment joining. Native focused validation reports `moon test
  --target native pdf_shape_test.mbt` at 4/4 tests passing; native full-suite
  validation reports 1721/1721 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` path-geometry slice extends the cpdf path
  model with `PdfPathSegment::bounds`, `PdfPath::bounds`,
  `PdfPathSegment::transform`, `PdfPath::transform`, and compatibility
  wrappers, covering straight-segment bounds, Bezier control-point bounds,
  multi-subpath path bounds, cpdf's empty-path zero rectangle, segment
  transforms, and whole-path transforms while leaving the full semantic
  content-object filter/JSON walk for later slices. Native focused validation
  reports `moon test --target native --package bobzhang/pdflite --file
  pdf_shape_test.mbt` at 6/6 tests passing; native full-suite validation
  reports 1911/1911 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` path JSON slice exposes
  `PdfDrawnPath`, `PdfPathSegment::content_json`,
  `PdfPathSubpath::content_json`, `PdfDrawnPath::content_json`, and
  compatibility wrappers, matching cpdf's line/Bezier point arrays, closed
  subpath flag, winding strings, stroked/filled flags, and omitted subpath hole
  flag while leaving full semantic content-object extraction for later slices.
  Native focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_shape_test.mbt` at 7/7 tests passing; native
  full-suite validation reports 1912/1912 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` colour-state JSON slice exposes
  `PdfColourSpace::content_json`, `PdfContentColourValues`,
  `PdfContentColourValues::content_json`, and compatibility wrappers, matching
  cpdf's colour-space discriminator strings and `Floats`/`Named`/`Pattern`
  colour operand JSON while leaving the full path-state object assembly for a
  later slice. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_space_test.mbt` at 22/22 tests passing;
  native full-suite validation reports 1913/1913 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` path-state JSON slice exposes
  `PdfContentDashPattern`, `PdfContentPathState`, their `content_json` methods,
  and compatibility wrappers, matching cpdf's clipping-path wrapping,
  colour-space/colour-value fields, line width/cap/join, dash-pattern object,
  and rendering-intent state while leaving operator-driven state extraction for
  later slices. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_content_state_test.mbt` at 1/1 tests
  passing; native full-suite validation reports 1914/1914 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` content object/state JSON slice exposes
  `PdfContentClippingState`, `PdfContentGlyphState`, `PdfContentObject`, their
  `content_json` methods, and compatibility wrappers, matching cpdf's
  clipping-only state, glyph text-state fields, inline-image null placeholder,
  image/path/shading object JSON, and precomputed glyph bytes/extracted text
  fields while leaving font-driven glyph extraction and operator-driven content
  traversal for later slices. Native focused validation reports `moon test
  --target native --package bobzhang/pdflite --file pdf_content_state_test.mbt`
  at 3/3 tests passing; native full-suite validation reports 1916/1916 tests
  passing.~~
- [x] ~~Standalone `cpdfcontent.ml` content entry JSON assembly slice exposes
  `PdfContentState`, `PdfContentBoundingBox`, `PdfContentJsonEntry`, their
  `content_json` methods, and entry-array serialization, matching cpdf's
  `{"object", "state", "bbox"}` entry shape and eight-number bbox array while
  leaving `filter`-driven content discovery for later slices. Native focused
  validation reports `moon test --target native --package bobzhang/pdflite
  --file pdf_content_state_test.mbt` at 4/4 tests passing; native full-suite
  validation reports 1917/1917 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` raw-text charcode slice exposes
  `PdfFont::content_charcodes_of_bytes` and
  `pdf_content_charcodes_of_bytes`, matching cpdf's `charcodes_of_string`
  behavior for one-byte standard/simple fonts, big-endian two-byte CID-keyed
  fonts, and odd-length CID input returning an empty result while leaving
  `filter`-driven glyph discovery for later slices. Native focused validation
  reports `moon test --target native --package bobzhang/pdflite --file
  pdf_content_text_test.mbt` at 1/1 tests passing; native full-suite validation
  reports 1918/1918 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` glyph byte-construction slice exposes
  `PdfFont::content_bytes_of_charcode` and
  `pdf_content_bytes_of_charcode`, matching the raw byte construction used by
  cpdf's glyph JSON and test extractor paths for one-byte standard/simple
  fonts, big-endian two-byte CID-keyed fonts, and `char_of_int`-style invalid
  byte failures via `PdfError::InvalidByte`. Native focused validation reports
  `moon test --target native --package bobzhang/pdflite --file
  pdf_content_text_test.mbt` at 2/2 tests passing; native full-suite validation
  reports 1919/1919 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` text extra-metrics slice exposes
  `PdfFont::content_extra_metrics` and `pdf_content_extra_metrics`, matching
  cpdf's Type3 font-matrix bbox transform, descriptor bbox/ascent-descent
  fallback for simple and CID fonts, Standard 14 AFM `FontBBox` extraction, and
  missing-simple-descriptor zero fallback while leaving glyph placement in
  `process_tj` for later slices. Native focused validation reports `moon test
  --target native --package bobzhang/pdflite --file pdf_content_text_test.mbt`
  at 3/3 tests passing; native full-suite validation reports 1920/1920 tests
  passing.~~
- [x] ~~Standalone `cpdfcontent.ml` vertical-text predicate slice exposes
  `PdfFont::content_is_vertical` and `pdf_content_is_vertical`, matching
  cpdf's narrow `/Identity-V` predefined-CMap handling, horizontal
  `/Identity-H`, parsed external CMap `wmode = 1`, and false fallbacks for
  other fonts and other predefined CMaps while leaving width/placement
  integration for `process_tj` later. Native focused validation reports `moon
  test --target native --package bobzhang/pdflite --file
  pdf_content_text_test.mbt` at 4/4 tests passing; native full-suite validation
  reports 1921/1921 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` glyph width slice exposes
  `PdfFont::content_width_of_charcode` and
  `pdf_content_width_of_charcode`, matching cpdf's simple-font metric branch
  including Type3 font-matrix transforms, Standard 14 charwidth lookup, CID
  horizontal default-width fallback, CID vertical `/W2` widths, vertical
  fallback from `/W`, and zero fallback for missing vertical widths and simple
  fonts without metrics while leaving `process_tj` placement integration for
  later slices. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_content_text_test.mbt` at 5/5 tests
  passing; native full-suite validation reports 1922/1922 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` `process_tj` geometry slice exposes
  `PdfContentTextLayout`, `PdfContentTextGlyphPlacement`,
  `PdfContentTextLayoutResult`, `PdfFont::content_text_layout_of_bytes`, and
  `pdf_content_text_layout_of_bytes`, matching cpdf's glyph-unit divisor,
  text-rendering matrix composition, horizontal word/character spacing,
  vertical advance behavior, CID placement vectors, and final text-matrix
  advance while leaving the operator-driven content filter walk and `TJ`
  array adjustment integration for later slices. Native focused validation
  reports `moon test --target native --package bobzhang/pdflite --file
  pdf_content_text_test.mbt` at 7/7 tests passing; native full-suite validation
  reports 1924/1924 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` `process_capital_tj` adjustment slice
  exposes `PdfFont::content_text_layout_of_tj_array` and
  `pdf_content_text_layout_of_tj_array`, matching cpdf's `PdfString` delegation
  to `process_tj`, horizontal numeric text-matrix backtracking, vertical numeric
  displacement, ignored non-string/non-real operands, and final text-matrix
  threading while leaving the full operator-driven content filter walk for
  later slices. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_content_text_test.mbt` at 9/9 tests
  passing; native full-suite validation reports 1926/1926 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` shading/pattern reader slice exposes
  `PdfContentTiling`, `PdfContentFunctionShading`,
  `PdfContentRadialShading`, `PdfContentAxialShading`,
  `PdfContentShadingKind`, `PdfContentShading`, `PdfContentPattern`,
  document shading-reader methods, and pattern lookup wrappers, matching cpdf's
  function/radial/axial domain defaults, function fallback, extend defaults,
  shading-type dispatch, lowercase `/colourSpace` lookup, `/BBox`-driven
  antialias behavior, tiling-pattern placeholder, and missing-shading error
  while leaving stateful colour/pattern integration for later slices. Native
  focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_content_shading_test.mbt` at 4/4 tests passing;
  native full-suite validation reports 1930/1930 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` path bounding-box emission slice exposes
  `PdfPath::content_bounding_box` and `pdf_path_content_bounding_box`, matching
  cpdf's CTM-first path transform, empty-path suppression, stroked line-width
  expansion from the transformed `(line_width, line_width)` vector, and
  eight-point quad assembly while leaving the stateful operator callback wiring
  for later slices. Native focused validation reports `moon test --target
  native --package bobzhang/pdflite --file pdf_shape_test.mbt` at 8/8 tests
  passing; native full-suite validation reports 1931/1931 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` path state-machine slice exposes
  `PdfContentPartialPath`, `PdfContentPartialPathState`,
  `PdfContentPathOpResult`, `pdf_content_no_partial_path`,
  `PdfContentPartialPath::content_apply_path_op`, and
  `pdf_content_apply_path_op`, matching cpdf's move-to subpath splitting,
  line/Bezier shorthand construction, close-path behavior, rectangle expansion
  to three explicit line segments plus a closed subpath, nonzero/even-odd
  fill/stroke painting, `s`/`b`/`B*` close-before-paint behavior, source-shaped
  `b*` double-close behavior, `n` reset, and non-path operator ignore behavior
  while leaving the full stateful content walker for later slices. Native
  focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_content_path_machine_test.mbt` at 5/5 tests
  passing; native full-suite validation reports 1936/1936 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` clipping path update slice exposes
  `PdfContentClippingOpResult`,
  `PdfContentPartialPath::content_apply_clipping_op`, and
  `pdf_content_apply_clipping_op`, matching cpdf's `W`/`W*` handling,
  nonzero/even-odd clipping rules, closed current-segment clipping, preserved
  partial path until a later `n`, no-op empty/no-partial clipping, newest
  clipping-path stack prepending, and cpdf's newest-subpath-first clipping
  order while leaving the full stateful content walker for later slices. Native
  focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_content_path_machine_test.mbt` at 7/7 tests
  passing; native full-suite validation reports 1938/1938 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` initial-state slice exposes
  `pdf_content_initial_clipping_path`, `pdf_content_initial_drawn_path`,
  `pdf_content_initial_path_state`, `pdf_content_initial_clipping_state`, and
  `pdf_content_initial_glyph_state`, matching cpdf's page-boundary even-odd
  clipping rectangle, empty drawn-path placeholder, DeviceGray/default-white
  colour state, default line/dash/rendering-intent path state, and default
  glyph rendering mode, knockout, font name, and font size while leaving the
  full stateful content walker for later slices. Native focused validation
  reports `moon test --target native --package bobzhang/pdflite --file
  pdf_content_state_test.mbt` at 5/5 tests passing; native full-suite
  validation reports 1939/1939 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` pure path-state operator slice exposes
  `PdfContentPathState::content_apply_path_state_op` and
  `pdf_content_apply_path_state_op`, matching cpdf's `w`, `J`, `j`, `d`, `ri`,
  device colour setters, float colour operands, device-name `CS`/`cs` initial
  colours, ignored resource-dependent colour-space names, and the source-shaped
  `SCN`/`scn` named-colour target behavior while leaving resource dictionary
  lookup, graphics-state dictionaries, and the full stateful content walker for
  later slices. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_content_state_test.mbt` at 7/7 tests
  passing; native full-suite validation reports 1941/1941 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` pure text-state operator slice exposes
  `PdfContentTextState`, `pdf_content_initial_text_state`,
  `PdfContentTextState::content_apply_text_state_op`, and
  `pdf_content_apply_text_state_op`, matching cpdf's initial spacing, leading,
  font, rendering, rise, and matrix defaults; `BT`/`ET`; spacing/scaling/font
  state updates; `Td`/`TD`/`Tm`/`T*`; and quote/double-quote state shorthands
  while leaving font resource lookup, text-showing glyph emission, text-matrix
  advance from `Tj`/`TJ`, and the full stateful content walker for later
  slices. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_content_text_test.mbt` at 11/11 tests
  passing; native full-suite validation reports 1943/1943 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` text-show operator slice exposes
  `PdfContentTextOpResult`, `PdfContentTextState::content_text_layout`,
  `PdfContentTextState::content_apply_text_op`, and
  `pdf_content_apply_text_op`, integrating the existing `Tj`/`TJ` glyph layout
  helpers with text-state matrix advancement, preserving line matrix state,
  handling non-array `TJ` operands as empty, and applying quote/double-quote
  shorthands before glyph emission while leaving font resource lookup and the
  full stateful content walker for later slices. Native focused validation
  reports `moon test --target native --package bobzhang/pdflite --file
  pdf_content_text_test.mbt` at 13/13 tests passing; native full-suite
  validation reports 1945/1945 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` JSON-facing state adapter slice exposes
  `pdf_content_clipping_state_of_paths`,
  `PdfContentPathState::content_with_clipping_path`,
  `pdf_content_path_state_with_clipping_path`,
  `PdfContentTextState::content_glyph_state`, and
  `pdf_content_glyph_state_of_text_state`, matching cpdf's reuse of the current
  clipping path stack across clipping-only/path/glyph JSON states and glyph
  state projection from text rendering mode, knockout, font, and font size
  while leaving the full stateful content walker for later slices. Native
  focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_content_state_test.mbt` at 8/8 tests passing;
  native full-suite validation reports 1946/1946 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` graphics-state stack slice exposes
  `PdfContentOperatorFrame`, `PdfContentOperatorState`,
  `pdf_content_initial_operator_state`,
  `PdfContentOperatorState::content_apply_graphics_state_op`, and
  `pdf_content_apply_graphics_state_op`, matching cpdf's initial operator-state
  assembly, `q` frame push, `Q` frame restore with underflow no-op behavior,
  and `cm` CTM concatenation while leaving resource dictionaries and the full
  stateful content walker for later slices. Native focused validation reports
  `moon test --target native --package bobzhang/pdflite --file
  pdf_content_operator_state_test.mbt` at 3/3 tests passing; native full-suite
  validation reports 1949/1949 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` resource-free operator dispatcher slice
  exposes `PdfContentOperatorState::content_apply_core_op` and
  `pdf_content_apply_core_op`, routing q/Q/cm, path construction and painting,
  clipping-path updates, path drawing state, and text state through the
  already-ported helpers while deliberately leaving font lookup, glyph emission,
  shadings, images/XObjects, marked-content metadata, and graphics-state
  dictionaries for resource-backed slices. Native focused validation reports
  `moon test --target native --package bobzhang/pdflite --file
  pdf_content_operator_state_test.mbt` at 5/5 tests passing; native full-suite
  validation reports 1951/1951 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` marked-content state slice adds
  `PdfContentMarkedContent`, carries `marked_content_point` and
  `marked_content` through `PdfContentOperatorState`/stack frames, and exposes
  `PdfContentOperatorState::content_apply_marked_content_op` plus
  `pdf_content_apply_marked_content_op`, matching cpdf's MP/DP point assignment,
  BMC/BDC newest-first stack push, EMC pop, underflow no-op, and q/Q
  save/restore behavior. Native focused validation reports `moon test --target
  native --package bobzhang/pdflite --file pdf_content_operator_state_test.mbt`
  at 6/6 tests passing; native full-suite validation reports 1952/1952 tests
  passing.~~
- [x] ~~Standalone `cpdfcontent.ml` Type 3 metric-state slice adds
  `PdfContentType3D0`, `PdfContentType3D1`, `type3_d0`, and `type3_d1` to the
  operator state and stack frames, and exposes
  `PdfContentOperatorState::content_apply_type3_metrics_op` plus
  `pdf_content_apply_type3_metrics_op`, matching cpdf's `d0` and `d1` state
  assignments and q/Q save/restore behavior while leaving Type 3 resource
  integration for later slices. Native focused validation reports `moon test
  --target native --package bobzhang/pdflite --file
  pdf_content_operator_state_test.mbt` at 7/7 tests passing; native full-suite
  validation reports 1953/1953 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` direct graphics-parameter slice adds
  `miter_limit` and `flatness` to the operator state and stack frames, and
  exposes `PdfContentOperatorState::content_apply_graphics_parameter_op` plus
  `pdf_content_apply_graphics_parameter_op`, matching cpdf's initial `M = 10`
  and `i = 1` values, direct `M`/`i` assignment, and q/Q save/restore behavior
  while leaving ExtGState dictionary parsing for a later resource-backed slice.
  Native focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_content_operator_state_test.mbt` at 8/8 tests
  passing; native full-suite validation reports 1954/1954 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` image-entry emission slice exposes
  `PdfContentOperatorState::content_unit_square_bounding_box`,
  `content_inline_image_entry`, `content_image_entry`, and compatibility
  wrappers, matching cpdf's current-CTM unit-square bbox for inline images and
  image XObjects plus clipping-only content state while leaving inline-image
  data preservation and XObject resource lookup for later slices. Native
  focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_content_operator_state_test.mbt` at 9/9 tests
  passing; native full-suite validation reports 1955/1955 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` path-entry emission slice exposes
  `PdfContentOperatorState::content_path_entry` and
  `pdf_content_path_entry`, matching cpdf's `emit_path_bounding_box` behavior
  for current drawn paths: CTM-transformed path bounds, stroked line-width
  expansion, clipping-aware path state, and no emitted entry for empty paths.
  Native focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_content_operator_state_test.mbt` at 10/10 tests
  passing; native full-suite validation reports 1956/1956 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` shading-entry emission slice exposes
  `PdfContentOperatorState::content_shading_entry` and
  `pdf_content_shading_entry`, matching cpdf's `Op_sh` entry assembly for
  explicit shading `/BBox` rectangles and the unbounded-shading fallback to the
  current CTM-transformed clipping path, with clipping-only content state while
  leaving `/Shading` resource lookup for a later slice. Native focused
  validation reports `moon test --target native --package bobzhang/pdflite
  --file pdf_content_operator_state_test.mbt` at 11/11 tests passing; native
  full-suite validation reports 1957/1957 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` shading resource-entry slice exposes
  `PdfDocument::content_shading_entry_from_resources` and
  `pdf_content_shading_entry_from_resources`, matching cpdf's `Op_sh`
  resource lookup for named `/Shading` entries, explicit `/BBox` parsing,
  malformed bbox suppression, missing-resource no-op, and unbounded fallback
  to the current clipping path while leaving full operator walking for later
  slices. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_content_operator_state_test.mbt` at
  12/12 tests passing; native full-suite validation reports 1958/1958 tests
  passing.~~
- [x] ~~Standalone `cpdfcontent.ml` image XObject resource-entry slice exposes
  `PdfDocument::content_image_entry_from_resources` and
  `pdf_content_image_entry_from_resources`, matching cpdf's `Op_Do` `/XObject`
  lookup for named image resources, cpdf error strings for missing resources,
  missing names, and unknown XObject kinds, and the no-entry behavior for
  `/Form` XObjects while leaving recursive Form content walking for later
  slices. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_content_operator_state_test.mbt` at
  13/13 tests passing; native full-suite validation reports 1959/1959 tests
  passing.~~
- [x] ~~Standalone `cpdfcontent.ml` Form XObject entry-state slice exposes
  `PdfDocument::content_form_xobject_enter_state` and
  `pdf_content_form_xobject_enter_state`, matching cpdf's `Op_Do /Form` setup
  for graphics-state save, Form `/Matrix` concatenation, `/BBox` clipping,
  malformed or missing BBox fallback, malformed Matrix propagation, and
  image-XObject no-entry behavior while leaving recursive Form content walking
  for a later slice. Native focused validation reports `moon test --target
  native --package bobzhang/pdflite --file
  pdf_content_operator_state_test.mbt` at 14/14 tests passing; native
  full-suite validation reports 1960/1960 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` Form XObject resource-merge slice exposes
  `PdfDocument::content_form_xobject_resources` and
  `pdf_content_form_xobject_resources`, matching cpdf's `process_form_xobject`
  shallow `mergedict pagedict xobjdict` behavior where Form stream
  `/Resources` replace page resources on duplicate top-level keys, page-only
  resources are retained, image XObjects produce no Form resources, and
  recursive Form content walking remains for a later slice. Focused native
  validation reports `moon test --target native
  pdf_content_operator_state_test.mbt --filter '*Form XObject*'` at 2/2 tests
  passing and `moon test --target native pdf_content_operator_state_test.mbt`
  at 15/15 tests passing; native check validation reports `moon check --target
  native` passing with the known `markdown/cmd` warning and
  `moon check --target native --warn-list +73` at the known 10-warning
  baseline. Full native suite validation is deferred to the next batch.~~
- [x] ~~Standalone `cpdfcontent.ml` Form XObject operator-parse slice exposes
  `PdfDocument::content_form_xobject_ops` and
  `pdf_content_form_xobject_ops`, matching cpdf's `process_form_xobject`
  parse step by decoding and parsing the named Form XObject stream with the
  merged page/Form resource dictionary, including resource-aware inline-image
  parsing, image-XObject no-op behavior, and the existing cpdf XObject error
  paths while leaving recursive stateful Form walking for a later slice.
  Focused native validation reports `moon test --target native
  pdf_content_operator_state_test.mbt --filter '*Form XObject*'` at 3/3 tests
  passing and `moon test --target native pdf_content_operator_state_test.mbt`
  at 16/16 tests passing; native check validation reports `moon check --target
  native` passing with the known `markdown/cmd` warning and
  `moon check --target native --warn-list +73` at the known 10-warning
  baseline. Full native suite validation is deferred to the next batch.~~
- [x] ~~Standalone `cpdfcontent.ml` text knockout-state slice adds `knockout`
  to `PdfContentTextState` and projects it through
  `PdfContentTextState::content_glyph_state`, matching cpdf's
  `initial_text_state` default and `json_of_state_glyph` use of the current text
  state's knockout flag while preparing the later `/ExtGState /TK` slice.
  Focused native validation reports `moon test --target native
  pdf_content_text_test.mbt` at 13/13 tests passing and `moon test --target
  native pdf_content_state_test.mbt` at 8/8 tests passing; native check
  validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at
  the known 10-warning baseline. Native full-suite validation reports
  1962/1962 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` ExtGState text-state slice exposes
  `PdfDocument::content_apply_extgstate_text_op` and
  `pdf_content_apply_extgstate_text_op`, matching cpdf's
  `read_graphics_state_dictionary` `/TK` branch once an ExtGState dictionary has
  been resolved by applying boolean `/TK` values to the current text-state
  knockout flag and ignoring missing or non-boolean values while leaving
  ExtGState resource-name resolution and the remaining graphics-state dictionary
  fields for later slices. Focused native validation reports `moon test --target
  native pdf_content_operator_state_test.mbt --filter '*ExtGState*'` at 1/1
  tests passing and `moon test --target native
  pdf_content_operator_state_test.mbt` at 17/17 tests passing; native check
  validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at the
  known 10-warning baseline. Full native suite validation is deferred to the
  next batch.~~
- [x] ~~Standalone `cpdfcontent.ml` ExtGState graphics-parameter slice exposes
  `PdfDocument::content_apply_extgstate_graphics_parameter_op` and
  `pdf_content_apply_extgstate_graphics_parameter_op`, matching cpdf's
  `read_graphics_state_dictionary` scalar/name graphics branches once an
  ExtGState dictionary has been resolved by applying `/LW`, `/LC`, `/LJ`, `/ML`,
  `/RI`, and `/FL` through the existing core operator state machinery, including
  integer-to-float widening where cpdf does it and source-shaped ignored
  malformed values, while leaving `/D` dash parsing, resource-name resolution,
  and the wider non-JSON graphics-state fields for later slices. Focused native
  validation reports `moon test --target native
  pdf_content_operator_state_test.mbt --filter '*ExtGState*'` at 2/2 tests
  passing and `moon test --target native pdf_content_operator_state_test.mbt` at
  18/18 tests passing; native check validation reports `moon check --target
  native` passing with the known `markdown/cmd` warning and `moon check --target
  native --warn-list +73` at the known 10-warning baseline. Full native suite
  validation is deferred to the next batch.~~
- [x] ~~Standalone `cpdfcontent.ml` ExtGState dash-parameter slice exposes
  `PdfDocument::content_apply_extgstate_dash_op` and
  `pdf_content_apply_extgstate_dash_op`, matching cpdf's
  `read_graphics_state_dictionary` `/D` branch once an ExtGState dictionary has
  been resolved by applying exact two-element dash arrays, widening integer dash
  values and phase to floats, treating a non-array dash-list operand as an empty
  dash array, ignoring malformed outer `/D` shapes, and propagating
  `NumberExpected` for malformed numeric dash members or phase while leaving
  resource-name resolution and the remaining non-JSON graphics-state fields for
  later slices. Focused native validation reports `moon test --target native
  pdf_content_operator_state_test.mbt --filter '*ExtGState*'` at 3/3 tests
  passing and `moon test --target native pdf_content_operator_state_test.mbt` at
  19/19 tests passing; native check validation reports `moon check --target
  native` passing with the known `markdown/cmd` warning and `moon check --target
  native --warn-list +73` at the known 10-warning baseline. Native full-suite
  validation reports 1965/1965 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` ExtGState alpha-state slice adds
  `alpha_constant_stroke`, `alpha_constant_non_stroke`, and `alpha_source` to
  `PdfContentOperatorState` and q/Q frames, and exposes
  `PdfDocument::content_apply_extgstate_alpha_op` plus
  `pdf_content_apply_extgstate_alpha_op`, matching cpdf's initial alpha defaults
  and `read_graphics_state_dictionary` `/CA`, `/ca`, and `/AIS` branches once an
  ExtGState dictionary has been resolved, including integer-to-float widening,
  boolean alpha-source handling, ignored malformed values, and q/Q
  save-restore behavior while leaving resource-name resolution and the remaining
  non-JSON graphics-state fields for later slices. Focused native validation
  reports `moon test --target native pdf_content_operator_state_test.mbt
  --filter '*ExtGState*'` at 4/4 tests passing and `moon test --target native
  pdf_content_operator_state_test.mbt` at 20/20 tests passing; native check
  validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at the
  known 10-warning baseline. Full native suite validation is deferred to the
  next batch.~~
- [x] ~~Standalone `cpdfcontent.ml` ExtGState rendering-state slice adds
  `smoothness` and `stroke_adjustment` to `PdfContentOperatorState` and q/Q
  frames, and exposes `PdfDocument::content_apply_extgstate_rendering_op` plus
  `pdf_content_apply_extgstate_rendering_op`, matching cpdf's initial
  smoothness/stroke-adjustment defaults and `read_graphics_state_dictionary`
  `/SM` and `/SA` branches once an ExtGState dictionary has been resolved,
  including integer-to-float widening, boolean stroke-adjustment handling,
  ignored malformed values, and q/Q save-restore behavior while leaving
  resource-name resolution and the remaining non-JSON graphics-state fields for
  later slices. Focused native validation reports `moon test --target native
  pdf_content_operator_state_test.mbt --filter '*ExtGState*'` at 5/5 tests
  passing and `moon test --target native pdf_content_operator_state_test.mbt` at
  21/21 tests passing; native check validation reports `moon check --target
  native` passing with the known `markdown/cmd` warning and `moon check --target
  native --warn-list +73` at the known 10-warning baseline. Full native suite
  validation is deferred to the next batch.~~
- [x] ~~Standalone `cpdfcontent.ml` ExtGState overprint-state slice adds
  `overprint_stroke`, `overprint_non_stroke`, and `overprint_mode` to
  `PdfContentOperatorState` and q/Q frames, and exposes
  `PdfDocument::content_apply_extgstate_overprint_op` plus
  `pdf_content_apply_extgstate_overprint_op`, matching cpdf's initial overprint
  defaults and `read_graphics_state_dictionary` `/OP` and source-shaped `/op`
  branches once an ExtGState dictionary has been resolved, including `/OP`
  propagation to non-stroking overprint when boolean `/op` is absent, explicit
  boolean `/op` non-stroking override, integer `/op` overprint-mode assignment,
  ignored malformed values, and q/Q save-restore behavior while leaving
  resource-name resolution and the remaining non-JSON graphics-state fields for
  later slices. Focused native validation reports `moon test --target native
  pdf_content_operator_state_test.mbt --filter '*ExtGState*'` at 6/6 tests
  passing and `moon test --target native pdf_content_operator_state_test.mbt` at
  22/22 tests passing; native check validation reports `moon check --target
  native` passing with the known `markdown/cmd` warning and `moon check --target
  native --warn-list +73` at the known 10-warning baseline. Native full-suite
  validation reports 1968/1968 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` ExtGState transfer-function slice adds
  `black_generation`, `undercolour_removal`, and `transfer` to
  `PdfContentOperatorState` and q/Q frames, and exposes
  `PdfDocument::content_apply_extgstate_transfer_op` plus
  `pdf_content_apply_extgstate_transfer_op`, matching cpdf's initial `Pdf.Null`
  defaults and `read_graphics_state_dictionary` `/BG`, `/BG2`, `/UCR`, `/UCR2`,
  `/TR`, and `/TR2` branches once an ExtGState dictionary has been resolved,
  including source-order `*2` override behavior, ignored `Null` values, arbitrary
  direct PDF object preservation, and q/Q save-restore behavior while leaving
  resource-name resolution and the remaining non-JSON graphics-state fields for
  later slices. Focused native validation reports `moon test --target native
  pdf_content_operator_state_test.mbt --filter '*ExtGState*'` at 7/7 tests
  passing and `moon test --target native pdf_content_operator_state_test.mbt` at
  23/23 tests passing; native check validation reports `moon check --target
  native` passing with the known `markdown/cmd` warning and `moon check --target
  native --warn-list +73` at the known 10-warning baseline. Full native suite
  validation is deferred to the next batch.~~
- [x] ~~Standalone `cpdfcontent.ml` ExtGState halftone-state slice adds
  `halftone` to `PdfContentOperatorState` and q/Q frames, and exposes
  `PdfDocument::content_apply_extgstate_halftone_op` plus
  `pdf_content_apply_extgstate_halftone_op`, matching cpdf's initial `Pdf.Null`
  default and `read_graphics_state_dictionary` `/HT`, source-shaped `/SMask`, and
  `/HTO` assignments once an ExtGState dictionary has been resolved, including
  source-order override behavior where `/SMask` replaces `/HT` and `/HTO`
  replaces both, ignored `Null` values, arbitrary direct PDF object preservation,
  and q/Q save-restore behavior while leaving resource-name resolution and the
  remaining non-JSON graphics-state fields for later slices. Focused native
  validation reports `moon test --target native
  pdf_content_operator_state_test.mbt --filter '*ExtGState*'` at 8/8 tests
  passing and `moon test --target native pdf_content_operator_state_test.mbt` at
  24/24 tests passing; native check validation reports `moon check --target
  native` passing with the known `markdown/cmd` warning and `moon check --target
  native --warn-list +73` at the known 10-warning baseline. Full native suite
  validation is deferred to the next batch.~~
- [x] ~~Standalone `cpdfcontent.ml` ExtGState compositing-state slice adds
  `blend_mode` and `black_point_compensation` to `PdfContentOperatorState` and
  q/Q frames, and exposes `PdfDocument::content_apply_extgstate_compositing_op`
  plus `pdf_content_apply_extgstate_compositing_op`, matching cpdf's initial
  `/Normal` blend-mode and `/Default` black-point-compensation defaults and
  `read_graphics_state_dictionary` `/BM` and `/UseBlackPtComp` branches once an
  ExtGState dictionary has been resolved, including arbitrary direct blend-mode
  object preservation, name-only black-point-compensation assignment, ignored
  `Null`/malformed values, and q/Q save-restore behavior while leaving
  resource-name resolution, the unused `soft_mask` state slot, and font-backed
  ExtGState entries for later slices. Focused native validation reports `moon
  test --target native pdf_content_operator_state_test.mbt --filter
  '*ExtGState*'` at 9/9 tests passing and `moon test --target native
  pdf_content_operator_state_test.mbt` at 25/25 tests passing; native check
  validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at the
  known 10-warning baseline. Native full-suite validation reports `moon test
  --target native` at 1971/1971 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` soft-mask state-completeness slice adds the
  cpdf initial `soft_mask = Pdf.Null` slot to `PdfContentOperatorState` and q/Q
  frames, including initial-state exposure and graphics-state save/restore
  coverage while preserving cpdf's source-shaped `/SMask` ExtGState assignment
  through the existing halftone field rather than mutating this unused slot.
  Focused native validation reports `moon test --target native
  pdf_content_operator_state_test.mbt --filter '*initial state*'` at 1/1 test
  passing, `moon test --target native pdf_content_operator_state_test.mbt
  --filter '*q Q*'` at 1/1 test passing, and `moon test --target native
  pdf_content_operator_state_test.mbt` at 25/25 tests passing; native check
  validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at the
  known 10-warning baseline. Full native suite validation is deferred to the
  next batch.~~
- [x] ~~Standalone `cpdfcontent.ml` ExtGState font-state slice exposes
  `PdfDocument::content_apply_extgstate_font_op` and
  `pdf_content_apply_extgstate_font_op`, matching cpdf's `/Font` branch for a
  resolved ExtGState dictionary by accepting `[indirect-font size]`, validating
  the indirect font through `read_font`, assigning the synthetic
  `__EXTGSTATE__<object-number>` font name, widening numeric font sizes,
  preserving the previous size for malformed size objects, ignoring non-indirect
  font arrays, and propagating malformed font-object errors while leaving cached
  `font_data`/text-extractor storage and glyph emission from ExtGState fonts for
  a later resource-backed pass. Focused native validation reports `moon test
  --target native pdf_content_operator_state_test.mbt --filter '*ExtGState*'` at
  10/10 tests passing and `moon test --target native
  pdf_content_operator_state_test.mbt` at 26/26 tests passing; native check
  validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at the
  known 10-warning baseline. Full native suite validation is deferred to the
  next batch.~~
- [x] ~~Standalone `cpdfcontent.ml` source-shaped ExtGState resource slice
  exposes `PdfDocument::content_apply_extgstate_resource_op` and
  `pdf_content_apply_extgstate_resource_op`, mirroring cpdf's `Op_gs` dispatch
  by looking up `/ExtGState` in the supplied resources and treating that object
  itself as the graphics-state dictionary while deliberately ignoring the `gs`
  operand name, then applying the already-ported graphics, dash, font,
  overprint, transfer, halftone, rendering, compositing, alpha, and text-state
  branches in cpdf-compatible order. Coverage locks down source-shaped direct
  `/ExtGState` dictionaries, wrapper parity, missing resources, and the
  source-compatible non-application of spec-shaped nested `/GS1` dictionaries
  while leaving a future spec-correct named-resource helper, if desired, separate
  from the cpdf port. Focused native validation reports `moon test --target
  native pdf_content_operator_state_test.mbt --filter '*ExtGState*'` at 11/11
  tests passing and `moon test --target native
  pdf_content_operator_state_test.mbt` at 27/27 tests passing; native check
  validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at the
  known 10-warning baseline. Native full-suite validation reports `moon test
  --target native` at 1973/1973 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` text glyph-entry bridge slice adds
  `PdfContentOperatorTextResult`,
  `PdfContentOperatorState::content_text_glyph_entry`,
  `pdf_content_text_glyph_entry`,
  `PdfContentOperatorState::content_apply_text_show_op`, and
  `pdf_content_apply_text_show_op`, turning already-ported text layout glyph
  placements into cpdfcontent JSON glyph entries with raw glyph bytes,
  extracted UTF-8 text through the font extractor, glyph-state projection, and
  bounding boxes while returning the advanced text state for `Tj`, `TJ`, quote,
  and double-quote text-showing operators. It leaves page resource font lookup,
  cached `font_data`, and the full stateful content walker for later slices.
  Focused native validation reports `moon test --target native
  pdf_content_operator_state_test.mbt --filter '*text glyph*'` at 1/1 test
  passing and `moon test --target native pdf_content_operator_state_test.mbt`
  at 28/28 tests passing; native check validation reports `moon check --target
  native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at the
  known 10-warning baseline. Full native suite validation is deferred to the
  next batch.~~
- [x] ~~Standalone `cpdfcontent.ml` font resource/cache bridge slice adds
  `PdfContentTextFontCacheEntry`,
  `PdfContentTextState.current_font`,
  `PdfContentTextState.font_cache`,
  `PdfContentTextState::content_cached_font`,
  `PdfContentTextState::content_cache_font`,
  `PdfDocument::content_apply_font_resource_op`, and
  `pdf_content_apply_font_resource_op`, mirroring cpdf's `Tf` resource lookup
  through page `/Font` dictionaries with cache hits before resource lookup,
  missing-resource fallback that preserves the previous font data, and malformed
  font-object error propagation. The slice also teaches ExtGState `/Font` to
  update the current font object, matching cpdf's uncached ExtGState font-data
  branch. It leaves resource-backed text-showing dispatch, Form XObject
  temporary font-cache clearing, and the full stateful content walker for later
  slices. Focused native validation reports the native
  `pdf_content_text_test.mbt --filter '*initial defaults*'` run at 1/1 test
  passing and the native `pdf_content_operator_state_test.mbt` run with
  `--filter '*font*'` at 2/2 tests passing; widened native validation reports
  `moon test --target native pdf_content_text_test.mbt` at 13/13 tests passing,
  `moon test --target native pdf_content_operator_state_test.mbt` at 29/29
  tests passing, and `moon test --target native pdf_content_state_test.mbt` at
  8/8 tests passing. Native check validation reports `moon check --target
  native` passing with the known `markdown/cmd` warning and `moon check --target
  native --warn-list +73` at the known 10-warning baseline. Full native suite
  validation is deferred to the next batch.~~
- [x] ~~Standalone `cpdfcontent.ml` resource-backed text operator slice adds
  `PdfDocument::content_apply_text_resource_op` and
  `pdf_content_apply_text_resource_op`, routing `Tf` through the page `/Font`
  resource/cache bridge, applying text-state-only operators without emitted
  entries, and emitting `Tj`/`TJ`/quote/double-quote glyph entries through the
  current font stored in `PdfContentTextState.current_font`. This connects the
  previous font-data bridge to the glyph-entry bridge while leaving path/image/
  shading/Form dispatch and the full stateful content walker for later slices.
  Focused native validation reports `moon test --target native
  pdf_content_operator_state_test.mbt --filter '*text operators*'` at 1/1 test
  passing; widened native validation reports `moon test --target native
  pdf_content_operator_state_test.mbt` at 30/30 tests passing. Native check
  validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at the
  known 10-warning baseline. Batch full-suite validation reports `moon test
  --target native` at 1976/1976 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` single resource-operator dispatcher slice
  adds `PdfContentOperatorResourceResult`,
  `PdfDocument::content_apply_resource_op`, and
  `pdf_content_apply_resource_op`, composing the already-ported core state
  machine, resource-backed text operator bridge, source-shaped ExtGState
  application, path painting entry emission, shading lookup, image XObject entry
  emission, and inline-image entry emission for one operator at a time. It
  deliberately leaves recursive Form XObject walking and full page-content
  collection for later slices. Focused native validation reports the native
  `pdf_content_operator_state_test.mbt` run with
  `--filter '*resource operator dispatcher*'` at 1/1 test passing; widened
  native validation reports `moon test --target native
  pdf_content_operator_state_test.mbt` at 31/31 tests passing. Native check
  validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at the
  known 10-warning baseline. Full native suite validation is deferred to the
  next batch.~~
- [x] ~~Standalone `cpdfcontent.ml` nonrecursive content-entry collection slice
  adds `PdfDocument::content_entries_of_ops` and
  `pdf_content_entries_of_ops`, threading an initial cpdfcontent page state
  through a content-operator array via `content_apply_resource_op` and
  accumulating emitted JSON entries in source order. Coverage locks down mixed
  font selection, glyph emission, path painting, inline-image emission, and
  wrapper parity for a single nonrecursive content stream while leaving
  recursive Form XObject walking and page-level content parsing for later
  slices. Focused native validation reports the native
  `pdf_content_operator_state_test.mbt` run with
  `--filter '*nonrecursive content entries*'` at 1/1 test passing; widened
  native validation reports `moon test --target native
  pdf_content_operator_state_test.mbt` at 32/32 tests passing. Native check
  validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at the
  known 10-warning baseline. Full native suite validation is deferred to the
  next batch.~~
- [x] ~~Standalone `cpdfcontent.ml` recursive Form-entry collection slice adds
  `PdfDocument::content_entries_of_ops_recursive` and
  `pdf_content_entries_of_ops_recursive`, walking Form XObjects from `Do`
  operators by entering the cpdf-style q/CTM/BBox clipping state, clearing the
  temporary form font cache, merging form resources, parsing form operators, and
  recursively accumulating their entries before resuming the outer page stream.
  Coverage locks down Form glyph emission and restoration of the following
  page-level font state while preserving wrapper parity. Focused native
  validation reports the native `pdf_content_operator_state_test.mbt` run with
  `--filter '*recursively collects Form*'` at 1/1 test passing; widened native
  validation reports `moon test --target native
  pdf_content_operator_state_test.mbt` at 33/33 tests passing. Native check
  validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at the
  known 10-warning baseline. Batch full-suite validation reports `moon test
  --target native` at 1979/1979 tests passing.~~
- [x] ~~Standalone `cpdfcontent.ml` page-content JSON adapter slice adds
  `PdfDocument::content_entries_of_page`,
  `PdfDocument::content_json_of_ops`, `PdfDocument::content_json_of_page`, and
  `PdfDocument::page_content_json` plus compatibility wrappers, matching cpdf's
  outer `PageContentJSON` flow by parsing page streams with resources, using the
  recursive content-entry walker, serializing entries through the existing JSON
  shape, and assembling selected pages as `{page, contents}` objects in document
  order. Coverage locks down page-level path entry extraction, direct
  operator-list JSON parity, wrapper parity, selected-page ordering, empty
  selection, and invalid-page diagnostics. Focused native validation reports
  `moon test --target native pdf_content_page_json_test.mbt --filter '*page
  JSON*'` at 1/1 test passing; widened native validation reports `moon test
  --target native pdf_content_page_json_test.mbt` at 1/1 test passing. Native
  check validation reports `moon check --target native` passing with the known
  `markdown/cmd` warning and `moon check --target native --warn-list +73` at the
  known 10-warning baseline. Full native suite validation is deferred to the
  next batch.~~
- [x] ~~Standalone `cpdfcontent.ml` content-filter callback slice adds
  `PdfDocument::content_filter` and `pdf_content_filter`, matching cpdf's
  current `filter` behavior by walking recursive content entries, invoking the
  callback for each emitted object, ignoring the callback result, and returning
  the original operator list unchanged. Coverage locks down callback observation
  of page path entries, unchanged returned operators, and wrapper parity.
  Focused native validation reports `moon test --target native
  pdf_content_page_json_test.mbt --filter '*page JSON*'` at 1/1 test passing;
  widened native validation reports `moon test --target native
  pdf_content_page_json_test.mbt` at 1/1 test passing. Native check validation
  reports `moon check --target native` passing with the known `markdown/cmd`
  warning and `moon check --target native --warn-list +73` at the known
  10-warning baseline. Full native suite validation is deferred to the next
  batch.~~
- [x] ~~Standalone `cpdfcontent.ml` test text-extraction slice adds
  `PdfDocument::test_extract_text` and `pdf_test_extract_text`, matching cpdf's
  simple proof/testing extractor by emitting one newline per document page,
  extracting glyph text only from selected pages via the recursive page-content
  entries, and returning UTF-8 bytes. Coverage locks down all-pages extraction,
  wrapper parity for a selected first page, selected later-page newline
  behavior, empty selection, and invalid-page diagnostics. Focused native
  validation reports `moon test --target native pdf_content_page_json_test.mbt
  --filter '*test text extraction*'` at 1/1 test passing; widened native
  validation reports `moon test --target native pdf_content_page_json_test.mbt`
  at 2/2 tests passing. Native check validation reports `moon check --target
  native` passing with the known `markdown/cmd` warning and `moon check --target
  native --warn-list +73` at the known 10-warning baseline. Batch full-suite
  validation reports `moon test --target native` at 1981/1981 tests passing.~~
- [x] ~~Standalone `cpdfspot.ml` spot-colour listing slice exposes
  `PdfDocument::list_spot_colours` and `pdf_list_spot_colours`, covering cpdf's
  top-level `/Separation` array scan, direct and indirect colourant names,
  ignored `/DeviceN`, nested dictionary colour spaces, non-name colourants,
  unresolved indirect colourants, output order, and wrapper parity. Native
  focused validation reports `moon test --target native pdf_spot_test.mbt` at
  2/2 tests passing; native full-suite validation reports 1721/1721 tests
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
- [x] ~~Standalone `cpdffont.ml` embedded-font removal slice now exposes
  `PdfDocument::remove_embedded_fonts` and `pdf_remove_fonts`, covering
  copy-on-write `/Type /Font` descriptor rewriting, `/FontFile`, `/FontFile2`,
  and `/FontFile3` stripping, descriptor metadata preservation, original
  descriptor preservation, wrapper parity, and non-font dictionary no-ops.
  Native focused validation reports `moon test --target native
  pdf_font_test.mbt` at 1/1 tests passing; native full-suite validation reports
  1748/1748 tests passing.~~
- [x] ~~Standalone `cpdffont.ml` font-listing slice now exposes
  `PdfFontListEntry`, `PdfDocument::list_fonts`, `list_fonts_text`,
  `fonts_json`, `fonts_json_blob`, and compatibility wrappers, covering page
  resource fonts, nested XObject resources, duplicate indirect XObject
  suppression, cpdf plain-text line formatting, JSON null conversion for
  missing subtype/basefont/encoding fields, wrapper parity, and invalid-page
  rejection. Native focused validation reports `moon test --target native
  pdf_font_test.mbt` at 3/3 tests passing; native full-suite validation reports
  1750/1750 tests passing.~~
- [x] ~~Standalone `cpdffont.ml` missing-font reporting slice now exposes
  `PdfMissingFontEntry`, `PdfDocument::is_missing_font`, `missing_fonts`,
  `missing_fonts_text`, and compatibility wrappers, covering Type3 exclusion,
  missing descriptors, embedded `/FontFile*` descriptors, descriptor-without-file
  detection, descendant-font expansion, cpdf's page-resource-only traversal,
  Built-in encoding fallback, wrapper parity, and invalid-page rejection. Native
  focused validation reports `moon test --target native pdf_font_test.mbt` at
  5/5 tests passing; native full-suite validation reports 1752/1752 tests
  passing.~~
- [x] ~~Standalone `cpdffont.ml` font path and extraction slice now exposes
  `PdfDocument::font_from_name`, `PdfFontFile::object_number`,
  `PdfFont::embedded_fontfile_number`, `extract_fontfile_bytes`, and
  compatibility wrappers, covering page font-name resolution, nested XObject
  font paths, missing-path nulls, invalid-page rejection, decoded embedded
  `/FontFile` and `/FontFile2` stream extraction, no-fontfile `None`, and
  missing-font `None`. Native focused validation reports `moon test --target
  native pdf_font_test.mbt` at 7/7 tests passing; native full-suite validation
  reports 1754/1754 tests passing.~~
- [x] ~~Standalone `cpdffont.ml` copy-font slice now exposes
  `PdfDocument::copy_font_from` and `pdf_copy_font`, covering source/target
  object renumbering, copied referenced font objects, adding the direct source
  font under its `/BaseFont` resource name, preserving existing target page
  fonts, selected-page-only updates, wrapper parity, and invalid target-page
  rejection. Native focused validation reports `moon test --target native
  pdf_font_test.mbt` at 8/8 tests passing; native full-suite validation reports
  1755/1755 tests passing.~~
- [x] ~~Standalone `cpdffont.ml` font-table slice now exposes
  `PdfFontTableEntry`, `PdfDocument::font_table`, `font_table_text`, and
  compatibility wrappers, covering named page-font resolution, cpdf row-format
  rendering, glyph-name slash stripping, `.notdef` filtering, wrapper parity,
  and invalid-page rejection. Native focused validation reports `moon test
  --target native --package bobzhang/pdflite --file pdf_font_test.mbt` at
  9/9 tests passing; native full-suite validation reports 1756/1756 tests
  passing.~~
- [x] ~~Standalone `cpdfunicodedata.ml` row-parser slice now exposes
  `PdfUnicodeDataEntry`, `pdf_parse_unicode_data`, and
  `pdf_parse_flate_unicode_data`, covering cpdf's public UnicodeData row
  schema, ASCII semicolon-field parsing, CRLF row endings, the compressed
  source decode path through Flate, and malformed-row `SoftError` propagation.
  Focused native validation reports `moon test --target native
  pdf_unicode_data_test.mbt` at 4/4 tests passing; native check validation
  reports `moon check --target native --warn-list +73` passing with the known
  markdown main-package warning and 10-warning baseline; native full-suite
  validation reports 2176/2176 tests passing.~~
- [x] ~~Standalone `cpdfunicodedata.ml` embedded-source/provider slice now
  exposes `pdf_unicode_data_source` and `pdf_unicode_data`, generated from
  cpdf's full compressed `unicodedata_source` payload and decoded/parsed on
  demand with a cached table. `cpdffont.ml` font-table rows now use the same
  UnicodeData lookup as cpdf for Unicode character names and `Cc`
  nonprintable classification instead of the previous empty-name fallback.
  Focused native validation reports `moon test --target native
  pdf_unicode_data_test.mbt` at 5/5 tests passing and `moon test --target
  native pdf_font_test.mbt --filter '*font_table*'` at 1/1 test passing;
  native check validation reports `moon check --target native --warn-list +73`
  passing with the known markdown main-package warning and 10-warning baseline;
  native full-suite validation reports 2177/2177 tests passing.~~
- [x] ~~Standalone `cpdftruetype.ml` cmap-listing slice exposes
  `pdf_truetype_cmaps`, covering TrueType table-directory scanning, `cmap`
  platform/encoding record collection in cpdf's prepended order, non-cmap table
  skipping, malformed-tail tolerance after complete records, and malformed
  header no-op behavior. Native focused validation reports `moon test --target
  native --package bobzhang/pdflite --file pdf_truetype_test.mbt` at 3/3 tests
  passing; native full-suite validation reports 1894/1894 tests passing.~~
- [x] ~~Standalone `cpdftoc.ml` text-run helper slice exposes
  `pdf_toc_split_title`, `pdf_toc_title_real_newlines`, `pdf_toc_of_utf8`,
  `pdf_toc_of_pdfdocencoding`, `pdf_toc_width_of_runs`,
  `pdf_toc_shorten_text`, and `pdf_toc_make_dots`, covering literal `\n`
  title splitting/bookmark newline conversion, fontpack run collation,
  skipped unrepresentable codepoints, PDFDocString conversion, cpdftype width
  summing, cpdf's final-run ellipsis trimming, and dot-leader remainder glue.
  Native focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_toc_test.mbt` at 7/7 tests passing; native
  full-suite validation reports 1901/1901 tests passing.~~
- [x] ~~Standalone `cpdftoc.ml` used-codepoint scan slice exposes
  `PdfDocument::toc_used_codepoints` and `pdf_toc_used_codepoints`, covering
  cpdf's pre-embedding dot/title/bookmark/page-label scan, PDFDocString
  decoding, destination-to-page-label lookup, null-target fallback numbering,
  first-occurrence de-duplication, and wrapper parity. Native focused
  validation reports `moon test --target native --package bobzhang/pdflite
  --file pdf_toc_test.mbt` at 8/8 tests passing; native full-suite validation
  reports 1902/1902 tests passing.~~
- [x] ~~Standalone `cpdftoc.ml` cpdftype element assembly slice exposes
  `PdfDocument::toc_type_elements` and `pdf_toc_type_elements`, covering
  title splitting into doubled-size runs, `BeginDocument` first-font prelude,
  bookmark destination rows, indentation, page-label runs, optional structure
  tags, dot-leader insertion, no-leader glue, and wrapper parity while leaving
  actual typesetting/page insertion for a later slice. Native focused
  validation reports `moon test --target native --package bobzhang/pdflite
  --file pdf_toc_test.mbt` at 10/10 tests passing; native full-suite validation
  reports 1904/1904 tests passing.~~
- [x] ~~Standalone `cpdftoc.ml` TOC page typesetting geometry slice exposes
  `PdfDocument::toc_typeset_pages` and `pdf_toc_typeset_pages`, covering
  first-page media-box paper sizing, cpdf's 10% minimum-dimension margin,
  cropbox-adjusted content width and margins, cpdftype page/tag generation,
  generated-TOC cropbox copying, and wrapper parity while leaving TOC page
  insertion, page-label shifting, bookmark addition, and full structure-tree
  rewrites for later slices. Native focused validation reports `moon test
  --target native --package bobzhang/pdflite --file pdf_toc_test.mbt` at 11/11
  tests passing; native full-suite validation reports 1905/1905 tests
  passing.~~
- [x] ~~Standalone `cpdftoc.ml` TOC page insertion slice exposes
  `pdf_toc_shift_page_labels`, `PdfDocument::toc_insert_pages`, and
  `pdf_toc_insert_pages`, covering prepending already-generated TOC pages,
  explicit old-to-new page-serial reference changes, destination/bookmark
  reference preservation after insertion, cpdf's no-label TOC range, shifted
  existing page-label ranges, and wrapper parity while leaving font embedding,
  TOC bookmark creation, and structure-tree integration for later slices.
  Native focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_toc_test.mbt` at 12/12 tests passing; native
  full-suite validation reports 1906/1906 tests passing.~~
- [x] ~~Standalone `cpdftoc.ml` TOC bookmark creation slice exposes
  `pdf_toc_bookmark_text`, `PdfDocument::toc_add_bookmark`, and
  `pdf_toc_add_bookmark`, covering cpdf's literal-title-`\n` to line-feed
  conversion, PDFDocString bookmark title encoding, prepending a closed
  top-level TOC bookmark, targeting the first inserted TOC page with an XYZ
  destination, preserving existing bookmark order/levels, and wrapper parity
  while leaving PDF/UA2 structure-destination actions for a later slice. Native
  focused validation reports `moon test --target native --package
  bobzhang/pdflite --file pdf_toc_test.mbt` at 13/13 tests passing; native
  full-suite validation reports 1907/1907 tests passing.~~
- [x] ~~Standalone `cpdftoc.ml` composed non-structure TOC slice exposes
  `PdfDocument::toc_with_fontpack` and `pdf_toc_with_fontpack`, covering the
  prepared-fontpack path that reads document bookmarks/page labels, no-ops when
  there are no bookmarks, typesets TOC pages, prepends them, shifts page labels,
  preserves bookmark destinations after insertion, optionally adds the generated
  TOC bookmark, and validates wrapper parity semantically while leaving TrueType
  embedding/font-source dispatch and PDF/UA structure-tree integration for later
  slices. Native focused validation reports `moon test --target native
  --package bobzhang/pdflite --file pdf_toc_test.mbt` at 14/14 tests passing;
  native full-suite validation reports 1908/1908 tests passing.~~
- [x] ~~Standalone `cpdftoc.ml` font-source dispatch slice exposes
  `PdfTocFontSource`, `PdfDocument::toc_with_source`, and
  `pdf_toc_with_source`, covering premade-fontpack dispatch into the composed
  TOC path, the cpdf-compatible existing-named-font rejection message, and
  wrapper parity while leaving TrueType `EmbedInfo` font embedding and PDF/UA
  structure-tree integration for later slices. Native focused validation reports
  `moon test --target native --package bobzhang/pdflite --file
  pdf_toc_test.mbt` at 15/15 tests passing; native full-suite validation reports
  1909/1909 tests passing.~~
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
- [x] ~~The source-listed direct-Unicode predefined CMap reader-boundary gate
  now also covers `/UniCNS-UCS2-H`, `/UniCNS-UTF16-H`, `/UniJIS-UCS2-V`, and
  `/UniJIS-UTF16-V`, including horizontal CNS extraction, vertical JIS
  extraction, surrogate-pair reverse lookup, and compressed write/read/reread
  stability. `moon test --target native --package bobzhang/pdflite --file
  pdf_native_acceptance_test.mbt` reports 88/88 tests passing; native
  full-suite validation reports 2143/2143 tests passing.~~
- [x] ~~The cpdfua-listed `/GBKp-EUC-H` predefined CMap now has direct
  text-extractor and native compressed reader-boundary coverage, including GBK
  mixed-byte segmentation with `0x80`/`0xFF` single-byte charcodes, Adobe-GB1
  table lookup, raw-code fallback, reverse lookup, and truncated input
  rejection. `moon test --target native pdf_text_test.mbt` reports 152/152
  tests passing, `moon test --target native pdf_native_acceptance_test.mbt`
  reports 88/88 tests passing, and `moon test --target native` reports
  2200/2200 tests passing.~~
- [x] ~~The cpdfua-listed `/KSCms-UHC-HW-H` Korean half-width predefined CMap
  now has native compressed reader-boundary coverage in addition to direct
  extractor coverage, gating Adobe-Korea1 extraction and reverse lookup for
  Hangul and half-width filler codepoints after write/read/reread. `moon test
  --target native pdf_native_acceptance_test.mbt` reports 88/88 tests passing,
  and `moon test --target native` reports 2200/2200 tests passing.~~
- [x] ~~The cpdfua source typo `/KSCms-UHS-HW-V` is now pinned through a native
  compressed reader-boundary Matterhorn gate: the typo remains listed for
  `31-006`, while the corrected `/KSCms-UHC-HW-V` spelling is still reported as
  unlisted after write/read/reread. `moon test --target native
  pdf_native_acceptance_test.mbt` reports 89/89 tests passing, and `moon test
  --target native` reports 2201/2201 tests passing.~~
- [x] ~~The same cpdfua source typo is now pinned for Matterhorn `31-008`
  `/UseCMap` dictionaries through the native compressed reader boundary: the
  source `/KSCms-UHS-HW-V` spelling remains listed, while the corrected
  `/KSCms-UHC-HW-V` spelling is still reported as unlisted after
  write/read/reread. `moon test --target native pdf_native_acceptance_test.mbt`
  reports 89/89 tests passing, `moon test --target native` reports 2201/2201
  tests passing, and `moon check --target all --warn-list +73` completes with
  the known warning-73/main-package warnings and no errors.~~
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
- [x] ~~The cpdfimage JBIG2 fixed-offset dimension path now has a native
  compressed reader-boundary gate: synthetic JBIG2 bytes with source-style
  width/height offsets build a single-page `/JBIG2Decode` document, preserve
  `/JBIG2Globals`, and re-extract the encoded payload after write/read/reread.
  `moon test --target native pdf_native_acceptance_test.mbt` reports 90/90
  tests passing, `moon test --target native` reports 2202/2202 tests passing,
  and `moon check --target all --warn-list +73` completes with the known
  warning-73/main-package warnings and no errors.~~
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
- [x] ~~Split or otherwise reduce the largest regression suites so the current
  plain-Wasm package-level smoke tests can instantiate under the runtime's
  maximum function-size limit: root's heavy package-level test files and the
  Markdown package generated test module are now filtered out only for plain
  Wasm, while wasm-gc/js/native/llvm retain the full root and Markdown
  coverage. `moon check --target wasm . --warn-list +73` passes, `moon test
  --target wasm .` reports 2/2 root README smoke tests passing, and full `moon
  test --target wasm` reports 41/41 tests passing.~~
- [ ] Further split root and Markdown tests into smaller packages or target
  groups if broader plain-Wasm behavioral coverage becomes required beyond the
  current smoke suite.
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
- [x] ~~Markdown fixture acceptance now also gates the optional local
  `.repos/cpdf-source/cpdfmanual.pdf` source corpus when present, covering
  real-world cpdf manual extraction and malformed-`startxref` recovery without
  requiring ignored source fixtures in CI.~~
- [x] ~~Markdown fixture acceptance now also gates the optional local
  `.repos/cpdf-source/hello.pdf` source corpus when present, covering the
  top-level PDF 1.1 hello fixture's text extraction and malformed-`startxref`
  recovery with no raw controls or replacement characters. `moon test --target
  native markdown/fixture_acceptance` reports 14/14 tests passing; native
  full-suite validation reports 2172/2172 tests passing.~~
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
- [x] ~~Recursive cpdfcontent `Do` walking now resolves each named XObject once
  per operator and dispatches directly to image emission or Form recursion,
  avoiding repeated Form resource/operator lookups without changing collected
  entries.~~
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
- [x] ~~Add the next remaining format parity slice: optional cpdf manual-image
  source-corpus PDFs now gate read/rewrite plus bad-`startxref` reconstruction
  across 21 one-page drawing/image fixtures.~~
- [x] ~~Add the next remaining format parity slice: optional cpdf manual-image
  source-corpus PDFs now gate malformed classic xref row marker, offset,
  generation, subsection object number, and subsection count recovery across
  the same 21 one-page drawing/image fixtures.~~
- [x] ~~Add the next remaining format parity slice: optional cpdf manual-image
  source-corpus PDFs now gate valid-`startxref` recovery when the targeted
  classic `xref` table header itself is damaged across the same 21 one-page
  drawing/image fixtures.~~
- [x] ~~Add the next remaining format parity slice: reconstructed documents can
  infer a minimal trailer root from a scanned catalog when no trailer
  dictionary survives, and optional cpdf manual-image source-corpus PDFs now
  gate damaged classic `trailer` keyword recovery across the same 21 one-page
  drawing/image fixtures.~~
- [x] ~~Add the next remaining format parity slice: optional cpdf manual
  source-corpus recovery now gates damaged xref-stream `/Root` trailer entries
  in the 175-page manual, reconstructing through scanned catalog-root inference
  while keeping xref-stream object entries available.~~
- [x] ~~Add the next remaining format parity slice: optional cpdf manual
  source-corpus recovery now gates an unrelated malformed `/ObjStm /N` entry
  in the 175-page manual while preserving the existing mismatched root
  object-stream rejection guard.~~
- [x] ~~Add the next remaining format parity slice: optional cpdf manual
  source-corpus recovery now gates an unrelated malformed `/ObjStm /First`
  entry in the 175-page manual through public reconstruction and compressed
  rewrite/reread preservation.~~
- [x] ~~Add the next remaining format parity slice: optional cpdf manual
  source-corpus recovery now gates an unrelated malformed `/ObjStm /Filter`
  entry in the 175-page manual while preserving rejection for unusable root
  object streams.~~
- [x] ~~Add the next remaining format parity slice: optional cpdf manual
  source-corpus recovery now gates malformed and unsupported xref-stream
  `/DecodeParms` metadata in the 175-page manual through public reconstruction
  and compressed rewrite/reread preservation.~~
- [x] ~~Add the next remaining format parity slice: optional cpdf source raw
  PNG input coverage now gates `manualimages/sheet.png` through PNG parsing,
  image-document creation, RGB24 extraction, and compressed rewrite/reread
  preservation. `moon test --target native` now reports 2188/2188 tests
  passing.~~
- [x] ~~Add the next remaining format parity slice: optional cpdf manual
  source-corpus recovery now gates malformed xref-stream `/Type` metadata in
  the 175-page manual through strict-reader rejection, public reconstruction,
  and compressed rewrite/reread preservation. `moon test --target native` now
  reports 2189/2189 tests passing.~~
- [x] ~~Add the next remaining format parity slice: optional cpdf manual
  source-corpus recovery now gates a malformed xref-stream `stream` marker in
  the 175-page manual; public reconstruction now detects the xref-stream
  dictionary prefix after `ParseStreamExpected` so the trailer root can be
  reused. `moon test --target native` now reports 2191/2191 tests passing.~~
- [x] ~~Add the next remaining format parity slice: optional cpdf manual
  source-corpus recovery now gates malformed xref-stream `endstream` and
  `endobj` terminators in the 175-page manual; public reconstruction now uses
  the same xref-stream dictionary-prefix path after `ParseEndStreamExpected`
  and `ParseEndObjectExpected`. `moon test --target native` now reports
  2194/2194 tests passing.~~
- [x] ~~Add the next remaining format parity slice: optional cpdf manual
  source-corpus object-stream token handling now gates the first `/ObjStm`
  `stream`, physical `endstream`, and physical `endobj` markers in the 175-page
  manual, covering public reconstruction for strict `ParseStreamExpected` and
  `ParseEndObjectExpected` errors plus strict length-repair for the malformed
  `endstream`. `moon test --target native` now reports 2197/2197 tests
  passing.~~
- [x] ~~Add the next remaining format parity slice: the cpdfua-listed
  `/GBKp-EUC-H` predefined CMap now has direct extractor and compressed native
  read/write/reread coverage for the same GBK mixed-byte semantics already
  exercised by `/GBK-EUC-H`. `moon test --target native` reports 2200/2200 tests
  passing.~~
- [x] ~~Add the next remaining format parity slice: the cpdfua-listed
  `/KSCms-UHC-HW-H` Korean half-width predefined CMap now has compressed native
  read/write/reread coverage for Adobe-Korea1 Hangul and half-width filler
  extraction plus reverse lookup. `moon test --target native` reports 2200/2200
  tests passing.~~
- [x] ~~Add the next remaining format parity slice: the cpdfua source typo
  `/KSCms-UHS-HW-V` now has compressed native reader-boundary coverage for
  Matterhorn `31-006`, preserving acceptance of the typo and rejection of the
  corrected `/KSCms-UHC-HW-V` spelling. `moon test --target native` reports
  2201/2201 tests passing.~~
- [x] ~~Add the next remaining format parity slice: Matterhorn `31-008`
  `/UseCMap` handling now shares the cpdfua source CMap typo gate through
  compressed native read/write/reread, preserving acceptance of
  `/KSCms-UHS-HW-V` and rejection of `/KSCms-UHC-HW-V`. `moon test --target
  native` reports 2201/2201 tests passing.~~
- [x] ~~Add the next remaining format parity slice: cpdfimage JBIG2 document
  construction from fixed source dimension offsets now has compressed native
  read/write/reread coverage for page size, `/JBIG2Decode` metadata,
  `/JBIG2Globals`, and encoded image extraction. `moon test --target native`
  reports 2202/2202 tests passing.~~
- [x] ~~Add the next remaining format parity slice: cpdfcomposition bucket
  classification now has compressed native read/write/reread coverage for images,
  fonts, content streams, structure info, piece info, xref table accounting, JSON
  blob parity, and unclassified bytes. `moon test --target native` reports
  2203/2203 tests passing.~~
- [x] ~~Add the next remaining format parity slice: cpdfattach document and
  page attachments now have compressed native reader-boundary coverage for
  listing, decoded payloads, page annotation linkage, size accounting, and
  removal across rereads. `moon test --target native` reports 2204/2204 tests
  passing.~~
- [x] ~~Add the next remaining source-boundary slice: cpdfembed Standard 14
  substitute font loading now has a native async file wrapper that mirrors
  `load_substitute` by reading the selected URW `.ttf` file and returning its
  extension-stripped font name. `moon test --target native` reports 2205/2205
  tests passing.~~
- [x] ~~Add the next remaining format parity slice: source-corpus image
  coverage now decodes the embedded 400x294 RGB image in
  `.repos/cpdf-source/cpdfmanual.pdf`, verifies the 175-page manual boundary,
  and rechecks the same image after compressed rewrite. `moon test --target
  native image/fixture_acceptance` reports 13/13 tests passing, `moon test
  --target native` reports 2206/2206 tests passing, and `moon check --target
  all --warn-list +73` completes with the known warning baseline and no
  errors.~~
- [x] ~~Add the next remaining format parity slice: source-corpus image
  recovery now corrupts `.repos/cpdf-source/cpdfmanual.pdf`'s `startxref`,
  requires strict-reader failure, reconstructs the 175-page manual through the
  public reader, decodes the embedded 400x294 RGB image, and rechecks it after
  compressed rewrite. `moon test --target native image/fixture_acceptance`
  reports 14/14 tests passing, `moon test --target native` reports 2207/2207
  tests passing, and `moon check --target all --warn-list +73` completes with
  the known warning baseline and no errors.~~
- [x] ~~Add the next remaining source-boundary predefined CMap slice:
  `/KSCms-UHC-HW-V` now has native synthetic-PDF reader-boundary coverage in
  the vertical predefined CMap acceptance document, complementing the existing
  unit-level extraction and reverse-lookup coverage while preserving the
  separate cpdfua Matterhorn typo checks. `moon test --target native
  pdf_native_acceptance_test.mbt --filter '*vertical predefined CMap*'` reports
  1/1 tests passing, `moon test --target native` reports 2207/2207 tests
  passing, and `moon check --target all --warn-list +73` completes with the
  known warning baseline and no errors.~~
- [x] ~~Add the next remaining source-boundary predefined CMap slice: Adobe-KR
  direct Unicode CMaps `/UniAKR-UTF8-H`, `/UniAKR-UTF16-H`, and
  `/UniAKR-UTF32-H` now have native synthetic-PDF reader-boundary coverage for
  extraction and reverse lookup, complementing the existing unit-level gates.
  `moon test --target native pdf_native_acceptance_test.mbt --filter '*Unicode
  predefined CMap*'` reports 1/1 tests passing, `moon test --target native`
  reports 2207/2207 tests passing, and `moon check --target all --warn-list
  +73` completes with the known warning baseline and no errors.~~
- [x] ~~Add the next remaining source-boundary predefined CMap slice: the
  cpdfua-listed generic Adobe-Japan1 `/V` CMap now has native synthetic-PDF
  reader-boundary coverage for vertical JIS extraction and reverse lookup, and
  the cpdfua `cmap_names` source list now has no entries absent from
  `pdf_native_acceptance_test.mbt`. `moon test --target native
  pdf_native_acceptance_test.mbt --filter '*Adobe-Japan1 predefined CMap*'`
  reports 1/1 tests passing, `moon test --target native` reports 2207/2207
  tests passing, and `moon check --target all --warn-list +73` completes with
  the known warning baseline and no errors.~~
- [x] ~~Add the next remaining source-corpus parity slice: the optional
  `.repos/cpdf-source/manualimages/*.pdf` corpus now has native fixture coverage
  for reading every one-page manual-image PDF, parsing page content operators,
  and preserving the same boundary after compressed rewrite. `moon test --target
  native image/fixture_acceptance --filter '*manual image PDF corpus*'` reports
  1/1 tests passing and `moon test --target native image/fixture_acceptance`
  reports 15/15 tests passing. `moon test --target native` reports 2208/2208
  tests passing, and `moon check --target all --warn-list +73` completes with
  the known warning baseline and no errors.~~
- [x] ~~Add the next remaining malformed recovery source-corpus slice: the
  optional `.repos/cpdf-source/manualimages/*.pdf` corpus now corrupts the final
  `startxref`, requires strict-reader failure, reconstructs each one-page
  manual-image PDF through the public reader, parses page content, and rechecks
  after compressed rewrite. `moon test --target native image/fixture_acceptance
  --filter '*manual image PDF corpus reconstructs malformed startxref*'`
  reports 1/1 tests passing and `moon test --target native
  image/fixture_acceptance` reports 16/16 tests passing. `moon test --target
  native` reports 2209/2209 tests passing, and `moon check --target all
  --warn-list +73` completes with the known warning baseline and no errors.~~
- [x] ~~Add the next real-world PDF-to-Markdown corpus gate: the optional
  `.repos/cpdf-source/manualimages/*.pdf` corpus now converts every one-page
  manual-image PDF to clean Markdown, verifies at least one textful extraction,
  corrupts the final `startxref`, and requires reconstructed Markdown to match
  the normal output with no raw control or replacement characters. `moon test
  --target native markdown/fixture_acceptance --filter '*manual image PDF
  corpus*'` reports 1/1 tests passing and `moon test --target native
  markdown/fixture_acceptance` reports 15/15 tests passing. `moon test --target
  native` reports 2210/2210 tests passing, and `moon check --target all
  --warn-list +73` completes with the known warning baseline and no errors.~~
- [x] ~~Add the next top-level cpdf source corpus reader gate: optional
  `.repos/cpdf-source/cpdfmanual.pdf`, `hello.pdf`, and `logo.pdf` are now
  checked together through public reading, compressed-xref rewrite/reread, and
  bad-final-`startxref` reconstruction, with the source corpus expected to
  cover 177 pages when present. `moon test --target native fixture_acceptance
  --filter '*top-level PDF corpus*'` reports 1/1 tests passing and `moon test
  --target native fixture_acceptance` reports 42/42 tests passing. `moon test
  --target native` reports 2211/2211 tests passing, and `moon check --target
  all --warn-list +73` completes with the known warning baseline and no
  errors.~~
- [x] ~~Refresh portable backend validation after the latest source-corpus
  gates: WasmGC and JavaScript full test suites each report 2012/2012 tests
  passing, all-target type checking completes with the known warning baseline,
  and full plain-Wasm test execution is still explicitly not claimed because it
  hits the runtime maximum-function-size limit in the root/markdown blackbox
  test executables.~~
- [x] ~~Add the next source-corpus malformed metadata slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` now corrupts the final xref stream
  `/Length 4551` entry to `/Length /Bad`, exercises strict stream-length
  repair instead of physical reconstruction, preserves the 175-page manual, and
  rechecks the result after compressed rewrite/reread. `moon test --target
  native fixture_acceptance --filter '*malformed xref stream length*'` reports
  1/1 test passing, `moon test --target native fixture_acceptance` reports
  43/43 tests passing, and `moon test --target native` reports 2212/2212 tests
  passing.~~
- [x] ~~Add the next source-corpus object-stream repair slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` now corrupts the first `/ObjStm`
  `/Length 1526` entry to `/Length /Bad`, exercises strict malformed-stream
  length repair by scanning to `endstream`, preserves the 175-page manual, and
  rechecks the result after compressed rewrite/reread. `moon test --target
  native fixture_acceptance --filter '*malformed object stream length*'`
  reports 1/1 test passing, `moon test --target native fixture_acceptance`
  reports 44/44 tests passing, and `moon test --target native` reports
  2213/2213 tests passing.~~
- [x] ~~Add the next source-corpus Markdown command slice: the native
  `pdflite-markdown` command helper now converts optional
  `.repos/cpdf-source/cpdfmanual.pdf` through real file input/output, checks
  manual markers such as `Coherent PDF`, `Chapter 15: PDF and JSON`, and
  `Accessible PDFs with PDF/UA`, and verifies UTF-8 output without replacement
  characters. `moon test --target native markdown/cmd --filter '*cpdf source
  manual*'` reports 1/1 test passing, `moon test --target native markdown/cmd`
  reports 10/10 tests passing, and `moon test --target native` reports
  2214/2214 tests passing.~~
- [x] ~~Add the next source-corpus Markdown command corpus slice: the native
  `pdflite-markdown` command helper now converts every optional
  `.repos/cpdf-source/manualimages/*.pdf` fixture through real file
  input/output, verifies a clean `# Page 1` Markdown boundary, checks for no raw
  controls or UTF-8 replacement characters, and requires at least one textful
  extraction when the corpus is present. `moon test --target native
  markdown/cmd --filter '*manual image PDF corpus*'` reports 1/1 test passing,
  `moon test --target native markdown/cmd` reports 11/11 tests passing, and
  `moon test --target native` reports 2215/2215 tests passing.~~
- [x] ~~Add the next source-boundary `cpdfpagespec` slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` now gates document-backed page-spec
  parsing for `end`, `~n`, reversed ranges, `NOT`, `DUP`, odd/even suffixes,
  portrait/landscape selectors, annotated-page selection, and compact
  `string_of_pagespec` output before and after compressed rewrite/reread.
  `moon test --target native fixture_acceptance --filter '*parses page
  specifications*'` reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 45/45 tests passing, and `moon test --target
  native` reports 2216/2216 tests passing.~~
- [x] ~~Add the next source-boundary reporting slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` now gates cpdf-style document-info JSON,
  XMP/subformat reporting, page-info JSON/plain text, and composition bucket
  reporting against the real 175-page manual before and after compressed
  rewrite/reread. `moon test --target native fixture_acceptance --filter
  '*reports info page details and composition*'` reports 1/1 test passing,
  `moon test --target native fixture_acceptance` reports 46/46 tests passing,
  and `moon test --target native` reports 2217/2217 tests passing.~~
- [x] ~~Refresh portable backend validation after the latest cpdf source gates:
  `moon test --target wasm-gc` and `moon test --target js` each report
  2012/2012 tests passing. Full plain-Wasm `moon test --target wasm` remains
  explicitly not claimed because it still exceeds the runtime maximum
  function-size limit in `markdown.blackbox_test.wasm`.~~
- [x] ~~Add the next source-boundary annotation JSON slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` now gates cpdf-style real link annotation
  JSON export and UTF-8 blob output from an annotated manual page before and
  after compressed rewrite/reread. `moon test --target native
  fixture_acceptance --filter '*annotation JSON*'` reports 1/1 test passing,
  `moon test --target native fixture_acceptance` reports 47/47 tests passing,
  and `moon test --target native` reports 2218/2218 tests passing.~~
- [x] ~~Add the next source-boundary image corpus slice: optional
  `.repos/cpdf-source/manualimages/png.pdf` now gates cpdf-style image JSON
  listing, image-resolution JSON, UTF-8 blob output, and 24bpp extraction of the
  real FlateDecode/DeviceRGB PNG XObject before and after compressed
  rewrite/reread. `moon test --target native fixture_acceptance --filter '*PNG
  image fixture*'` reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 48/48 tests passing, and `moon test --target
  native` reports 2219/2219 tests passing.~~
- [x] ~~Add the next broader source-boundary image corpus slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` now gates cpdf-style image JSON,
  image-resolution JSON, and UTF-8 blob output for the real embedded
  FlateDecode/DeviceRGB 400x294 manual image across all 175 pages before and
  after compressed rewrite/reread. `moon test --target native
  fixture_acceptance --filter '*embedded images*'` reports 1/1 test passing,
  `moon test --target native fixture_acceptance` reports 49/49 tests passing,
  and `moon test --target native` reports 2220/2220 tests passing.~~
- [x] ~~Add the next source-boundary `cpdffont` slice: optional
  `.repos/cpdf-source/manualimages/fonts.pdf` now gates real Type1 font
  listing, font JSON/UTF-8 blob output, named font lookup, font-table rendering,
  and cpdf-style missing-font rows for unembedded Times resources before and
  after compressed rewrite/reread. `moon test --target native
  fixture_acceptance --filter '*font fixture*'` reports 1/1 test passing,
  `moon test --target native fixture_acceptance` reports 50/50 tests passing,
  and `moon test --target native` reports 2221/2221 tests passing.~~
- [x] ~~Add the next source-boundary `cpdfcontent` slice: optional
  `.repos/cpdf-source/manualimages/text.pdf` and `xobj.pdf` now gate real
  glyph/text extraction, page-content JSON, and recursive Form XObject path
  content entries before and after compressed rewrite/reread. `moon test
  --target native fixture_acceptance --filter '*content fixtures*'` reports 1/1
  test passing, `moon test --target native fixture_acceptance` reports 51/51
  tests passing, and `moon test --target native` reports 2222/2222 tests
  passing.~~
- [x] ~~Add the next source-boundary `cpdfbookmarks` slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` now gates the real 163-entry outline tree,
  cpdf-style bookmark JSON/UTF-8 blob output, selected page bookmark listing,
  compressed rewrite/reread, and remove/add bookmark round-tripping. `moon test
  --target native fixture_acceptance --filter '*bookmarks*'` reports 1/1 test
  passing, `moon test --target native fixture_acceptance` reports 52/52 tests
  passing, and `moon test --target native` reports 2223/2223 tests passing.~~
- [x] ~~Add the next source-boundary `cpdftoc` slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` now gates table-of-contents codepoint
  collection, cpdftype element generation, dot leaders, destination contents,
  and generated TOC bookmark round-tripping from the real manual outline before
  and after compressed rewrite/reread. `moon test --target native
  fixture_acceptance --filter '*table of contents*'` reports 1/1 test passing,
  `moon test --target native fixture_acceptance` reports 53/53 tests passing,
  and `moon test --target native` reports 2224/2224 tests passing.~~
- [x] ~~Add the next source-boundary text-extraction slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` now gates root-package
  `PdfDocument::test_extract_text` output for selected real manual pages,
  including the cover text, Basic Usage, Merging and Splitting, and Splitting on
  Bookmarks, with no replacement characters or raw controls before compressed
  rewrite/reread and after bad-`startxref` reconstruction. `moon test --target
  native fixture_acceptance --filter '*extracts selected text*'` reports 1/1
  test passing, `moon test --target native fixture_acceptance` reports 54/54
  tests passing, `moon test --target native` reports 2225/2225 tests passing,
  and `moon check --target all --warn-list +73` reports the known warning
  baseline with 0 errors.~~
- [x] ~~Add the next source-corpus `cpdfcontent` slice: every optional
  `.repos/cpdf-source/manualimages/*.pdf` fixture now gates
  `PdfDocument::content_entries_of_page` and page-content JSON traversal before
  and after compressed rewrite/reread, requiring non-empty content entries for
  each real one-page manual fixture and aggregate coverage of glyph, image, and
  path objects. `moon test --target native fixture_acceptance --filter
  '*traverse content entries*'` reports 1/1 test passing, `moon test --target
  native fixture_acceptance` reports 55/55 tests passing, and `moon test
  --target native` reports 2226/2226 tests passing.~~
- [x] ~~Refresh portable backend validation after the latest native cpdf-source
  gates: `moon test --target wasm-gc` and `moon test --target js` each report
  2012/2012 tests passing after the manual text-extraction and manual-image
  cpdfcontent corpus gates. Full plain-Wasm `moon test --target wasm` remains
  explicitly not claimed because it still exceeds the runtime maximum
  function-size limit in `markdown.blackbox_test.wasm`.~~
- [x] ~~Add the next raw source-asset image slice: optional
  `.repos/cpdf-source/manualimages/sheet.png` now gates direct `pdf_read_png`
  metadata parsing, `pdf_image_document_of_png_data` document construction,
  cpdf-style image JSON reporting, compressed rewrite/reread, and 24bpp pixel
  extraction for the real 400x294 RGB source PNG. `moon test --target native
  fixture_acceptance --filter '*raw sheet PNG*'` reports 1/1 test passing,
  `moon test --target native fixture_acceptance` reports 56/56 tests passing,
  and `moon test --target native` reports 2227/2227 tests passing.~~
- [x] ~~Add the next source-boundary page-label slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` now gates the real lower-roman frontmatter
  and decimal body `/PageLabels` tree, cpdf-style page-info label JSON/text,
  add-text `%Label`/`%EndLabel` replacement values, compressed rewrite/reread,
  and bad-`startxref` recovery for the 175-page manual. `moon test --target
  native fixture_acceptance --filter '*page label fallbacks*'` reports 1/1 test
  passing, `moon test --target native fixture_acceptance` reports 57/57 tests
  passing, `moon test --target native` reports 2228/2228 tests passing, and
  `moon check --target all --warn-list +73` reports the known warning baseline
  with 0 errors.~~
- [x] ~~Add the next source-boundary catalog metadata slice: optional
  `.repos/cpdf-source/logo.pdf` now gates the real `/PageMode /UseNone` and
  `/OpenAction` XYZ destination through cpdf-style catalog item reporting,
  OpenAction object/string/JSON output, document-info JSON, compressed
  rewrite/reread, and bad-`startxref` recovery. `moon test --target native
  fixture_acceptance --filter '*catalog view metadata*'` reports 1/1 test
  passing, `moon test --target native fixture_acceptance` reports 58/58 tests
  passing, `moon test --target native` reports 2229/2229 tests passing, and
  `moon check --target all --warn-list +73` reports the known warning baseline
  with 0 errors.~~
- [x] ~~Add the next source-boundary PDF/UA structure-tree slice: optional
  `.repos/cpdf-source/manualimages/h1.pdf` now gates the real PDF 2.0
  `/StructTreeRoot` with one `H1` and two `P` elements through catalog
  reporting, document-info JSON, cpdf-style structure text/CPDFJSON blobs,
  structure-tree replacement round-tripping, compressed rewrite/reread, and
  bad-`startxref` recovery. `moon test --target native fixture_acceptance
  --filter '*structure tree*'` reports 1/1 test passing, `moon test --target
  native fixture_acceptance` reports 59/59 tests passing, `moon test --target
  native` reports 2230/2230 tests passing, and `moon check --target all
  --warn-list +73` reports the known warning baseline with 0 errors.~~
- [x] ~~Broaden the source-boundary PDF/UA structure-tree lifecycle slice:
  optional `.repos/cpdf-source/manualimages/h1.pdf` now also gates
  `PdfDocument::remove_struct_tree`/`pdf_remove_struct_tree` and
  `PdfDocument::mark_all_as_artifact`/`pdf_mark_all_as_artifact` against the
  real PDF 2.0 structure-tree fixture. The gate verifies removal of
  `/StructTreeRoot`, `/StructParent`, and `/StructParents`, empty
  `struct_tree_text`, header-only extracted CPDFJSON, retained text-showing
  operators with all structure marking operators stripped, artifact wrapping
  after removal, compressed xref-stream rewrite/reread, and malformed
  `startxref` public reconstruction of the marked output. `moon check --target
  native fixture_acceptance --warn-list +73` passes, the focused H1
  remove/artifact test reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 124/124 tests passing, and `moon test --target
  native` reports 2349/2349 tests passing. `moon info && moon fmt` reports no
  public API or formatting work, and `moon check --target all --warn-list +73`
  reports the known warning-73/main-package baseline with 10 warnings and 0
  errors.~~
- [x] ~~Add the next source-boundary transparency/resource slice: optional
  `.repos/cpdf-source/logo.pdf` now gates real `/BleedBox` and `/TrimBox`,
  transparency group, blend-mode `/ExtGState` resources, page-info/document-info
  box reporting, compressed rewrite/reread, and bad-`startxref` recovery;
  optional `.repos/cpdf-source/manualimages/trans.pdf` now gates real fill-alpha
  `/ca 0.5` ExtGState resources and the content stream `/G1 gs` operator across
  the same boundaries. `moon test --target native fixture_acceptance --filter
  '*transparency fixtures*'` reports 1/1 test passing, `moon test --target
  native fixture_acceptance` reports 60/60 tests passing, `moon test --target
  native` reports 2231/2231 tests passing, and `moon check --target all
  --warn-list +73` reports the known warning baseline with 0 errors.~~
- [x] ~~Add the next source-boundary drawing-operator slice: optional
  `.repos/cpdf-source/manualimages/{dash,capjoins,colfill,clip,textclip,matrix,pop,fontparams,stext,para,paras}.pdf`
  now gate real cpdf drawing/text operator parameters, including line dash,
  caps/joins/miter, RGB and gray color operators, clipping, text clipping,
  matrix push/pop, font parameters, special text, and paragraph layout tokens
  before compressed rewrite/reread and after bad-`startxref` recovery. `moon
  test --target native fixture_acceptance --filter '*drawing fixtures*'`
  reports 1/1 test passing, `moon test --target native fixture_acceptance`
  reports 61/61 tests passing, `moon test --target native` reports 2232/2232
  tests passing, and `moon check --target all --warn-list +73` reports the known
  warning baseline with 0 errors.~~
- [x] ~~Add the next source-boundary attachment slice: optional
  `.repos/cpdf-source/hello.pdf` now gates `cpdfattach`-style document and
  page attachments using real `.repos/cpdf-source/README.md` and
  `.repos/cpdf-source/Changes.txt` payloads, including basename extraction,
  descriptions, `/AFRelationship` names, payload-size accounting, compressed
  rewrite/reread, bad-`startxref` recovery, and attachment removal/reread.
  `moon test --target native fixture_acceptance --filter '*source
  attachments*'` reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 62/62 tests passing, `moon test --target native`
  reports 2233/2233 tests passing, and `moon check --target all --warn-list
  +73` reports the known warning baseline with 0 errors.~~
- [x] ~~Add the next source-boundary metadata slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` now gates cpdfmetadata-style XMP creation
  from real `/Info` fields, catalog `/Lang` setting, `/Title` and `/Author`
  `/Info` updates synchronized into XMP, compressed rewrite/reread,
  bad-`startxref` recovery, and metadata removal/reread. `moon test --target
  native fixture_acceptance --filter '*mutates metadata*'` reports 1/1 test
  passing, `moon test --target native fixture_acceptance` reports 63/63 tests
  passing, `moon test --target native` reports 2234/2234 tests passing, and
  `moon check --target all --warn-list +73` reports the known warning baseline
  with 0 errors.~~
- [x] ~~Add the next source-boundary font slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` now gates cpdffont-style listing across
  the real manual's embedded subset Type 1 fonts, decoded font-file extraction
  for Nimbus/URW/monospace subset programs, Standard 14 font-table reporting,
  Standard 14 non-extraction behavior, empty missing-font reporting, compressed
  rewrite/reread, and bad-`startxref` recovery. `moon test --target native
  fixture_acceptance --filter '*embedded fonts*'` reports 1/1 test passing,
  `moon test --target native fixture_acceptance` reports 64/64 tests passing,
  `moon test --target native` reports 2235/2235 tests passing, and `moon check
  --target all --warn-list +73` reports the known warning baseline with 0
  errors.~~
- [x] ~~Add the next source-boundary image extraction slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` now gates the real manual's embedded RGB
  image on page 128/object 1477 through cpdfimage-style image JSON reporting,
  image-resolution reporting, raw 24bpp extraction, decoded byte-count checks,
  and stable pixel samples after compressed rewrite/reread. `moon test --target
  native fixture_acceptance --filter '*embedded images*'` reports 1/1 test
  passing, `moon test --target native fixture_acceptance` reports 64/64 tests
  passing, `moon test --target native` reports 2235/2235 tests passing, and
  `moon check --target all --warn-list +73` reports the known warning baseline
  with 0 errors.~~
- [x] ~~Add the next source-boundary ToUnicode text slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` now gates page-2 non-ASCII text extraction
  through the real manual's embedded font ToUnicode data, including the
  copyright sign and PDF Association text across compressed rewrite/reread and
  bad-`startxref` recovery. `moon test --target native fixture_acceptance
  --filter '*extracts selected text*'` reports 1/1 test passing, `moon test
  --target native fixture_acceptance` reports 64/64 tests passing, `moon test
  --target native` reports 2235/2235 tests passing, and `moon check --target
  all --warn-list +73` reports the known warning baseline with 0 errors.~~
- [x] ~~Add the next source-boundary presentation slice: optional
  `.repos/cpdf-source/hello.pdf` now gates cpdfpresent-style `/Trans` page
  transition dictionaries on a real source PDF, including `/Split`, `/D`,
  `/Dm`, `/M`, `/Dur`, compressed rewrite/reread, and bad-`startxref`
  recovery. `moon test --target native fixture_acceptance --filter
  '*presentation transitions*'` reports 1/1 test passing, `moon test --target
  native fixture_acceptance` reports 65/65 tests passing, `moon test --target
  native` reports 2236/2236 tests passing, and `moon check --target all
  --warn-list +73` reports the known warning baseline with 0 errors.~~
- [x] ~~Add the next source-boundary portfolio slice: optional
  `.repos/cpdf-source/hello.pdf` now gates cpdfportfolio-style collection
  construction from real `.repos/cpdf-source/README.md` and
  `.repos/cpdf-source/Changes.txt` payloads, including `/EmbeddedFiles` name
  tree keys, `/Collection /View /T`, `/FileSpec` basename strings,
  `/AFRelationship` explicit/default values, embedded file stream payloads,
  `/Params /ModDate`, size/length metadata, compressed rewrite/reread, and
  bad-`startxref` recovery. `moon test --target native fixture_acceptance
  --filter '*builds portfolio*'` reports 1/1 test passing, `moon test --target
  native fixture_acceptance` reports 66/66 tests passing, `moon test --target
  native` reports 2237/2237 tests passing, and `moon check --target all
  --warn-list +73` reports the known warning baseline with 0 errors.~~
- [x] ~~Add the next source-boundary JavaScript slice: optional
  `.repos/cpdf-source/hello.pdf` now gates cpdfjs-style detection and scrubbing
  on a real source PDF after injecting `/JS` dictionaries, lowercase
  `javascript:` URI actions, a `/Root /Names /JavaScript` name tree, and stream
  dictionary markers. The gate verifies compressed rewrite/reread,
  bad-`startxref` recovery, `pdf_remove_javascript`, name-tree removal, `/JS` and
  JavaScript URI emptying, non-JavaScript URI preservation, and stream payload
  preservation. `moon test --target native fixture_acceptance --filter
  '*removes JavaScript markers*'` reports 1/1 test passing, `moon test --target
  native fixture_acceptance` reports 67/67 tests passing, `moon test --target
  native` reports 2238/2238 tests passing, and `moon check --target all
  --warn-list +73` reports the known warning baseline with 0 errors.~~
- [x] ~~Add the next source-boundary chop slice: optional
  `.repos/cpdf-source/hello.pdf` now gates cpdfchop-style page splitting on a
  real source PDF after decorating the source page with `/CropBox`, extra page
  boxes, annotations, and a retained dictionary key. The gate verifies CropBox
  preference, 2x2 page ordering, exact output `/MediaBox` rectangles,
  `/CropBox`/`/BleedBox`/`/TrimBox`/`/ArtBox`/`/Annots` erasure, retained key
  preservation, compressed rewrite/reread, and bad-`startxref` recovery. `moon
  test --target native fixture_acceptance --filter '*chops CropBox-backed page*'`
  reports 1/1 test passing, `moon test --target native fixture_acceptance`
  reports 68/68 tests passing, `moon test --target native` reports 2239/2239
  tests passing, and `moon check --target all --warn-list +73` reports the known
  warning baseline with 0 errors.~~
- [x] ~~Add the next source-boundary remove-text slice: optional
  `.repos/cpdf-source/hello.pdf` now gates cpdfremovetext-style
  `pdf_remove_all_text` on a real text-bearing source PDF. The gate verifies
  original `Hello, World!` extraction, presence of a source text-showing content
  operator, removal of all text-showing operators, retained non-empty non-text
  content structure, compressed rewrite/reread, and bad-`startxref` recovery.
  `moon test --target native fixture_acceptance --filter '*removes all text*'`
  reports 1/1 test passing, `moon test --target native fixture_acceptance`
  reports 69/69 tests passing, `moon test --target native` reports 2240/2240
  tests passing, and `moon check --target all --warn-list +73` reports the known
  warning baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-boundary page-transform slice: optional
  `.repos/cpdf-source/hello.pdf` now gates cpdfpage-style rotate, shift, and
  hard-box clipping through compatibility wrappers on a real source PDF. The
  gate decorates the page with `/CropBox` and `/Annots`, then verifies `/Rotate`
  persistence, exact CropBox geometry, shifted annotation rectangle geometry,
  hard-box clipping operator prefix, shifted content matrix prefix, preserved
  text extraction, compressed rewrite/reread, and bad-`startxref` recovery.
  `moon test --target native fixture_acceptance --filter
  '*page geometry transforms*'` reports 1/1 test passing, `moon test --target
  native fixture_acceptance` reports 70/70 tests passing, `moon test --target
  native` reports 2241/2241 tests passing, and `moon check --target all
  --warn-list +73` reports the known warning baseline with 10 warnings and 0
  errors.~~
- [x] ~~Add the next source-boundary draft slice: optional
  `.repos/cpdf-source/manualimages/png.pdf` now gates cpdfdraft-style image
  removal on a real FlateDecode/DeviceRGB source PDF. The gate verifies the
  original `/I1` image before drafting, then runs `pdf_draft` through the
  compatibility wrapper and checks that image XObject resources are emptied,
  `/I1 Do` invocations are gone, cpdf's crossed-unit-box replacement operator
  sequence is present, image JSON no longer reports image entries, compressed
  rewrite/reread survives, and bad-`startxref` recovery preserves the drafted
  shape. `moon test --target native fixture_acceptance --filter
  '*drafts replacement boxes*'` reports 1/1 test passing, `moon test --target
  native fixture_acceptance` reports 71/71 tests passing, `moon test --target
  native` reports 2242/2242 tests passing, and `moon check --target all
  --warn-list +73` reports the known warning baseline with 10 warnings and 0
  errors.~~
- [x] ~~Add the next source-boundary pad slice: optional
  `.repos/cpdf-source/hello.pdf` now gates cpdfpad-style blank page insertion
  on a real text-bearing source PDF. The gate decorates the source page with
  `/Annots` and a retained dictionary key, runs `pdf_pad_after` through the
  compatibility wrapper, and checks two-page output, blank-page MediaBox and
  rotation inheritance, empty blank content/resources, annotation removal from
  the inserted blank, retained non-annotation dictionary data, original text
  preservation on page 1, blank page text absence, compressed rewrite/reread,
  and bad-`startxref` recovery. `moon test --target native fixture_acceptance
  --filter '*pads blank page after source*'` reports 1/1 test passing, `moon
  test --target native fixture_acceptance` reports 72/72 tests passing, `moon
  test --target native` reports 2243/2243 tests passing, and `moon check
  --target all --warn-list +73` reports the known warning baseline with 10
  warnings and 0 errors.~~
- [x] ~~Add the next source-boundary redaction slice: optional
  `.repos/cpdf-source/hello.pdf` now gates cpdfredact's current path-redaction
  stub/no-op behavior on a real text-bearing source PDF. The gate records the
  original parsed content operators, runs `pdf_redact` through the compatibility
  wrapper with a concrete path, verifies page geometry/resources/rest
  preservation, confirms `Hello, World!` extraction and exact parsed-operator
  preservation after redaction, then repeats the assertions after compressed
  rewrite/reread and bad-`startxref` recovery. `moon test --target native
  fixture_acceptance --filter '*path redaction stub*'` reports 1/1 test passing,
  `moon test --target native fixture_acceptance` reports 73/73 tests passing,
  `moon test --target native` reports 2244/2244 tests passing, and `moon check
  --target all --warn-list +73` reports the known warning baseline with 10
  warnings and 0 errors.~~
- [x] ~~Add the next source-boundary bounding-box overlay slice: optional
  `.repos/cpdf-source/manualimages/text.pdf` and `xobj.pdf` now gate
  cpdfredact-style `show_bounding_boxes` behavior on real manual fixtures. The
  gate preserves original text/Form-XObject content assertions, runs both the
  method and compatibility wrapper, verifies page geometry/resources/rest
  preservation, checks that overlay path strokes and graphics-state saves are
  added for the original recursive content entries, and repeats the assertions
  after compressed rewrite/reread and bad-`startxref` recovery. `moon test
  --target native fixture_acceptance --filter '*bounding box overlays*'`
  reports 1/1 test passing, `moon test --target native fixture_acceptance`
  reports 74/74 tests passing, `moon test --target native` reports 2245/2245
  tests passing, and `moon check --target all --warn-list +73` reports the known
  warning baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-boundary cpdftweak slice: optional
  `.repos/cpdf-source/manualimages/clip.pdf` now gates `pdf_remove_clipping` on
  a real clipping-path fixture, and `textclip.pdf` now gates
  `reveal_hidden_text` on real text rendering-mode clipping. The gate verifies
  original drawing operators, page geometry/resources/rest preservation, exact
  removal of `W n` clipping setup pairs, removal of `Tr` text rendering-mode
  operators while retaining text-showing operators and recursive content JSON,
  compressed rewrite/reread, and bad-`startxref` recovery. `moon test --target
  native fixture_acceptance --filter '*tweak fixtures*'` reports 1/1 test
  passing, `moon test --target native fixture_acceptance` reports 75/75 tests
  passing, `moon test --target native` reports 2246/2246 tests passing, and
  `moon check --target all --warn-list +73` reports the known warning baseline
  with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-boundary cpdfsqueeze slice: optional
  `.repos/cpdf-source/manualimages/text.pdf` and `xobj.pdf` now gate
  `decompress_pdf`, `recompress_pdf`, and `squeeze` on real Flate-compressed
  content streams and a real Form XObject fixture. The gate verifies stream
  count preservation across decompression/recompression, complete removal of
  supported `/Filter` and `/F` stream filter entries after decompression,
  cpdf-style `only_if_smaller` recompression by allowing small streams to remain
  unfiltered, page-data squeeze/reread behavior, preserved text/Form-XObject
  content JSON, compressed rewrite/reread, and bad-`startxref` recovery. `moon
  test --target native fixture_acceptance --filter '*squeeze fixtures*'` reports
  1/1 test passing, `moon test --target native fixture_acceptance` reports 76/76
  tests passing, `moon test --target native` reports 2247/2247 tests passing,
  and `moon check --target all --warn-list +73` reports the known warning
  baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-boundary cpdftweak slice: optional
  `.repos/cpdf-source/manualimages/colfill.pdf`, `fontparams.pdf`,
  `capjoins.pdf`, and top-level `hello.pdf` now gate cpdf-style colour
  rewrites, text fill insertion, thin-line maximum-width rewriting, and
  byte-string page-content prepending on real cpdf source fixtures. The gate
  verifies page geometry/resources/rest preservation, stroke-only and fill-only
  colour replacement without changing the other paint channel, inserted black
  text fill state while retaining source text operators, negative-width
  `thin_lines` threshold behavior, parsed `append_page_content` byte payloads
  before existing page content, text preservation, compressed rewrite/reread,
  and bad-`startxref` recovery. `moon test --target native fixture_acceptance
  --filter '*recolor thin and append*'` reports 1/1 test passing, `moon test
  --target native fixture_acceptance` reports 77/77 tests passing, `moon test
  --target native` reports 2248/2248 tests passing, and `moon check --target
  all --warn-list +73` reports the known warning baseline with 10 warnings and
  0 errors.~~
- [x] ~~Add the next source-boundary cpdfpage marks slice: optional
  `.repos/cpdf-source/logo.pdf` now gates `show_page_boxes` and `trim_marks`
  against a real one-page cpdf fixture carrying `/MediaBox`, `/BleedBox`, and
  `/TrimBox`. The gate verifies page geometry/resources/rest preservation,
  retained transparency resources, cpdf show-box artifact markers, MediaBox red,
  TrimBox orange dashed, and BleedBox pink dashed outline operators, cpdf
  trim-mark artifact and CMYK stroke setup, allowance-based mark geometry,
  compressed rewrite/reread, and bad-`startxref` recovery. `moon test --target
  native fixture_acceptance --filter '*draws page marks*'` reports 1/1 test
  passing, `moon test --target native fixture_acceptance` reports 78/78 tests
  passing, `moon test --target native` reports 2249/2249 tests passing, and
  `moon check --target all --warn-list +73` reports the known warning baseline
  with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-boundary cpdfpage stamp/combine slice: optional
  `.repos/cpdf-source/hello.pdf` and `logo.pdf` now gate `stamp_pages` and
  `combine_pages` against real source PDFs. The gate verifies base page
  geometry/rotation preservation, Hello text preservation, prefixed logo
  ExtGState resources, merged logo transparency rest/TrimBox/BleedBox data,
  explicit stamp translation, scale-to-fit combine matrix, compressed
  rewrite/reread, and bad-`startxref` recovery. `moon test --target native
  fixture_acceptance --filter '*stamp and combine*'` reports 1/1 test passing,
  `moon test --target native fixture_acceptance` reports 79/79 tests passing,
  `moon test --target native` reports 2250/2250 tests passing, and `moon check
  --target all --warn-list +73` reports the known warning baseline with 10
  warnings and 0 errors.~~
- [x] ~~Add the next source-boundary optional-content slice: optional
  `.repos/cpdf-source/hello.pdf` now gates cpdf-style optional-content group
  writing, listing, JSON export/import, rename, order-all, and coalesce paths
  on a real source PDF after injecting OCG catalog metadata. The gate verifies
  original Hello text preservation, duplicate raw layer names, usage
  dictionaries, usage-application dictionaries, UTF-8 JSON blob output,
  replacement from exported JSON, compressed rewrite/reread, bad-`startxref`
  recovery, wrapper parity, order-all output, duplicate layer coalescing,
  duplicate object removal, and reference rewriting for an unrelated witness
  dictionary. The slice also fixes `write_optional_content_groups` so auxiliary
  usage/config objects are allocated after the explicit OCG object-number
  range, preventing a later explicit OCG object from overwriting a just-created
  usage dictionary. `moon test --target native pdf_ocg_test.mbt` reports 18/18
  tests passing, `moon test --target native fixture_acceptance --filter
  'optional cpdf source hello fixture roundtrips optional content groups'`
  reports 1/1 test passing, `moon test --target native fixture_acceptance`
  reports 80/80 tests passing, `moon test --target native` reports 2252/2252
  tests passing, and `moon check --target all --warn-list +73` reports the
  known warning baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-boundary cpdfbookmarks mutation slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` now gates `bookmarks_open_to_level` and
  `add_bookmark_title` method/wrapper behavior on the real 163-entry manual
  outline. The gate verifies top-level/child open-state rewriting, title
  bookmark insertion from filename basename, decoded PDFDocString title
  preservation across source UTF-16 and generated strings, original outline
  indentation, page-target preservation, JSON/list output, compressed
  rewrite/reread, and bad-`startxref` recovery. `moon check --target native
  fixture_acceptance --warn-list +73` passes, `moon test --target native
  fixture_acceptance --filter 'optional cpdf source manual fixture mutates
  bookmark open state and title'` reports 1/1 test passing, `moon test --target
  native fixture_acceptance` reports 81/81 tests passing, `moon test --target
  native` reports 2253/2253 tests passing, and `moon check --target all
  --warn-list +73` reports the known warning baseline with 10 warnings and 0
  errors.~~
- [x] ~~Add the next source-boundary cpdffont mutation slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` and `.repos/cpdf-source/hello.pdf` now
  gate real embedded-font removal and cross-document font copy behavior. The
  gate verifies `remove_embedded_fonts`/`pdf_remove_fonts` strip decoded
  Nimbus/URW font-file extraction from the manual and report the stripped fonts
  as missing, while `copy_font_from`/`pdf_copy_font` copies a real embedded
  Nimbus font from the manual onto `hello.pdf`, preserves Hello text, exposes
  the copied font resource under its basefont name, keeps its decoded font file
  extractable, avoids a missing-font row for the copy, and survives compressed
  rewrite/reread plus bad-`startxref` recovery. `moon check --target native
  fixture_acceptance --warn-list +73` passes, `moon test --target native
  fixture_acceptance --filter 'optional cpdf source font mutations remove and
  copy embedded fonts'` reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 82/82 tests passing, `moon test --target native`
  reports 2254/2254 tests passing, and `moon check --target all --warn-list
  +73` reports the known warning baseline with 10 warnings and 0 errors.~~
- [x] ~~Broaden the source-boundary image reporting slice: optional
  `.repos/cpdf-source/manualimages/png.pdf` and
  `.repos/cpdf-source/cpdfmanual.pdf` now gate cpdf-style image reporting
  wrapper parity and tuple-level resolution output on real source images. The
  gate verifies `pdf_image_images`, `pdf_image_images_json_blob`,
  `pdf_image_resolution`, `pdf_image_resolution_json`, and
  `pdf_image_resolution_json_blob` match the method APIs, pins the PNG
  fixture's `/I1` 400x294 resolution tuple, and pins the manual's embedded
  object `1477` on page 128 while retaining RGB24 extraction, compressed
  rewrite/reread, and optional source-corpus behavior. `moon check --target
  native fixture_acceptance --warn-list +73` passes, the two affected source
  image fixture tests each report 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 82/82 tests passing, `moon test --target native`
  reports 2254/2254 tests passing, and `moon check --target all --warn-list
  +73` reports the known warning baseline with 10 warnings and 0 errors.~~
- [x] ~~Broaden the source-boundary ToUnicode/content extraction slice:
  optional `.repos/cpdf-source/cpdfmanual.pdf` now gates `pdf_test_extract_text`,
  `pdf_content_entries_of_page`, and `pdf_page_content_json` wrapper parity on
  real manual text pages. The gate pins selected-page UTF-8 extraction without
  replacement/control leakage, page-2 glyph-content extraction through the
  manual's embedded ToUnicode data including `©CoherentGraphicsLimited`, page
  content JSON glyph output, compressed rewrite/reread, and bad-`startxref`
  recovery. `moon check --target native fixture_acceptance --warn-list +73`
  passes, `moon test --target native fixture_acceptance --filter 'optional cpdf
  source manual fixture extracts selected text'` reports 1/1 test passing,
  `moon test --target native fixture_acceptance` reports 82/82 tests passing,
  `moon test --target native` reports 2254/2254 tests passing, and `moon check
  --target all --warn-list +73` reports the known warning baseline with 10
  warnings and 0 errors.~~
- [x] ~~Broaden the source-boundary manual image content corpus slice:
  optional `.repos/cpdf-source/manualimages/*.pdf` now pins per-fixture
  cpdfcontent shape counts for all 21 checked-in manual image PDFs, covering
  476 glyph entries, 1 image entry, and 18 path entries across text, clipping,
  transparency, matrix, XObject, and raster-image fixtures. The shared corpus
  helper now also gates `pdf_content_entries_of_page`,
  `pdf_content_json_of_page`, and `pdf_page_content_json` wrapper parity for
  each fixture and keeps compressed rewrite/reread count preservation. `moon
  check --target native fixture_acceptance --warn-list +73` passes, `moon test
  --target native fixture_acceptance --filter 'optional cpdf source manual image
  fixtures traverse content entries'` reports 1/1 test passing, `moon test
  --target native fixture_acceptance` reports 82/82 tests passing, `moon test
  --target native` reports 2254/2254 tests passing, and `moon check --target
  all --warn-list +73` reports the known warning baseline with 10 warnings and 0
  errors.~~
- [x] ~~Broaden the source-boundary manual image operator corpus slice:
  optional `.repos/cpdf-source/manualimages/*.pdf` now gates parsed content
  operator parameters for all 21 manual image PDFs, extending the prior drawing
  fixture gate from 11 fixtures to the full corpus. The slice pins Bezier,
  line/fill, font/text, marked-content H1, line-wrapped text, PNG image draw,
  transparency ExtGState, and repeated XObject operators through original
  reads, compressed rewrite/reread, and bad-`startxref` recovery. `moon check
  --target native fixture_acceptance --warn-list +73` passes, `moon test
  --target native fixture_acceptance --filter 'optional cpdf source drawing
  fixtures preserve operator parameters'` reports 1/1 test passing, `moon test
  --target native fixture_acceptance` reports 82/82 tests passing, `moon test
  --target native` reports 2254/2254 tests passing, and `moon check --target
  all --warn-list +73` reports the known warning baseline with 10 warnings and 0
  errors.~~
- [x] ~~Broaden the source-boundary manual image text extraction slice:
  optional `.repos/cpdf-source/manualimages/*.pdf` text-bearing fixtures now
  gate exact `test_extract_text` and `pdf_test_extract_text` wrapper parity on
  nine real source PDFs, covering font parameter, font, tagged H1, wrapped
  line, paragraph, multi-paragraph, scaled text, plain text, and clipped text
  fixtures. The gate pins the current cpdf-style extraction strings, verifies no
  UTF-8 replacement/control leakage, and repeats the assertions through original
  reads, compressed rewrite/reread, and bad-`startxref` recovery. `moon check
  --target native fixture_acceptance --warn-list +73` passes, `moon test
  --target native fixture_acceptance --filter 'optional cpdf source manual image
  text fixtures extract exact text'` reports 1/1 test passing, `moon test
  --target native fixture_acceptance` reports 83/83 tests passing, `moon test
  --target native` reports 2255/2255 tests passing, and `moon check --target all
  --warn-list +73` reports the warning 73 baseline with 7 warnings and 0
  errors.~~
- [x] ~~Broaden the source-boundary spot-colour slice: optional
  `.repos/cpdf-source/hello.pdf` now gates cpdfspot-style `list_spot_colours`
  and `pdf_list_spot_colours` wrapper parity on a real source PDF after
  injecting direct and indirect top-level `/Separation` colour-space objects.
  The gate verifies the original source fixture has no spot colours, preserves
  Hello text after the mutation, pins direct and resolved indirect colourant
  names in object-order scan order, and repeats the assertions through
  compressed rewrite/reread and bad-`startxref` recovery. `moon check --target
  native fixture_acceptance --warn-list +73` passes, `moon test --target native
  fixture_acceptance --filter 'optional cpdf source hello fixture lists injected
  spot colours'` reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 84/84 tests passing, `moon test --target native`
  reports 2256/2256 tests passing, and `moon check --target all --warn-list
  +73` reports the warning 73 baseline with 10 warnings and 0 errors.~~
- [x] ~~Broaden the source-boundary inline-image reporting slice: optional
  `.repos/cpdf-source/hello.pdf` now gates cpdfimage-style inline image
  reporting on a real source PDF after appending a small inline `/DeviceRGB`
  image content stream. The gate verifies the original source fixture has no
  images, preserves Hello text after the mutation, keeps default XObject-only
  `images_json` and `image_resolution` output empty, pins `-inline` image JSON
  fields for object `0`, dimensions, byte count, colour space, and filter, pins
  inline DPI tuple output, checks `pdf_image_images`,
  `pdf_image_images_json_blob`, `pdf_image_resolution`,
  `pdf_image_resolution_json`, and `pdf_image_resolution_json_blob` wrapper
  parity, and repeats the assertions through compressed rewrite/reread and
  bad-`startxref` recovery. `moon check --target native fixture_acceptance
  --warn-list +73` passes, `moon test --target native fixture_acceptance
  --filter 'optional cpdf source hello fixture reports inline images'` reports
  1/1 test passing, `moon test --target native fixture_acceptance` reports
  85/85 tests passing, `moon test --target native` reports 2257/2257 tests
  passing, and `moon check --target all --warn-list +73` reports the warning 73
  baseline with 10 warnings and 0 errors.~~
- [x] ~~Broaden the source-boundary Type3 glyph-program slice: optional
  `.repos/cpdf-source/hello.pdf` now gates Type3 font reading on a real source
  PDF after injecting an indirect Type3 font resource, `/CharProcs` glyph
  streams, a glyph XObject resource, and a `/ToUnicode` CMap. The gate preserves
  Hello text while extracting the injected `ZY` text, verifies `list_fonts` and
  `pdf_list_fonts` expose the `/SourceT3` `/Type3` font, pins Type3 `/FontBBox`,
  `/FontMatrix`, CharProc ordering, parsed `d0`/`d1` glyph programs, nested
  glyph-resource parsing, width metrics, fabricated descriptor ToUnicode bytes,
  `font_table`/`pdf_font_table` rows, Unicode names, and repeats the assertions
  through compressed rewrite/reread and bad-`startxref` recovery. `moon check
  --target native fixture_acceptance --warn-list +73` passes, `moon test
  --target native fixture_acceptance --filter 'optional cpdf source hello
  fixture reads injected Type3 glyph programs'` reports 1/1 test passing, `moon
  test --target native fixture_acceptance` reports 86/86 tests passing, `moon
  test --target native` reports 2258/2258 tests passing, and `moon check
  --target all --warn-list +73` reports the warning 73 baseline with 10 warnings
  and 0 errors.~~
- [x] ~~Broaden the source-boundary ToUnicode variation slice: optional
  `.repos/cpdf-source/hello.pdf` now gates filtered `/ToUnicode` variation text
  extraction on a real source PDF after injecting a Type1 font resource with a
  Flate-compressed CMap containing surrogate-pair `bfchar`, array-form
  multi-codepoint `bfrange`, and sequential `bfrange` mappings. The gate
  preserves Hello text while extracting the injected Unicode sequence, pins the
  descriptor's raw UTF-16BE ToUnicode bytes, verifies
  `PdfTextExtractor::codepoints_of_text` output, reverse
  `charcode_of_codepoint` behavior for single-codepoint and multi-codepoint
  entries, `font_table`/`pdf_font_table` rows for non-BMP and multi-scalar
  mappings, and repeats the assertions through compressed rewrite/reread and
  bad-`startxref` recovery. `moon check --target native fixture_acceptance
  --warn-list +73` passes, `moon test --target native fixture_acceptance
  --filter 'optional cpdf source hello fixture extracts ToUnicode variation
  text'` reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 87/87 tests passing, `moon test --target native`
  reports 2259/2259 tests passing, and `moon check --target all --warn-list
  +73` reports the warning 73 baseline with 10 warnings and 0 errors.~~
- [x] ~~Broaden the source-boundary predefined CMap slice: optional
  `.repos/cpdf-source/hello.pdf` now gates rare UniAKR predefined CMap behavior
  on a real source PDF after injecting Type0 CID-keyed fonts for
  `/UniAKR-UTF8-H`, `/UniAKR-UTF16-H`, and `/UniAKR-UTF32-H` with Adobe
  Korea1 descendant font metadata. The gate preserves the original Hello text,
  extracts injected Hangul text through the two-byte UniAKR UTF-16 page content
  path, verifies `list_fonts` and `read_font` expose each `/Type0`
  `PdfFontCIDKeyed` resource with the expected predefined CMap and
  `uses_two_byte_codes` behavior, pins `PdfTextExtractor::codepoints_of_text`
  and reverse `charcode_of_codepoint` behavior for UTF-8, UTF-16, and UTF-32
  encoded Hangul byte streams, and repeats the assertions through compressed
  rewrite/reread and bad-`startxref` recovery. `moon check --target native
  fixture_acceptance --warn-list +73` passes, `moon test --target native
  fixture_acceptance --filter 'optional cpdf source hello fixture extracts
  UniAKR predefined CMaps'` reports 1/1 test passing, `moon test --target
  native fixture_acceptance` reports 88/88 tests passing, `moon test --target
  native` reports 2260/2260 tests passing, and `moon check --target all
  --warn-list +73` reports the warning 73 baseline with 10 warnings and 0
  errors.~~
- [x] ~~Broaden the source-boundary Japan1 predefined CMap slice: optional
  `.repos/cpdf-source/hello.pdf` now gates Adobe-Japan1 legacy/supplemental
  predefined CMap behavior on a real source PDF after injecting Type0
  CID-keyed fonts for `/90msp-RKSJ-H`, `/90msp-RKSJ-V`, and `/Hojo-EUC-V`
  with Adobe Japan1 descendant font metadata. The gate preserves the original
  Hello text, extracts injected vertical 90msp-RKSJ text through the source
  page content path, verifies `list_fonts` and `read_font` expose each
  `/Type0` `PdfFontCIDKeyed` resource with the expected predefined CMap and
  mixed-byte `uses_two_byte_codes` behavior, pins
  `PdfTextExtractor::codepoints_of_text` output for 90msp horizontal,
  90msp vertical, and three-byte Hojo-EUC byte streams, verifies reverse
  `charcode_of_codepoint` behavior for single-byte, two-byte, and three-byte
  character codes, and repeats the assertions through compressed rewrite/reread
  and bad-`startxref` recovery. `moon check --target native fixture_acceptance
  --warn-list +73` passes, `moon test --target native fixture_acceptance
  --filter 'optional cpdf source hello fixture extracts Japan1 predefined
  CMaps'` reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 89/89 tests passing, `moon test --target native`
  reports 2261/2261 tests passing, and `moon check --target all --warn-list
  +73` reports the warning 73 baseline with 10 warnings and 0 errors.~~
- [x] ~~Broaden the source-boundary image corpus slice: optional
  `.repos/cpdf-source/hello.pdf` now gates recursive Form XObject image
  traversal on a real source PDF after injecting a Form XObject that owns a
  `/SourceNestedImage` Image XObject. The gate preserves the original Hello
  text, verifies `images_json`/`pdf_image_images` and JSON blob wrappers report
  the nested image with width, height, byte count, bit depth, colourspace, and
  filter metadata, verifies `image_resolution` and its JSON/blob wrappers
  descend through the Form XObject and pin the reported DPI/object tuple,
  confirms the Form content stream and resource dictionary parse back to the
  injected `/Do` path, decodes the nested Flate/DeviceGray image through
  `get_image_24bpp`, and repeats the assertions through compressed
  rewrite/reread and bad-`startxref` recovery. `moon check --target native
  fixture_acceptance --warn-list +73` passes, `moon test --target native
  fixture_acceptance --filter 'optional cpdf source hello fixture reports
  nested form images'` reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 90/90 tests passing, `moon test --target native`
  reports 2262/2262 tests passing, `moon info && moon fmt` reports no pending
  interface or formatting work, and `moon check --target all --warn-list +73`
  reports the warning 73 baseline with 10 warnings and 0 errors.~~
- [x] ~~Broaden the source-boundary predefined CMap slice: optional
  `.repos/cpdf-source/hello.pdf` now gates cpdf-listed Adobe-GB1 and
  Adobe-CNS1 direct-Unicode predefined CMaps on a real source PDF after
  injecting Type0 CID-keyed fonts for `/UniGB-UTF16-H`, `/UniGB-UTF16-V`,
  `/UniGB-UCS32-H`, `/UniGB-UCS32-V`, `/UniCNS-UCS2-H`, `/UniCNS-UCS2-V`,
  `/UniCNS-UTF16-H`, and `/UniCNS-UTF16-V`. The gate preserves the original
  Hello text, extracts injected GB and CNS BMP text through the source page
  content path, verifies `list_fonts` and `read_font` expose each `/Type0`
  `PdfFontCIDKeyed` resource with the expected predefined CMap, GB1/CNS1
  CIDSystemInfo ordering, and fixed/variable code-width behavior, pins direct
  `PdfTextExtractor::codepoints_of_text` and reverse `charcode_of_codepoint`
  behavior for UTF-16, UCS-2, and UCS-32 byte streams including a CNS UTF-16
  surrogate-pair path, and repeats the assertions through compressed
  rewrite/reread and bad-`startxref` recovery. `moon check --target native
  fixture_acceptance --warn-list +73` passes, `moon test --target native
  fixture_acceptance --filter 'optional cpdf source hello fixture extracts GB
  CNS predefined CMaps'` reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 91/91 tests passing, `moon test --target native`
  reports 2263/2263 tests passing, `moon info && moon fmt` reports no pending
  interface or formatting work, and `moon check --target all --warn-list +73`
  reports the warning 73 baseline with 10 warnings and 0 errors.~~
- [x] ~~Broaden the source-boundary predefined CMap slice: optional
  `.repos/cpdf-source/hello.pdf` now gates the cpdf-listed Korean
  `/UniKS-UCS2-H` and `/UniKS-UCS2-V` direct-Unicode predefined CMaps on a real
  source PDF after injecting horizontal and vertical Type0 CID-keyed font
  resources. The gate preserves the original Hello text, extracts injected
  Hangul text through the source page content path, verifies `list_fonts` and
  `read_font` expose each `/Type0` `PdfFontCIDKeyed` resource with the expected
  predefined CMap, Korea1 CIDSystemInfo ordering, and two-byte code behavior,
  pins direct `PdfTextExtractor::codepoints_of_text` and reverse
  `charcode_of_codepoint` behavior for the UCS-2 Hangul byte stream, verifies
  out-of-UCS2 reverse lookup fails, and repeats the assertions through
  compressed rewrite/reread and bad-`startxref` recovery. `moon check --target
  native fixture_acceptance --warn-list +73` passes, `moon test --target native
  fixture_acceptance --filter 'optional cpdf source hello fixture extracts
  UniKS predefined CMaps'` reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 92/92 tests passing, `moon test --target native`
  reports 2264/2264 tests passing, `moon info && moon fmt` reports no pending
  interface or formatting work, and `moon check --target all --warn-list +73`
  reports the warning 73 baseline with 10 warnings and 0 errors.~~
- [x] ~~Broaden the source-boundary predefined CMap slice: optional
  `.repos/cpdf-source/hello.pdf` now gates vertical Korea1 predefined CMaps on
  a real source PDF after injecting Type0 CID-keyed fonts for `/KSC-EUC-V`,
  `/KSCpc-EUC-V`, `/KSCms-UHC-V`, and `/KSCms-UHC-HW-V`. The gate preserves
  the original Hello text, extracts injected vertical ellipsis text through the
  source page content path, verifies `list_fonts` and `read_font` expose each
  `/Type0` `PdfFontCIDKeyed` resource with the expected predefined CMap,
  Korea1 CIDSystemInfo ordering, and mixed-byte code behavior, pins direct
  `PdfTextExtractor::codepoints_of_text` and reverse `charcode_of_codepoint`
  behavior for the vertical `A1 A6` byte stream, verifies unrelated Unicode
  reverse lookup fails, and repeats the assertions through compressed
  rewrite/reread and bad-`startxref` recovery. `moon check --target native
  fixture_acceptance --warn-list +73` passes, `moon test --target native
  fixture_acceptance --filter 'optional cpdf source hello fixture extracts
  Korea1 vertical CMaps'` reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 93/93 tests passing, `moon test --target native`
  reports 2265/2265 tests passing, `moon info && moon fmt` reports no pending
  interface or formatting work, and `moon check --target all --warn-list +73`
  reports the warning 73 baseline with 10 warnings and 0 errors.~~
- [x] ~~Broaden the source-boundary Japan1 predefined CMap slice again:
  optional `.repos/cpdf-source/hello.pdf` now gates base Adobe-Japan1
  predefined CMaps `/90ms-RKSJ-H`, `/90pv-RKSJ-H`, `/H`, `/EUC-H`, and
  `/Hojo-EUC-H` on a real source PDF after injecting Type0 CID-keyed font
  resources. The gate preserves the original Hello text, extracts injected
  90ms RKSJ text through the source page content path, verifies `list_fonts`
  and `read_font` expose each `/Type0` `PdfFontCIDKeyed` resource with Japan1
  CIDSystemInfo ordering and expected fixed/mixed byte-code behavior, pins
  `PdfTextExtractor::codepoints_of_text` and reverse
  `charcode_of_codepoint` behavior for RKSJ, 90pv-RKSJ, JIS, EUC, and
  three-byte Hojo-EUC byte streams, checks the 90ms Euro reverse mapping and
  the 90pv private-use non-reverse mapping, and repeats the assertions through
  compressed rewrite/reread and bad-`startxref` recovery. `moon check --target
  native fixture_acceptance --warn-list +73` passes, `moon test --target
  native fixture_acceptance --filter 'optional cpdf source hello fixture
  extracts Japan1 base predefined CMaps'` reports 1/1 test passing, `moon test
  --target native fixture_acceptance` reports 94/94 tests passing, `moon test
  --target native` reports 2266/2266 tests passing, `moon info && moon fmt`
  reports no pending interface or formatting work, and `moon check --target
  all --warn-list +73` reports the warning 73 baseline with 10 warnings and 0
  errors.~~
- [x] ~~Broaden the source-boundary predefined CMap slice to GB1 legacy
  families: optional `.repos/cpdf-source/hello.pdf` now gates `/GB-EUC-H`,
  `/GBpc-EUC-H`, `/GBK-EUC-H`, `/GBKp-EUC-H`, and `/GBK2K-H` on a real source
  PDF after injecting Type0 CID-keyed font resources. The gate preserves the
  original Hello text, verifies the injected GB-EUC text operator survives in
  the parsed source page content stream, verifies `list_fonts` and `read_font`
  expose each `/Type0` `PdfFontCIDKeyed` resource with GB1 CIDSystemInfo
  ordering and mixed-byte code behavior, pins `PdfTextExtractor` codepoint and
  reverse `charcode_of_codepoint` behavior for GB-EUC, GBpc-EUC, GBK, GBKp,
  and four-byte GBK2K byte streams, checks unmapped reverse lookups for Euro,
  combining-grave, emoji, and GBK private-use paths, and repeats the assertions
  through compressed rewrite/reread and bad-`startxref` recovery. `moon check
  --target native fixture_acceptance --warn-list +73` passes, `moon test
  --target native fixture_acceptance --filter 'optional cpdf source hello
  fixture extracts GB1 legacy predefined CMaps'` reports 1/1 test passing,
  `moon test --target native fixture_acceptance` reports 95/95 tests passing,
  `moon test --target native` reports 2267/2267 tests passing, `moon info &&
  moon fmt` reports no pending interface or formatting work, and `moon check
  --target all --warn-list +73` reports the warning 73 baseline with 10
  warnings and 0 errors.~~
- [x] ~~Broaden the source-boundary predefined CMap slice to CNS1 legacy and
  variant families: optional `.repos/cpdf-source/hello.pdf` now gates
  `/ETen-B5-H`, `/B5pc-H`, `/HKscs-B5-H`, `/ETenms-B5-H`, `/HKdla-B5-H`,
  `/HKdlb-B5-H`, `/HKgccs-B5-H`, `/HKm314-B5-H`, `/HKm471-B5-H`,
  `/CNS-EUC-H`, and `/CNS-EUC-V` on a real source PDF after injecting Type0
  CID-keyed font resources. The gate preserves the original Hello text,
  verifies the injected ETen-B5 text operator survives in the parsed source
  page content stream, verifies `list_fonts` and `read_font` expose each
  `/Type0` `PdfFontCIDKeyed` resource with CNS1 CIDSystemInfo ordering and
  mixed-byte code behavior, pins `PdfTextExtractor` codepoint and reverse
  `charcode_of_codepoint` behavior for Big5, B5pc, HKSCS, ETenms, Hong Kong
  variant Big5, CNS-EUC horizontal, and CNS-EUC vertical byte streams, checks
  unmapped reverse lookup paths, and repeats the assertions through compressed
  rewrite/reread and bad-`startxref` recovery. `moon check --target native
  fixture_acceptance --warn-list +73` passes, `moon test --target native
  fixture_acceptance --filter 'optional cpdf source hello fixture extracts
  CNS1 legacy predefined CMaps'` reports 1/1 test passing, `moon test --target
  native fixture_acceptance` reports 96/96 tests passing, `moon test --target
  native` reports 2268/2268 tests passing, `moon info && moon fmt` reports no
  pending interface or formatting work, and `moon check --target all
  --warn-list +73` reports the warning 73 baseline with 10 warnings and 0
  errors.~~
- [x] ~~Broaden the source-boundary predefined CMap slice to vertical GB/CNS
  families: optional `.repos/cpdf-source/hello.pdf` now gates `/GB-EUC-V`,
  `/GBpc-EUC-V`, `/GBK-EUC-V`, `/GBKp-EUC-V`, `/GBK2K-V`, `/B5-V`,
  `/B5pc-V`, `/ETen-B5-V`, `/ETenms-B5-V`, `/HKdla-B5-V`, `/HKdlb-B5-V`,
  `/HKgccs-B5-V`, `/HKm314-B5-V`, `/HKm471-B5-V`, and `/HKscs-B5-V` on a real
  source PDF after injecting Type0 CID-keyed font resources. The gate preserves
  the original Hello text, verifies the injected vertical GB-EUC text operator
  survives in the parsed source page content stream, verifies `list_fonts` and
  `read_font` expose each `/Type0` `PdfFontCIDKeyed` resource with GB1/CNS1
  CIDSystemInfo ordering and mixed-byte vertical code behavior, pins
  `PdfTextExtractor` codepoint and reverse `charcode_of_codepoint` behavior for
  GB1 vertical, GBK2K vertical, Big5 vertical, ETenms vertical, and Hong Kong
  variant vertical byte streams, verifies unrelated emoji reverse lookup fails,
  and repeats the assertions through compressed rewrite/reread and
  bad-`startxref` recovery. `moon check --target native fixture_acceptance
  --warn-list +73` passes, `moon test --target native fixture_acceptance
  --filter 'optional cpdf source hello fixture extracts vertical GB CNS
  predefined CMaps'` reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 97/97 tests passing, `moon test --target native`
  reports 2269/2269 tests passing, `moon info && moon fmt` reports no pending
  interface or formatting work, and `moon check --target all --warn-list +73`
  reports the warning 73 baseline with 10 warnings and 0 errors.~~
- [x] ~~Broaden the source-boundary PDF/UA CMap-name slice: optional
  `.repos/cpdf-source/hello.pdf` now gates the cpdfua source typo
  `/KSCms-UHS-HW-V` on a real source PDF after injecting unused Type0
  CID-keyed font resources and `/UseCMap` dictionaries for both the source typo
  and the corrected-looking `/KSCms-UHC-HW-V` spelling. The gate preserves the
  original Hello text, verifies `list_fonts` and `read_font` expose both
  injected `/Type0` `PdfFontCIDKeyed` resources with Korea1 CIDSystemInfo
  ordering, verifies Matterhorn `31-006` still accepts the source typo while
  reporting only `/KSCms-UHC-HW-V` as an unlisted CMap, verifies the public
  `pdf_ua_test_matterhorn_json` wrapper does the same for `31-008` `/UseCMap`
  references, and repeats the assertions through compressed rewrite/reread and
  bad-`startxref` recovery. `moon check --target native fixture_acceptance
  --warn-list +73` passes, `moon test --target native fixture_acceptance
  --filter 'optional cpdf source hello fixture preserves Matterhorn CMap typo'`
  reports 1/1 test passing, `moon test --target native fixture_acceptance`
  reports 98/98 tests passing, `moon test --target native` reports 2270/2270
  tests passing, `moon info && moon fmt` reports no pending interface or
  formatting work, and `moon check --target all --warn-list +73` reports the
  warning 73 baseline with 10 warnings and 0 errors.~~
- [x] ~~Broaden the source-boundary ToUnicode parser-corner slice: optional
  `.repos/cpdf-source/hello.pdf` now gates a Flate-compressed Type1
  `/ToUnicode` CMap on a real source PDF after injecting a font resource and
  page content that exercise commented-out fake metadata, split `bfchar`
  operands, odd-nibble hex strings, multiline `bfrange` arrays,
  multi-codepoint entries, compact same-line `beginbfchar`/`endbfchar`, and
  unmapped fallback bytes. The gate preserves the original Hello text, verifies
  the injected text operators survive parsed page-content rereads, pins
  extracted codepoints for BMP, supplementary-plane, multi-scalar, and fallback
  mappings, verifies `list_fonts`, `read_font`, descriptor raw UTF-16BE
  mappings, reverse `charcode_of_codepoint` lookups, and `font_table`/wrapper
  rows for compact, multi-codepoint, and supplementary entries, then repeats
  the assertions through compressed rewrite/reread and bad-`startxref`
  recovery. `moon check --target native fixture_acceptance --warn-list +73`
  passes, `moon test --target native fixture_acceptance --filter 'optional cpdf
  source hello fixture extracts ToUnicode parser corners'` reports 1/1 test
  passing, `moon test --target native fixture_acceptance` reports 99/99 tests
  passing, `moon test --target native` reports 2271/2271 tests passing, `moon
  info && moon fmt` reports no pending interface or formatting work, and `moon
  check --target all --warn-list +73` reports the warning 73 baseline with 10
  warnings and 0 errors.~~
- [x] ~~Broaden the source-boundary Type3 glyph-program slice: optional
  `.repos/cpdf-source/hello.pdf` now extends the injected Type3 font gate with
  a third `/C` CharProc that consumes Type3 `/Resources` for both a nested
  `/GlyphMark` Form XObject and a named inline-image `/ColorSpace` resource
  (`/GlyphGray` -> `/DeviceGray`). The gate preserves the original Hello text,
  verifies injected `/SourceT3` text now extracts `ZY` plus U+2603, verifies
  `list_fonts` and `read_font` expose the `/Type3` font with `/A`/`/B`/`/C`
  CharProc ordering, `/MissingWidth`, sparse metrics, Type3 resource
  dictionaries, parsed `d0`/`d1` programs, parsed resource-consuming inline
  image glyph content, fabricated descriptor ToUnicode bytes, font table rows,
  and repeats the assertions through compressed rewrite/reread and
  bad-`startxref` recovery. `moon check --target native fixture_acceptance
  --warn-list +73` passes, `moon test --target native fixture_acceptance
  --filter 'optional cpdf source hello fixture reads injected Type3 glyph
  programs'` reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 99/99 tests passing, `moon test --target native`
  reports 2271/2271 tests passing, `moon info && moon fmt` reports no pending
  interface or formatting work, and `moon check --target all --warn-list +73`
  reports the warning 73 baseline with 10 warnings and 0 errors.~~
- [x] ~~Broaden the source-boundary ToUnicode stream-inheritance slice:
  optional `.repos/cpdf-source/hello.pdf` now gates multi-hop indirect
  `/UseCMap` composition on a real source PDF after injecting a Type1 font
  whose Flate-compressed child `/ToUnicode` stream points at a base CMap stream,
  which points at a grandbase CMap stream. The gate preserves the original
  Hello text, verifies extracted injected `/SourceUseCMap` text honors child
  mappings over inherited duplicate entries plus inherited fallback mappings,
  verifies parsed page-content operators, `list_fonts`, `read_font`, composed
  descriptor ToUnicode bytes, direct `parse_cmap` output, reverse
  `charcode_of_codepoint` lookups, `font_table`/wrapper rows, and repeats the
  assertions through compressed rewrite/reread and bad-`startxref` recovery.
  `moon check --target native fixture_acceptance --warn-list +73` passes,
  `moon test --target native fixture_acceptance --filter 'optional cpdf source
  hello fixture composes ToUnicode UseCMap streams'` reports 1/1 test passing,
  `moon test --target native fixture_acceptance` reports 100/100 tests
  passing, `moon test --target native` reports 2272/2272 tests passing, `moon
  info && moon fmt` reports no pending interface or formatting work, and `moon
  check --target all --warn-list +73` reports the warning 73 baseline with 10
  warnings and 0 errors.~~
- [x] ~~Broaden the source-boundary malformed classic xref recovery slice:
  optional `.repos/cpdf-source/hello.pdf` now gates reconstruction across
  first in-use row marker, offset, generation, first subsection object number,
  and first subsection count corruption. Each case verifies strict classic
  reading rejects the damaged table, fallback reconstruction resets
  `first_xref()` to `0`, preserves the one-page source fixture, and survives a
  compressed rewrite/reread. `moon check --target native fixture_acceptance
  --warn-list +73` passes, `moon test --target native fixture_acceptance
  --filter 'optional cpdf source hello fixture reconstructs malformed classic
  xref table variants'` reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 100/100 tests passing, `moon test --target native`
  reports 2272/2272 tests passing, `moon info && moon fmt` reports no pending
  interface or formatting work, and `moon check --target all --warn-list +73`
  reports the warning 73 baseline with 7 warnings and 0 errors.~~
- [x] ~~Broaden the top-level source-logo malformed classic xref recovery
  slice: optional `.repos/cpdf-source/logo.pdf` now gates the same five classic
  xref table corruptions as the source hello fixture and checked-in CamlPDF logo
  fixture: first in-use row marker, offset, generation, first subsection object
  number, and first subsection count. Each variant verifies strict classic
  reading rejects the damaged linearized source-logo table, fallback
  reconstruction resets `first_xref()` to `0`, preserves the one-page fixture,
  and survives compressed rewrite/reread. `moon check --target native
  fixture_acceptance --warn-list +73` passes, `moon test --target native
  fixture_acceptance --filter 'optional cpdf source logo fixture reconstructs
  malformed classic xref table variants'` reports 1/1 test passing, `moon test
  --target native fixture_acceptance` reports 101/101 tests passing, `moon test
  --target native` reports 2273/2273 tests passing, `moon info && moon fmt`
  reports no pending interface or formatting work, and `moon check --target all
  --warn-list +73` reports the warning 73 baseline with 7 warnings and 0
  errors.~~
- [x] ~~Broaden the source-boundary predefined CMap slice for Identity maps:
  optional `.repos/cpdf-source/hello.pdf` now gates injected `/Identity-H` and
  `/Identity-V` Type0 CID-keyed fonts on a real source PDF. The gate preserves
  the original Hello text, verifies two-byte charcode segmentation through
  extracted Identity-H text `0041 20AC 4E00` and Identity-V text `0042 4E8C`,
  pins parsed page-content `/Tf` and `/Tj` operators, verifies `list_fonts`,
  `read_font`, `PdfPredefinedCMap` encoding, `/CIDSystemInfo` ordering,
  `uses_two_byte_codes`, `is_identity_h`, `is_identity_v`,
  `content_is_vertical`, direct extractor codepoints, and the current
  no-reverse-lookup behavior for Identity maps, then repeats the assertions
  through compressed rewrite/reread and bad-`startxref` recovery. `moon check
  --target native fixture_acceptance --warn-list +73` passes, `moon test
  --target native fixture_acceptance --filter 'optional cpdf source hello
  fixture extracts Identity predefined CMaps'` reports 1/1 test passing, `moon
  test --target native fixture_acceptance` reports 102/102 tests passing, `moon
  test --target native` reports 2274/2274 tests passing, `moon info && moon
  fmt` reports no pending interface or formatting work, and `moon check
  --target all --warn-list +73` reports the warning 73 baseline with 7 warnings
  and 0 errors.~~
- [x] ~~Broaden the source-boundary predefined CMap slice for UniJIS direct
  Unicode maps: optional `.repos/cpdf-source/hello.pdf` now gates injected
  `/UniJIS-UCS2-H`, `/UniJIS-UCS2-V`, `/UniJIS-UTF16-H`,
  `/UniJIS-UTF16-V`, `/UniJIS-UTF8-H`, `/UniJIS-UCS2-HW-H`, and
  `/UniJIS-UCS2-HW-V` Type0 CID-keyed fonts on a real source PDF. The gate
  preserves the original Hello text, pins page-content `/Tf` and `/Tj`
  operators for the two-byte families, verifies `list_fonts`, `read_font`,
  `PdfPredefinedCMap` encoding, `/CIDSystemInfo` `Japan1` ordering,
  two-byte-vs-UTF8 charcode classification, direct extractor codepoints, reverse
  charcode lookup including UTF8 packed charcodes, and invalid-codepoint misses,
  then repeats the assertions through compressed rewrite/reread and
  bad-`startxref` recovery. `moon check --target native fixture_acceptance
  --warn-list +73` passes, `moon test --target native fixture_acceptance
  --filter 'optional cpdf source hello fixture extracts UniJIS Unicode predefined
  CMaps'` reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 103/103 tests passing, `moon test --target native`
  reports 2275/2275 tests passing, `moon info && moon fmt` reports no pending
  interface or formatting work, and `moon check --target all --warn-list +73`
  reports the known warning-73/main-package baseline with 10 warnings and 0
  errors.~~
- [x] ~~Pin the source-boundary UniJIS cpdfcontent variable-width Unicode
  boundary: optional `.repos/cpdf-source/hello.pdf` now injects real page
  content for `/UniJIS-UTF8-H` UTF-8 bytes and `/UniJIS-UTF16-H`
  surrogate-pair bytes, verifies the page-content operators and direct
  `PdfTextExtractor` codepoints/reverse lookups still succeed, and preserves
  cpdfcontent's upstream fixed-two-byte CID glyph behavior by requiring
  `test_extract_text` and `page_content_json` to raise `InvalidUTF8` or
  `InvalidUTF16BE` at that boundary after compressed rewrite/reread and
  bad-`startxref` recovery. `moon check --target native fixture_acceptance
  --warn-list +73` passes, `moon test --target native fixture_acceptance
  --filter 'optional cpdf source hello fixture pins UniJIS cpdfcontent Unicode
  boundary'` reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 104/104 tests passing, `moon test --target native`
  reports 2276/2276 tests passing, `moon info && moon fmt` reports no pending
  interface or formatting work, and `moon check --target all --warn-list +73`
  reports the known warning-73/main-package baseline with 10 warnings and 0
  errors.~~
- [x] ~~Pin the source-boundary Korea1/GB1 cpdfcontent variable-width
  direct-Unicode boundary: optional `.repos/cpdf-source/hello.pdf` now injects
  real page content for `/UniAKR-UTF8-H`, `/UniAKR-UTF32-H`, and
  `/UniGB-UCS32-H`, verifies the page-content operators and direct
  `PdfTextExtractor` codepoints/reverse lookups still succeed, and preserves
  cpdfcontent's upstream fixed-two-byte CID glyph behavior by requiring
  `test_extract_text` and `page_content_json` to raise `InvalidUTF8` or
  `BadText` at those split variable-width boundaries after compressed
  rewrite/reread and bad-`startxref` recovery. `moon check --target native
  fixture_acceptance --warn-list +73` passes, `moon test --target native
  fixture_acceptance --filter 'optional cpdf source hello fixture pins Korea GB
  direct Unicode cpdfcontent boundaries'` reports 1/1 test passing, `moon test
  --target native fixture_acceptance` reports 105/105 tests passing, `moon test
  --target native` reports 2277/2277 tests passing, `moon info && moon fmt`
  reports no pending interface or formatting work, and `moon check --target all
  --warn-list +73` reports the known warning-73/main-package baseline with
  10 warnings and 0 errors.~~
- [x] ~~Broaden the source-boundary ToUnicode `/UseCMap` variation slice:
  optional `.repos/cpdf-source/hello.pdf` now gates a three-stream indirect
  `/UseCMap` chain where the child ToUnicode CMap overrides inherited duplicate
  mappings while inherited supplementary-plane and multi-codepoint mappings
  still survive composition. The gate preserves the original Hello text,
  verifies parsed page-content `/Tf` and `/Tj` operators, `list_fonts`,
  `read_font`, descriptor ToUnicode bytes, direct `parse_cmap` output,
  extracted codepoints, reverse single-codepoint lookup, overridden-entry
  misses, multi-codepoint reverse misses, and `font_table`/wrapper rows for
  supplementary, derived, inherited, and multi-codepoint entries, then repeats
  the assertions through compressed rewrite/reread and bad-`startxref`
  recovery. `moon check --target native fixture_acceptance --warn-list +73`
  passes, `moon test --target native fixture_acceptance --filter 'optional cpdf
  source hello fixture composes ToUnicode UseCMap variation streams'` reports
  1/1 test passing, `moon test --target native fixture_acceptance` reports
  106/106 tests passing, `moon test --target native` reports 2278/2278 tests
  passing, `moon info && moon fmt` reports no pending interface or formatting
  work, and `moon check --target all --warn-list +73` reports the known
  warning-73/main-package baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-boundary `cpdftexttopdf` corpus slice: optional
  `.repos/cpdf-source/README.md` now feeds the real source README bytes through
  `pdf_texttopdf_typeset` using a Standard 14 Helvetica fontpack with
  paragraph structure-tree tagging enabled. The gate verifies a generated
  multi-page text PDF, per-page `/StructParents`, full-page extraction through
  both method and wrapper APIs, stable README markers with no replacement or
  raw-control characters, structure-tree text/JSON/blob output, paragraph
  `/P` structure nodes, and marked-content `/P` BDC operators, then repeats the
  same assertions through compressed xref-stream rewrite/reread and
  bad-`startxref` recovery. `moon check --target native fixture_acceptance
  --warn-list +73` passes, `moon test --target native fixture_acceptance
  --filter 'optional cpdf source README typesets tagged text PDF'` reports 1/1
  test passing, `moon test --target native fixture_acceptance` reports 109/109
  tests passing, `moon test --target native` reports 2281/2281 tests passing,
  `moon info && moon fmt` reports no pending interface or formatting work, and
  `moon check --target all --warn-list +73` reports the known warning-73/main-
  package baseline with 7 warnings and 0 errors.~~
- [x] ~~Broaden the source-boundary `cpdftexttopdf` PDF/UA slice: optional
  `.repos/cpdf-source/README.md` now also feeds the real source README bytes
  through `pdf_texttopdf_typeset` with `subformat=Some(PdfUA2)` and a required
  title, exercising the source `cpdftexttopdf.ml` branch where PDF/UA
  subformats force structure-tree processing. The gate reuses the source README
  extraction and paragraph-tag assertions, then verifies PDF 2.0 output, `/Info`
  title, `/MarkInfo /Marked true`, `/Lang (en-US)`, the `/ViewerPreferences`
  `/DisplayDocTitle true` pair, the PDF/UA-2 namespace object, the `/StructTreeRoot`
  raw reference, the document node under root `/K`, namespace parent links, and
  paragraph `/P` parent references, before repeating all assertions through
  compressed xref-stream rewrite/reread and bad-`startxref` recovery. `moon
  check --target native fixture_acceptance --warn-list +73` passes, `moon test
  --target native fixture_acceptance --filter 'optional cpdf source README
  typesets PDF UA2 text PDF'` reports 1/1 test passing, `moon test --target
  native fixture_acceptance` reports 110/110 tests passing, `moon test --target
  native` reports 2282/2282 tests passing, `moon info && moon fmt` reports no
  pending interface or formatting work, and `moon check --target all --warn-list
  +73` reports the known warning-73/main-package baseline with 7 warnings and 0
  errors.~~
- [x] ~~Complete the source-boundary `cpdftexttopdf` PDF/UA-1 corpus branch:
  optional `.repos/cpdf-source/Changes.txt` now feeds the larger real source
  changelog bytes through `pdf_texttopdf_typeset` with `subformat=Some(PdfUA1)`
  and a required title, covering the source branch where PDF/UA-1 also forces
  paragraph structure-tree processing. The gate verifies multi-page extraction
  of source changelog markers, no replacement or raw-control characters,
  per-page `/StructParents`, structure-tree text/JSON/blob output, paragraph
  marked-content operators, PDF 1.7 output, `/Info` title, `/MarkInfo /Marked
  true`, `/Lang (en-US)`, the `/ViewerPreferences` `/DisplayDocTitle true`
  pair, the raw `/StructTreeRoot` reference, absence of PDF/UA-2 namespaces, root
  `/K` paragraph arrays, and paragraph `/P` parent references, before repeating
  all assertions through compressed xref-stream rewrite/reread and
  bad-`startxref` recovery. `moon check --target native fixture_acceptance
  --warn-list +73` passes, `moon test --target native fixture_acceptance
  --filter 'optional cpdf source Changes typesets PDF UA1 text PDF'` reports
  1/1 test passing, `moon test --target native fixture_acceptance` reports
  111/111 tests passing, `moon test --target native` reports 2283/2283 tests
  passing, `moon info && moon fmt` reports no pending interface or formatting
  work, and `moon check --target all --warn-list +73` reports the known
  warning-73/main-package baseline with 7 warnings and 0 errors.~~
- [x] ~~Add the next remaining format parity slice: optional
  `.repos/cpdf-source/hello.pdf` now gates the cpdfua-listed Korea1 horizontal
  predefined CMaps `/KSC-EUC-H`, `/KSCpc-EUC-H`, `/KSCms-UHC-H`, and
  `/KSCms-UHC-HW-H`. The gate installs source-boundary Type 0 fonts over the
  real top-level hello fixture, verifies font listing/read-font state, mixed
  byte extraction, reverse charcode lookups, Korean compatibility mappings,
  undefined-codepoint fallbacks, page text extraction, compressed xref-stream
  rewrite/reread, and bad-`startxref` recovery. `moon check --target native
  fixture_acceptance --warn-list +73` passes, `moon test --target native
  fixture_acceptance --filter 'optional cpdf source hello fixture extracts
  Korea1 horizontal CMaps'` reports 1/1 test passing, `moon test --target
  native fixture_acceptance` reports 112/112 tests passing, `moon test --target
  native` reports 2284/2284 tests passing, `moon info && moon fmt` reports no
  pending interface or formatting work, and `moon check --target all --warn-list
  +73` reports the known warning-73/main-package baseline with 7 warnings and 0
  errors.~~
- [x] ~~Add the next remaining format parity slice: optional
  `.repos/cpdf-source/hello.pdf` now gates the cpdfua-listed rare Japan1
  predefined CMaps `/83pv-RKSJ-H`, `/90ms-RKSJ-V`, `/EUC-V`, `/V`,
  `/Add-RKSJ-H`, `/Add-RKSJ-V`, `/Ext-RKSJ-H`, and `/Ext-RKSJ-V`. The gate
  installs source-boundary Type 0 fonts over the real top-level hello fixture,
  appends all rare-map text runs to page content, verifies font
  listing/read-font state, whole-page extraction, per-font codepoint extraction,
  reverse charcode lookup including the 83pv `0x80` backslash mapping,
  undefined-codepoint fallbacks, compressed xref-stream rewrite/reread, and
  bad-`startxref` recovery. `moon check --target native fixture_acceptance
  --warn-list +73` passes, `moon test --target native fixture_acceptance
  --filter 'optional cpdf source hello fixture extracts rare Japan1 predefined
  CMaps'` reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 113/113 tests passing, `moon test --target
  native` reports 2285/2285 tests passing, `moon info && moon fmt` reports no
  pending interface or formatting work, and `moon check --target all --warn-list
  +73` reports the known warning-73/main-package baseline with 7 warnings and 0
  errors.~~
- [x] ~~Add the next remaining format parity slice: optional
  `.repos/cpdf-source/hello.pdf` now gates the supplemental Japan1 predefined
  CMaps `/78-H`, `/78-V`, `/78-RKSJ-H`, `/78-RKSJ-V`, `/78ms-RKSJ-H`,
  `/78ms-RKSJ-V`, `/90pv-RKSJ-V`, `/RKSJ-H`, `/RKSJ-V`, `/78-EUC-H`,
  `/78-EUC-V`, `/Add-H`, `/Add-V`, `/Ext-H`, `/Ext-V`, `/Hojo-H`, `/Hojo-V`,
  `/NWP-H`, and `/NWP-V`. The gate installs source-boundary Type 0 fonts over
  the real top-level hello fixture, appends supplemental-map text runs to page
  content, verifies font listing/read-font state, whole-page extraction,
  per-font codepoint extraction including the 90pv vertical `0x80` backslash
  mapping, reverse charcode lookup, undefined-codepoint fallbacks, compressed
  xref-stream rewrite/reread, and bad-`startxref` recovery. `moon check
  --target native fixture_acceptance --warn-list +73` passes, `moon test
  --target native fixture_acceptance --filter 'optional cpdf source hello
  fixture extracts supplemental Japan1 predefined CMaps'` reports 1/1 test
  passing, `moon test --target native fixture_acceptance` reports 114/114 tests
  passing, `moon test --target native` reports 2286/2286 tests passing, `moon
  info && moon fmt` reports no pending interface or formatting work, `moon check
  --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 10 warnings and 0 errors, and `git diff --check` passes.~~
- [x] ~~Add the next remaining format parity slice: optional
  `.repos/cpdf-source/hello.pdf` and `.repos/cpdf-source/logo.pdf` now gate
  top-level classic malformed recovery for damaged `xref` headers and damaged
  `trailer` keywords. The gate complements the existing top-level bad
  `startxref` and malformed classic xref-row coverage by requiring strict
  classic reads to reject each corruption, fallback reconstruction to reset
  `first_xref()` to `0`, page counts to survive, and compressed rewrite/reread
  to preserve the recovered documents. `moon check --target native
  fixture_acceptance --warn-list +73` passes, `moon test --target native
  fixture_acceptance --filter 'optional cpdf source top-level classic fixtures
  reconstruct damaged xref headers and trailers'` reports 1/1 test passing,
  `moon test --target native fixture_acceptance` reports 115/115 tests passing,
  `moon test --target native` reports 2287/2287 tests passing, `moon info &&
  moon fmt` reports no pending interface or formatting work, `moon check
  --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 10 warnings and 0 errors, and `git diff --check` passes.~~
- [x] ~~Add the next remaining format parity slice: optional
  `.repos/cpdf-source/manualimages/*.pdf` now gates image-package source-corpus
  recovery for damaged classic `xref` headers and damaged `trailer` keywords.
  The gate runs over every manual-image PDF in the source tree, requires strict
  classic reads to reject each corruption, reconstructs through the public
  malformed reader, verifies `first_xref()` resets to `0`, parses non-empty page
  content operators for the recovered document, and rechecks those content
  operators after compressed rewrite/reread. `moon check --target native
  image/fixture_acceptance --warn-list +73` passes, `moon test --target native
  image/fixture_acceptance --filter 'cpdf source manual image PDF corpus
  reconstructs damaged classic xref metadata'` reports 1/1 test passing, `moon
  test --target native image/fixture_acceptance` reports 17/17 tests passing,
  `moon test --target native` reports 2288/2288 tests passing, `moon info &&
  moon fmt` reports no pending interface or formatting work, `moon check
  --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 10 warnings and 0 errors, and `git diff --check` passes.~~
- [x] ~~Add the next remaining format parity slice: optional
  `.repos/cpdf-source/manualimages/*.pdf` now gates the Markdown/PDF-to-Markdown
  boundary for damaged classic `xref` headers and damaged `trailer` keywords.
  The gate runs over every manual-image PDF in the source tree, requires strict
  classic reads to reject each corruption, reconstructs through
  `pdf_bytes_to_markdown`, verifies reconstructed Markdown stays byte-for-byte
  equal to normal Markdown per fixture, keeps the existing clean-output checks
  for raw control bytes and replacement characters, and requires at least one
  textful source fixture. `moon check --target native
  markdown/fixture_acceptance --warn-list +73` passes, `moon test --target
  native markdown/fixture_acceptance --filter 'pdf_bytes_to_markdown
  reconstructs optional cpdf source manual image PDF corpus with damaged classic
  xref metadata'` reports 1/1 test passing, `moon test --target native
  markdown/fixture_acceptance` reports 16/16 tests passing, `moon test --target
  native` reports 2289/2289 tests passing, `moon info && moon fmt` reports no
  pending interface or formatting work, and `moon check --target all --warn-list
  +73` reports the known warning-73/main-package baseline with 10 warnings and
  0 errors.~~
- [x] ~~Add the next remaining format parity slice: optional
  `.repos/cpdf-source/manualimages/*.pdf` now gates image-package
  source-corpus recovery for malformed classic xref rows, complementing the
  existing bad-`startxref`, damaged-`xref`-header, and damaged-`trailer`
  coverage. The gate runs over every manual-image PDF in the source tree,
  corrupts the first in-use xref row marker, offset, and generation fields plus
  the first xref subsection object number and count, requires strict classic
  reads to reject each corruption, reconstructs through the public reader,
  verifies `first_xref()` resets to `0`, parses non-empty page content
  operators for the recovered image fixture, and rechecks those operators after
  compressed rewrite/reread. `moon check --target native
  image/fixture_acceptance --warn-list +73` passes, `moon test --target native
  image/fixture_acceptance --filter 'cpdf source manual image PDF corpus
  reconstructs malformed classic xref rows'` reports 1/1 test passing, `moon
  test --target native image/fixture_acceptance` reports 18/18 tests passing,
  `moon test --target native` reports 2290/2290 tests passing, `moon info &&
  moon fmt` reports no pending interface or formatting work, and `moon check
  --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next remaining format parity slice: optional
  `.repos/cpdf-source/manualimages/*.pdf` now gates the Markdown/PDF-to-Markdown
  boundary for malformed classic xref rows, complementing the existing
  bad-`startxref`, damaged-`xref`-header, and damaged-`trailer` Markdown
  coverage. The gate runs over every manual-image PDF in the source tree,
  corrupts the first in-use xref row marker, offset, and generation fields plus
  the first xref subsection object number and count, requires strict classic
  reads to reject each corruption, reconstructs through `pdf_bytes_to_markdown`,
  verifies reconstructed Markdown stays byte-for-byte equal to normal Markdown
  per fixture, keeps the existing clean-output checks for raw control bytes and
  replacement characters, and requires at least one textful source fixture.
  `moon check --target native markdown/fixture_acceptance --warn-list +73`
  passes, `moon test --target native markdown/fixture_acceptance --filter
  'pdf_bytes_to_markdown reconstructs optional cpdf source manual image PDF
  corpus with malformed classic xref rows'` reports 1/1 test passing, `moon
  test --target native markdown/fixture_acceptance` reports 17/17 tests
  passing, `moon test --target native` reports 2291/2291 tests passing, `moon
  info && moon fmt` reports no pending interface or formatting work, and `moon
  check --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next remaining format parity slice: optional
  `.repos/cpdf-source/hello.pdf` and `.repos/cpdf-source/logo.pdf` now gate the
  Markdown/PDF-to-Markdown boundary for the top-level classic source corpus.
  The gate covers clean extraction for textful `hello.pdf` and page-structure
  extraction for image-heavy `logo.pdf`, hardens the Markdown bad-`startxref`
  corruptor to accept PDF whitespace after the `startxref` keyword, corrupts
  bad `startxref`, damaged classic `xref` headers, damaged `trailer` keywords,
  first in-use xref row marker/offset/generation fields, and first xref
  subsection object/count fields, requires strict classic reads to reject each
  corruption, reconstructs through `pdf_bytes_to_markdown`, verifies
  reconstructed Markdown stays byte-for-byte equal to normal Markdown per
  fixture, keeps raw-control/replacement-character hygiene checks, and requires
  at least one textful source fixture. `moon check --target native
  markdown/fixture_acceptance --warn-list +73` passes, `moon test --target
  native markdown/fixture_acceptance --filter 'pdf_bytes_to_markdown extracts
  optional cpdf source top-level classic PDF corpus'` reports 1/1 test passing,
  `moon test --target native markdown/fixture_acceptance --filter
  'pdf_bytes_to_markdown reconstructs optional cpdf source top-level classic PDF
  corpus with malformed xref metadata and rows'` reports 1/1 test passing,
  `moon test --target native markdown/fixture_acceptance` reports 19/19 tests
  passing, `moon test --target native` reports 2293/2293 tests passing, `moon
  info && moon fmt` reports no pending interface or formatting work, and `moon
  check --target all --warn-list +73` reports the known
  warning-73/main-package baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next remaining format parity slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` now gates the Markdown/PDF-to-Markdown
  boundary for malformed xref-stream metadata. The gate corrupts the
  startxref-targeted xref stream's `/Type /XRef` entry and `stream` marker,
  requires strict classic reads to reject each corruption, reconstructs through
  `pdf_bytes_to_markdown`, verifies reconstructed Markdown stays byte-for-byte
  equal to the normal 175-page manual extraction, preserves key manual markers
  such as `Coherent PDF`, `Command Line Tools`, `Chapter 15: PDF and JSON`, and
  `Accessible PDFs with PDF/UA`, and keeps replacement-character hygiene at
  zero. `moon check --target native markdown/fixture_acceptance --warn-list
  +73` passes, `moon test --target native markdown/fixture_acceptance --filter
  'pdf_bytes_to_markdown reconstructs optional cpdf source manual fixture with
  malformed xref stream metadata'` reports 1/1 test passing, `moon test
  --target native markdown/fixture_acceptance` reports 20/20 tests passing,
  `moon test --target native` reports 2294/2294 tests passing, `moon info &&
  moon fmt` reports no pending interface or formatting work, and `moon check
  --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next remaining format parity slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` now gates the Markdown/PDF-to-Markdown
  boundary for malformed xref-stream terminators. The gate corrupts the
  startxref-targeted xref stream's `endstream` and `endobj` markers, requires
  strict classic reads to reject each corruption, reconstructs through
  `pdf_bytes_to_markdown`, verifies reconstructed Markdown stays byte-for-byte
  equal to the normal 175-page manual extraction, preserves key manual markers
  such as `Coherent PDF`, `Command Line Tools`, `Chapter 15: PDF and JSON`, and
  `Accessible PDFs with PDF/UA`, and keeps replacement-character hygiene at
  zero. `moon check --target native markdown/fixture_acceptance --warn-list
  +73` passes, `moon test --target native markdown/fixture_acceptance --filter
  'pdf_bytes_to_markdown reconstructs optional cpdf source manual fixture with
  malformed xref stream terminators'` reports 1/1 test passing, `moon test
  --target native markdown/fixture_acceptance` reports 21/21 tests passing,
  `moon test --target native` reports 2295/2295 tests passing, `moon info &&
  moon fmt` reports no pending interface or formatting work, and `moon check
  --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next remaining format parity slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` now gates the Markdown/PDF-to-Markdown
  boundary for malformed xref-stream dictionary entries. The gate corrupts the
  startxref-targeted xref stream's `/Root`, `/DecodeParms`, unsupported
  predictor, and `/Filter` entries, requires strict classic reads to reject
  each corruption, reconstructs through `pdf_bytes_to_markdown`, verifies
  reconstructed Markdown stays byte-for-byte equal to the normal 175-page
  manual extraction, preserves key manual markers such as `Coherent PDF`,
  `Command Line Tools`, `Chapter 15: PDF and JSON`, and `Accessible PDFs with
  PDF/UA`, and keeps replacement-character hygiene at zero. `moon check
  --target native markdown/fixture_acceptance --warn-list +73` passes, `moon
  test --target native markdown/fixture_acceptance --filter
  'pdf_bytes_to_markdown reconstructs optional cpdf source manual fixture with
  malformed xref stream dictionary entries'` reports 1/1 test passing, `moon
  test --target native markdown/fixture_acceptance` reports 22/22 tests
  passing, `moon test --target native` reports 2296/2296 tests passing, `moon
  info` and `moon fmt` report no pending interface or formatting work, and
  `moon check --target all --warn-list +73` reports the known
  warning-73/main-package baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next remaining format parity slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` now gates the Markdown/PDF-to-Markdown
  boundary for malformed object-stream entries. The gate corrupts the first
  `/ObjStm` stream's `/N`, `/First`, `/Filter`, `stream`, `endstream`, and
  `endobj` markers, requires strict classic reads to reject the reconstruction
  cases and strict repair to retain the full 175-page document for the
  `endstream` case, reconstructs or repairs through `pdf_bytes_to_markdown`,
  verifies Markdown stays byte-for-byte equal to the normal manual extraction,
  preserves key manual markers such as `Coherent PDF`, `Command Line Tools`,
  `Chapter 15: PDF and JSON`, and `Accessible PDFs with PDF/UA`, and keeps
  replacement-character hygiene at zero. `moon check --target native
  markdown/fixture_acceptance --warn-list +73` passes, `moon test --target
  native markdown/fixture_acceptance --filter 'pdf_bytes_to_markdown
  reconstructs optional cpdf source manual fixture with malformed object stream
  entries'` reports 1/1 test passing, `moon test --target native
  markdown/fixture_acceptance` reports 23/23 tests passing, `moon test --target
  native` reports 2297/2297 tests passing, `moon info` and `moon fmt` report
  no pending interface or formatting work, and `moon check --target all
  --warn-list +73` reports the known warning-73/main-package baseline with 10
  warnings and 0 errors.~~
- [x] ~~Add the next remaining format parity slice: optional
  `.repos/cpdf-source/cpdfmanual.pdf` now gates the Markdown/PDF-to-Markdown
  boundary for repairable malformed stream-length entries. The gate corrupts
  the startxref-targeted xref stream's `/Length 4551` and the first `/ObjStm`
  stream's `/Length 1526` entries to `/Length /Bad`, requires strict classic
  reads to repair each document while preserving the full 175-page manual,
  verifies `pdf_bytes_to_markdown` output stays byte-for-byte equal to the
  normal manual extraction, preserves key manual markers such as `Coherent
  PDF`, `Command Line Tools`, `Chapter 15: PDF and JSON`, and `Accessible PDFs
  with PDF/UA`, and keeps replacement-character hygiene at zero. `moon check
  --target native markdown/fixture_acceptance --warn-list +73` passes, `moon
  test --target native markdown/fixture_acceptance --filter
  'pdf_bytes_to_markdown repairs optional cpdf source manual fixture with
  malformed stream length entries'` reports 1/1 test passing, `moon test
  --target native markdown/fixture_acceptance` reports 24/24 tests passing,
  `moon test --target native` reports 2298/2298 tests passing, `moon info` and
  `moon fmt` report no pending interface or formatting work, and `moon check
  --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 10 warnings and 0 errors.~~
- [x] ~~Refresh portable backend validation after the latest optional
  `.repos/cpdf-source` Markdown recovery gates: `moon test --target wasm-gc`
  reports 2013/2013 tests passing, `moon test --target js` reports 2013/2013
  tests passing, and `moon check --target all --warn-list +73` reports the
  known warning-73/main-package baseline with 10 warnings and 0 errors. Full
  plain-Wasm package-level validation remains separately tracked because the
  largest regression executables still need to be split or reduced before they
  fit the runtime's maximum-function-size limit.~~
- [x] ~~Add the next source-corpus Markdown command recovery slice: the native
  `pdflite-markdown` command helper now converts an optional
  `.repos/cpdf-source/cpdfmanual.pdf` copy with a corrupted final `startxref`
  pointer through real file input/output, compares the recovered Markdown
  byte-for-byte with clean command output, preserves manual markers such as
  `Coherent PDF`, `Command Line Tools`, `Chapter 15: PDF and JSON`, and
  `Accessible PDFs with PDF/UA`, and verifies UTF-8 output without replacement
  characters. `moon check --target native markdown/cmd --warn-list +73` passes
  with the known main-package warning baseline, `moon test --target native
  markdown/cmd --filter 'markdown command reconstructs optional cpdf source
  manual fixture with bad startxref'` reports 1/1 test passing, `moon test
  --target native markdown/cmd` reports 12/12 tests passing, `moon test
  --target native` reports 2299/2299 tests passing, `moon info` and `moon fmt`
  report no pending interface or formatting work, and `moon check --target all
  --warn-list +73` reports the known warning-73/main-package baseline with 10
  warnings and 0 errors.~~
- [x] ~~Add the next source-corpus Markdown command recovery slice: the native
  `pdflite-markdown` command helper now converts optional
  `.repos/cpdf-source/cpdfmanual.pdf` copies with malformed xref-stream
  metadata through real file input/output. The gate corrupts the
  startxref-targeted xref stream's `/Type /XRef` entry and `stream` marker,
  compares each recovered Markdown output byte-for-byte with clean command
  output, preserves manual markers such as `Coherent PDF`, `Command Line
  Tools`, `Chapter 15: PDF and JSON`, and `Accessible PDFs with PDF/UA`, and
  verifies UTF-8 output without replacement characters. `moon check --target
  native markdown/cmd --warn-list +73` passes with the known main-package
  warning baseline, `moon test --target native markdown/cmd --filter
  'markdown command reconstructs optional cpdf source manual fixture with
  malformed xref stream metadata'` reports 1/1 test passing, `moon test
  --target native markdown/cmd` reports 13/13 tests passing, `moon test
  --target native` reports 2300/2300 tests passing, `moon info` and `moon
  fmt` report no pending interface or formatting work, and `moon check
  --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-corpus Markdown command recovery slice: the native
  `pdflite-markdown` command helper now converts optional
  `.repos/cpdf-source/cpdfmanual.pdf` copies with malformed xref-stream
  terminators through real file input/output. The gate corrupts the
  startxref-targeted xref stream's physical `endstream` and `endobj` markers,
  compares each recovered Markdown output byte-for-byte with clean command
  output, preserves manual markers such as `Coherent PDF`, `Command Line
  Tools`, `Chapter 15: PDF and JSON`, and `Accessible PDFs with PDF/UA`, and
  verifies UTF-8 output without replacement characters. `moon check --target
  native markdown/cmd --warn-list +73` passes with the known main-package
  warning baseline, `moon test --target native markdown/cmd --filter
  'markdown command reconstructs optional cpdf source manual fixture with
  malformed xref stream terminators'` reports 1/1 test passing, `moon test
  --target native markdown/cmd` reports 14/14 tests passing, and `moon test
  --target native` reports 2301/2301 tests passing. `moon info` and `moon
  fmt` report no pending interface or formatting work, and `moon check
  --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-corpus Markdown command recovery slice: the native
  `pdflite-markdown` command helper now converts optional
  `.repos/cpdf-source/cpdfmanual.pdf` copies with malformed xref-stream
  dictionary entries through real file input/output. The gate corrupts the
  startxref-targeted xref stream's `/Root`, `/DecodeParms`, unsupported
  predictor, and `/Filter` entries, compares each recovered Markdown output
  byte-for-byte with clean command output, preserves manual markers such as
  `Coherent PDF`, `Command Line Tools`, `Chapter 15: PDF and JSON`, and
  `Accessible PDFs with PDF/UA`, and verifies UTF-8 output without replacement
  characters. `moon check --target native markdown/cmd --warn-list +73` passes
  with the known main-package warning baseline, `moon test --target native
  markdown/cmd --filter 'markdown command reconstructs optional cpdf source
  manual fixture with malformed xref stream dictionary entries'` reports 1/1
  test passing, `moon test --target native markdown/cmd` reports 15/15 tests
  passing, and `moon test --target native` reports 2302/2302 tests passing.
  `moon info` and `moon fmt` report no pending interface or formatting work,
  and `moon check --target all --warn-list +73` reports the known
  warning-73/main-package baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-corpus Markdown command recovery slice: the native
  `pdflite-markdown` command helper now converts optional
  `.repos/cpdf-source/cpdfmanual.pdf` copies with malformed first
  object-stream entries through real file input/output. The gate corrupts the
  first `/ObjStm` stream's `/N`, `/First`, `/Filter`, `stream`, `endstream`,
  and `endobj` markers, compares each recovered Markdown output byte-for-byte
  with clean command output, preserves manual markers such as `Coherent PDF`,
  `Command Line Tools`, `Chapter 15: PDF and JSON`, and `Accessible PDFs with
  PDF/UA`, and verifies UTF-8 output without replacement characters. `moon
  check --target native markdown/cmd --warn-list +73` passes with the known
  main-package warning baseline, `moon test --target native markdown/cmd
  --filter 'markdown command reconstructs optional cpdf source manual fixture
  with malformed object stream entries'` reports 1/1 test passing, `moon test
  --target native markdown/cmd` reports 16/16 tests passing, and `moon test
  --target native` reports 2303/2303 tests passing. `moon info` and `moon
  fmt` report no pending interface or formatting work, and `moon check
  --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-corpus Markdown command recovery slice: the native
  `pdflite-markdown` command helper now converts optional
  `.repos/cpdf-source/cpdfmanual.pdf` copies with repairable malformed stream
  length entries through real file input/output. The gate corrupts the
  startxref-targeted xref stream's `/Length 4551` entry and the first
  `/ObjStm` stream's `/Length 1526` entry to `/Length /Bad`, compares each
  repaired Markdown output byte-for-byte with clean command output, preserves
  manual markers such as `Coherent PDF`, `Command Line Tools`, `Chapter 15:
  PDF and JSON`, and `Accessible PDFs with PDF/UA`, and verifies UTF-8 output
  without replacement characters. `moon check --target native markdown/cmd
  --warn-list +73` passes with the known main-package warning baseline, `moon
  test --target native markdown/cmd --filter 'markdown command repairs
  optional cpdf source manual fixture with malformed stream length entries'`
  reports 1/1 test passing, `moon test --target native markdown/cmd` reports
  17/17 tests passing, and `moon test --target native` reports 2304/2304 tests
  passing. `moon info` and `moon fmt` report no pending interface or
  formatting work, and `moon check --target all --warn-list +73` reports the
  known warning-73/main-package baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-corpus Markdown command recovery slice: the native
  `pdflite-markdown` command helper now converts optional
  `.repos/cpdf-source/hello.pdf` and `.repos/cpdf-source/logo.pdf` through real
  file input/output, checking textful `hello.pdf` extraction and image-heavy
  `logo.pdf` page-structure extraction without raw control or replacement
  characters. The command gate now also writes corrupted copies with bad final
  `startxref`, damaged classic `xref` headers, damaged `trailer` keywords,
  first in-use xref row marker/offset/generation fields, and first subsection
  object/count fields, requires strict classic reads to reject each corruption,
  converts the damaged files through the command helper, and compares each
  recovered Markdown output byte-for-byte with clean command output. `moon
  check --target native markdown/cmd --warn-list +73` passes with the known
  main-package warning baseline, focused command tests for clean and malformed
  top-level classic PDF corpus conversion each report 1/1 test passing, `moon
  test --target native markdown/cmd` reports 19/19 tests passing, and `moon
  test --target native` reports 2306/2306 tests passing. `moon info && moon
  fmt` reports no pending interface or formatting work, and `moon check
  --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-corpus Markdown command recovery slice: the native
  `pdflite-markdown` command helper now reconstructs the optional
  `.repos/cpdf-source/manualimages/*.pdf` corpus through real file
  input/output when classic xref data is malformed. The command gate writes
  corrupted copies for all 21 one-page manual-image PDFs when present, covering
  bad final `startxref`, damaged classic `xref` headers, damaged `trailer`
  keywords, first in-use xref row marker/offset/generation fields, and first
  subsection object/count fields, requires strict classic reads to reject each
  corruption, compares recovered Markdown byte-for-byte with clean command
  output, and keeps page-marker/raw-control/replacement-character hygiene
  checks. `moon check --target native markdown/cmd --warn-list +73` passes
  with the known main-package warning baseline, the focused command recovery
  test reports 1/1 test passing, `moon test --target native markdown/cmd`
  reports 20/20 tests passing, and `moon test --target native` reports
  2307/2307 tests passing. `moon info && moon fmt` reports no pending
  interface or formatting work, and `moon check --target all --warn-list +73`
  reports the known warning-73/main-package baseline with 10 warnings and 0
  errors.~~
- [x] ~~Add the next source-corpus draw/parser recovery slice: optional
  `.repos/cpdf-source/manualimages/*.pdf` now gates cpdfdraw/content-operator
  parsing after malformed-reader reconstruction. The draw fixture corrupts all
  21 one-page manual-image PDFs when present with bad final `startxref`,
  damaged classic `xref` headers, damaged `trailer` keywords, first in-use xref
  row marker/offset/generation fields, and first subsection object/count
  fields, requires strict classic reads to reject each corruption, verifies
  public reconstruction resets `first_xref()` to `0`, parses non-empty page
  content operators with no unknown operators, and rechecks the same draw
  parsing after compressed-xref rewrite/reread. `moon check --target native
  draw/fixture_acceptance --warn-list +73` passes, the focused draw recovery
  test reports 1/1 test passing, `moon test --target native
  draw/fixture_acceptance` reports 12/12 tests passing, and `moon test
  --target native` reports 2308/2308 tests passing. `moon info && moon fmt`
  reports no pending interface or formatting work, and `moon check --target all
  --warn-list +73` reports the known warning-73/main-package baseline with 10
  warnings and 0 errors.~~
- [x] ~~Refresh portable backend validation after the latest source-corpus
  draw/parser recovery gate: `moon test --target wasm-gc` reports 2013/2013
  tests passing, `moon test --target js` reports 2013/2013 tests passing, and
  `moon check --target all --warn-list +73` reports the known
  warning-73/main-package baseline with 10 warnings and 0 errors. Full
  plain-Wasm `moon test --target wasm` remains explicitly not claimed; the
  current run still fails when instantiating
  `_build/wasm/debug/test/markdown/markdown.blackbox_test.wasm` because the
  generated module exceeds the runtime maximum function-size limit.~~
- [x] ~~Add the next source-corpus font recovery slice: the native
  `font/fixture_acceptance` package now gates optional
  `.repos/cpdf-source/manualimages/fonts.pdf` through font-list, font-table,
  JSON, font lookup, and missing-font reporting before and after compressed
  rewrite/reread. The same package now also corrupts that real source fixture
  with a bad final `startxref`, damaged classic `xref` header, damaged
  `trailer` keyword, first in-use xref row marker/offset/generation fields,
  and first subsection object/count fields, requires strict classic reading to
  reject each damaged file, and verifies public reconstruction preserves the
  same font behavior through compressed rewrite/reread. `moon check --target
  native font/fixture_acceptance --warn-list +73` passes, the focused cpdf
  source font tests report 2/2 tests passing, `moon test --target native
  font/fixture_acceptance` reports 7/7 tests passing, and `moon test --target
  native` reports 2310/2310 tests passing. `moon info && moon fmt` reports no
  pending interface or formatting work, and `moon check --target all
  --warn-list +73` reports the known warning-73/main-package baseline with 10
  warnings and 0 errors.~~
- [x] ~~Add the next source-corpus font recovery slice: the native
  `font/fixture_acceptance` package now also gates optional
  `.repos/cpdf-source/cpdfmanual.pdf` embedded-font reporting across the real
  175-page source manual. The gate verifies cpdf-style font listing, embedded
  Type1 fontfile extraction for representative Nimbus/Palladio/Monospace fonts,
  Helvetica's unembedded standard-font boundary and Unicode font table,
  font-JSON reporting, empty missing-font reporting, compressed rewrite/reread,
  and bad-final-`startxref` reconstruction for the xref-stream-backed source
  manual. `moon check --target native font/fixture_acceptance --warn-list +73`
  passes, focused cpdf source manual font tests report 3/3 tests passing,
  `moon test --target native font/fixture_acceptance` reports 8/8 tests
  passing, and `moon test --target native` reports 2311/2311 tests passing.
  `moon info && moon fmt` reports no pending interface or formatting work, and
  `moon check --target all --warn-list +73` reports the known
  warning-73/main-package baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-corpus font mutation slice: the native
  `font/fixture_acceptance` package now gates cpdf-style embedded-font removal
  and font copying across optional `.repos/cpdf-source/cpdfmanual.pdf` and
  `.repos/cpdf-source/hello.pdf`. The gate checks both method and wrapper
  surfaces (`remove_embedded_fonts`/`pdf_remove_fonts` and
  `copy_font_from`/`pdf_copy_font`), verifies representative removed manual
  fonts become missing while font-list/JSON/text reporting remains stable,
  verifies copied `NimbusSanL-Bold` on the real Hello source page preserves
  text extraction and embedded fontfile extraction, and repeats the assertions
  after compressed rewrite/reread plus bad-final-`startxref` reconstruction.
  `moon check --target native font/fixture_acceptance --warn-list +73` passes,
  the focused source font mutation test reports 1/1 test passing, `moon test
  --target native font/fixture_acceptance` reports 9/9 tests passing, and
  `moon test --target native` reports 2312/2312 tests passing. `moon info &&
  moon fmt` reports no pending interface or formatting work, and `moon check
  --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-corpus image reporting slice: the native
  `image/fixture_acceptance` package now gates optional
  `.repos/cpdf-source/cpdfmanual.pdf` through cpdf-style image JSON rows,
  JSON/UTF-8 byte wrappers, image-resolution tuples and JSON/blob wrappers,
  direct `get_image_24bpp` extraction for the real FlateDecode/DeviceRGB
  `400x294` manual image object, compressed rewrite/reread, and
  bad-final-`startxref` reconstruction for the xref-stream-backed source
  manual. The image fixture `startxref` corruptor now also tolerates ordinary
  PDF whitespace after the keyword. `moon check --target native
  image/fixture_acceptance --warn-list +73` passes, the focused cpdf source
  manual image reporting test reports 1/1 test passing, `moon test --target
  native image/fixture_acceptance` reports 19/19 tests passing, and `moon test
  --target native` reports 2313/2313 tests passing. `moon info && moon fmt`
  reports no pending interface or formatting work, and `moon check --target all
  --warn-list +73` reports the known warning-73/main-package baseline with 10
  warnings and 0 errors.~~
- [x] ~~Add the next source-corpus image reporting slice: the native
  `image/fixture_acceptance` package now gates optional
  `.repos/cpdf-source/hello.pdf` through cpdf-style inline-image reporting.
  The gate starts from the real source hello fixture, verifies it has no image
  rows before injection, appends a `3x2` `/DeviceRGB` inline image, checks
  `images_json`/blob wrappers and `image_resolution`/JSON/blob wrappers with
  `inline=true`, preserves Hello text extraction, and repeats the checks after
  compressed rewrite/reread plus bad-final-`startxref` reconstruction. `moon
  check --target native image/fixture_acceptance --warn-list +73` passes, the
  focused cpdf source hello inline-image test reports 1/1 test passing, `moon
  test --target native image/fixture_acceptance` reports 20/20 tests passing,
  and `moon test --target native` reports 2314/2314 tests passing. `moon info
  && moon fmt` reports no pending interface or formatting work, and `moon check
  --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 7 warnings and 0 errors.~~
- [x] ~~Add the next source-corpus recursive image reporting slice: the native
  `image/fixture_acceptance` package now gates optional
  `.repos/cpdf-source/hello.pdf` through cpdf-style nested Form XObject image
  reporting. The gate starts from the real source hello fixture, verifies it
  has no image rows before injection, injects a Form XObject that owns a
  `/SourceNestedImage` FlateDecode `/DeviceGray` Image XObject, checks
  `images_json`/blob wrappers, `image_resolution`/JSON/blob wrappers, recursive
  Form content/resource parsing, and direct `get_image_24bpp` extraction, then
  repeats the checks after compressed rewrite/reread plus
  bad-final-`startxref` reconstruction. `moon check --target native
  image/fixture_acceptance --warn-list +73` passes, the focused cpdf source
  hello nested-form-image test reports 1/1 test passing, `moon test --target
  native image/fixture_acceptance` reports 21/21 tests passing, and `moon test
  --target native` reports 2315/2315 tests passing. `moon info && moon fmt`
  reports no pending interface or formatting work, and `moon check --target all
  --warn-list +73` reports the known warning-73/main-package baseline with 7
  warnings and 0 errors.~~
- [x] ~~Add the next source-corpus image draft slice: the native
  `image/fixture_acceptance` package now gates optional
  `.repos/cpdf-source/manualimages/png.pdf` through cpdf-style replacement-box
  draft behavior. The gate verifies the real source PNG fixture decodes as a
  `400x294` RGB24 image before drafting, runs `pdf_draft(None, true, [1],
  document)`, checks that the `/I1` image XObject draw is removed, the drafted
  page resource `/XObject` dictionary is emptied, the replacement unit-box
  cross operator sequence is present, and image JSON no longer reports image
  names or widths, then repeats those assertions after compressed rewrite/reread
  plus bad-final-`startxref` reconstruction. `moon check --target native
  image/fixture_acceptance --warn-list +73` passes, the focused cpdf source PNG
  draft test reports 1/1 test passing, `moon test --target native
  image/fixture_acceptance` reports 22/22 tests passing, and `moon test --target
  native` reports 2316/2316 tests passing. `moon info && moon fmt` reports no
  pending interface or formatting work, and `moon check --target all --warn-list
  +73` reports the known warning-73/main-package baseline with 7 warnings and 0
  errors.~~
- [x] ~~Add the next source-corpus content JSON slice: the native
  `draw/fixture_acceptance` package now gates optional
  `.repos/cpdf-source/manualimages/text.pdf` and
  `.repos/cpdf-source/manualimages/xobj.pdf` through cpdfcontent-style content
  entry and JSON reporting. The gate verifies glyph extraction and text JSON
  markers for the text fixture, path/bounding-box JSON markers for the Form
  XObject fixture, checks both method and wrapper surfaces
  (`content_json_of_page`/`pdf_content_json_of_page` and
  `page_content_json`/`pdf_page_content_json`), and repeats the assertions after
  compressed rewrite/reread. `moon check --target native
  draw/fixture_acceptance --warn-list +73` passes, the focused cpdf source
  content JSON test reports 1/1 test passing, `moon test --target native
  draw/fixture_acceptance` reports 13/13 tests passing, and `moon test --target
  native` reports 2317/2317 tests passing. `moon info && moon fmt` reports no
  pending interface or formatting work, and `moon check --target all --warn-list
  +73` reports the known warning-73/main-package baseline with 7 warnings and 0
  errors.~~
- [x] ~~Add the next source-corpus cpdfsqueeze slice: the native
  `draw/fixture_acceptance` package now gates optional
  `.repos/cpdf-source/manualimages/text.pdf` and
  `.repos/cpdf-source/manualimages/xobj.pdf` through stream transcode and
  squeeze workflows. The gate checks both function and method surfaces
  (`decompress_pdf`/`PdfDocument::decompress`, `recompress_pdf`/
  `PdfDocument::recompress`, and `squeeze`/`PdfDocument::squeeze`), verifies
  decompression removes stream filters while preserving stream counts,
  recompression preserves stream counts and does not increase filtered-stream
  coverage, keeps text/path content JSON assertions valid after each stage, and
  repeats squeezed-document assertions after compressed rewrite/reread plus
  bad-final-`startxref` reconstruction. `moon check --target native
  draw/fixture_acceptance --warn-list +73` passes, the focused cpdf source
  squeeze test reports 1/1 test passing, `moon test --target native
  draw/fixture_acceptance` reports 14/14 tests passing, and `moon test --target
  native` reports 2318/2318 tests passing. `moon info && moon fmt` reports no
  pending interface or formatting work, and `moon check --target all --warn-list
  +73` reports the known warning-73/main-package baseline with 7 warnings and 0
  errors.~~
- [x] ~~Add the next source-corpus bounding-box overlay slice: the native
  `draw/fixture_acceptance` package now gates optional
  `.repos/cpdf-source/manualimages/text.pdf` and
  `.repos/cpdf-source/manualimages/xobj.pdf` through cpdf-style content-object
  bounding-box overlays. The gate checks both method and wrapper surfaces
  (`PdfDocument::show_bounding_boxes` and `pdf_show_bounding_boxes`), verifies
  page shape/resource preservation, content-entry growth, content-operator
  growth, added stroke/save operators, and path/bbox content JSON markers, then
  repeats text/path assertions after compressed rewrite/reread plus
  bad-final-`startxref` reconstruction. `moon check --target native
  draw/fixture_acceptance --warn-list +73` passes, the focused cpdf source
  bounding-box test reports 1/1 test passing, `moon test --target native
  draw/fixture_acceptance` reports 15/15 tests passing, and `moon test --target
  native` reports 2319/2319 tests passing. `moon info && moon fmt` reports no
  pending interface or formatting work, and `moon check --target all --warn-list
  +73` reports the known warning-73/main-package baseline with 10 warnings and
  0 errors.~~
- [x] ~~Add the next source-corpus structure-tree slice: the native
  `draw/fixture_acceptance` package now gates optional
  `.repos/cpdf-source/manualimages/h1.pdf` through cpdf-style PDF/UA
  structure-tree reporting. The gate verifies PDF 2.0/catalog/mark-info
  metadata, info JSON markers, `struct_tree_text`, `extract_struct_tree`,
  `struct_tree_json_blob`, and wrapper surfaces
  (`pdf_ua_print_struct_tree`, `pdf_ua_extract_struct_tree`,
  `pdf_ua_extract_struct_tree_json_blob`, and `pdf_ua_replace_struct_tree`),
  then repeats the structure-tree assertions after compressed rewrite/reread
  and bad-final-`startxref` reconstruction. `moon check --target native
  draw/fixture_acceptance --warn-list +73` passes, the focused cpdf source H1
  structure-tree test reports 1/1 test passing, `moon test --target native
  draw/fixture_acceptance` reports 16/16 tests passing, and `moon test --target
  native` reports 2320/2320 tests passing. `moon info && moon fmt` reports no
  pending interface or formatting work, and `moon check --target all --warn-list
  +73` reports the known warning-73/main-package baseline with 10 warnings and
  0 errors.~~
- [x] ~~Add the next source-corpus manual-image content/text slice: the native
  `draw/fixture_acceptance` package now gates the optional
  `.repos/cpdf-source/manualimages/*.pdf` corpus through cpdfcontent-style
  content-entry traversal and exact text extraction. The content-entry gate
  verifies all 21 manual-image PDFs, wrapper parity for
  `pdf_content_entries_of_page`, `pdf_content_json_of_page`, and
  `pdf_page_content_json`, per-fixture glyph/image/path counts, compressed
  rewrite/reread count stability, and aggregate source-corpus totals of 476
  glyphs, 1 image, and 18 paths. The text gate verifies the nine text-bearing
  fixtures against cpdf source expected strings, wrapper parity for
  `pdf_test_extract_text`, and zero raw-control/replacement characters after
  original reads, compressed rewrite/reread, and bad-final-`startxref`
  reconstruction. `moon check --target native draw/fixture_acceptance
  --warn-list +73` passes, both focused cpdf source manual-image corpus tests
  report 1/1 test passing, `moon test --target native draw/fixture_acceptance`
  reports 18/18 tests passing, and `moon test --target native` reports
  2322/2322 tests passing. `moon info && moon fmt` reports no pending interface
  or formatting work, and `moon check --target all --warn-list +73` reports the
  known warning-73/main-package baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-corpus page-spec/page-label slice: the new native
  `page/fixture_acceptance` package now gates optional
  `.repos/cpdf-source/cpdfmanual.pdf` through cpdf-style page selection and
  page-label reporting. The page-spec gate verifies all-page parsing, explicit
  ranges, reverse/end/not/duplicate selectors, odd/even selectors,
  portrait/landscape filters, annotated-page bounds, `string_of_pagespec`, and
  wrapper parity for `pdf_parse_pagespec` and `pdf_string_of_pagespec` after
  compressed rewrite/reread. The page-label gate verifies the manual's roman
  front-matter and decimal body labels, `read_page_labels` wrapper parity,
  page-info JSON/text labels, add-text label/replacement wrappers, formatted
  `%Label`/`%EndLabel` output, compressed rewrite/reread, and
  bad-final-`startxref` reconstruction. `moon check --target native
  page/fixture_acceptance --warn-list +73` passes, both focused cpdf source
  manual page tests report 1/1 test passing, `moon test --target native
  page/fixture_acceptance` reports 2/2 tests passing, and `moon test --target
  native` reports 2324/2324 tests passing. `moon info && moon fmt` reports no
  pending interface or formatting work, and `moon check --target all --warn-list
  +73` reports the known warning-73/main-package baseline with 10 warnings and
  0 errors.~~
- [x] ~~Add the next source-corpus manual text-extraction slice: the new native
  `text/fixture_acceptance` package now gates optional
  `.repos/cpdf-source/cpdfmanual.pdf` through cpdf-style selected-page text
  extraction and page content reporting. The gate verifies selected pages
  `[1, 2, 19, 31, 33]`, wrapper parity for `pdf_test_extract_text`,
  `pdf_content_entries_of_page`, and `pdf_page_content_json`, manual text
  markers including the Coherent Graphics copyright line and table-of-contents
  headings, glyph-level extracted text on page 2, zero replacement characters
  and raw controls, compressed rewrite/reread, and bad-final-`startxref`
  reconstruction. `moon check --target native text/fixture_acceptance
  --warn-list +73` passes, the focused cpdf source manual text test reports 1/1
  test passing, `moon test --target native text/fixture_acceptance` reports 1/1
  test passing, and `moon test --target native` reports 2325/2325 tests
  passing. `moon info && moon fmt` reports no pending interface or formatting
  work, and `moon check --target all --warn-list +73` reports the known
  warning-73/main-package baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-corpus metadata/composition slice: the new native
  `metadata/fixture_acceptance` package now gates optional
  `.repos/cpdf-source/cpdfmanual.pdf` through cpdf-style info, XMP, page-info,
  and composition reporting plus metadata mutation/removal. The reporting gate
  verifies the manual's PDF 1.7 page count, creator/producer fields, empty XMP
  subformat/language output, page-info JSON/text for pages 1 and 175,
  composition buckets and byte counts, compressed rewrite/reread, and wrapper
  parity for `pdf_output_info_json_blob`, `pdf_output_xmp_info_json_blob`,
  `pdf_page_info_json`, `pdf_output_page_info_text`, `pdf_composition`, and
  `pdf_show_composition_json_blob`. The mutation gate creates XMP metadata,
  sets language plus `/Title` and `/Author` through wrapper APIs, verifies
  PDFDoc/XMP escaping and preserved source creator/producer fields, repeats
  after compressed rewrite/reread and bad-final-`startxref` reconstruction, then
  removes all metadata while preserving language reporting. `moon check --target
  native metadata/fixture_acceptance --warn-list +73` passes, both focused cpdf
  source metadata tests report 1/1 test passing, `moon test --target native
  metadata/fixture_acceptance` reports 2/2 tests passing, and `moon test
  --target native` reports 2327/2327 tests passing. `moon info && moon fmt`
  reports no pending interface or formatting work, and `moon check --target all
  --warn-list +73` reports the known warning-73/main-package baseline with 10
  warnings and 0 errors.~~
- [x] ~~Add the next source-corpus annotation JSON slice: the new native
  `annotation/fixture_acceptance` package now gates optional
  `.repos/cpdf-source/cpdfmanual.pdf` through cpdf-style annotation JSON export
  on the first annotated manual page. The gate verifies annotated page-spec
  discovery, `/CPDFJSONannotformatversion`, `/Subtype`, `/Link`, `/Rect`, and
  `/A` JSON markers, method/blob/wrapper parity for `annotations_json`,
  `annotations_json_blob`, and `pdf_get_annotations_json`, compressed
  rewrite/reread, strict-reader rejection of a bad final `startxref`, malformed
  reconstruction with `first_xref() == 0`, and recovered compressed
  rewrite/reread. `moon check --target native annotation/fixture_acceptance
  --warn-list +73` passes, the focused cpdf source annotation test reports 1/1
  test passing, `moon test --target native annotation/fixture_acceptance`
  reports 1/1 test passing, and `moon test --target native` reports 2328/2328
  tests passing. `moon info && moon fmt` reports no pending interface or
  formatting work, and `moon check --target all --warn-list +73` reports the
  known warning-73/main-package baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-corpus bookmark slice: the new native
  `bookmark/fixture_acceptance` package now gates optional
  `.repos/cpdf-source/cpdfmanual.pdf` through cpdf-style bookmark listing,
  JSON export, remove-and-rebuild, open-state mutation, and generated title
  bookmark insertion. The listing/rebuild gate verifies the 163-entry manual
  outline tree, top-level target pages, JSON/listed chapter markers, wrapper
  parity for `pdf_read_bookmarks`, `pdf_get_bookmarks_json`,
  `pdf_list_bookmarks`, `pdf_remove_bookmarks`, and `pdf_add_bookmarks`, and
  compressed rewrite/reread. The mutation gate verifies
  `bookmarks_open_to_level` plus `pdf_bookmarks_open_to_level`, generated
  `/tmp/cpdfmanual.pdf` title bookmarks plus `pdf_add_bookmark_title`,
  `pdf_pagenumber_of_target` parity, compressed rewrite/reread, and
  bad-final-`startxref` reconstruction for both mutated documents. `moon check
  --target native bookmark/fixture_acceptance --warn-list +73` passes, both
  focused cpdf source bookmark tests report 1/1 test passing, `moon test
  --target native bookmark/fixture_acceptance` reports 2/2 tests passing, and
  `moon test --target native` reports 2330/2330 tests passing. `moon info &&
  moon fmt` reports no pending interface or formatting work, and `moon check
  --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-corpus table-of-contents slice: the new native
  `toc/fixture_acceptance` package now gates optional
  `.repos/cpdf-source/cpdfmanual.pdf` through cpdftoc-style codepoint scanning,
  table-of-contents type-element construction, and generated title bookmark
  insertion. The gate verifies the 175-page manual, its 163-entry source
  outline tree, selected chapter bookmarks, required dot/title/page-number
  codepoints, title/body/page-label text runs, destination names, generated
  `Contents\nGenerated` bookmark text, target-page preservation, wrapper parity
  for `pdf_read_bookmarks`, `pdf_toc_used_codepoints`,
  `pdf_toc_type_elements`, `pdf_toc_add_bookmark`, and
  `pdf_pagenumber_of_target`, plus compressed rewrite/reread and
  bad-final-`startxref` reconstruction for the generated bookmark document.
  `moon check --target native toc/fixture_acceptance --warn-list +73` passes,
  the focused cpdf source TOC test reports 1/1 test passing, `moon test
  --target native toc/fixture_acceptance` reports 1/1 test passing, and `moon
  test --target native` reports 2331/2331 tests passing. `moon info && moon
  fmt` reports no pending interface or formatting work, and `moon check
  --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-corpus ToUnicode/CMap slice: the native
  `text/fixture_acceptance` package now also gates optional
  `.repos/cpdf-source/hello.pdf` through a cpdf-style `/ToUnicode` `UseCMap`
  chain. The gate synthesizes a three-stream grandbase/base/child CMap chain,
  mixes uncompressed and Flate-compressed CMap streams, attaches it to a
  source-page Type1 font, appends source content using that font, and verifies
  extracted text, content operators, font listing, descriptor ToUnicode maps,
  `parse_cmap` plus `pdf_parse_cmap` wrapper parity, text-extractor reverse
  lookup behavior, `font_table` plus `pdf_font_table` wrapper parity,
  compressed rewrite/reread, strict-reader rejection of a bad final
  `startxref`, and malformed reconstruction with `first_xref() == 0`. `moon
  check --target native text/fixture_acceptance --warn-list +73` passes, the
  focused cpdf source CMap test reports 1/1 test passing, `moon test --target
  native text/fixture_acceptance` reports 2/2 tests passing, and `moon test
  --target native` reports 2332/2332 tests passing. `moon info && moon fmt`
  reports no pending interface or formatting work, and `moon check --target all
  --warn-list +73` reports the known warning-73/main-package baseline with 10
  warnings and 0 errors.~~
- [x] ~~Add the next source-corpus ToUnicode/CMap variation slice: the native
  `text/fixture_acceptance` package now also gates optional
  `.repos/cpdf-source/hello.pdf` through a cpdf-style `/ToUnicode` `UseCMap`
  variation chain. The gate synthesizes inherited grandbase/base/child CMap
  streams with child overrides, supplementary-plane text, multi-codepoint
  values, inherited Omega/Z mappings, and mixed uncompressed plus
  Flate-compressed CMap streams, then attaches the chain to a source-page Type1
  font. It verifies extracted text, content operators, font listing,
  descriptor ToUnicode maps, `parse_cmap` plus `pdf_parse_cmap` wrapper parity,
  text-extractor reverse lookup behavior including intentionally unmapped
  inherited values, `font_table` plus `pdf_font_table` wrapper parity,
  compressed rewrite/reread, strict-reader rejection of a bad final
  `startxref`, and malformed reconstruction with `first_xref() == 0`. `moon
  check --target native text/fixture_acceptance --warn-list +73` passes, the
  focused cpdf source CMap variation test reports 1/1 test passing, `moon test
  --target native text/fixture_acceptance` reports 3/3 tests passing, and
  `moon test --target native` reports 2333/2333 tests passing. `moon info &&
  moon fmt` reports no pending interface or formatting work, and `moon check
  --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-corpus ToUnicode parser-corner slice: the native
  `text/fixture_acceptance` package now also gates optional
  `.repos/cpdf-source/hello.pdf` through a cpdf-style parser-corner
  `/ToUnicode` CMap. The gate exercises comment handling, `/WMode` parsing
  with a commented conflicting value, odd-nibble hex padding, split
  `beginbfchar` pairs, inline `beginbfchar`, bfrange array comments,
  multi-codepoint values, supplementary-plane values, and Flate-compressed
  CMap streams attached to a source-page Type1 font. It verifies extracted
  text, content operators, font listing, descriptor ToUnicode maps,
  `parse_cmap`, `pdf_parse_cmap`, and `pdf_parse_cmap_data` parity,
  text-extractor reverse lookup behavior, `font_table` plus `pdf_font_table`
  wrapper parity, compressed rewrite/reread, strict-reader rejection of a bad
  final `startxref`, and malformed reconstruction with `first_xref() == 0`.
  `moon check --target native text/fixture_acceptance --warn-list +73` passes,
  the focused cpdf source parser-corner test reports 1/1 test passing, `moon
  test --target native text/fixture_acceptance` reports 4/4 tests passing, and
  `moon test --target native` reports 2334/2334 tests passing. `moon info &&
  moon fmt` reports no pending interface or formatting work, and `moon check
  --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-corpus add-text slice: the native
  `fixture_acceptance` package now also gates optional
  `.repos/cpdf-source/cpdfmanual.pdf` through the cpdf-style source-level
  add-text path. The gate stamps real manual pages `1`, `19`, and `175` with
  expanded `%filename`, `%Page`, `%EndPage`, `%Label`, `%EndLabel`, and
  zero-padded `%Bates` values, uses a Standard 14 Helvetica font source, emits
  `/CPDFSTAMP` outline text with opacity resources, creates URL annotations
  from `%URL[...]` markup, verifies extracted stamp text has no replacement
  characters, and checks compressed rewrite/reread plus bad-final-`startxref`
  reconstruction with `first_xref() == 0`. `moon check --target native
  fixture_acceptance --warn-list +73` passes, the focused cpdf source add-text
  test reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 116/116 tests passing, and `moon test --target
  native` reports 2335/2335 tests passing. `moon info && moon fmt` reports no
  pending interface or formatting work, and `moon check --target all
  --warn-list +73` reports the known warning-73/main-package baseline with 7
  warnings and 0 errors.~~
- [x] ~~Add the next source-corpus `Pdfpage.pdf_of_pages` slice: the native
  `fixture_acceptance` package now also gates optional
  `.repos/cpdf-source/cpdfmanual.pdf` through retained page extraction in
  source order `[33, 19, 1, 175]`. The gate verifies that the non-retained path
  drops page labels, while the retained/process-structure path preserves source
  labels `15`, `1`, `i`, and `157`, keeps and retargets real manual bookmarks
  such as `1 Basic Usage` and `2.4 Splitting on Bookmarks`, retains ancestor
  bookmark context, preserves selected text extraction without replacement or
  raw-control leakage, and survives compressed rewrite/reread plus bad-final-
  `startxref` reconstruction with `first_xref() == 0`. `moon check --target
  native fixture_acceptance --warn-list +73` passes, the focused retained-pages
  test reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 117/117 tests passing, and `moon test --target
  native` reports 2336/2336 tests passing. `moon info && moon fmt` reports no
  pending interface or formatting work, and `moon check --target all
  --warn-list +73` reports the known warning-73/main-package baseline with 7
  warnings and 0 errors.~~
- [x] ~~Add the next source-corpus `cpdfxobject.stamp_as_xobject` slice: the
  native `fixture_acceptance` package now also gates optional
  `.repos/cpdf-source/hello.pdf` stamped with `.repos/cpdf-source/logo.pdf` as a
  reusable Form XObject. The gate verifies the method and compatibility wrapper
  return the same generated `CPDFXObj` name, preserve the base page box/rotation
  and extracted `Hello, World!` text, embed a Form XObject with the overlay
  bounding box and prefixed logo resources, retain `/aG0` and `/aG1`
  transparency state resources in the form resources, decode deferred or
  compressed form stream bytes before parsing content operators, and survive
  compressed rewrite/reread plus bad-final-`startxref` reconstruction with
  `first_xref() == 0`. `moon check --target native fixture_acceptance
  --warn-list +73` passes, the focused Form XObject stamp test reports 1/1 test
  passing, `moon test --target native fixture_acceptance` reports 118/118 tests
  passing, and `moon test --target native` reports 2337/2337 tests passing.
  `moon info && moon fmt` reports no pending interface or formatting work, and
  `moon check --target all --warn-list +73` reports the known
  warning-73/main-package baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-corpus `cpdfclip` native polygon slice: the native
  `fixture_acceptance` package now also gates optional
  `.repos/cpdf-source/manualimages/clip.pdf` through cpdf/GPC-style polygon
  operations derived from the real fixture page box. The gate parses the source
  `/MediaBox`, builds page and inset-box polygons, verifies native
  intersection bounds/area, difference and exclusive-or hole handling plus
  signed area, union area/bounds, the compatibility method wrapper, compressed
  rewrite/reread, and bad-final-`startxref` reconstruction before rerunning the
  same polygon assertions. `moon check --target native fixture_acceptance
  --warn-list +73` passes, the focused source clip test reports 1/1 test
  passing, `moon test --target native fixture_acceptance` reports 119/119 tests
  passing, and `moon test --target native` reports 2338/2338 tests passing.
  `moon info && moon fmt` reports no pending interface or formatting work, and
  `moon check --target all --warn-list +73` reports the known
  warning-73/main-package baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-corpus Markdown manual-image text slice: the native
  `markdown/fixture_acceptance` package now compares optional
  `.repos/cpdf-source/manualimages` text fixtures against expected Markdown text
  fragments, rewrites each fixture with compressed xref streams, corrupts the
  rewritten `startxref` pointer, verifies strict classic parsing rejects the
  damaged bytes, and confirms reconstructed Markdown remains byte-for-byte equal
  to the clean conversion. `moon check --target native markdown/fixture_acceptance
  --warn-list +73` passes, the focused source Markdown comparison test reports
  1/1 test passing, `moon test --target native markdown/fixture_acceptance`
  reports 25/25 tests passing, and `moon test --target native` reports
  2339/2339 tests passing. `moon info && moon fmt` reports no pending interface
  or formatting work, and `moon check --target all --warn-list +73` reports the
  known warning-73/main-package baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next source-corpus async attach/portfolio file-wrapper slice:
  the native `async_io` package now gates `.repos/cpdf-source/hello.pdf`,
  `README.md`, and `Changes.txt` through `pdf_attach_file_from_path`,
  `pdf_dump_attached_files_to_directory`, and `pdf_portfolio_from_files`. The
  gate verifies source text extraction, document-level attachment metadata and
  dumped bytes, portfolio embedded-file name trees and payload streams,
  compressed xref-stream file write/read, and bad-final-`startxref` file
  reconstruction preserving the portfolio payloads. `moon check --target native
  async_io --warn-list +73` passes, the focused source async attach/portfolio
  test reports 1/1 test passing, `moon test --target native async_io` reports
  89/89 tests passing, and `moon test --target native` reports 2340/2340 tests
  passing. `moon info && moon fmt` reports no pending interface or formatting
  work, and `moon check --target all --warn-list +73` reports the known
  warning-73/main-package baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next cpdfmetadata source/API parity slice: the root package now
  exposes the public `pdf_expand_date` compatibility helper corresponding to
  `Cpdfmetadata.expand_date`, including reproducible `"now"` coverage in
  `pdf_metadata_test.mbt`, and the native `metadata/fixture_acceptance` package
  now gates `.repos/cpdf-source/cpdfmanual.pdf` through catalog view/open-action
  mutation. The source gate verifies page layout, full-screen page mode,
  non-full-screen viewer preferences, display-title viewer preferences,
  cpdf-style open-action object/string/JSON reporting, compressed xref-stream
  rewrite/reread, and bad-final-`startxref` reconstruction. `moon check --target
  native --warn-list +73` and `moon check --target native
  metadata/fixture_acceptance --warn-list +73` pass with the known warning
  baseline, both focused metadata tests report 1/1 passing,
  `moon test --target native metadata/fixture_acceptance` reports 3/3 tests
  passing, and `moon test --target native` reports 2341/2341 tests passing.
  `moon info && moon fmt` updates the expected `pkg.generated.mbti` API entry,
  and `moon check --target all --warn-list +73` reports the known
  warning-73/main-package baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next cpdfannot source-corpus import slice: the native
  `annotation/fixture_acceptance` package now also gates optional
  `.repos/cpdf-source/cpdfmanual.pdf` through real annotation JSON removal,
  import, and copy flows. The gate exports the first annotated manual page,
  verifies selected-page `remove_annotations` leaves only the cpdf annotation
  JSON header, restores the page through `set_annotations_json`,
  `pdf_set_annotations_json`, `copy_annotations_from`, and
  `pdf_copy_annotations`, then checks restored `/Link`, `/Rect`, `/A`, blob,
  wrapper, compressed rewrite/reread, strict-reader rejection of a bad final
  `startxref`, and malformed reconstruction with `first_xref() == 0`. `moon
  check --target native annotation/fixture_acceptance --warn-list +73` passes,
  the focused cpdf source annotation import test reports 1/1 test passing,
  `moon test --target native annotation/fixture_acceptance` reports 2/2 tests
  passing, and `moon test --target native` reports 2342/2342 tests passing.
  `moon info && moon fmt` reports no pending interface or formatting work, and
  `moon check --target all --warn-list +73` reports the known
  warning-73/main-package baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next cpdfremovetext source-corpus lifecycle slice: the native
  `fixture_acceptance` package now also gates optional
  `.repos/cpdf-source/cpdfmanual.pdf` through add-text stamping followed by
  `remove_added_text` and `pdf_remove_added_text`. The gate reuses the real
  manual add-text fixture, strips `/CPDFSTAMP` content from pages 1, 19, and
  175, verifies the stamped text is gone while original manual text remains
  extractable, pins cpdf-compatible URL-annotation retention, and checks
  compressed rewrite/reread plus strict-reader rejection of a bad final
  `startxref` followed by malformed reconstruction with `first_xref() == 0`.
  `moon check --target native fixture_acceptance --warn-list +73` passes, the
  focused cpdf source remove-added-text test reports 1/1 test passing, `moon
  test --target native fixture_acceptance` reports 120/120 tests passing, and
  `moon test --target native` reports 2343/2343 tests passing. `moon info &&
  moon fmt` reports no pending interface or formatting work, and `moon check
  --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next `cpdfimpose` source-corpus lifecycle slice: the native
  `fixture_acceptance` package now gates optional `.repos/cpdf-source/hello.pdf`
  through a two-page source document, `PdfDocument::impose`/`pdf_impose`,
  `PdfDocument::twoup`/`pdf_twoup`, and
  `PdfDocument::twoup_stack`/`pdf_twoup_stack`. The gate checks two-up sheet
  geometry, transformed content stream placement, `/CPDFSTAMP` border marking,
  retained text extraction quality, compressed xref-stream rewrite/reread, and
  malformed-`startxref` public reconstruction with `first_xref() == 0`.
  `moon check --target native fixture_acceptance --warn-list +73` passes, the
  focused cpdf source imposition test reports 1/1 test passing, `moon test
  --target native fixture_acceptance` reports 122/122 tests passing, and `moon
  test --target native` reports 2345/2345 tests passing. `moon info && moon
  fmt` reports no pending interface or formatting work, and `moon check
  --target all --warn-list +73` reports the known warning-73/main-package
  baseline with 10 warnings and 0 errors.~~
- [x] ~~Add the next `cpdfjson` source/API parity slice: the root package now
  exposes `PdfDocument::json_of_document_blob` and
  `pdf_json_of_document_blob`, mirroring `Cpdfjson.to_output` as UTF-8 bytes
  while reusing the existing full-document CPDFJSON encoder. Optional
  `.repos/cpdf-source/hello.pdf` now gates parsed UTF-8 document output,
  wrapper parity, operation-token spelling, `Hello, World!` import
  round-trips, compressed xref-stream rewrite/reread, and malformed
  `startxref` public reconstruction. `moon check --target native --warn-list
  +73` passes, the focused root CPDFJSON blob test reports 1/1 test passing,
  the focused source CPDFJSON gate reports 1/1 test passing, `moon test
  --target native fixture_acceptance` reports 123/123 tests passing, and `moon
  test --target native` reports 2347/2347 tests passing. `moon info` updates
  `pkg.generated.mbti` with the two intended public entries, `moon fmt` reports
  no pending formatting work, and `moon check --target all --warn-list +73`
  reports the known warning-73/main-package baseline with 10 warnings and 0
  errors.~~
- [x] ~~Add the matching `cpdfjson` source/API parity slice for input: the root
  package now exposes `pdf_document_of_json_blob`, mirroring
  `Cpdfjson.of_input` for in-memory UTF-8 CPDFJSON bytes by decoding, parsing,
  and forwarding to the existing full-document importer. Optional
  `.repos/cpdf-source/hello.pdf` now gates parsed UTF-8 document output through
  byte import as well as direct JSON import, retaining `Hello, World!` text
  across direct read, compressed xref-stream rewrite/reread, and malformed
  `startxref` public reconstruction. The root focused byte-input test also
  pins restored object-table/content-stream state and `BadText` for non-UTF8
  or malformed JSON input. `moon check --target native --warn-list +73`
  passes, the focused root CPDFJSON byte-input test reports 1/1 test passing,
  the focused source CPDFJSON gate reports 1/1 test passing, `moon test
  --target native fixture_acceptance` reports 123/123 tests passing, and `moon
  test --target native` reports 2348/2348 tests passing. `moon info` updates
  `pkg.generated.mbti` with the intended new public entry, `moon fmt` reports
  no pending formatting work, and `moon check --target all --warn-list +73`
  reports the known warning-73/main-package baseline with 10 warnings and 0
  errors.~~
- [x] ~~Add the next cpdfpage source-corpus lifecycle slice: optional
  `.repos/cpdf-source/manualimages/h1.pdf` now gates the real PDF/UA
  structure-tree fixture through `remove_struct_tree`, `pdf_remove_struct_tree`,
  `mark_all_as_artifact`, and `pdf_mark_all_as_artifact`. The gate checks
  structure-entry removal, header-only structure extraction after removal,
  visible text preservation, removal of original marked-content operators,
  `/Artifact` wrapping after removal, compressed xref-stream rewrite/reread,
  and malformed `startxref` public reconstruction. `moon check --target native
  fixture_acceptance --warn-list +73` passes, the focused source H1
  remove/artifact test reports 1/1 test passing, `moon test --target native
  fixture_acceptance` reports 124/124 tests passing, and `moon test --target
  native` reports 2349/2349 tests passing. `moon info && moon fmt` reports no
  pending public API or formatting work, and `moon check --target all
  --warn-list +73` reports the known warning-73/main-package baseline with 10
  warnings and 0 errors.~~
- [x] ~~Complete the remaining `cpdfprinttree` buffer-output surface: the root
  package now exposes `pdf_print_tree_to_buffer`, mirroring
  `Cpdfprinttree.to_buffer` by appending cpdf's tree-line rendering to an
  existing `@buffer.Buffer` while preserving the existing `line_prefix`
  behavior. Focused coverage pins append semantics and prefixed Unicode tree
  lines, with `moon test --target native pdf_print_tree_test.mbt` reporting
  3/3 tests passing, `moon test --target native` reporting 2350/2350 tests
  passing, `moon check --target native --warn-list +73` reporting the known
  warning-73/main-package baseline with 10 warnings and 0 errors, and
  `moon check --target all --warn-list +73` reporting the same 10-warning
  baseline with 0 errors.~~
- [x] ~~Restore clean validation on the MoonBit `moonc v0.9.3+43fd170a1`
  toolchain: migrated the module manifest from deprecated `moon.mod.json` to
  `moon.mod`, replaced deprecated `Map::of(...)` construction with `Map(...)`,
  switched buffer text writes to explicit `Buffer()` /
  `write_string_utf16le(...)` calls where `Buffer.to_string()` semantics are
  required, and removed the remaining redundant warning-73 annotations.
  Focused coverage reports `moon test --target native
  pdf_print_tree_test.mbt` at 3/3 tests passing, `moon test --target native
  markdown` at 42/42 tests passing, add-text source-dispatch focused coverage
  at 4/4 tests passing, add-text measurement focused coverage at 1/1 test
  passing, and TOC source-dispatch focused coverage at 1/1 test passing.
  `moon check --target native --warn-list +73` and `moon check --target all
  --warn-list +73` pass with no numbered diagnostics, aside from the tool's
  future main-package blackbox-test notice for `markdown/cmd`, and `moon test
  --target native` reports 2350/2350 tests passing.~~
- [x] ~~Add an optional cpdf source UnicodeData table gate: fixture acceptance
  now parses `.repos/cpdf-source/compressor/UnicodeData.txt`, compares its row
  count and selected parsed rows against pdflite's embedded cpdf UnicodeData
  table, and pins the first control row, Latin capital A, and final Plane 16
  private-use row without doing brittle whole-table byte comparisons. The
  focused UnicodeData fixture test reports 1/1 test passing, `moon check
  --target native fixture_acceptance --warn-list +73` passes, `moon test
  --target native fixture_acceptance` reports 125/125 tests passing, `moon
  check --target native --warn-list +73` and `moon check --target all
  --warn-list +73` pass aside from the known future main-package
  blackbox-test notice for `markdown/cmd`, and `moon test --target native`
  reports 2351/2351 tests passing. `moon info && moon fmt` reports no pending
  public API or formatting work.~~
- [x] ~~Add the next remaining format parity slice: the optional cpdf source
  raw sheet PNG gate now decodes `.repos/cpdf-source/manualimages/sheet.png`
  through the real PNG parser, Flate decoder, and PNG predictor path, pins
  stable source pixels, and checks that `pdf_image_document_of_png_data` plus a
  compressed PDF roundtrip extracts the same 24bpp pixels. The focused raw
  sheet PNG fixture test reports 1/1 test passing, `moon check --target native
  fixture_acceptance --warn-list +73` passes, `moon test --target native
  fixture_acceptance` reports 125/125 tests passing, `moon check --target
  native --warn-list +73` and `moon check --target all --warn-list +73` pass
  aside from the known future main-package blackbox-test notice for
  `markdown/cmd`, and `moon test --target native` reports 2351/2351 tests
  passing on MoonBit 0.9.3. `moon info && moon fmt` reports no pending public
  API or formatting work.~~
- [x] ~~Run a compiler-0.9.3 backend readiness pass next: reran the non-native
  backend test/check slices that were previously deferred after native
  stabilization. WasmGC and JavaScript are green at 2016/2016 each, all-target
  checking passes with the known `markdown/cmd` future notice, plain Wasm is
  still blocked by runtime maximum-function-size limits in generated test
  modules, and LLVM remains blocked by the installed toolchain's missing LLVM
  core bundle.~~
- [x] ~~Reduce the generated plain-Wasm test modules enough for a meaningful
  current smoke suite to instantiate under the runtime maximum-function-size
  limit, without dropping source-corpus coverage from wasm-gc/js/native: root's
  heavy test files and the Markdown package-level test module are filtered out
  only for plain Wasm, full `moon test --target wasm` now reports 41/41 tests
  passing, `moon test --target wasm-gc` and `moon test --target js` remain
  2016/2016 each, and `moon test --target native` remains 2351/2351.~~
- [x] ~~Continue source-port hardening with another small cpdf-source API parity
  gap: added cpdfmetadata namespace aliases and a tree-free
  `pdf_metadata_get_data_for_bytes` helper over in-memory XMP bytes, matching
  cpdf's namespace/local-name lookup across alternate prefixes, attributes,
  element text, RDF lists, named XML entities, and numeric XML entities. Updated
  the source-corpus metadata fixture expectations to decoded XMP JSON values.
  Validation on MoonBit 0.9.3: `moon check --target all --warn-list +73`
  passes with the known `markdown/cmd` future notice; `moon test --target
  native` reports 2352/2352; `moon test --target wasm-gc` and `moon test
  --target js` report 2017/2017 each; `moon test --target wasm` reports 41/41;
  `moon info`, `moon fmt`, and `git diff --check` are clean.~~
- [x] ~~Continue cpdfmetadata API parity with the XML-tree helpers from
  `.repos/cpdf-source/cpdfmetadata.mli`: added public XML name/tag/attribute/
  tree/document types plus `pdf_metadata_xmltree_of_bytes`,
  `pdf_metadata_string_of_xmltree`, `pdf_metadata_xmltree_get_data_for`, and
  `pdf_metadata_bytes_of_xmltree`. The parser resolves namespace declarations,
  skips comments and processing instructions, preserves optional DTD text,
  normalizes XML whitespace like `Cpdfxmlm` with `strip:true`, decodes named and
  numeric entities, and mirrors cpdf's attribute/text/RDF-list lookup behavior.
  Coverage pins attribute lookup, RDF Bag list collection, debug string output,
  and serialization without an XML declaration. Validation on MoonBit 0.9.3:
  `moon check --target all --warn-list +73` passes with the known
  `markdown/cmd` future notice; `moon test --target native` reports 2353/2353;
  `moon test --target wasm-gc` and `moon test --target js` report 2018/2018
  each; `moon test --target wasm` reports 41/41; `moon info`, `moon fmt`, and
  `git diff --check` are clean.~~
- [x] ~~Continue cpdfmetadata file-operation parity in the native `async_io`
  package: added `pdf_set_metadata_from_file`,
  `pdf_write_metadata_to_file`, and
  `pdf_extract_all_metadata_to_directory` wrappers around the portable metadata
  core. The extraction wrapper follows cpdfmetadata's naming scheme by writing
  the catalog metadata object to `main.xml` and other parsed `/Type /Metadata`
  stream objects to `obj<num>.xml`, decoding supported stream filters before
  writing. Coverage pins file-backed metadata setting, catalog metadata output,
  and extraction of both the catalog stream and an additional Flate-compressed
  metadata stream. Validation on MoonBit 0.9.3:
  `moon check --target native async_io --warn-list +73` passes,
  `moon test --target native async_io --filter '*metadata file wrappers*'`
  reports 1/1, `moon test --target native async_io` reports 90/90,
  `moon check --target all --warn-list +73` passes with the known
  `markdown/cmd` future notice, and `moon test --target native` reports
  2354/2354. This slice is native-only, so the portable wasm-gc/js/plain-wasm
  counts remain unchanged.~~
- [x] ~~Rebaseline the source-port suite after the compiler 0.9.3 upgrade with
  a CMap parser performance fix: the compact-whitespace fallback now runs only
  when CMap section markers are actually split by PDF whitespace, avoiding a
  pathological one-line parse of large well-formed ToUnicode maps such as the
  external Unicode CJK chart. Existing malformed/split-marker CMap tests still
  pass, and the previously stuck `markdown/fixture_acceptance` Unicode CJK
  fixture now completes. Validation on MoonBit 0.9.3:
  `moon check --target all --warn-list +73` passes with the known
  `markdown/cmd` future notice; `moon test --target native` reports 2354/2354;
  `moon test --target wasm-gc` and `moon test --target js` report 2018/2018
  each; `moon test --target wasm` reports 41/41.~~
- [x] ~~Continue cpdffont file-operation parity with
  `.repos/cpdf-source/cpdffont.mli`: the native `async_io` package now exposes
  `pdf_extract_fontfile_to_file`, the filesystem counterpart of cpdf's
  `extract_fontfile`. The wrapper delegates font lookup and stream decoding to
  the portable `PdfDocument::extract_fontfile_bytes` helper, writes the decoded
  bytes to disk, and reports cpdf-style unsupported/unfound-font errors without
  creating an output file. Validation on MoonBit 0.9.3:
  `moon check --target native async_io --warn-list +73` passes, and
  `moon test --target native async_io --filter '*extract embedded font files*'`
  reports 1/1; `moon test --target native async_io` reports 91/91;
  `moon check --target all --warn-list +73` passes with the known
  `markdown/cmd` future notice; `moon test --target native` reports 2355/2355;
  `moon info && moon fmt` and `git diff --check` are clean.~~
- [x] ~~Continue cpdfimage API parity with
  `.repos/cpdf-source/cpdfimage.mli`: added portable
  `pdf_image_obj_of_jpeg_data`, `pdf_image_obj_of_png_data`,
  `pdf_image_obj_of_jbig2_data`, and `pdf_image_obj_of_jpeg2000_data`
  wrappers. These expose cpdf's `(PdfObject, extra_objects)` constructor shape
  while delegating to the existing image XObject builders, preserve PNG alpha
  mask insertion through the supplied document, and preserve the JBIG2 globals
  extra object contract at object number 10000. Validation on MoonBit 0.9.3:
  `moon check --target native --warn-list +73` passes with the known
  `markdown/cmd` future notice; `moon test --target native pdf_image_test.mbt
  --filter '*obj_of*'` reports 4/4; `moon check --target all --warn-list +73`
  passes with the known `markdown/cmd` future notice; `moon test --target
  native` reports 2359/2359; `moon info`, `moon fmt`, and `git diff --check`
  are clean.~~
- [x] ~~Continue cpdffont/cpdfcoord API parity with
  `.repos/cpdf-source`: added `pdf_json_fonts`,
  `PdfDocument::missing_fonts_return`, `pdf_missing_fonts_return`,
  `pdf_parse_rectangle`, and `pdf_parse_rectangles`. These wrappers preserve
  the existing richer MoonBit record APIs while exposing cpdf's direct function
  names and tuple-shaped return rows for missing fonts and coordinate
  rectangles. Coverage pins the font JSON alias, cpdf's missing-font tuple
  order, single-rectangle default-page parsing, and per-page rectangle parsing.
  Validation on MoonBit 0.9.3: `moon check --target native --warn-list +73`
  passes with the known `markdown/cmd` future notice; `moon test --target
  native pdf_font_test.mbt --filter '*font*'` reports 9/9; `moon test --target
  native pdf_coord_test.mbt --filter '*coord*'` reports 7/7; `moon check
  --target all --warn-list +73` passes with the known `markdown/cmd` future
  notice; `moon test --target native` reports 2359/2359; `moon info`,
  `moon fmt`, and `git diff --check` are clean.~~
- [x] ~~Continue cpdfbookmarks/cpdfcomposition API parity with
  `.repos/cpdf-source`: added `pdf_parse_bookmark_file` with cpdf's
  `(verify, document, input-bytes)` argument order, plus
  `PdfDocument::composition_text` and `pdf_show_composition`. The composition
  wrapper returns the bytes cpdf would print: line-oriented text for
  `json=false`, and JSON bytes plus a trailing newline for `json=true`.
  Coverage pins the bookmark-file alias against the existing verified text
  parser and the exact composition text rows/JSON newline behavior. Validation
  on MoonBit 0.9.3: `moon check --target native --warn-list +73` passes with
  the known `markdown/cmd` future notice; `moon test --target native
  pdf_bookmark_test.mbt --filter '*parse_bookmark*'` reports 4/4; `moon test
  --target native pdf_composition_test.mbt --filter '*composition*'` reports
  3/3; `moon check --target all --warn-list +73` passes with the known
  `markdown/cmd` future notice; `moon test --target native` reports
  2359/2359; `moon info`, `moon fmt`, and `git diff --check` are clean.~~
- [x] ~~Continue cpdffont/cpdfredact API parity with `.repos/cpdf-source`:
  added `PdfDocument::print_fonts`, `pdf_print_fonts`, and `pdf_apply_type`.
  The font wrapper returns the exact bytes cpdf's `print_fonts` would emit,
  using the existing text listing for `json=false` and font JSON blob for
  `json=true`; the redaction wrapper preserves cpdfredact's `apply_type` name
  over the current redaction-type stub. Coverage pins both text and JSON font
  print aliases and the redaction compatibility alias. Validation on MoonBit
  compiler 0.9.3: `moon check --target native --warn-list +73` passes with the
  known `markdown/cmd` future notice; `moon test --target native
  pdf_redact_test.mbt --filter '*redaction*'` reports 1/1; `moon test --target
  native pdf_font_test.mbt --filter '*font listing*'` reports 1/1; `moon check
  --target all --warn-list +73` passes with the known `markdown/cmd` future
  notice; `moon test --target native` reports 2359/2359; `moon info`,
  `moon fmt`, and `git diff --check` are clean.~~
- [x] ~~Continue cpdfaddtext/cpdfembed/cpdfimage API parity with
  `.repos/cpdf-source`: added `pdf_process_text`,
  `pdf_fontpack_of_standardfont`, native `pdf_load_substitute`, and
  `pdf_image_of_input`. The add-text wrapper exposes cpdfaddtext's replacement
  plus strftime pass under its cpdf name; the embed wrappers preserve
  cpdfembed's Standard 14 fontpack and substitute-font loading names; the image
  wrapper ports cpdfimage's generic input-to-single-page-document builder using
  a `BytesView` input boundary and the existing `(image, extra_objects)`
  callback shape. Coverage pins the add-text alias, fontpack alias, native
  substitute loader alias, and image callback document construction including
  structure-tree alt text. Validation on MoonBit compiler 0.9.3: `moon check
  --target native --warn-list +73` passes with the known `markdown/cmd` future
  notice; `moon test --target native pdf_addtext_test.mbt --filter
  '*process_text*'` reports 3/3; `moon test --target native pdf_embed_test.mbt
  --filter '*fontpack*'` reports 2/2; `moon test --target native
  pdf_image_test.mbt --filter '*image_of_input*'` reports 1/1; `moon test
  --target native async_io --filter '*substitute*'` reports 1/1; `moon check
  --target all --warn-list +73` passes with the known `markdown/cmd` future
  notice; `moon test --target native` reports 2360/2360; `moon info`,
  `moon fmt`, and `git diff --check` are clean.~~
- [x] ~~Continue cpdffont API parity with `.repos/cpdf-source`: added
  `PdfDocument::print_font_table`, `pdf_print_font_table`, and native
  `pdf_extract_fontfile`. The font-table wrappers expose cpdffont's
  stdout-oriented `print_font_table` as deterministic bytes over the existing
  `font_table_text` port, while the native filesystem alias preserves
  cpdffont's `(page, font, filename, document)` argument order over the existing
  `pdf_extract_fontfile_to_file` writer. Coverage pins the font-table bytes
  aliases and the cpdf-order extraction alias. Validation on MoonBit compiler
  0.9.3: `moon check --target native --warn-list +73` passes with the known
  `markdown/cmd` future notice; `moon test --target native pdf_font_test.mbt
  --filter '*font_table*'` reports 1/1; `moon test --target native async_io
  --filter '*extract embedded font files*'` reports 1/1; `moon check --target
  all --warn-list +73` passes with the known `markdown/cmd` future notice;
  `moon test --target native` reports 2360/2360; `moon info`, `moon fmt`, and
  `git diff --check` are clean.~~
- [x] ~~Continue cpdfimage API parity with `.repos/cpdf-source`: added
  `pdf_image_debug_image_processing` and
  `pdf_image_set_debug_image_processing` over a module-level Boolean flag,
  mirroring cpdfimage's public `debug_image_processing : bool ref` without
  exposing a raw mutable reference in the MoonBit API. Coverage pins false,
  true, and restore behavior so later image-processing/extraction work can use
  the same flag. Validation on MoonBit compiler 0.9.3: `moon check --target
  native --warn-list +73` passes with the known `markdown/cmd` future notice;
  `moon test --target native pdf_image_test.mbt --filter '*debug_image*'`
  reports 1/1; `moon check --target all --warn-list +73` passes with the known
  `markdown/cmd` future notice; `moon test --target native` reports 2361/2361;
  `moon info`, `moon fmt`, and `git diff --check` are clean.~~
- [x] ~~Continue cpdfcoord API parity with `.repos/cpdf-source`: added
  tuple-shaped `PdfDocument::parse_coordinate_tuple`,
  `pdf_parse_coordinate_tuple`, `PdfDocument::parse_coordinates_tuple`, and
  `pdf_parse_coordinates_tuple`, preserving the existing `Point2` APIs while
  exposing cpdfcoord's `(float * float)` return shape. Coverage pins both method
  and function wrappers across single-coordinate and per-page coordinate parsing.
  Validation on MoonBit compiler 0.9.3: `moon check --target native --warn-list
  +73` passes with the known `markdown/cmd` future notice; `moon test --target
  native pdf_coord_test.mbt --filter '*coordinates*'` reports 1/1; `moon check
  --target all --warn-list +73` passes with the known `markdown/cmd` future
  notice; `moon test --target native` reports 2361/2361; `moon info`, `moon
  fmt`, and `git diff --check` are clean.~~
- [x] ~~Continue cpdfjpeg API parity with `.repos/cpdf-source`: added
  `pdf_jpeg_backup_dimensions_view`, `pdf_jpeg_backup_dimensions`, and the
  native async file wrapper `pdf_backup_jpeg_dimensions`. The core fallback
  scans JPEG SOF markers directly, including progressive SOF2 data rejected by
  cpdf's primary `jpeg_dimensions` parser, while the async wrapper preserves the
  filename boundary and accepts `path_to_im` for cpdf API parity without
  shelling out. Coverage pins progressive JFIF data, generic SOF scanning,
  malformed fallback inputs, and the async filename wrapper; synthetic JPEG
  fixtures now use bounded SOF lengths. Validation on MoonBit compiler 0.9.3:
  `moon check --target native --warn-list +73` passes with the known
  `markdown/cmd` future notice; `moon test --target native pdf_jpeg_test.mbt
  --filter '*backup_dimensions*'` reports 2/2; `moon test --target native
  async_io --filter '*backup dimensions*'` reports 1/1; `moon test --target
  native pdf_jpeg_test.mbt` reports 9/9; `moon check --target all --warn-list
  +73` passes with the known `markdown/cmd` future notice; `moon test --target
  native` reports 2364/2364; `moon info`, `moon fmt`, and `git diff --check`
  are clean.~~
- [x] ~~Continue cpdfpage API parity with `.repos/cpdf-source`: added string
  page-box compatibility wrappers over the existing typed `PdfName` page-box
  implementation: `PdfDocument::hard_box_string`, `pdf_hard_box_string`,
  `PdfDocument::hasbox_string`, `pdf_hasbox_string`,
  `PdfDocument::copy_box`, cpdf-order `pdf_copy_box`,
  `PdfDocument::crop_pdf_string`, cpdf-order `pdf_crop_pdf_string`,
  `PdfDocument::set_box_string`, and cpdf-order `pdf_set_box_string`. These
  preserve the typed internal API while exposing cpdfpage's string box-name
  calling shape for `/CropBox`, `/MediaBox`, `/TrimBox`, `/BleedBox`, and
  related names. Coverage pins string hard-box clipping, hasbox checks,
  copy-box media fallback and cpdf argument order, crop custom-box strings, and
  setBox-style scalar ordering. Validation on MoonBit compiler 0.9.3: `moon
  check --target native --warn-list +73` passes with the known `markdown/cmd`
  future notice; `moon test --target native pdf_page_box_test.mbt --filter
  '*box*'` reports 16/16; `moon check --target all --warn-list +73` passes with
  the known `markdown/cmd` future notice; `moon test --target native` reports
  2364/2364; `moon info`, `moon fmt`, and `git diff --check` are clean.~~
- [x] ~~Continue cpdfpage transform API parity with `.repos/cpdf-source`: added
  cpdf-order, absolute page-indexed wrappers for the existing page transform
  kernels: `PdfDocument::shift_pdf`, `pdf_shift_pdf`,
  `PdfDocument::scale_pdf`, `pdf_scale_pdf`, `PdfDocument::stretch`,
  `pdf_stretch`, `PdfDocument::scale_to_fit_pdf`, `pdf_scale_to_fit_pdf`,
  `PdfDocument::scale_to_fit_rotate`, `pdf_scale_to_fit_rotate`,
  `PdfDocument::center_to_fit`, and `pdf_center_to_fit`. The wrappers preserve
  cpdfpage's source behavior that transform lists are indexed by absolute page
  number while selected pages determine which entries are applied. Coverage
  pins cpdf-order shift, scale, stretch, scale-to-fit, scale-to-fit-rotate, and
  center-to-fit aliases plus count validation. Validation on MoonBit compiler
  0.9.3: `moon check --target native --warn-list +73` passes with the known
  `markdown/cmd` future notice; `moon test --target native
  pdf_page_shift_test.mbt` reports 4/4; `moon test --target native
  pdf_page_scale_test.mbt` reports 19/19; `moon check --target all --warn-list
  +73` passes with the known `markdown/cmd` future notice; `moon test --target
  native` reports 2369/2369; `moon info`, `moon fmt`, and `git diff --check`
  are clean.~~
- [x] ~~Continue cpdfpage rotation/flip API parity with `.repos/cpdf-source`:
  added source-name rotation aliases `PdfDocument::rotate_pdf`,
  `PdfDocument::rotate_pdf_by`, cpdf-order wrappers `pdf_rotate_pdf` and
  `pdf_rotate_pdf_by`, and a cpdf-order `pdf_rotate_contents_cpdf_order`
  wrapper without breaking the existing document-first `pdf_rotate_contents`.
  Added `PdfDocument::vflip_pdf` and `PdfDocument::hflip_pdf` method aliases
  over the existing flip kernels. Coverage pins absolute rotation, relative
  rotation, cpdf-order rotate-contents, and flip method aliases. Validation on
  MoonBit compiler 0.9.3: `moon check --target native --warn-list +73` passes
  with the known `markdown/cmd` future notice; `moon test --target native
  pdf_page_rotate_test.mbt` reports 5/5; `moon test --target native
  pdf_page_flip_test.mbt` reports 3/3; `moon check --target all --warn-list
  +73` passes with the known `markdown/cmd` future notice; `moon test --target
  native` reports 2369/2369; `moon info`, `moon fmt`, and `git diff --check`
  are clean.~~
- [x] ~~Continue cpdfpage stamp/combine API parity with `.repos/cpdf-source`:
  added `PdfDocument::stamp_pages_string` for cpdf's string page-box names,
  cpdf-order `pdf_stamp_cpdf_order`, and cpdf-order
  `pdf_combine_pages_cpdf_order`. These wrappers preserve the existing
  document-first MoonBit APIs while exposing cpdfpage's historical
  `process_struct_tree`, `fast`, string box-name, `range`, overlay, and base
  document ordering. Coverage pins cpdf-order stamping, string-box stamping,
  and cpdf-order combine behavior against the existing verified kernels.
  Validation on MoonBit compiler 0.9.3: `moon check --target native
  --warn-list +73` passes with the known `markdown/cmd` future notice; `moon
  test --target native pdf_page_stamp_test.mbt` reports 5/5; `moon test
  --target native pdf_page_combine_test.mbt` reports 4/4; `moon check --target
  all --warn-list +73` passes with the known `markdown/cmd` future notice;
  `moon test --target native` reports 2369/2369; `moon info`, `moon fmt`, and
  `git diff --check` are clean.~~
- [ ] Continue source-port hardening with either another real-world malformed
  recovery fixture, another small cpdf-source API parity gap, or a performance
  slice that affects large source-corpus reads.
