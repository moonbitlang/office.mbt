///|
// Page assembly: IR items to content operators, then to a PDF document.

///|
/// Convert an IR y (down from the page top) to a PDF y (up from the
/// page bottom).
fn flip(page_height : Double, y : Double) -> Double {
  page_height - y
}

///|
fn colour_of(c : @pagelayout.Color) -> (Double, Double, Double) {
  (c.r.to_double() / 255.0, c.g.to_double() / 255.0, c.b.to_double() / 255.0)
}

///|
/// The operand of one text-showing operator under construction: codes,
/// split by displacements wherever the IR's advance for a glyph differs
/// from the width the font dictionary declares for it.
///
/// Without the displacements a viewer spaces every glyph by its declared
/// width, so any layout that moves glyphs apart — justification widens
/// the spaces, most visibly — would be measured one way and painted
/// another. A run whose advances all match comes out as a plain `Tj`.
priv struct ShowText {
  parts : Array[@syntax.PdfObject]
  codes : Array[Byte]
  mut adjusted : Bool
}

///|
fn ShowText::new() -> ShowText {
  { parts: [], codes: [], adjusted: false, }
}

///|
/// Append one glyph's code, then move the pen by `extra_pt` beyond the
/// declared width (text space, points at `size_pt`).
fn ShowText::push(
  self : ShowText,
  code : Array[Byte],
  extra_pt : Double,
  size_pt : Double,
) -> Unit {
  self.codes.append(code)
  // TJ displacements are thousandths of text space; negative moves right
  let adjust = -extra_pt * 1000.0 / size_pt
  if adjust.abs() >= 0.005 {
    self.parts.push(PdfString(Bytes::from_array(self.codes)))
    self.codes.clear()
    self.parts.push(PdfReal(adjust))
    self.adjusted = true
  }
}

///|
fn ShowText::is_empty(self : ShowText) -> Bool {
  self.codes.length() == 0 && !self.adjusted
}

///|
/// The operator showing everything pushed so far; empties the builder.
fn ShowText::take(self : ShowText) -> @content.PdfContentOp {
  let op : @content.PdfContentOp = if self.adjusted {
    if self.codes.length() > 0 {
      self.parts.push(PdfString(Bytes::from_array(self.codes)))
    }
    Op_TJ(PdfArray(self.parts.copy()))
  } else {
    Op_Tj(Bytes::from_array(self.codes))
  }
  self.parts.clear()
  self.codes.clear()
  self.adjusted = false
  op
}

///|
/// The width, in points at `size_pt`, that a simple font's `/Widths`
/// declares for WinAnsi `code` — the same rounding `font_object` writes.
fn declared_simple_width(
  face : PdfFace,
  code : Int,
  size_pt : Double,
) -> Double {
  face.metrics.advance_pt(winansi_unicode(code), 1000.0).round() *
  size_pt /
  1000.0
}

///|
/// Emit one glyph run. The run is placed with `Tm` at its own origin and
/// drawn as a single string: `/Widths` in the font dictionary carries the
/// natural advances, and a `TJ` displacement corrects any glyph the layout
/// moved (see `ShowText`).
///
/// Characters WinAnsi cannot encode are dropped from the string but
/// still counted, so everything after them keeps its position.
fn emit_run(
  ops : Array[@content.PdfContentOp],
  run : @pagelayout.GlyphRun,
  face : PdfFace,
  resource : @core.PdfName,
  page_height : Double,
) -> Unit {
  if face.is_composite() {
    emit_run_composite(ops, run, face, resource, page_height)
    return
  }
  let show = ShowText::new()
  let mut segment_x = run.x_pt
  let mut pending_x = run.x_pt
  let baseline = flip(page_height, run.baseline_pt)
  let (r, g, b) = colour_of(run.color)
  fn flush(x : Double) -> Unit {
    if show.is_empty() {
      return
    }
    ops.push(Op_BT)
    ops.push(Op_Tf(resource, run.size_pt))
    ops.push(Op_rg(r, g, b))
    ops.push(Op_Tm({ a: 1, b: 0, c: 0, d: 1, e: x, f: baseline, }))
    ops.push(show.take())
    ops.push(Op_ET)
  }

  let mut i = 0
  while i < run.text.length() {
    let unit = run.text[i].to_int()
    // surrogate pairs are outside WinAnsi by definition
    let advance = run.advances_pt[i]
    match winansi_code(unit) {
      Some(code) => {
        if show.is_empty() {
          segment_x = pending_x
        }
        show.push(
          [code.to_byte()],
          advance - declared_simple_width(face, code, run.size_pt),
          run.size_pt,
        )
      }
      None => {
        // an unencodable character breaks the string; resume after it
        flush(segment_x)
        segment_x = pending_x + advance
      }
    }
    pending_x += advance
    i += 1
  }
  flush(segment_x)
}

