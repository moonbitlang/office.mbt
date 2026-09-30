# Changelog

## Unreleased: PPTX Office integration

- Add PPTX identification, slide outlines, slide/notes text extraction, and
  transactional one-slide creation to the unified Office CLI.
- Add the `moonbitlang/office-lib/pptx` SDK package. Existing-deck mutation,
  batch authoring, selectors, and rendering remain outside this initial scope.


Breaking and notable changes for the published modules in this workspace.
Entries are grouped by module and by the version they ship in; `Unreleased`
covers changes that have landed on `main` but are not yet published.

### moonbitlang/pagelayout [0.6.0]

- **BREAKING**: `PageItem` has a new variant, `Graphic(GraphicItem)`: vector
  graphics, a display list of `GraphicOp`s drawn in a space of its own whose
  origin is the item's `(x_pt, y_pt)` (points, y down). The ops are `Save` /
  `Restore` (transformation, clip and alpha, like PDF's `q`/`Q`),
  `Transform(Matrix)`, `Clip(segments, rule)`, `Alpha(fill, stroke)`,
  `Path(PathItem)` (move/line/cubic curve/rectangle/close segments, filled by
  the nonzero or even-odd rule and/or stroked with a `StrokeStyle`: width,
  cap, join, miter limit, dash), and glyph runs (`Text`, or `PaintedText`
  with a `TextPaint`: filled, outlined in a whole `StrokeStyle` of its own,
  both, or invisible but extractable, PDF's text rendering modes) and images
  (`Image`, stretched to their rectangle) placed in the graphic's space.
  A `Rectangle` segment is a closed subpath from its bottom-left corner,
  counter-clockwise on the page, like PDF's `re`.
  - Stroke widths are a `StrokeWidth`: `Width(w)` with `w` positive, or
    `Hairline`, the thinnest line the device draws (PDF's `0 w`, an SVG
    non-scaling stroke one pixel wide). Width 0 is rejected by `validate`,
    since PDF draws it as a hairline and SVG not at all. Dashes are
    measured in the space a stroke is drawn in, a hairline's too, as PDF
    does: SVG draws a dashed hairline path as its dashes, each a solid
    non-scaling stroke (a non-scaling stroke's own dashes would be
    measured in device or CSS pixels), and `validate` rejects text
    outlined with a dashed hairline, which SVG cannot dash so. The dashes
    are cut as PDF (Poppler) dashes: a dash of length 0 is a dot, at a
    subpath's start too (at phase 0), and none starts at its end; a
    closed subpath keeps its closing join, its one dash closed when it
    runs all round, and a dash running to its end continuing through the
    start into the first.
  - A path's fill and stroke are a `Paint`: a solid `Color` or a
    `Gradient { shape, stops, transform }`, whose `GradientShape` is
    `Linear(x1~, y1~, x2~, y2~)` or `Radial(x1~, y1~, r1~, x2~, y2~, r2~)`
    (from the first circle to the second), padded past its ends. Stops at
    one offset make a sharp colour change there; at offset 0 only the last
    of them counts, at 1 only the first. A gradient without extent (a
    linear one whose ends coincide, a radial one whose end circle has
    radius 0 or whose circles coincide) paints its last stop's colour, as
    SVG specifies for the first two; `Gradient::degenerate_color` gives it.
  - The PDF backend writes content operators, `/ExtGState` alpha resources
    and shading patterns (axial or radial, an exponential function per
    non-empty interval between stops, stitched), placing a pattern by the
    transformation current where it paints. Alpha states, shadings and
    patterns (by shading and effective matrix) are shared by value across
    the document. Text in a graphic embeds and subsets its fonts like page
    text. Numbers in a graphic's content, pattern matrices, shading
    coordinates and stitching bounds are written exactly (shortest
    round-trip, without an exponent, and an integral number beyond
    2147483647 with a decimal point: pdflite's new `PdfExactReal`); page
    items outside graphics keep pdflite's rounding, so their output is
    unchanged. A shading is built in a canonical space (a linear one from
    (0, 0) to (1, 0), a radial one centred on its end circle and scaled
    by the largest of its radii and its centres' separation), the pattern
    matrix placing it on the page. Distinct stop offsets, however near,
    stay distinct `/Bounds`, strictly increasing as written. A path
    painted with a gradient where the transformation shrinks areas below
    1e-4 is drawn with its numbers scaled down by a power of two and the
    transformation scaled up as much, since Poppler refuses patterns under
    a tiny determinant.
  - The SVG backend writes nested groups, `<clipPath>`s, paths, text with
    independent fill and stroke opacities, and gradient definitions (one
    per distinct gradient on a page). Numbers in graphics are written
    exactly (shortest round-trip), as their transformations may scale them
    arbitrarily; page items outside graphics keep three decimals.
  - `PageModel::validate` checks that saves and restores balance; that
    every number in a graphic is finite and within ±3.403e38, the range a
    PDF reader is sure to hold (PDF 32000-1, Annex C), as are the
    transformations composed from the page and where each gradient lands
    on it; that each gradient with extent is from 0.001 to 1e12 points in
    size on the page (a linear one's length; a radial one's largest radius
    or separation of its centres, both circles counted), since renderers
    draw gradients outside that range wrongly or not at all (Cairo, and so
    pdftocairo, Evince and librsvg, paints nothing below about 1e-4
    points; Poppler nothing for a linear gradient about 1e18 points long)
    and the backends draw a gradient's geometry as it is rather than
    reshape it (this is the supported range, not a promise that every
    renderer draws an accepted gradient the same: Cairo, and so librsvg,
    resolves a gradient's parameter to about 1/65536 of its size, so it
    merges or moves colour changes closer than that, which Poppler's
    Splash draws where they are; see `Gradient`); that `LineTo`, `CurveTo` and `Close` have a current
    point; that alphas are within 0..=1, stroke widths positive, miter
    limits from 1, dashes empty or non-negative with a positive length;
    that text is not outlined with a dashed hairline; that gradient stops
    are ascending within 0..=1 from 0 to 1; and that glyph runs and images
    are well-formed. `unembeddable_images` reports images inside graphics
    too.

  Code that matches `PageItem` exhaustively must handle the new variant (a
  wildcard arm, or `Graphic(_) => ()`). The PDF backend uses pdflite's
  `PdfExactReal`, so this release of pagelayout requires
  moonbitlang/pdflite 0.3.0.

### moonbitlang/pagelayout [0.5.0]

- `FontRegistry::register_standard(family, metrics, standard=name)`
  registers a PDF standard font and returns the metrics layout measures it
  with. The supported fonts are the twelve Latin faces listed by the new
  `standard_fonts()`: `Helvetica`, `Times-Roman` and `Courier` with their
  bold, italic/oblique and bold italic faces. The PDF declares one by name
  as a Type1 font with an explicit `/WinAnsiEncoding` and embeds nothing
  (no `/FontFile`, `/Widths`, descriptor or `/ToUnicode`, all optional for
  a standard font in PDF 1.7), and its text is encoded over the whole of
  WinAnsi, 0x80–0x9F included (`€`, `’`, `™`, ...); characters WinAnsi
  lacks are dropped, their advances kept. Any other name — a misspelling,
  an alias such as `Arial`, or the symbolic `Symbol` and `ZapfDingbats`,
  whose built-in encodings the renderer does not implement — raises the
  new `FontRegistryError::UnsupportedStandard`. Like `register`, the face
  takes the registered family and style as its identity (the returned
  metrics carry them), so a run laid out in it names the registered family
  and is drawn in this face. The viewer draws the font with its own widths,
  so the metrics must be the font's AFM widths (conventionally each
  character WinAnsi encodes mapped to its code, advances by code, 1000
  units per em); kerning goes into the runs' advances, which the renderer
  shows as displacements. The AFM data is the caller's: pagelayout ships
  none. `RegisteredFace` gains a `standard` field.
- `FaceMetrics::new(family~, units_per_em~, ascender~, descender~,
  line_gap~, advances~, cmap~)` builds metrics outright (from an AFM, say)
  instead of parsing an sfnt, copying its tables. It raises the new
  `FaceMetricsError::InvalidFaceMetrics` unless `units_per_em` is
  positive, `advances` is non-empty with no negative advance, and every
  `cmap` entry maps a codepoint to a glyph that indexes `advances`, so
  that no measurement of the face can abort or be infinite.
- `FontRegistryError` gains the `UnsupportedStandard` variant; a match on
  it that lists every variant needs the new case.

### moonbitlang/pagelayout [0.4.0]

- **BREAKING**: `LinkRegion::target` is a `LinkTarget` instead of a string:
  `Named(name)` jumps to the anchor `name` (a PDF named destination), and
  `Uri(uri)` opens `uri` as a URI action, even one that is only a fragment
  such as `#name`, which a string target could not express (Ruby
  asciidoctor-pdf writes `link:#name[]` that way, and an xref to `name` as
  a jump). `LinkTarget::parse(string)` reads a string by the old
  convention: `#name` is `Named(name)`, anything else `Uri`. A link region
  serializes its target as `["Named", name]` or `["Uri", uri]`. Migration:
  `target: s` becomes `target: LinkTarget::parse(s)`, which renders exactly
  as before, or `target: Named(...)` / `target: Uri(...)`; code reading
  `link.target` as a string matches on the two variants.
- `RenderOptions::new(notdef_text=true)`: a character the face has no
  glyph for is drawn as its `.notdef` glyph and kept in the text layer, as
  Prawn does, instead of being left out of the page (its advance is kept
  either way). A font that needs this goes composite even when the face
  cannot draw the character, and each such character gets a two-byte code
  of its own that no glyph the document shows uses (past the program's
  glyphs, then below them), mapped to glyph 0 by a `/CIDToGIDMap` stream
  and to the character by `/ToUnicode`, so extraction and search find it.
  A font whose text uses up all 65,535 codes shows the characters left
  over as glyph 0 with the character as `/ActualText`. This also covers
  characters WinAnsi has (such as `…`) once the font is composite. It
  needs the face's program embedded: a face registered metrics-only is a
  simple font declared by name and still drops the characters it lacks.
  Off by default; output without it is unchanged.
- `RenderOptions::new(typo_metrics=true)`: font descriptors declare
  `/Ascent` and `/Descent` from the OS/2 typographic metrics where the
  program has them (a version 1 or later table long enough to hold them,
  nonzero values) instead of from `hhea`, and `/CapHeight` from OS/2
  `sCapHeight` (version 2 on, nonzero) instead of the ascent, falling back
  to the ascent as Prawn does. All three are truncated to thousandths of
  an em, as ttfunk and Prawn read them (Prawn 2.4 declares `sCapHeight`
  unscaled; it is scaled here like the other metrics). Readers size
  selection and extracted word boxes by these. Off by default; output
  without it is unchanged.

### moonbitlang/pagelayout [0.3.0]

- **BREAKING**: `PageItem` has a new variant, `Anchor(AnchorItem)`: a named,
  non-visual position that `#name` link targets and outline entries jump to
  (a PDF named destination). Code that matches `PageItem` exhaustively must
  handle it; the SVG backend and `PageModel::validate` do (anchors draw
  nothing). Migration: add an `Anchor(_) => ()` arm, or a wildcard arm.
- **BREAKING**: `@fonts.FaceMetrics` no longer exposes its glyph tables:
  `advances` and `cmap` are private, because one face value is shared by
  every lookup (the bundled cache, a `FontRegistry`, layout and renderer),
  and writing to a table changed what every later document drew. Read them
  through `FaceMetrics::glyph_id(codepoint)` (was `cmap.get(codepoint)`),
  `FaceMetrics::cmap_entries()` (was iterating `cmap`), and `advance_pt` /
  `has_char` as before.
- `@pdf.render_pdf(model, options?)`: an optional `RenderOptions`
  (`RenderOptions::new(...)`, or `RenderOptions::default()`) adds a document
  outline (`OutlineEntry` with an `OutlineDest`: a `Named` anchor or an
  explicit `Position`), typed document information (`DocumentInfo`, with
  `Trapped` written as a name, dates checked field by field as PDF dates
  per ISO 32000-1 §7.9.4 — `is_pdf_date` is that check — and custom keys
  that must be unique), the initial
  zoom (`InitialZoom`), the page mode (`PageMode`), `DisplayDocTitle`,
  explicit page boxes, literal page labels (one per page) and Prawn-style
  truncated glyph widths. `render_pdf(model)` keeps its signature and uses
  the bundled fonts. It raises `RenderOptionError` for options it cannot
  honour.
- PDF output changes for existing callers: glyph runs whose advances differ
  from the declared widths (justified spaces) are shown with `TJ`
  displacements; simple WinAnsi fonts declare the width of the character a
  code stands for (0x92 is U+2019) and carry a `/ToUnicode` map; embedded
  fonts are named by their PostScript name when the program has one.
- `LinkRegion`s become link annotations, written as indirect objects: a
  `#name` target jumps to the anchor's named destination, any other target
  is a URI action whose target is written as an ASCII URI (non-ASCII
  percent-encoded as UTF-8, RFC 3987 §3.1; existing escapes kept).
- `@fonts.FontRegistry`: faces of the caller's own, registered from sfnt
  bytes that supply both the metrics layout measures with and the program
  the PDF embeds. A registry is an explicit value shared by measurement
  (`FontRegistry::face`, `@paragraph.layout_paragraph(..., fonts=)`) and
  rendering (`RenderOptions::fonts`); it is sealed by its first lookup and
  never replaces a face, so a laid-out model cannot change typeface
  underneath. Nothing about it is process-wide. The package-level `@fonts`
  functions and `@fontoutlines.outline_sfnt` keep serving the bundled faces
  only. The CJK fallback resolves through the registry as well
  (`FontRegistry::cjk_fallback`): a registered Noto Sans SC is the face
  fallback characters are measured, sized and drawn in, and
  `FontRegistry::uncovered` reports what neither the run's face nor that
  fallback can draw.

### moonbitlang/ooxml [Unreleased]

- Add shared OPC, XML, and URI packages below the document engines. Extract
  DOCX's URI rules and preserve its existing public entry points as re-exports.
- Use flate for ZIP I/O and `Milky2018/xml@0.5.0` for namespace-aware XML reading.
  Version 0.5.0 fixes the reported attribute-whitespace serialization issue;
  delegate writing and escaping to its checked Writer through a QName and
  incremental-attribute adapter. `XmlWriter::xml_declaration()` now raises
  `XmlError`; malformed output is rejected through `WriterMisuse`.

### moonbitlang/docx2html [Unreleased]

- Depend on `ooxml/uri` for OPC part names and relationship URI rules.
  Existing `docx2html/opc` functions and registry types remain available through
  re-exports; DOCX-specific validation and resource budgets remain in DOCX.

### moonbitlang/pptx [Unreleased]

- Move low-level `opc` and `xml` imports to `moonbitlang/ooxml/...`.
  Replace fzip with flate; `Presentation::save()` now raises `PptxError` and
  `Package::to_bytes()` raises `OpcError` on ZIP write failure.
- Reject malformed XML, empty documents, and DOCTYPE declarations through the
  shared XML reader.

- Add PPTX parsing, building, and writing, derived from t-ujiie-g/moon-pptx
  0.10.0; retain upstream attribution and Apache-2.0 notices.
- Organize PPTX as an Office module with direct package directories, shared
  demos, and `cmd/demos` and `cmd/bench` executables under the root workspace.
- Integrate root scripts, the shared OpenXML SDK validator, the common CI and
  release workflow, and Office warning conventions. Existing public library
  document-model import paths remain `moonbitlang/pptx/...`.
- Restrict imported implementation fields and helpers to their owning packages.
  Use `Presentation::opc_package()` for raw OPC edits, and `Part::bytes()`,
  `ContentTypes::defaults()` / `overrides()`, and `Relationships::items()` for
  snapshots. Package enumeration and part payloads no longer expose writable
  backing storage.

### moonbitlang/mbtexcel [0.2.0]

- **BREAKING**: Moved the `testutil/zip_fixture` ZIP byte fixture out of
  `moonbitlang/mbtexcel/testutil` to
  `moonbitlang/docx2html/testutil/zip_fixture` (see docx2html below), and
  dropped the package's byte-push helpers (`push_u16_le`, `push_u16_be`,
  `push_u32_le`, `push_u32_be`, `push_u64_le`, `push_bytes`), which duplicated
  `moonbitlang/core/buffer`; use the core `Buffer` API instead
  (`write_uint16_le`/`write_uint16_be`, `write_uint_le`/`write_uint_be`,
  `write_uint64_le`, `write_bytes`, then `Buffer::to_bytes`).

### moonbitlang/docx2html [0.6.1]

- Added `moonbitlang/docx2html/testutil/zip_fixture`, a test-only ZIP byte
  fixture moved from `moonbitlang/mbtexcel/testutil/zip_fixture`.
- Removed the test-only `moonbitlang/mbtexcel` dependency; no package in the
  module imported mbtexcel outside that fixture.

### moonbitlang/office-lib [0.6.1]

- **BREAKING**: Moved the unified CLI implementation and its internal
  `input_contract` helper from `moonbitlang/office-lib/cmd/office` to the
  `moonbitlang/office` module (`office-cli`); importers of
  `moonbitlang/office-lib/cmd/office` should use the new location (see below).
- Removed the `moonbitlang/pagelayout` and `tonyfettes/unicode` dependencies,
  which only that CLI used.

### moonbitlang/office [0.2.0]

- Moved the unified CLI implementation from `moonbitlang/office-lib` into the
  module root package (`moonbitlang/office`) and its `input_contract` helper to
  `moonbitlang/office/internal/input_contract`; the module now declares the
  CLI's dependencies directly.

### moonbitlang/pdflite [0.3.0]

- **BREAKING**: `PdfObject` has a new variant, `PdfExactReal(Double)`, a real
  written exactly: the shortest decimal that reads back as the value,
  without an exponent, where `PdfReal` rounds (to six decimals below 1e-4 in
  magnitude, otherwise to twelve significant digits). It serves numbers no
  fixed precision does, such as pattern matrices; `pdf_write_exact_real`
  formats one on its own. An integral value is written as an integer up to
  2147483647 in magnitude and with a decimal point beyond, where a PDF
  integer may overflow (PDF 32000-1, Annex C). The parser never produces it;
  `get_number` and the content, ExtGState and JSON helpers read it as a
  real. Code that matches `PdfObject` exhaustively must handle it.
- Reading a TrueType `cmap` (`pdf_truetype_cmap_glyphs`) now finds an earlier
  mapping of each codepoint through an index instead of scanning all mappings
  so far: expected linear work in the decoded mappings (overlapping and
  repeated ranges included), where it was quadratic. Results and their order
  are unchanged. Measured with native release office-cli on the 11-page
  `docxcorp-reports-en-015012bf8890.docx` fixture (macOS ARM64, medians of 15
  interleaved runs on an otherwise idle machine, wall time including I/O):
  DOCX to PDF about 0.97 s -> 0.50 s and DOCX to SVG about 0.54 s -> 0.06 s;
  the scan dominated both profiles (loading the fonts' faces during layout).

### moonbitlang/pdflite [0.2.1]

- Enable the `cmd/pdflite` CLI on Wasm for the default `moonx` launcher, while
  retaining native support. Run the CLI Cram suite on both backends in CI.
- Align the CLI version string with the module version and document the
  published launcher in the README and CLI skill.
- Remove redundant CLI whitebox tests and their test-only imports; retain
  command-line coverage in the Cram suite.

### moonbitlang/pdflite [0.2.0]

- **BREAKING**: Moved the standalone PDF→Markdown CLI from
  `moonbitlang/pdflite/markdown/cmd` to the new `moonbitlang/pdf2md` module.
  The `moonbitlang/pdflite/markdown` library package is unchanged.

### moonbitlang/pdf2md [0.1.0]

- New module: the standalone PDF→Markdown CLI, a thin wrapper over
  `moonbitlang/pdflite/markdown`.
