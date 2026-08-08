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
  resource : @core.PdfName,
  page_height : Double,
) -> Unit {
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
/// Fonts are declared with widths from the bundled metrics but not
/// embedded; see the module comment in emit.mbt for why, and for what
/// that does and does not cost.
pub fn render_pdf(model : @pagelayout.PageModel) -> Bytes raise {
  let document = @pdflite.pdf_document_empty()
  document.set_version(1, 7)

  // one PDF font object per interned IR font, shared by every page
  let font_objects : Array[Int] = []
  for spec in model.fonts {
    let metrics = @fonts.face(
      @fonts.resolve_family(spec.family),
      bold=spec.bold,
      italic=spec.italic,
    )
    font_objects.push(font_object(document, { spec, metrics }))
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
          emit_run(ops, run, font_resource_name(number), model_page.height_pt)
        }
        Rect(rect) => emit_rect(ops, rect, model_page.height_pt)
        Image(image) =>
          match image_object(document, image) {
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
/// Each distinct byte string is added once and shared across pages.
fn image_object(
  document : @pdflite.PdfDocument,
  image : @pagelayout.ImageItem,
) -> Int? {
  match image_cache.get(image.data) {
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
  image_cache[image.data] = number
  Some(number)
}

///|
/// Images repeat across pages (a logo in a header), so each distinct
/// byte string becomes one XObject.
let image_cache : Map[Bytes, Int] = Map([])

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