///|
/// The codepoint starting at UTF-16 code unit `i`, with the index just
/// past it. The IR pairs one advance with each code unit and gives the
/// trail half of a surrogate pair advance 0, so a run walks by code unit
/// but encodes by character.
fn codepoint_at(text : String, i : Int) -> (Int, Int) {
  let unit = text[i].to_int()
  if unit >= 0xD800 && unit <= 0xDBFF && i + 1 < text.length() {
    let low = text[i + 1].to_int()
    if low >= 0xDC00 && low <= 0xDFFF {
      return (0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00), i + 2)
    }
  }
  (unit, i + 1)
}

///|
/// Emit one glyph run in a composite font. Every character encodes — a
/// codepoint the face lacks maps to glyph 0 rather than breaking the
/// string — so the whole run is one `Tj` (or `TJ`, see `ShowText`) of
/// two-byte CIDs placed by a single `Tm`.
fn emit_run_composite(
  ops : Array[@content.PdfContentOp],
  run : @pagelayout.GlyphRun,
  face : PdfFace,
  resource : @core.PdfName,
  page_height : Double,
) -> Unit {
  let show = ShowText::new()
  let mut i = 0
  while i < run.text.length() {
    let (codepoint, next) = codepoint_at(run.text, i)
    // Identity-H: the code is the glyph index itself
    let glyph = face.metrics.cmap.get(codepoint).unwrap_or(0)
    let mut advance = 0.0
    for j in i..<next {
      advance += run.advances_pt[j]
    }
    // the width `composite_font_object` declares: `/W` for glyphs the
    // face has, the 1000-unit default for .notdef
    let declared = if glyph == 0 {
      run.size_pt
    } else {
      face.metrics.advance_pt(codepoint, 1000.0).round() * run.size_pt / 1000.0
    }
    show.push(
      [(glyph >> 8).to_byte(), (glyph & 0xFF).to_byte()],
      advance - declared,
      run.size_pt,
    )
    i = next
  }
  if show.is_empty() {
    return
  }
  let (r, g, b) = colour_of(run.color)
  ops.push(Op_BT)
  ops.push(Op_Tf(resource, run.size_pt))
  ops.push(Op_rg(r, g, b))
  ops.push(
    Op_Tm({
      a: 1,
      b: 0,
      c: 0,
      d: 1,
      e: run.x_pt,
      f: flip(page_height, run.baseline_pt),
    }),
  )
  ops.push(show.take())
  ops.push(Op_ET)
}

///|
fn emit_rect(
  ops : Array[@content.PdfContentOp],
  rect : @pagelayout.RectItem,
  page_height : Double,
) -> Unit {
  // an IR rect is anchored at its top-left; PDF's is bottom-left
  let y = flip(page_height, rect.y_pt + rect.h_pt)
  match rect.fill {
    Some(colour) => {
      let (r, g, b) = colour_of(colour)
      ops.push(Op_q)
      ops.push(Op_rg(r, g, b))
      ops.push(Op_re(rect.x_pt, y, rect.w_pt, rect.h_pt))
      ops.push(Op_f)
      ops.push(Op_Q)
    }
    None => ()
  }
  match rect.stroke {
    Some(colour) => {
      let (r, g, b) = colour_of(colour)
      ops.push(Op_q)
      ops.push(Op_RG(r, g, b))
      ops.push(Op_w(rect.stroke_w_pt))
      ops.push(Op_re(rect.x_pt, y, rect.w_pt, rect.h_pt))
      ops.push(Op_S)
      ops.push(Op_Q)
    }
    None => ()
  }
}

