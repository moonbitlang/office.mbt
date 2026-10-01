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
  face.declared_width(face.simple_unicode(code)) * size_pt / 1000.0
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
    match face.simple_code(unit) {
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
///
/// With `notdef_text`, a character the face lacks shows its own code (see
/// `notdef_cids`); one left without a code, because the font's text has
/// used up the codespace, shows glyph 0 inside a marked-content span whose
/// `/ActualText` is the character, so that it still extracts.
fn emit_run_composite(
  ops : Array[@content.PdfContentOp],
  run : @pagelayout.GlyphRun,
  face : PdfFace,
  resource : @core.PdfName,
  page_height : Double,
) -> Unit {
  let show = ShowText::new()
  // the text-showing operators, and the spans around them
  let body : Array[@content.PdfContentOp] = []
  let mut i = 0
  while i < run.text.length() {
    let (codepoint, next) = codepoint_at(run.text, i)
    // Identity-H: the code is the glyph index itself, or for a character
    // the face lacks, its own code drawn with glyph 0 (`notdef_cids`)
    let glyph = face.metrics.glyph_id(codepoint).unwrap_or(0)
    let code = if glyph != 0 {
      Some(glyph)
    } else {
      match face.notdef_cids.get(codepoint) {
        Some(cid) => Some(cid)
        None if face.notdef_text => None
        None => Some(0)
      }
    }
    let mut advance = 0.0
    for j in i..<next {
      advance += run.advances_pt[j]
    }
    match code {
      Some(code) => {
        // the width `composite_font_object` declares: `/W` for glyphs the
        // face has and for `notdef_cids`, the 1000-unit default for .notdef
        let declared = if code == 0 {
          run.size_pt
        } else {
          face.declared_width(codepoint) * run.size_pt / 1000.0
        }
        show.push(
          [(code >> 8).to_byte(), (code & 0xFF).to_byte()],
          advance - declared,
          run.size_pt,
        )
      }
      None => {
        if !show.is_empty() {
          body.push(show.take())
        }
        body.push(
          Op_BDC(
            name("/Span"),
            PdfDictionary([
              (
                name("/ActualText"),
                PdfString(text_string(run.text[i:next].to_owned())),
              ),
            ]),
          ),
        )
        show.push([b'\x00', b'\x00'], advance - run.size_pt, run.size_pt)
        body.push(show.take())
        body.push(Op_EMC)
      }
    }
    i = next
  }
  if !show.is_empty() {
    body.push(show.take())
  }
  if body.is_empty() {
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
  ops.append(body)
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
/// The face, metrics and program together, that draws `spec`: a face
/// registered in `options.fonts`, else the bundled one. Metrics and program always
/// come from one and the same face — the one layout measured with — so the
/// font dictionary and the codes shown in it cannot disagree.
fn pdf_face(spec : @pagelayout.FontSpec, options : RenderOptions) -> PdfFace {
  let fonts = options.fonts
  let family = fonts.resolve_family(spec.family)
  let (metrics, program, standard) = match
    fonts.registered_face(family, bold=spec.bold, italic=spec.italic) {
    Some(registered) => {
      // the registry admits only the names of `@fonts.standard_fonts`,
      // every one of which pdflite knows
      let standard = registered.standard.map(name => {
        guard @pdflite.pdf_standard_font_of_name("/" + name) is Some(font) else {
          abort("not a PDF standard font: \{name}")
        }
        font
      })
      (registered.metrics, registered.program, standard)
    }
    None => {
      let metrics = @fonts.face(family, bold=spec.bold, italic=spec.italic)
      // exactly the bundled face `face` settled on, fallbacks included
      let program = @fontoutlines.outline_sfnt(
        metrics.family,
        bold=metrics.bold,
        italic=metrics.italic,
      )
      (metrics, program, None)
    }
  }
  {
    spec,
    metrics,
    program,
    // decided once the document's character set is known
    composite: false,
    truncate_widths: options.truncate_widths,
    notdef_text: options.notdef_text,
    typo_metrics: options.typo_metrics,
    notdef_cids: Map([]),
    standard,
  }
}

///|
/// Render a page model to PDF bytes.
///
/// Every face with a TrueType program — the bundled ones, and registered
/// ones whose bytes carry outlines — is embedded, subset to the characters
/// the document uses: as a simple WinAnsi font while the text stays within
/// that encoding, as a Type0 composite font when it needs more. Any other
/// registered face is declared by name and not embedded: a PDF standard
/// font (`@fonts.FontRegistry::register_standard`) as a WinAnsi Type1
/// font the viewer draws with its own copy and widths, a face without a
/// program as a TrueType font with `/Widths` from its metrics, drawn by
/// whatever the viewer substitutes. Either way characters outside WinAnsi
/// are dropped from its text, their advances kept. See the module comment
/// in emit.mbt for why, and for what each choice costs.
///
/// Link regions become link annotations: a `Named(name)` target jumps to
/// the named destination the `AnchorItem` called `name` defines (the first
/// anchor of a name wins; a name no anchor defines leaves a dead link), a
/// `Uri` target opens as a URI, written as ASCII (see `uri_bytes`).
///
/// `options` adds the outline, metadata and catalog settings (see
/// `RenderOptions`); `render_pdf(model)` uses the bundled fonts and writes
/// none of them. Raises `RenderOptionError` for options it cannot honour:
/// page labels that do not match the page count, malformed dates, custom
/// metadata keys that are empty, repeated or name a standard entry, an
/// initial zoom position that is not finite.
pub fn render_pdf(
  model : @pagelayout.PageModel,
  options? : RenderOptions = RenderOptions::new(),
) -> Bytes raise {
  if !options.page_labels.is_empty() &&
    options.page_labels.length() != model.pages.length() {
    raise RenderOptionError(
      "\{options.page_labels.length()} page labels for \{model.pages.length()} pages",
    )
  }
  match options.initial_zoom {
    Some(FitHAt(top=position) | FitVAt(left=position)) =>
      if position.is_nan() || position.is_inf() {
        raise RenderOptionError(
          "initial zoom position \{position} is not finite",
        )
      }
    _ => ()
  }
  let document = @pdflite.pdf_document_empty()
  document.set_version(1, 7)
  let faces : Array[PdfFace] = []
  for spec in model.fonts {
    faces.push(pdf_face(spec, options))
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
    let composite = needs_composite(face, codepoints)
    faces[index] = {
      ..face,
      composite,
      notdef_cids: if composite && face.notdef_text {
        notdef_cids(face, codepoints)
      } else {
        Map([])
      },
    }
  }

  // one PDF font object per interned IR font, shared by every page
  let font_objects : Array[Int] = []
  for index, face in faces {
    font_objects.push(
      match (face.composite, face.program) {
        // needs_composite only says yes with a program to address glyphs in,
        // and `emit_run` encodes by the same flag, so the dictionary written
        // here and the codes shown in it always agree
        (true, Some(program)) =>
          composite_font_object(
            document,
            face,
            program,
            index,
            used_codepoints[index],
          )
        _ => font_object(document, face, index, used_codepoints[index])
      },
    )
  }
  let pages : Array[@page.PdfPage] = []
  let graphic_resources = GraphicResources::new(document)
  // (name, page index, x, y) of every anchor, in document order
  let anchors : Array[(String, Int, Double, Double)] = []
  for page_index, model_page in model.pages {
    let ops : Array[@content.PdfContentOp] = []
    // the fonts and images the page uses, in the order of first use, with
    // sets to look them up in (a page can hold many thousand runs)
    let used : Array[Int] = []
    let used_set : Map[Int, Unit] = Map([])
    let images : Array[Int] = []
    let images_set : Map[Int, Unit] = Map([])
    let annots : Array[@syntax.PdfObject] = []
    let page_graphics = PageGraphics::new()
    let text = fn(run : @pagelayout.GlyphRun, page_height : Double) {
      guard font_objects.get(run.font) is Some(number) else { return }
      if !used_set.contains(number) {
        used_set[number] = ()
        used.push(number)
      }
      guard faces.get(run.font) is Some(face) else { return }
      emit_run(ops, run, face, font_resource_name(number), page_height)
    }
    let image = fn(image : @pagelayout.ImageItem, page_height : Double) {
      match image_object(document, image, image_cache) {
        Some(number) => {
          if !images_set.contains(number) {
            images_set[number] = ()
            images.push(number)
          }
          emit_image(ops, image, image_resource_name(number), page_height)
        }
        // a format pdflite cannot embed is skipped rather than
        // written as something a reader would reject
        None => ()
      }
    }
    for item in model_page.items {
      match item {
        Text(run) => text(run, model_page.height_pt)
        Rect(rect) => emit_rect(ops, rect, model_page.height_pt)
        Image(item) => image(item, model_page.height_pt)
        Graphic(graphic) =>
          emit_graphic(
            ops,
            graphic,
            model_page.height_pt,
            graphic_resources,
            page_graphics,
            text=run => text(run, 0.0),
            image=item => image(item, 0.0),
          )
        // an annotation must be an indirect object (PDF 32000-1, Table 30)
        Link(link) =>
          annots.push(
            PdfIndirect(
              document.add_object(link_annotation(link, model_page.height_pt)),
            ),
          )
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
    if options.page_boxes {
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
      resources: resources_of(used, images, graphics=page_graphics),
      rotate: Rotate0,
      rest: PdfDictionary(rest),
    })
  }
  let page_root = document.add_pagetree(pages)
  ignore(document.add_root(page_root, []))
  let document = add_navigation(document, model, page_root, anchors, options)
  @pdflite.pdf_write_document(document)
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
  options : RenderOptions,
) -> @pdflite.PdfDocument raise {
  let outline = options.outline
  let info = options.info
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
      target: match entry.dest {
        Position(page~, x~, y~) =>
          match page_objects.get(page) {
            Some(page_object) =>
              DestXYZ(
                TargetPageObject(page_object),
                Some(x),
                Some(flip(model.pages[page].height_pt, y)),
                None,
              )
            None => DestNull
          }
        Named(anchor) =>
          match destinations.get(anchor) {
            Some(_) => DestString(@utf8.encode(anchor))
            None => DestNull
          }
      },
      is_open: entry.open,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    })
  }
  match options.page_mode {
    Some(mode) =>
      catalog.push((name("/PageMode"), PdfNameObject(name(mode.pdf_name()))))
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
        FitHAt(top~) =>
          [PdfNameObject(name("/FitH")), PdfReal(flip(height, top))]
        FitVAt(left~) => [PdfNameObject(name("/FitV")), PdfReal(left)]
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
  if options.display_doc_title || info.title is Some(_) {
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
    let info_object = document.add_object(PdfDictionary(info.entries()))
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
/// Whether PDFDocEncoding writes `c` as the byte ASCII would. Not every
/// ASCII character qualifies: PDFDocEncoding puts breve, caron and other
/// spacing accents at 0x18–0x1F, leaves 0x7F and the remaining controls
/// undefined, and keeps only tab, line feed and carriage return.
fn pdfdoc_same_as_ascii(c : Char) -> Bool {
  let code = c.to_int()
  (code >= 0x20 && code <= 0x7E) || code == 0x09 || code == 0x0A || code == 0x0D
}

///|
/// A PDF text string: PDFDocEncoding when every character means the same
/// there as in ASCII, else UTF-16BE behind a byte order mark. Either way it
/// decodes back to `text` exactly.
fn text_string(text : String) -> Bytes {
  // An empty string is written as a bare byte order mark, the empty
  // UTF-16 string: poppler (25.x) aborts `pdftotext -bbox` on an empty
  // literal in the information dictionary, and Prawn writes it this way.
  if text.is_empty() {
    return b"\xFE\xFF"
  }
  if text.iter().all(pdfdoc_same_as_ascii) {
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
/// `Named` target, a URI action for a `Uri` one (even one that is only a
/// `#fragment`). Borderless, as a link in running text is expected to be.
fn link_annotation(
  link : @pagelayout.LinkRegion,
  page_height : Double,
) -> @syntax.PdfObject {
  let target : (@core.PdfName, @syntax.PdfObject) = match link.target {
    Named(destination) => (name("/Dest"), PdfString(@utf8.encode(destination)))
    Uri(uri) =>
      (
        name("/A"),
        PdfDictionary([
          (name("/Type"), PdfNameObject(name("/Action"))),
          (name("/S"), PdfNameObject(name("/URI"))),
          (name("/URI"), PdfString(uri_bytes(uri))),
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
/// A URI action's target as the 7-bit ASCII URI a PDF requires (PDF
/// 32000-1, §12.6.4.7 and Table 206). An IRI maps to a URI as RFC 3987 §3.1
/// has it: every character outside ASCII is written as its UTF-8 bytes,
/// each percent-encoded (`café` → `caf%C3%A9`). ASCII that RFC 3986 never
/// allows in a URI — controls, space, DEL and `"<>\^`{|}` — is
/// percent-encoded the same way. A `%` that begins an escape is kept, so
/// input that is already encoded comes out unchanged; a stray `%` becomes
/// `%25`. Host names are percent-encoded like the rest rather than
/// converted to punycode, which RFC 3986 §3.2.2 permits.
///
/// Prawn, behind Ruby asciidoctor-pdf, writes such a target as raw UTF-8
/// (text links) or as a UTF-16 text string (image links); neither is an
/// ASCII URI, and both mean the URI this function writes.
///
/// Named destinations (`Named` targets) are byte-string identifiers, not
/// URIs, and keep their UTF-8 bytes.
fn uri_bytes(target : String) -> Bytes {
  let bytes = @utf8.encode(target)
  let out = Buffer()
  let hex = b"0123456789ABCDEF"
  let is_hex = fn(i : Int) {
    if i >= bytes.length() {
      return false
    }
    let b = bytes[i]
    (b >= b'0' && b <= b'9') ||
    (b >= b'A' && b <= b'F') ||
    (b >= b'a' && b <= b'f')
  }
  for i in 0..<bytes.length() {
    let b = bytes[i]
    let keep = match b {
      b'%' => is_hex(i + 1) && is_hex(i + 2)
      b'"' | b'<' | b'>' | b'\\' | b'^' | b'`' | b'{' | b'|' | b'}' => false
      _ => b > b' ' && b < b'\x7F'
    }
    if keep {
      out.write_byte(b)
    } else {
      out.write_byte(b'%')
      out.write_byte(hex[b.to_int() >> 4])
      out.write_byte(hex[b.to_int() & 0xF])
    }
  }
  out.contents()
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
  let collect = fn(run : @pagelayout.GlyphRun) {
    if run.font < 0 || run.font >= font_count {
      return
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
  for page in model.pages {
    for item in page.items {
      match item {
        Text(run) => collect(run)
        Graphic(graphic) =>
          for op in graphic.ops {
            if op is (Text(run) | PaintedText(run, _)) {
              collect(run)
            }
          }
        _ => ()
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
  graphics? : PageGraphics = PageGraphics::new(),
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
  if graphics.gstates.length() > 0 {
    let gstates : Array[(@core.PdfName, @syntax.PdfObject)] = []
    for n, _ in graphics.gstates {
      gstates.push((gstate_resource_name(n), PdfIndirect(n)))
    }
    entries.push((name("/ExtGState"), PdfDictionary(gstates)))
  }
  if graphics.patterns.length() > 0 {
    let patterns : Array[(@core.PdfName, @syntax.PdfObject)] = []
    for n, _ in graphics.patterns {
      patterns.push((pattern_resource_name(n), PdfIndirect(n)))
    }
    entries.push((name("/Pattern"), PdfDictionary(patterns)))
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
  let placed : Array[@pagelayout.ImageItem] = []
  for page in model.pages {
    for item in page.items {
      match item {
        Image(image) => placed.push(image)
        Graphic(graphic) =>
          for op in graphic.ops {
            if op is Image(image) {
              placed.push(image)
            }
          }
        _ => ()
      }
    }
  }
  for image in placed {
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
