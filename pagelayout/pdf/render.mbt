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
/// Emit one glyph run. The run is placed with `Tm` at its own origin and
/// drawn as a single string: `/Widths` in the font dictionary already
/// carries the advances the layout used, so the viewer reproduces the
/// same spacing without per-character positioning.
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
  let codes : Array[Byte] = []
  let mut segment_x = run.x_pt
  let mut pending_x = run.x_pt
  let baseline = flip(page_height, run.baseline_pt)
  let (r, g, b) = colour_of(run.color)
  fn flush(x : Double) -> Unit {
    if codes.length() == 0 {
      return
    }
    ops.push(Op_BT)
    ops.push(Op_Tf(resource, run.size_pt))
    ops.push(Op_rg(r, g, b))
    ops.push(Op_Tm({ a: 1, b: 0, c: 0, d: 1, e: x, f: baseline }))
    ops.push(Op_Tj(Bytes::from_array(codes)))
    ops.push(Op_ET)
    codes.clear()
  }

  let mut i = 0
  while i < run.text.length() {
    let unit = run.text[i].to_int()
    // surrogate pairs are outside WinAnsi by definition
    let advance = run.advances_pt[i]
    match winansi_code(unit) {
      Some(code) => {
        if codes.length() == 0 {
          segment_x = pending_x
        }
        codes.push(code.to_byte())
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
/// string — so the whole run is one `Tj` of two-byte CIDs placed by a
/// single `Tm`.
fn emit_run_composite(
  ops : Array[@content.PdfContentOp],
  run : @pagelayout.GlyphRun,
  face : PdfFace,
  resource : @core.PdfName,
  page_height : Double,
) -> Unit {
  let codes : Array[Byte] = []
  let mut i = 0
  while i < run.text.length() {
    let (codepoint, next) = codepoint_at(run.text, i)
    // Identity-H: the code is the glyph index itself
    let glyph = face.metrics.cmap.get(codepoint).unwrap_or(0)
    codes.push((glyph >> 8).to_byte())
    codes.push((glyph & 0xFF).to_byte())
    i = next
  }
  if codes.length() == 0 {
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
  ops.push(Op_Tj(Bytes::from_array(codes)))
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
pub fn render_pdf(model : @pagelayout.PageModel) -> Bytes raise {
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
    faces[index] = { ..face, composite: needs_composite(face, codepoints) }
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
  for model_page in model.pages {
    let ops : Array[@content.PdfContentOp] = []
    let used : Array[Int] = []
    let images : Array[Int] = []
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
        // link regions are geometry only; PDF annotations come later
        Link(_) => ()
      }
    }
    let content = if ops.length() == 0 {
      []
    } else {
      [@pdflite.pdf_content_stream_of_ops(ops)]
    }
    pages.push({
      content,
      mediabox: PdfArray([
        PdfReal(0.0),
        PdfReal(0.0),
        PdfReal(model_page.width_pt),
        PdfReal(model_page.height_pt),
      ]),
      resources: resources_of(used, images),
      rotate: Rotate0,
      rest: PdfDictionary([]),
    })
  }
  let page_root = document.add_pagetree(pages)
  ignore(document.add_root(page_root, []))
  @pdflite.pdf_write_document(document)
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
    Op_cm({ a: image.w_pt, b: 0, c: 0, d: image.h_pt, e: image.x_pt, f: y }),
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