///|
/// Render a page model to PDF bytes.
///
/// Families with bundled outlines are embedded as Type0 composite fonts
/// subset to the characters the document uses; the rest are declared with
/// widths from the bundled metrics but not embedded. See the module
/// comment in emit.mbt for why, and for what each choice costs.
///
/// Link regions become link annotations: a `#name` target jumps to the
/// named destination the `AnchorItem` called `name` defines, anything else
/// opens as a URI. `outline` becomes the document outline (bookmarks), and
/// `info` entries (`("Title", ...)`, `("Author", ...)`) the document
/// information dictionary; a date entry (`CreationDate`, `ModDate`) is
/// written as given, so pass it in PDF date form (`D:YYYYMMDDHHmmSS+HH'mm'`,
/// see `pdf_date`).
///
/// The rest shape the catalog and pages the way a viewer first sees them:
/// `initial_zoom` becomes an `/OpenAction` on the first page, `page_mode`
/// the `/PageMode` (by default `/UseOutlines` when there is an outline),
/// `display_doc_title` forces `/ViewerPreferences /DisplayDocTitle` (always
/// written when there is a title), `page_boxes` writes every page's crop,
/// bleed, trim and art boxes explicitly (equal to its media box) instead of
/// leaving them to their defaults, and a non-empty `page_labels` gives page
/// `i` the literal label `page_labels[i]`.
pub fn render_pdf(
  model : @pagelayout.PageModel,
  outline? : Array[OutlineEntry] = [],
  info? : Array[(String, String)] = [],
  initial_zoom? : InitialZoom,
  page_mode? : String,
  display_doc_title? : Bool = false,
  page_boxes? : Bool = false,
  page_labels? : Array[String] = [],
) -> Bytes raise {
  let document = @pdflite.pdf_document_empty()
  document.set_version(1, 7)
  let faces : Array[PdfFace] = []
  for spec in model.fonts {
    let family = @fonts.resolve_family(spec.family)
    faces.push({
      spec,
      metrics: @fonts.face(family, bold=spec.bold, italic=spec.italic),
      program: @fontoutlines.outline_sfnt(
        family,
        bold=spec.bold,
        italic=spec.italic,
      ),
      // decided below, once the document's character set is known
      composite: false,
    })
  }

  // one XObject per distinct image, for this document only. Keyed by
  // media type as well as bytes: the same bytes under a different type
  // are a different image as far as the reader is concerned, and reusing
  // an earlier decode would draw a picture the document did not ask for.
  let image_cache : Map[(Bytes, String), Int] = Map([])

  // Both font shapes subset the program they embed, and the character set
  // is also what decides which shape a font takes, so this has to be known
  // before any font object is written.
  let used_codepoints = collect_codepoints(model, faces.length())

  // A font goes composite only when its text needs codes WinAnsi cannot
  // express. Latin stays a simple font with an embedded program: that is
  // the smaller, more widely understood shape, and it keeps `/Widths`
  // rather than a `/W` array governing spacing.
  for index, codepoints in used_codepoints {
    let face = faces[index]
    faces[index] = { ..face, composite: needs_composite(face, codepoints), }
  }

  // one PDF font object per interned IR font, shared by every page
  let font_objects : Array[Int] = []
  for index, face in faces {
    font_objects.push(
      if face.is_composite() {
        // guaranteed by needs_composite: a font only goes composite when
        // it has a program to address glyphs in
        match face.program {
          Some(program) =>
            composite_font_object(
              document,
              face,
              program,
              index,
              used_codepoints[index],
            )
          None => font_object(document, face, index, used_codepoints[index])
        }
      } else {
        font_object(document, face, index, used_codepoints[index])
      },
    )
  }
  let pages : Array[@page.PdfPage] = []
  // (name, page index, x, y) of every anchor, in document order
  let anchors : Array[(String, Int, Double, Double)] = []
  for page_index, model_page in model.pages {
    let ops : Array[@content.PdfContentOp] = []
    let used : Array[Int] = []
    let images : Array[Int] = []
    let annots : Array[@syntax.PdfObject] = []
    for item in model_page.items {
      match item {
        Text(run) => {
          guard font_objects.get(run.font) is Some(number) else { continue }
          if !used.contains(number) {
            used.push(number)
          }
          guard faces.get(run.font) is Some(face) else { continue }
          emit_run(
            ops,
            run,
            face,
            font_resource_name(number),
            model_page.height_pt,
          )
        }
        Rect(rect) => emit_rect(ops, rect, model_page.height_pt)
        Image(image) =>
          match image_object(document, image, image_cache) {
            Some(number) => {
              if !images.contains(number) {
                images.push(number)
              }
              emit_image(
                ops,
                image,
                image_resource_name(number),
                model_page.height_pt,
              )
            }
            // a format pdflite cannot embed is skipped rather than
            // written as something a reader would reject
            None => ()
          }
        Link(link) => annots.push(link_annotation(link, model_page.height_pt))
        Anchor(anchor) =>
          anchors.push((anchor.name, page_index, anchor.x_pt, anchor.y_pt))
      }
    }
    let content = if ops.length() == 0 {
      []
    } else {
      // Page text compresses several-fold and was previously written
      // raw — the only uncompressed streams of any size in the file.
      // `only_if_smaller` keeps the rare page whose operators do not
      // shrink (a page holding one short line) stored plainly.
      [
        @pdflite.pdf_encode_stream_with_encoding(
          PdfStreamFlate,
          @pdflite.pdf_content_stream_of_ops(ops),
          only_if_smaller=true,
        ),
      ]
    }
    let box = fn() {
      @syntax.PdfArray([
        PdfReal(0.0),
        PdfReal(0.0),
        PdfReal(model_page.width_pt),
        PdfReal(model_page.height_pt),
      ])
    }
    let rest : Array[(@core.PdfName, @syntax.PdfObject)] = []
    if page_boxes {
      for key in ["/CropBox", "/BleedBox", "/TrimBox", "/ArtBox"] {
        rest.push((name(key), box()))
      }
    }
    if !annots.is_empty() {
      rest.push((name("/Annots"), PdfArray(annots)))
    }
    pages.push({
      content,
      mediabox: box(),
      resources: resources_of(used, images),
      rotate: Rotate0,
      rest: PdfDictionary(rest),
    })
  }
  let page_root = document.add_pagetree(pages)
  ignore(document.add_root(page_root, []))
  let document = add_navigation(
    document,
    model,
    page_root,
    anchors,
    outline,
    info,
    { initial_zoom, page_mode, display_doc_title, page_labels, },
  )
  @pdflite.pdf_write_document(document)
}

