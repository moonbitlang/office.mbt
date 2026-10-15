# Changelog

Breaking and notable changes for the published modules in this workspace.
Entries are grouped by module and by the version they ship in; `Unreleased`
covers changes that have landed on `main` but are not yet published.

### moonbitlang/pagelayout [Unreleased]

- DOCX body inline pictures now occupy their source position in the paragraph,
  participate in wrapping and line height, and paginate with their text instead
  of appearing in a separate block after it. Oversized pictures scale to the
  paragraph measure.
- **API:** adds `Block::ParagraphWithImages`, `Block::paragraph_with_images`,
  `paragraph.InlineImage`, and `layout_paragraph_with_images`. Consumers matching
  every `Block` variant must handle the new variant. Existing paragraph inputs
  and `layout_paragraph` remain supported.
- Body content controls retain their displayed paragraphs/tables. Unsupported
  floating drawings, nested tables, section breaks, notes, math, text boxes and
  alternate content are reported through `DocxDocument.unsupported`, while
  deleted and historical property content does not trigger false warnings.
- Inline image blocks in page furniture retain coordinates and dynamic page
  field offsets. DOCX table-cell and header/footer image reading, floating text
  wrapping, nested tables and multiple section geometry remain unsupported.

### moonbitlang/mbtexcel [Unreleased]

- HTML previews preserve two-color linear gradient direction, border weight and
  CSS line styles (dash-dot variants approximate dashed), combined underline/strike, and resolved theme/indexed colors
  with tint. Invalid colors and unsupported path gradients remain omitted.
- `style_css` accepts optional workbook context for theme/indexed colors.
- Frozen worksheets expose nonnegative `data-freeze-rows` and
  `data-freeze-columns` on their section for browser consumers. Split panes do
  not masquerade as frozen panes.

### moonbitlang/pdflite [0.4.0]

- **BREAKING** (builds that use flate 0.8 elsewhere): requires
  `moonbit-community/flate` 0.9.0, which renames API of 0.8.5, and a build
  has one version of flate. Whatever else in a build uses flate must be on
  0.9.0 too. Of this workspace that is moonbitlang/ooxml 0.1.0, mbtexcel
  0.3.0, docx2html 0.7.0, pptx 0.1.0, pagelayout 0.8.0, office-lib 0.7.0
  and office 0.3.0, released together with this version: mbtexcel 0.2.1,
  docx2html 0.6.1, office-lib 0.6.2 and pagelayout 0.7.1 do not compile
  with flate 0.9.0. pdflite's own API is what it was.

