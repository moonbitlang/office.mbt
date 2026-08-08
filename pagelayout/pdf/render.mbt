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
        // images and links are not carried into PDF yet
        Image(_) | Link(_) => ()
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
      resources: resources_of(used),
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
fn resources_of(font_objects : Array[Int]) -> @syntax.PdfObject {
  let entries : Array[(@core.PdfName, @syntax.PdfObject)] = []
  for number in font_objects {
    entries.push((font_resource_name(number), PdfIndirect(number)))
  }
  PdfDictionary([(name("/Font"), PdfDictionary(entries))])
}