///|
/// How the first page fits the window when the document opens (the
/// `/OpenAction` destination): the whole page, its width, or its height.
pub(all) enum InitialZoom {
  Fit
  FitH
  FitV
}

///|
/// The catalog settings of `render_pdf` beyond navigation proper.
priv struct CatalogOptions {
  initial_zoom : InitialZoom?
  page_mode : String?
  display_doc_title : Bool
  page_labels : Array[String]
}

///|
/// A PDF date string (PDF 32000-1 §7.9.4), `D:YYYYMMDDHHmmSS+HH'mm'`, for
/// `epoch_seconds` shown at `offset_seconds` from UTC.
pub fn pdf_date(epoch_seconds : Int64, offset_seconds? : Int = 0) -> String {
  let secs = epoch_seconds + offset_seconds.to_int64()
  let mut days = secs / 86400L
  let mut rem = secs % 86400L
  if rem < 0L {
    rem += 86400L
    days -= 1L
  }
  // civil from days (Howard Hinnant)
  let z = days.to_int() + 719468
  let era = (if z >= 0 { z } else { z - 146096 }) / 146097
  let doe = z - era * 146097
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp = (5 * doy + 2) / 153
  let day = doy - (153 * mp + 2) / 5 + 1
  let month = if mp < 10 { mp + 3 } else { mp - 9 }
  let year = yoe + era * 400 + (if month <= 2 { 1 } else { 0 })
  let rem = rem.to_int()
  let pad = fn(n : Int, width : Int) {
    let text = n.to_string()
    "0".repeat(width - text.length()) + text
  }
  // written as an explicit offset even at UTC (`+00'00'`), as Prawn does
  let sign = if offset_seconds < 0 { "-" } else { "+" }
  let minutes = offset_seconds.abs() / 60
  let zone = "\{sign}\{pad(minutes / 60, 2)}'\{pad(minutes % 60, 2)}'"
  "D:\{pad(year, 4)}\{pad(month, 2)}\{pad(day, 2)}\{pad(rem / 3600, 2)}\{pad(rem % 3600 / 60, 2)}\{pad(rem % 60, 2)}\{zone}"
}