- Depends on `moonbit-community/flate` 0.9.0 (from 0.8.5), as does every
  other module of the workspace that uses flate (ooxml, docx2html,
  mbtexcel, office-lib, office, pagelayout, pptx). The compressed bytes
  are what 0.8.5 wrote, so every PDF is byte for byte what it was: the
  tests that pin them pass unchanged (`flate/pdf_flate_pins_wbtest.mbt`:
  eleven kinds of stream at the ten levels and 760 outputs around the
  edges of the output window; the vectors of
  `flate/pdf_flate_determinism_wbtest.mbt`; the 34 documents of
  `export/text_random_test.mbt`; docx2html's `commented.docx` and
  mbtexcel's large workbook), and so do 2651 files of this repository
  (71 MB) at level 6 and 1351 of them at every level, compressed by both
  versions. What the decoder makes of damaged input is unchanged too
  (20 185 damaged streams, `flate/pdf_flate_pins_wbtest.mbt`). flate
  0.9.0 alone, on the 128 streams of a 117-page document (6.5 MB), native:
  compressing takes 10 % fewer instructions (377 to 338 million),
  decompressing 65 % fewer (506 to 176 million).

- Flate streams are compressed and decompressed with less copying; the
  bytes and the errors are what they were. The encoder's output was
  drained into a window of 32 KiB and copied from there byte by byte: the
  encoder now writes into the free end of one array (an array that the
  package keeps for the first 32 KiB, a larger one of the call's own
  beyond that), and the result is one copy of what it wrote. The
  compressed bytes cannot change with this: the stream of the streaming
  encoder does not depend on the windows it is drained into. The decoder
  was a `@zlib.Decoder` per stream, which takes its input 64 KiB at a
  time and copies what a step leaves, with the output copied byte by
  byte. A stream that is complete, right and within the output limit is
  now decoded by one raw inflater that the package keeps and resets, on
  the input as it is, under the package's own reading of the two bytes of
  zlib header and of the Adler-32, into one array the same way. Anything
  else (damage, a cut stream, an output over the limit) is decoded again
  by the loop that was the decoder before, so which error it is, and
  whether it is the limit or the damage where a stream has both, cannot
  differ from what it was; damaged input costs twice.
  `flate/pdf_flate_reuse_wbtest.mbt` holds the two decoders against each
  other. On the 128 streams of a 117-page document (6.5 MB), native, with
  flate 0.9.0: compressing 338 to 329 million instructions (-3 %),
  decompressing 176 to 75 million (-58 %); from the release with flate
  0.8.5 that is -13 % and -85 % (26 to 24 ms and 73 to 7 ms). The
  one-shot `@zlib.compress` would be faster still and its streams
  smaller, but they are other bytes, so it is not used: every PDF would
  change.

### moonbitlang/pagelayout [0.8.0]

- **BREAKING** (builds that use flate 0.8 elsewhere): requires
  `moonbit-community/flate` 0.9.0 (0.7.1 was published on 0.8.1), and with
  it moonbitlang/docx2html 0.7.0 (from 0.6.1) and moonbitlang/pdflite 0.4.0
  (from 0.3.2); see pdflite 0.4.0 above for what that asks of a build.
  pagelayout's own API and its pages are what they were: `@docx.read_docx`
  states its ZIP limits with flate's renamed `ReadLimits`, the same numbers.

### moonbitlang/pdf2md [0.1.2]

- Built on moonbitlang/pdflite 0.4.0 (from 0.2.2), so on flate 0.9.0. The
  command line is what it was.

### moonbitlang/pdflite [0.3.11]

- `export`: the host of a document can keep the compressed content streams
  between documents. krilla memoizes `deflate_encode_memoized` by the bytes
  of the stream (`comemo`), which is what makes the next export of a
  document cheap whose pages are mostly what they were; the package keeps
  nothing between documents, no table and no key. `Document::new_with(
  settings, memo=..)` takes a `Memo`, made by `Memo(deflate=..)` of a
  lookup: a function that is handed the data of a stream and the package's
  compression and returns the compressed data, computed now or kept from
  an earlier document. It is asked for what krilla compresses with
  `deflate_encode_memoized` (the content streams of pages, form XObjects,
  tiling patterns and Type 3 glyphs, ToUnicode CMaps and the PostScript
  functions of gradients, where content streams are compressed) and never
  for data without a byte; binary data (font programs, images, profiles,
  embedded files) is compressed for every document as before. What a
  lookup returns is written as it is and not checked: it must be what the
  compression it was handed returns for that data. The compressor is
  the package's own for every stream, so a document is byte for byte the
  same with a host whose lookup keeps to that, with `Memo()` and without a
  `memo`, and ordinary calls are unchanged. (`Document::new_with` has an
  optional parameter now: code that passes the function itself as a value
  needs a closure.) In typst.mbt, which keeps the streams by the hash of
  their bytes, an export of `bench/longer.typ` whose pages are what they
  were goes from 1114 to 773 million instructions (-31 %); a first export
  pays 2 % for the hashes.
- `export`: the host of a document can keep the subsets of its fonts
  between documents. krilla memoizes `subset_font` by the font and the
  glyph remapper (`comemo`); `Memo(subset=..)` takes the lookup for
  it: a function that is handed the font, the glyph IDs that the document
  uses of it in the order of their numbers in the subset (the subsetter
  adds the components of composite glyphs), and the computation, and
  returns a `FontSubset` (the subset's font file, the number of its glyphs
  and the bounding box of their outlines, opaque), computed now or kept
  from an earlier document. The result is a function of the font's data,
  index and variation coordinates and of the glyph IDs. An error of the
  computation is raised through the lookup. Without the lookup every font
  is subset for every document, as before, and the files are the same
  bytes either way. In typst.mbt a repeated export of `bench/showcase.typ`
  (thirteen font programs) goes from 135 to 63 million instructions
  (-53 %), `bench/long.typ` from 187 to 152 (-19 %).

### moonbitlang/pdflite [0.3.10]

- `export`: drawing text is faster, and a document is byte for byte what it
  was (for a caller whose colour-glyph hook is a function of the glyph, see
  below). In typst.mbt the export of `bench/longer.typ` (415 000 glyphs in
  36 000 runs) goes from 2471 to 1427 million instructions (-42 %),
  `bench/long.typ` from 526 to 318 (-40 %), and a document of Arabic and
  Hebrew text from 2854 to 1590 (-44 %). The time was in what a glyph
  and a run of glyphs allocated and asked again and again, not in what is
  written:
  - `FontContainer::add_glyph`, which is called three to four times per
    glyph, asked the colour-glyph hook and remapped the glyph each time and
    returned a tuple. It keeps the CID of a glyph (krilla's `cid_cache`,
    dense by glyph ID) and returns a value type. So `ColorGlyphs.is_color`
    is asked once per document about a glyph that is not a colour glyph,
    until the font is given another hook (`Font::set_color_glyphs`); it was
    asked every time. It must be a function of the glyph ID, and it must
    not write to the glyphs that are being drawn, which are read in place
    now (they were copied first).
  - The check whether a run needs `/ActualText` spans, the grouper and the
    clamp of cluster ranges allocate nothing per glyph, and neither does
    the segmentation of a run that needs spans (right-to-left text, glyphs
    that share a cluster); what a run allocates is its spans. A run of
    text makes no closures or cells of its own (about twenty objects per
    run before).
  - The `TJ` array of a run is written as it is encoded, through a scratch
    buffer of the content builder (krilla's), instead of built as objects
    first. The advance widths that the font gave are kept per glyph for
    the document (asking the font was three allocations and a walk through
    `hmtx` and `HVAR` for every glyph shown).
  - Numbers: the digits by divisions by the constant ten, small integral
    values first; names and operators by code unit; integers and
    references (`12 0 R`) without a string each.
  - `Transform`, `Point` and `Glyph` are value types (`#valtype`). Their
    interface is unchanged; on native, `physical_equal` of two of them is
    always false.
  No public signature of the package changes. What a caller still pays per
  glyph is its own: `Glyph.location` is an option of a `UInt64`, an
  allocation where it is `Some`.
- `export`: the structure tree is serialized without a string key per
  piece of marked content: the parent of marked content is found in a
  table by page and marked content ID instead of in a map by a string of
  the two, structure element IDs by their bytes instead of by their hex
  digits, and the attribute dictionaries of an element are started only
  for the owners it has attributes of. The files are the same bytes. In
  typst.mbt the export of `bench/longer.typ` (5222 structure elements,
  13 930 pieces of marked content) goes from 1206 to 1134 million
  instructions (-6 %).
- `export`: the file is written without a string per object (the header
  of an object and its offset in the cross-reference table are written as
  digits, the dictionary of a stream entry by entry instead of from a
  filtered copy). The files are the same bytes; `bench/longer.typ` in
  typst.mbt: 1134 to 1125 million instructions (-0.8 %).
- `export`: the ICC-based sRGB and sGrey colour spaces of a document
  without device colour spaces are found without a key: every solid fill
  asked for one through the cache of shared objects (a string hashed, a
  closure and an option made, per run of text). The files are the same
  bytes; `bench/longer.typ` in typst.mbt: 1125 to 1114 million
  instructions (-0.9 %).

### moonbitlang/pdflite [0.3.9]

- `export`: an image can keep its compressed samples. `Image::deflated`
  returns the image with its `Samples` as `ImageData::Deflated`, the zlib
  streams of the colour samples and of the alpha channel, compressed as
  `Document::finish` compresses them; a document that is given such an image
  writes the streams as they are, and is byte for byte the document that
  the image with `Samples` gives. A caller that exports again and again
  (an export after every edit) keeps the returned image and pays for the
  compression of an image once instead of once per document; it also need
  not keep the samples. This is what krilla's images do (`SampledRepr`).
  There is no table of images in the package and nothing to evict: what is
  kept is the value the caller holds, and what a document adds (the colour
  space, the profile's stream, `/Interpolate`, the mask's reference,
  validation) is made for every document. A JPEG and the image data of a
  PNG, which are embedded as they are, and samples without a byte are
  returned unchanged. `Deflated` data that does not start as a zlib stream
  (samples that were not compressed) makes `Document::finish` raise an
  `ImageError`. `ImageData` gains the case (breaking for code outside the
  package that matches on all cases of `ImageData`; building an `Image` is
  unchanged).

### moonbitlang/pdflite [0.3.8]

- `export`: a real number is written with the digits pdf-writer writes. The
  shortest digits of the `f32` are now ryu's (a port of its `f2d`): a value
  exactly halfway between two shortest decimals goes to the even one
  (`142.203125` is written `142.20312`, it was `142.20313`; 487 of the
  100 000 values of the previous test change, each in its last digit), and
  an integral value beyond the range of `i32` and below 1e12 ends in `.0`
  (`10000000000.0`), as ryu writes it. `export/oracle` generates
  `real_oracle_wbtest.mbt`, what the pdf-writer crate writes for 8876
  values; the one value that is written differently on purpose is 2^31
  (`format_real`).

### moonbitlang/pdflite [0.3.7]

- PNG colour keys: `pdf_read_png` reads a greyscale or truecolour PNG's
  `tRNS` chunk as `PdfPNG.transparency` (`PdfPNGColourKey`, the transparent
  colour's samples), and the image built from it gets that colour's `/Mask`
  range (`[g g]`, `[r r g g b b]`) instead of being drawn opaque. `PdfPNG`
  gains the field (breaking for code that constructs a `PdfPNG` literal).
- PNG palette transparency: a palette image whose `tRNS` makes an entry
  transparent is read (`PdfPNG.transparency` is `PdfPNGPaletteAlpha`, the
  entries' alpha) instead of refused, and the image built from it gets an
  `/SMask` of each pixel's alpha, at any index depth, interlaced or not.
- 16-bit PNGs with an alpha channel (greyscale or truecolour) are embedded,
  their two-byte samples split into a 16-bit image and a 16-bit `/SMask`,
  instead of being refused.
- PNG images raise the document to the PDF version they need: 1.3 for a
  colour key, 1.4 for a soft mask (an alpha channel's or a palette's), 1.5
  for 16-bit samples.
- A PNG with alpha (a channel, or a palette's) whose image data is short of
  its width and height is refused (`BadPNG`) rather than given a made-up
  mask, and `pdf_read_png` refuses a PNG of zero width or height, which PNG
  has not.
- A predictor row (`/Columns` × `/Colors` × `/BitsPerComponent`) of 2^31 bits
  or more raises `PredictorExpected` instead of wrapping, which could hang
  decoding.
- JPEG images: `pdf_image_object_of_jpeg_data` takes every JPEG `/DCTDecode`
  decodes — baseline, extended sequential or progressive, whatever markers it
  starts with (Adobe's CMYK files often have no JFIF header) — where it took
  only JFIF or Exif baseline files, and takes the colour space from the frame
  header: `/DeviceGray` for one component, `/DeviceRGB` for three,
  `/DeviceCMYK` for four, instead of always `/DeviceRGB`. A four-component
  JPEG with an Adobe (APP14) marker, whose samples Adobe writes inverted, gets
  `/Decode [1 0 1 0 1 0 1 0]`; three components named `R`, `G`, `B` with no
  JFIF or Adobe marker are RGB as they are, and get `/ColorTransform 0`.
  Lossless, arithmetic-coded, hierarchical and 12-bit JPEGs, and those of two
  components, raise `InvalidJPEGBlock`; a JPEG that ends before its frame
  header raises `JPEGDimensionsExpected` (it could raise `BadJPEGHeader`).
  `pdf_image_document_of_jpeg_data` makes a progressive JPEG's document PDF
  1.3.
- New `@codec.pdf_jpeg_info_view` (`PdfJpegInfo`): a JPEG's size, sample
  precision, components and their identifiers, frame type, JFIF and Adobe
  markers and whether it is hierarchical, read from any JPEG.
- Standard fonts kern by glyph name: `PdfStandardFont::kern_pairs_by_name`
  gives every pair of Adobe's Core 14 AFM files (2,705 for Helvetica),
  those of unencoded glyphs such as the accented letters included, which
  `afm_data().kerns` (pairs between glyphs with a character code, 289 for
  Helvetica) cannot hold; text re-encoded by glyph name (WinAnsi) kerns as
  Prawn and other AFM users do. The tables are generated by
  `scripts/gen_standard14_kern_pairs.mbtx` from the AFM files.
- `pdf_read_afm_kern_pairs` parses an AFM's pairs by glyph name.
- TrueType `cmap` formats 10, 12 and 13 (the 32-bit ones) are read, so
  `pdf_truetype_cmap_glyphs` and what is built on it (pagelayout's fonts)
  map the codepoints beyond the BMP — emoji, CJK extensions — that a font
  has, instead of leaving them `.notdef`.
- Reading a `cmap` is bounded: a font whose tables, segments or encoding
  records map the same ranges again and again is read until every codepoint
  has been mapped eight times over, not without end.

### moonbitlang/pdflite [0.3.6]

- Faster PDF export (typst.mbt: `bench/long.typ` to PDF 296 -> 255 ms,
  `bench/longer.typ` 1.39 -> 1.24 s). `pdflite/export` writes reals
  directly into the output buffer with exact table powers of ten instead of
  calling `@math.pow` about a dozen times per number (bit-identical to the
  previous `pow`-based search, checked on 100k values on every backend),
  keeps ToUnicode entries and the subsetter's glyph remapping in dense
  arrays instead of hash maps, and avoids per-glyph string and byte copies
  when encoding glyph runs and names. Output bytes are unchanged.
- Flate streams reuse one `@zlib.Encoder` per compression level through
  the new `Encoder::reset` (flate 0.8.5), which avoids allocating and
  filling about half a MiB of encoder tables per stream; the output equals
  a fresh encoder's. The cached encoders stay alive for the process.
- Depends on `moonbit-community/flate` 0.8.5 (from 0.8.1). Its level-6
  parser changed in 0.8.4, so Flate streams (in PDFs, and in DOCX/XLSX
  packages written by the other workspace modules) can differ in their
  compressed bytes; decompressed content is unchanged. On typst.mbt's
  benchmarks PDFs change size by -0.07% to +0.33%. 0.8.5 compresses about
  25% faster than 0.8.4 with identical output.

### moonbitlang/pdflite [0.3.5]

- New package `moonbitlang/pdflite/subsetter`: a port of the Rust
  `subsetter` crate 0.2.6 (with its `variable-fonts` feature),
  byte-identical with the crate on its oracle tests, on a sweep over
  local fonts and on single-byte variants of the test fonts
  (`pdflite/subsetter/oracle`). It subsets TrueType and CFF fonts with
  new, consecutive glyph IDs (CFF fonts become CID-keyed with an identity
  charset), instantiates variable fonts (`gvar`, `avar`, `HVAR`, `VARC`
  variable composites) and converts CFF2 fonts to TrueType. Outlines and
  variations come from internal ports of read-fonts 0.39.2 and skrifa 0.42.1
  (`pdflite/internal/*`, from typst.mbt, extended with variations and CFF2).
- `pdflite/export` embeds fonts like krilla: subsets made with
  `pdflite/subsetter` whose CIDs are the new glyph IDs (content streams,
  `/W`, `/ToUnicode` and validation errors use them), CFF subsets as
  `/FontFile3` `/CIDFontType0C` programs and TrueType subsets (also of CFF2
  fonts) as `/FontFile2` without `/Length1`. CFF fonts used to be embedded
  whole and TrueType fonts with all glyph IDs; PDFs with large fonts shrink
  accordingly (typst.mbt's showcase, with a few Chinese characters in
  PingFang SC, from 13.4 MB to 1.6 MB). Also like krilla: subset tags are
  SipHash-1-3 hashes of the glyph remapping, `/W` uses the `first last
  width` form with `f32` arithmetic, `/FontBBox` is the union of the
  outlines of the subset, the descriptor's `/Ascent` and `/Descent` are the
  OS/2 typo metrics, the PostScript name is the first name ID 6 record, a
  font with a readable CFF table is embedded as a CFF font, PDF versions
  before 2.0 get a `/CIDSet`, the ToUnicode CMap has `/Type /CMap /WMode 0`
  and an uppercase code space range. `Font::new_variable` creates a font at
  variation coordinates (advances from `HVAR`/`gvar`, cap height with
  `MVAR`), which the subset instantiates.
- `pdflite/export`: `Font::new` accepts fonts like krilla: it requires a
  readable table directory and `head` table (with nonzero units per em);
  tables are looked up like read-fonts (null or out-of-bounds records are
  missing tables), `hhea`/`maxp` are optional (they used to make
  `Font::new` fail) and the glyph count is skrifa's (`maxp`, or the charset
  of a name-keyed CFF font without `post` names). A font whose CFF
  table can't be read has no outlines, a broken `loca` table makes
  subsetting fail (`FontError`), advances always come from skrifa's glyph
  metrics, and non-finite variation coordinates are subset as 0, like in
  krilla.

### moonbitlang/pdflite [0.3.4]

- `pdflite/export`: `Surface::draw_external_xobject` draws form XObjects
  that a callback writes once per key and document (e.g. pages of other
  PDFs extracted by hayro-write; see `ExternalXObject` for the contract),
  and `Surface::page_tree_ref` gives such objects their `/Parent`. Stream
  dictionaries get exactly one `/Length`, and reals are written like
  pdf-writer writes `f32`s (shortest digits, no exponents) instead of with
  at most five decimals (#593).
- `pdflite/export`: `ImageData::Png` embeds the `IDAT` data of
  non-interlaced PNG images without alpha as is, with a PNG predictor
  (grayscale, RGB and indexed images, krilla's `Repr::Png`). Invalid
  combinations of samples, bit depth and palette, and 16-bit samples
  before PDF 1.5, make `Document::finish` raise an `ImageError` (#594).

### moonbitlang/pdflite [0.3.3]

- The content operator state follows ISO 32000-1 where it had followed
  cpdf's cpdfcontent (#595): the initial stroke and fill colour is black
  (DeviceGray 0.0, was 1.0); `gs` applies the ExtGState it names
  (`/ExtGState /<name>`, was the `/ExtGState` resource dictionary itself, so
  a real `gs` never took effect); `/SMask` sets `soft_mask` and `/None`
  clears it (was stored as `halftone`).
- TrueType subsets now carry correct OpenType table directory search fields
  (`entrySelector = floor(log2(numTables))`, `rangeShift = numTables * 16 -
  searchRange`). The previous values, ported from cpdf, were wrong for every
  table count other than 1 (#591). Embedded subset font bytes change; checksums
  (including `recompute_head`'s `checkSumAdjustment`) remain valid.
- New package `moonbitlang/pdflite/export`: a PDF writer modelled on
  krilla (the parts Typst's PDF exporter uses). A `Document` has pages
  whose `Surface` draws paths (device, ICC-based and separation colors,
  gradients, tiling patterns), clip paths, opacity, blend modes, masks,
  transforms, glyph runs (TrueType and CFF fonts as CID-keyed `Type0`
  fonts with `ToUnicode` maps, color glyphs through Type 3 fonts) and
  raster images (samples with alpha, JPEG passthrough). Documents carry
  link annotations, outlines, named destinations, page labels, metadata
  (info dictionary and XMP), embedded files and a tag tree, and are
  checked against PDF/A and PDF/UA (`ExportError::Validation`). Known
  limitations: TrueType fonts are subset by emptying unused glyphs and
  CFF fonts are embedded whole (as CID-keyed CFF); CFF2 fonts are
  embedded as OpenType font programs (krilla converts them to CFF); there
  is no CMYK output profile and no `CIDSet`. See
  `pdflite/export/README.mbt.md`.
- Depend on moonbitlang/x 0.5.5.

### moonbitlang/pagelayout [0.7.1]

- An `ImageItem` whose `mime` is `application/pdf` draws a page of the
  PDF in `data` as vector graphics, scaled to the item's box like a
  raster image: the first page, or the one a `page` parameter names
  (`application/pdf; page=2`). `render_pdf` imports the page as a Form
  XObject (pdflite's new `PdfDocument::import_page`), reading each
  distinct PDF (and walking its page tree) once per render, and once per
  `unembeddable_images` call, and importing each (bytes, media type)
  once. A PDF that cannot be read, a page it does not have, or a `page`
  parameter that is not a positive integer is skipped like any other
  image the backend cannot draw, and `unembeddable_images` reports it
  (`PDF this backend cannot read`, `PDF without the page to draw`, `PDF
  page this backend cannot import`). The SVG backend is unchanged: it
  embeds the bytes as a data URI, which browsers do not draw for a PDF.
  Requires moonbitlang/pdflite 0.3.2.

### moonbitlang/pdflite [0.3.2]

- Page tree walks no longer recurse. Counting pages (`endpage`,
  `pages_of_pagetree_quick`, which the reader uses while loading),
  `pages_of_pagetree`, `page_reference_numbers` and the page extraction
  helpers share one walk that keeps a frame per level of the path (its
  space grows with the tree's depth, not its width) and resolves each kid
  when it reaches it. Inherited-attribute lookups climb `/Parent` in a
  loop of their own, bounded by the 10,000-level depth limit.
- The shared walk raises `PageTreeExpected`:
  - for a node, or a `/Kids` array held by reference, that is its own
    ancestor (a page tree node listing itself, or a `/Kids` array holding
    a direct node that lists the same array), where the recursive walks
    overflowed the stack or looped;
  - for a tree deeper than 10,000 levels, as before;
  - once it has taken more than `2 * object_count + 16` steps.
- A step is the root, each kid examined (visited or skipped) and each
  `/Kids` array held by reference that a branch expands. Which kids are
  skipped depends on the function: counting pages and `pages_of_pagetree`
  reject kids that do not resolve to dictionaries, as before;
  `page_reference_numbers` and the extraction helpers skip null kids and
  kids that are not references, and `pdf_page_reference_numbers_unordered`
  keeps the numbers of references that do not resolve.
- The walk's own overhead is proportional to its steps; what a caller does
  per node (reading dictionaries, copying pages) is not metered by the
  limit. A well-formed tree (every kid a reference to a node object of its
  own, each `/Kids` array appearing once) takes at most `object_count`
  steps.
- The limit stops trees that sharing multiplies (each level listing the
  level below twice, through references or through direct nodes in a
  referenced array), and repeated scans of a shared `/Kids` array of
  skipped entries (1,000 branches sharing an array of 10,000 nulls).
- It also rejects some documents the recursive walks accepted: a page or
  node listed by many parents, or many times by one, or more skipped kids
  than the allowance leaves room for (a page listed 40 times in a
  two-object document). A node shared by a few parents is still visited
  once per parent, and inherits from each.
- `PdfDocument::import_page(source, page_number)` imports a page of
  another document as a Form XObject. Like prawn-templates (which
  asciidoctor-pdf uses), the page and the objects it needs are copied;
  prawn-templates copies the page object graph as a page, this builds a
  Form XObject that can be drawn anywhere, scaled like an image. The
  form's `/BBox` is the page's visible box (its media box clipped to its
  crop box, PDF 32000-1 §14.11.2), its `/Matrix` turns that box upright
  by the page's `/Rotate` with its lower-left corner at the origin and
  scales it by its `/UserUnit`, and it carries the page's resources and
  transparency `/Group`, inherited attributes included. A single content
  stream keeps its filters and encoded bytes; several are decoded, joined
  and Flate-compressed. Every object the form reaches is copied under a
  new object number (streams with their encoded data); references to the
  source's page tree nodes, or to any other dictionary whose resolved
  `/Type` is `/Page` or `/Pages`, become `null`. The source document is
  not modified. Everything is copied before the target changes, so a
  failed import leaves the target as it was: no object added, no object
  number taken, nothing in its event log. Annotations and
  document-level data are not imported. It returns a `PdfImportedPage`:
  the form's object number and the size it fills, `(0, 0)` to
  `(width, height)`.
- `PdfPageSource::new(document)` reads a document's page tree once for
  importing (`page_count`, `page_display_size`, and the `source` of
  `import_page`). It raises `PageTreeExpected` for a page tree with a
  cycle (or a node shared by two parents) or a malformed node, and
  `HardError` for an encrypted document, as prawn-templates refuses one.
  `page_display_size(page_number)` is the size a viewer shows a page at
  (and `import_page` reports): the visible box scaled by `/UserUnit`,
  width and height swapped for `/Rotate` 90 or 270. Both raise
  `BadPageSpecification` for a page the source does not have; the
  rectangle parser's errors or `BadRectangle` for a malformed box or an
  empty visible box (a crop box outside the media box is not widened to
  the media box); `PageRotationExpected` for a `/Rotate` that is not a
  multiple of 90; and `BadNumberArgument` for a `/UserUnit` that is not
  a positive number. Inherited attributes follow PDF 32000-1 §7.7.3.4; an
  entry whose value is null, directly or through a reference, is absent
  and inherits. Both walks use explicit worklists, not recursion: the
  page tree walk visits each node and each `/Kids` array held by
  reference once, and a second visit raises `PageTreeExpected`, so a
  cycle ends it; the walk over what a page reaches visits each object
  once. A copied object's direct nesting (arrays and dictionaries inside
  it) is limited to 256 levels, past which `import_page` raises
  `HardError`.

### moonbitlang/pagelayout [0.7.0]

- Embedded TrueType subsets now carry their own `head` bounding box, the
  union of the boxes in the headers of the glyphs they keep, instead of the
  whole font's, and valid table checksums and `checkSumAdjustment`, as
  TTFunk (Prawn, asciidoctor-pdf) writes a subset. Poppler derives its
  glyph cache cells from the font's box, so the whole font's box made
  pagelayout's text anti-alias differently from Prawn's. The embedded font
  bytes change. On the office-cli DOCX fixtures, extracted text, layout and
  SVG output were unchanged and PDF rasters differed only along glyph edges
  (about 0.05–0.09% of pixels). The recomputed box trusts the glyph
  headers: a font whose headers underreport its outlines' extent is not
  corrected. Uses pdflite's new `recompute_head` option, so this release
  of pagelayout requires moonbitlang/pdflite 0.3.1.
- **BREAKING** (exhaustive matches only): `InitialZoom` has two new
  variants, `FitHAt(top~)` and `FitVAt(left~)`, an open action at a given
  position: `[page /FitH t]` with the window's top `top` points below the
  first page's top edge (measured like a page item's `y_pt`; negative is
  above the page), and `[page /FitV left]`. `FitH` and `FitV` are
  unchanged (`FitHAt(top=0)` and `FitVAt(left=0)`). asciidoctor-pdf takes
  the first page's `/FitH` top from the height of the page that is current
  when it sets the open action (before any back cover is added), which is
  `FitHAt(top=first_height - current_height)`. `render_pdf` raises
  `RenderOptionError` for a position that is not finite. Code that
  constructs `InitialZoom` is unaffected; code that matches it exhaustively
  must handle the new variants.

### moonbitlang/pdflite [0.3.1]

- `pdf_truetype_subset_font` takes `recompute_head? : Bool = false`. With
  `recompute_head=true` the subset's `head` table is written as TTFunk 1.7
  writes a subset's: the bounding box (`xMin`, `yMin`, `xMax`, `yMax`) is
  the union of the boxes in the headers of the glyphs the subset keeps,
  simple and composite, every table's directory checksum is recomputed,
  and `checkSumAdjustment` makes the font sum to `0xB1B0AFBA`. Only glyphs
  with an empty `loca` range are skipped; as an exception kept for parity
  with TTFunk 1.7.0, a glyph that has data but `numberOfContours == 0`
  still contributes the box stored in its header, where OpenType's `head`
  box covers only glyphs with contours. The box is all zero when every
  kept glyph has an empty `loca` range. The default keeps cpdf's output,
  the source font's `head` and checksums, byte for byte.

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

### moonbitlang/ooxml [0.1.0]

- First release on Mooncakes, on `moonbit-community/flate` 0.9.0.
  moonbitlang/docx2html 0.7.0, pptx 0.1.0, office-lib 0.7.0 and office
  0.3.0 depend on it.
- Add shared OPC, XML, and URI packages below the document engines. Extract
  DOCX's URI rules and preserve its existing public entry points as re-exports.
- Use flate for ZIP I/O and `Milky2018/xml@0.5.0` for namespace-aware XML reading.
  Version 0.5.0 fixes the reported attribute-whitespace serialization issue;
  delegate writing and escaping to its checked Writer through a QName and
  incremental-attribute adapter. `XmlWriter::xml_declaration()` now raises
  `XmlError`; malformed output is rejected through `WriterMisuse`.

### moonbitlang/docx2html [0.7.0]

- **BREAKING**: requires `moonbit-community/flate` 0.9.0 (0.6.1 was
  published on 0.8.1), whose `@zip.Archive` is in this module's API
  (`docx`, `opc`, `splice`, `zip`): code that makes or reads such an
  archive with flate's 0.8 names moves to the 0.9.0 names with this
  release. Requires moonbitlang/ooxml 0.1.0, a new dependency.

- **BREAKING**: `RunProperties` has a field of another type and two new
  ones: `font_size` is a `Double?` in points (it was an `Int?`, so
  `w:sz="21"` reads as 10.5), and `font_size_cs` (`w:szCs`) and `color`
  are new. A literal record must give the new fields, and an `Int`
  variable that is passed as `font_size` needs `.to_double()`; the
  README has the rest ("Font sizes").

- Preserve run text colors in HTML conversion and DOCX writing, including
  document defaults, paragraph/character style inheritance, and theme colors
  with tint/shade. Add `RunProperties.color` and the optional `color` argument
  to `run_properties`; literal run-property records must supply the new field.

- Depend on `ooxml/uri` for OPC part names and relationship URI rules.
  Existing `docx2html/opc` functions and registry types remain available through
  re-exports; DOCX-specific validation and resource budgets remain in DOCX.

- Depend on flate 0.9.0 (from 0.8.5). Its ZIP reader checks the CRC-32 of
  every entry while it reads and its error does not say which entry failed,
  so `validate_docx_package` reports a package with such an entry as the
  one finding `entry data does not match its stored CRC-32`; with 0.8.5
  the finding ended with the name of the entry and the validation went on
  to the other findings. `validate_docx_archive` is unchanged.
  `max_zip_total_preserved_source_bytes` is compared with the length of
  the package now (0.8.5 counted the records it copied): with the default,
  the package limit and a comment, nothing changes; a caller's lower limit
  can now refuse a package with bytes between its records, and no longer
  refuses one for records that overlap. Packages that are written are
  byte for byte what they were (the tests that pin them pass unchanged),
  with one exception that is flate's: a package whose central directory
  lists the entries in another order than they are stored keeps the order
  of its directory when it is written with its records preserved, edited
  or not, where 0.8.5 wrote the directory in the order of the entries
  (checked with both versions on an archive of two entries with its
  directory swapped).

### moonbitlang/pptx [0.1.0]

- First release on Mooncakes, on `moonbit-community/flate` 0.9.0 and
  moonbitlang/ooxml 0.1.0. moonbitlang/office-lib 0.7.0 depends on it.
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

### moonbitlang/mbtexcel [0.3.0]

- **BREAKING**: requires `moonbit-community/flate` 0.9.0 (0.2.1 was
  published on 0.8.1), whose `@zip.Archive` is in this module's API
  (the root package and `xlsx`): code that makes or reads such an archive
  with flate's 0.8 names moves to the 0.9.0 names with this release.

- Depend on flate 0.9.0 (from 0.8.5). Workbooks that are written are byte
  for byte what they were (the large workbook of `regression_test.mbt`
  among them), and a package with an entry that fails its CRC-32 is
  `InvalidPackage(msg="ZIP entry CRC mismatch")` as before (the ZIP reader
  finds it now, before the other checks of the archive).
  `ReadLimits`' `max_total_preserved_source_bytes` is compared with the
  length of the package now (0.8.5 counted the records it copied): with
  the default, the package limit and a comment, nothing changes; a lower
  limit can now refuse a package with bytes between its records, and no
  longer refuses one for records that overlap.

### moonbitlang/office-lib [0.7.0]

- **BREAKING**: requires `moonbit-community/flate` 0.9.0 (0.6.2 was
  published on 0.8.1), whose `@zip.Archive` is in this module's API (the
  root package, `docx`, `raw`, `transaction`), and with it
  moonbitlang/mbtexcel 0.3.0 (from 0.2.1) and docx2html 0.7.0 (from
  0.6.1). Requires moonbitlang/ooxml 0.1.0 and pptx 0.1.0, new
  dependencies.

- **BREAKING** (exhaustive matches only): `DocumentFormat` has a new
  variant, `Pptx`.

- Add the `moonbitlang/office-lib/pptx` SDK package. Existing-deck mutation,
  batch authoring, selectors, and rendering remain outside this initial scope.

- Depend on flate 0.9.0 (from 0.8.5). Its ZIP reader checks the CRC-32 of
  every entry while it reads and its error does not say which entry failed:
  `detect_format` raises `InvalidPackage("entry data does not match its
  stored CRC-32")` without the name of the entry, and the bounded readers
  of `transaction` and `raw` report such a package as an unreadable ZIP
  package (they reported the detector's message, with the name).

### moonbitlang/office [0.3.0]

- Built on moonbitlang/office-lib 0.7.0 (from 0.6.2), docx2html 0.7.0
  (from 0.6.1), mbtexcel 0.3.0 (from 0.2.1), pagelayout 0.8.0 (from 0.2.1)
  and ooxml 0.1.0 (new).

- Add PPTX identification, slide outlines, slide/notes text extraction, and
  transactional one-slide creation to the unified Office CLI.

- Depend on flate 0.9.0 (from 0.8.5). A package with an entry that fails
  its CRC-32 is `office.invalid_package`, "invalid Office package: entry
  data does not match its stored CRC-32", without the name of the entry
  (flate's ZIP reader finds it now and does not say which entry it was).

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