///|
/// Byte-wise lexical order, the order PDF name trees keep their keys in
/// (PDF 32000-1 §7.9.6): the first differing byte decides, and a key that
/// is a prefix of another sorts first. `Bytes::compare` is not this order —
/// it compares lengths first, putting every short key before every long one.
fn lexical_compare(left : Bytes, right : Bytes) -> Int {
  let n = if left.length() < right.length() {
    left.length()
  } else {
    right.length()
  }
  for i in 0..<n {
    let c = left[i].compare(right[i])
    if c != 0 {
      return c
    }
  }
  left.length().compare(right.length())
}

///|
/// Named destinations for `anchors` (name, page index, x, y), the outline
/// and the information dictionary, on a document whose catalog already
/// points at its page tree. Returns the document to write, which is a new
/// one when an outline was added.
fn add_navigation(
  document : @pdflite.PdfDocument,
  model : @pagelayout.PageModel,
  page_root : Int,
  anchors : Array[(String, Int, Double, Double)],
  outline : Array[OutlineEntry],
  info : Array[(String, String)],
  options : CatalogOptions,
) -> @pdflite.PdfDocument raise {
  if anchors.is_empty() &&
    outline.is_empty() &&
    info.is_empty() &&
    options.initial_zoom is None &&
    options.page_mode is None &&
    !options.display_doc_title &&
    options.page_labels.is_empty() {
    return document
  }
  // destinations name page objects, which pdflite enumerates only once a
  // catalog points at the tree; the catalog is rewritten below with the
  // entries that need them
  let page_objects = document.page_reference_numbers()
  let destinations : Map[String, @syntax.PdfObject] = Map([])
  for anchor in anchors {
    let (anchor_name, page_index, x, y) = anchor
    // the first anchor of a name wins, as an HTML fragment would
    if destinations.contains(anchor_name) {
      continue
    }
    guard page_objects.get(page_index) is Some(page_object) else { continue }
    let height = model.pages[page_index].height_pt
    destinations[anchor_name] = PdfArray([
      PdfIndirect(page_object),
      PdfNameObject(name("/XYZ")),
      PdfReal(x),
      PdfReal(flip(height, y)),
      PdfNull,
    ])
  }
  let catalog : Array[(@core.PdfName, @syntax.PdfObject)] = []
  if !destinations.is_empty() {
    // a single-leaf name tree: /Names must be in lexical order of the key
    // bytes
    let keys = destinations.keys().collect()
    keys.sort_by(fn(left, right) {
      lexical_compare(@utf8.encode(left), @utf8.encode(right))
    })
    let names : Array[@syntax.PdfObject] = []
    for key in keys {
      names.push(PdfString(@utf8.encode(key)))
      names.push(destinations.get(key).unwrap())
    }
    catalog.push(
      (
        name("/Names"),
        PdfDictionary([
          (
            name("/Dests"),
            PdfIndirect(
              document.add_object(
                PdfDictionary([(name("/Names"), PdfArray(names))]),
              ),
            ),
          ),
        ]),
      ),
    )
  }
  let bookmarks : Array[@bookmark.PdfBookmark] = []
  for entry in outline {
    bookmarks.push({
      level: entry.level,
      text: text_string(entry.title),
      target: match destinations.get(entry.anchor) {
        Some(_) => DestString(@utf8.encode(entry.anchor))
        None => DestNull
      },
      is_open: entry.open,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    })
  }
  match options.page_mode {
    Some(mode) =>
      catalog.push((name("/PageMode"), PdfNameObject(name("/" + mode))))
    None =>
      if !bookmarks.is_empty() {
        catalog.push((name("/PageMode"), PdfNameObject(name("/UseOutlines"))))
      }
  }
  match (options.initial_zoom, page_objects.get(0)) {
    (Some(zoom), Some(first)) => {
      let height = model.pages[0].height_pt
      let fit : Array[@syntax.PdfObject] = match zoom {
        Fit => [PdfNameObject(name("/Fit"))]
        FitH => [PdfNameObject(name("/FitH")), PdfReal(height)]
        FitV => [PdfNameObject(name("/FitV")), PdfReal(0.0)]
      }
      catalog.push((name("/OpenAction"), PdfArray([PdfIndirect(first), ..fit])))
    }
    _ => ()
  }
  if !options.page_labels.is_empty() {
    let nums : Array[@syntax.PdfObject] = []
    for index, label in options.page_labels {
      nums.push(PdfInteger(index))
      nums.push(PdfDictionary([(name("/P"), PdfString(text_string(label)))]))
    }
    catalog.push(
      (
        name("/PageLabels"),
        PdfIndirect(
          document.add_object(PdfDictionary([(name("/Nums"), PdfArray(nums))])),
        ),
      ),
    )
  }
  if options.display_doc_title ||
    info.iter().any(fn(entry) { entry.0 == "Title" }) {
    catalog.push(
      (
        name("/ViewerPreferences"),
        PdfDictionary([(name("/DisplayDocTitle"), PdfBoolean(true))]),
      ),
    )
  }
  ignore(document.add_root(page_root, catalog))
  let document = if bookmarks.is_empty() {
    document
  } else {
    let document = document.add_bookmarks(bookmarks)
    // The outline dictionary's /Count is the number of visible items
    // (PDF 32000-1 §12.3.3). pdflite leaves it out when no item is
    // open, which a reader may take for an empty outline; readers and
    // Prawn count the top level as visible, so write it always.
    match document.catalog().lookup_immediate(name("/Outlines")) {
      Some(PdfIndirect(number)) => {
        let root = document.lookup_object_or_null(number)
        if root.lookup_immediate(name("/Count")) is None {
          document.add_object_given_number(
            number,
            root.add_dict_entry(
              name("/Count"),
              PdfInteger(visible_outline_entries(outline)),
            ),
          )
        }
      }
      _ => ()
    }
    document
  }
  if !info.is_empty() {
    let entries : Array[(@core.PdfName, @syntax.PdfObject)] = []
    for entry in info {
      entries.push((name("/" + entry.0), PdfString(text_string(entry.1))))
    }
    let info_object = document.add_object(PdfDictionary(entries))
    document.set_trailer_dict(
      document
      .trailer_dict()
      .add_dict_entry(name("/Info"), PdfIndirect(info_object)),
    )
  }
  document
}

///|
/// How many outline entries show when the document opens: the top level,
/// and the children of entries that are open and themselves showing.
fn visible_outline_entries(outline : Array[OutlineEntry]) -> Int {
  // (level, showing, open) of the entries enclosing the current one
  let stack : Array[(Int, Bool, Bool)] = []
  let mut count = 0
  for entry in outline {
    while stack.length() > 0 && stack[stack.length() - 1].0 >= entry.level {
      ignore(stack.pop())
    }
    let showing = match stack.last() {
      None => true
      Some((_, parent_showing, parent_open)) => parent_showing && parent_open
    }
    if showing {
      count += 1
    }
    stack.push((entry.level, showing, entry.open))
  }
  count
}

///|
/// One entry of the document outline (bookmarks). `level` 0 is the top
/// level, and each entry nests under the nearest preceding entry of a
/// lower level; `anchor` names the `AnchorItem` it jumps to. An `open`
/// entry shows its children when the document opens (a positive `/Count`);
/// otherwise they start collapsed.
pub(all) struct OutlineEntry {
  title : String
  level : Int
  anchor : String
  open : Bool
}

///|
/// A PDF text string: PDFDocEncoding when the text is ASCII, else
/// UTF-16BE behind a byte order mark.
fn text_string(text : String) -> Bytes {
  // An empty string is written as a bare byte order mark, the empty
  // UTF-16 string: poppler (25.x) aborts `pdftotext -bbox` on an empty
  // literal in the information dictionary, and Prawn writes it this way.
  if text.is_empty() {
    return b"\xFE\xFF"
  }
  if text.iter().all(fn(c) { c.to_int() < 0x80 }) {
    return @utf8.encode(text)
  }
  let buffer = Buffer()
  buffer.write_byte(0xFE)
  buffer.write_byte(0xFF)
  for i in 0..<text.length() {
    let unit = text[i].to_int()
    buffer.write_byte((unit >> 8).to_byte())
    buffer.write_byte((unit & 0xFF).to_byte())
  }
  buffer.contents()
}

///|
/// A link annotation over `link`'s box: a named-destination jump for a
/// `#name` target, a URI action otherwise. Borderless, as a link in
/// running text is expected to be.
fn link_annotation(
  link : @pagelayout.LinkRegion,
  page_height : Double,
) -> @syntax.PdfObject {
  let target : (@core.PdfName, @syntax.PdfObject) = if link.target.has_prefix(
      "#",
    ) {
    (name("/Dest"), PdfString(@utf8.encode(link.target[1:].to_owned())))
  } else {
    (
      name("/A"),
      PdfDictionary([
        (name("/Type"), PdfNameObject(name("/Action"))),
        (name("/S"), PdfNameObject(name("/URI"))),
        (name("/URI"), PdfString(@utf8.encode(link.target))),
      ]),
    )
  }
  PdfDictionary([
    (name("/Type"), PdfNameObject(name("/Annot"))),
    (name("/Subtype"), PdfNameObject(name("/Link"))),
    (
      name("/Rect"),
      PdfArray([
        PdfReal(link.x_pt),
        PdfReal(flip(page_height, link.y_pt + link.h_pt)),
        PdfReal(link.x_pt + link.w_pt),
        PdfReal(flip(page_height, link.y_pt)),
      ]),
    ),
    (name("/Border"), PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(0)])),
    target,
  ])
}

///|
/// Which codepoints each interned font actually renders, in first-use
/// order so the subset is a function of the document rather than of hash
/// iteration. Every font is collected, because both shapes now subset the
/// program they embed, and because the set is what decides which shape a
/// font takes.
fn collect_codepoints(
  model : @pagelayout.PageModel,
  font_count : Int,
) -> Array[Array[Int]] {
  let used : Array[Array[Int]] = []
  let seen : Array[Map[Int, Unit]] = []
  for _ in 0..<font_count {
    used.push([])
    seen.push(Map([]))
  }
  for page in model.pages {
    for item in page.items {
      guard item is Text(run) else { continue }
      if run.font < 0 || run.font >= font_count {
        continue
      }
      let mut i = 0
      while i < run.text.length() {
        let (codepoint, next) = codepoint_at(run.text, i)
        if !seen[run.font].contains(codepoint) {
          seen[run.font][codepoint] = ()
          used[run.font].push(codepoint)
        }
        i = next
      }
    }
  }
  used
}

///|
/// pdflite's convention: a font's resource name is derived from its
/// object number, so a page's `/Font` dictionary is built from the set
/// of objects it actually used.
fn font_resource_name(number : Int) -> @core.PdfName {
  name("/F" + number.to_string())
}

///|
fn resources_of(
  font_objects : Array[Int],
  image_objects : Array[Int],
) -> @syntax.PdfObject {
  let fonts : Array[(@core.PdfName, @syntax.PdfObject)] = []
  for number in font_objects {
    fonts.push((font_resource_name(number), PdfIndirect(number)))
  }
  let entries : Array[(@core.PdfName, @syntax.PdfObject)] = [
    (name("/Font"), PdfDictionary(fonts)),
  ]
  if image_objects.length() > 0 {
    let xobjects : Array[(@core.PdfName, @syntax.PdfObject)] = []
    for number in image_objects {
      xobjects.push((image_resource_name(number), PdfIndirect(number)))
    }
    entries.push((name("/XObject"), PdfDictionary(xobjects)))
  }
  PdfDictionary(entries)
}

///|
fn image_resource_name(number : Int) -> @core.PdfName {
  name("/I" + number.to_string())
}

///|
/// Add an image XObject, or None for a format pdflite cannot embed.
///
/// Images repeat across pages (a logo in a header), so each distinct
/// (bytes, media type) pair becomes one XObject. The cache belongs to a single render:
/// object numbers are allocated per document, so sharing it across
/// documents would have the second one reference an object the first
/// allocated and it does not contain.
fn image_object(
  document : @pdflite.PdfDocument,
  image : @pagelayout.ImageItem,
  cache : Map[(Bytes, String), Int],
) -> Int? {
  let key = (image.data, image.mime)
  match cache.get(key) {
    Some(number) => return Some(number)
    None => ()
  }
  // a malformed or unsupported image is skipped rather than aborting a
  // whole document over one picture
  let object = match image.mime {
    "image/png" =>
      @pdflite.pdf_image_object_of_png_data(document, image.data) catch {
        _ => return None
      }
    "image/jpeg" =>
      @pdflite.pdf_image_object_of_jpeg_data(image.data) catch {
        _ => return None
      }
    _ => return None
  }
  let number = document.add_object(object)
  cache[key] = number
  Some(number)
}

///|
/// Draw an image XObject into its box. A PDF image occupies the unit
/// square, so the transform carries its size, and the y flip uses the
/// box's bottom edge.
fn emit_image(
  ops : Array[@content.PdfContentOp],
  image : @pagelayout.ImageItem,
  resource : @core.PdfName,
  page_height : Double,
) -> Unit {
  let y = flip(page_height, image.y_pt + image.h_pt)
  ops.push(Op_q)
  ops.push(
    Op_cm({ a: image.w_pt, b: 0, c: 0, d: image.h_pt, e: image.x_pt, f: y, }),
  )
  ops.push(Op_Do(resource))
  ops.push(Op_Q)
}

///|
/// Images this backend cannot embed: one entry per distinct failure,
/// with how many occurrences it accounts for.
///
/// `render_pdf` skips them rather than abandoning a document over one
/// picture, which keeps the page geometry right — the space an image
/// occupies is reserved by layout, not by the backend — but leaves a
/// blank where the picture belongs and says nothing. Callers that want to
/// tell a user their screenshots are missing need to ask.
pub fn unembeddable_images(
  model : @pagelayout.PageModel,
) -> Array[(String, Int)] {
  let document = @pdflite.pdf_document_empty()
  let reasons : Array[String] = []
  let counts : Map[String, Int] = Map([])
  // Only successful conversions are cached by `render_pdf`, so a failing
  // image really is skipped at every occurrence — a header picture on
  // fifty pages is fifty holes, and reporting it once would understate
  // that. The verdict is cached all the same, because re-decoding a
  // broken PNG per page is pure waste. It is keyed by bytes *and* type:
  // the same bytes can appear under two media types, and the reader that
  // rejects them as one may accept them as the other.
  let verdict : Map[(Bytes, String), String?] = Map([])
  for page in model.pages {
    for item in page.items {
      guard item is Image(image) else { continue }
      let key = (image.data, image.mime)
      let why = match verdict.get(key) {
        Some(cached) => cached
        None => {
          let computed = image_verdict(document, image)
          verdict[key] = computed
          computed
        }
      }
      match why {
        Some(message) =>
          match counts.get(message) {
            Some(n) => counts[message] = n + 1
            None => {
              counts[message] = 1
              reasons.push(message)
            }
          }
        None => ()
      }
    }
  }
  [..reasons.map(fn(r) { (r, counts.get(r).unwrap_or(0)) })]
}

///|
/// Why this image cannot be embedded, or None when it can.
fn image_verdict(
  document : @pdflite.PdfDocument,
  image : @pagelayout.ImageItem,
) -> String? {
  match image.mime {
    // pdflite reads greyscale, truecolour and palette PNG, interlaced or
    // not
    "image/png" =>
      try {
        ignore(@pdflite.pdf_image_object_of_png_data(document, image.data))
        None
      } catch {
        // The reader rejects palette transparency by design — embedding
        // it opaque would be quietly wrong — but also rejects malformed
        // or truncated files, so the reason cannot claim which without
        // inspecting further.
        _ => Some("PNG this backend cannot read")
      }
    "image/jpeg" =>
      try {
        ignore(@pdflite.pdf_image_object_of_jpeg_data(image.data))
        None
      } catch {
        _ => Some("JPEG this backend cannot read")
      }
    other => Some("\{other} is not an embeddable image format")
  }
}
