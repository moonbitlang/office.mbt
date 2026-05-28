///|
/// Colour value used by cpdf-style content colour rewrite operations.
pub(all) enum PdfContentColour {
  PdfContentGrey(Double)
  PdfContentRGB(Double, Double, Double)
  PdfContentCMYK(Double, Double, Double, Double)
} derive(Debug, Eq, ToJson)

///|
/// The default black content colour.
pub let pdf_content_black : PdfContentColour = PdfContentGrey(0.0)

///|
fn PdfContentColour::pdf_tweak_fill_op(self : PdfContentColour) -> PdfContentOp {
  match self {
    PdfContentGrey(grey) => Op_g(grey)
    PdfContentRGB(red, green, blue) => Op_rg(red, green, blue)
    PdfContentCMYK(cyan, magenta, yellow, black) =>
      Op_k(cyan, magenta, yellow, black)
  }
}

///|
fn PdfContentColour::pdf_tweak_stroke_op(
  self : PdfContentColour,
) -> PdfContentOp {
  match self {
    PdfContentGrey(grey) => Op_G(grey)
    PdfContentRGB(red, green, blue) => Op_RG(red, green, blue)
    PdfContentCMYK(cyan, magenta, yellow, black) =>
      Op_K(cyan, magenta, yellow, black)
  }
}

///|
fn pdf_tweak_black_text_text_op(op : PdfContentOp) -> Bool {
  match op {
    Op_Tj(_)
    | Op_TJ(_)
    | Op_quote(_)
    | Op_double_quote(_, _, _)
    | Op_Td(_, _)
    | Op_TD(_, _)
    | Op_Tm(_)
    | Op_Tstar
    | Op_Tc(_)
    | Op_Tw(_)
    | Op_Tz(_)
    | Op_TL(_)
    | Op_Tf(_, _)
    | Op_Tr(_)
    | Op_Ts(_) => true
    _ => false
  }
}

///|
fn pdf_tweak_black_text_colour_op(op : PdfContentOp) -> Bool {
  match op {
    Op_G(_)
    | Op_g(_)
    | Op_RG(_, _, _)
    | Op_rg(_, _, _)
    | Op_K(_, _, _, _)
    | Op_k(_, _, _, _)
    | Op_SC(_)
    | Op_sc(_)
    | Op_SCN(_)
    | Op_scn(_)
    | Op_SCNName(_, _)
    | Op_scnName(_, _)
    | Op_CS(_)
    | Op_cs(_)
    | Op_sh(_)
    | Op_gs(_) => true
    _ => false
  }
}

///|
fn pdf_tweak_black_stroke_op(op : PdfContentOp) -> Bool {
  match op {
    Op_SC(_)
    | Op_SCN(_)
    | Op_SCNName(_, _)
    | Op_G(_)
    | Op_RG(_, _, _)
    | Op_K(_, _, _, _) => true
    _ => false
  }
}

///|
fn pdf_tweak_black_fill_op(op : PdfContentOp) -> Bool {
  match op {
    Op_sc(_)
    | Op_scn(_)
    | Op_scnName(_, _)
    | Op_g(_)
    | Op_rg(_, _, _)
    | Op_k(_, _, _, _) => true
    _ => false
  }
}

///|
/// Rewrite text content so text is painted with `colour`.
///
/// Colour and graphics-state operators inside text blocks are moved after the
/// text block, while non-text drawing operators inside the text block are
/// copied after `ET`, matching `cpdftweak.ml`'s `blacktext_ops`.
pub fn pdf_black_text_ops(
  colour : PdfContentColour,
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  let removed : Array[PdfContentOp] = []
  let mut text_level = 0
  for op in ops {
    match op {
      Op_BT => {
        text_level += 1
        output.push(op)
        output.push(colour.pdf_tweak_fill_op())
      }
      Op_ET => {
        text_level -= 1
        output.push(op)
        for removed_op in removed {
          output.push(removed_op)
        }
        removed.clear()
      }
      _ =>
        if text_level > 0 && pdf_tweak_black_text_colour_op(op) {
          removed.push(op)
        } else {
          if text_level > 0 && !pdf_tweak_black_text_text_op(op) {
            removed.push(op)
          }
          output.push(op)
        }
    }
  }
  output
}

///|
/// Rewrite stroke colour operators to `colour`.
pub fn pdf_black_lines_ops(
  colour : PdfContentColour,
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  for op in ops {
    match op {
      Op_CS(_) => output.push(Op_CS(pdf_tweak_device_rgb_key()))
      _ if pdf_tweak_black_stroke_op(op) =>
        output.push(colour.pdf_tweak_stroke_op())
      _ => output.push(op)
    }
  }
  output
}

///|
/// Rewrite fill colour operators to `colour`.
pub fn pdf_black_fills_ops(
  colour : PdfContentColour,
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  for op in ops {
    match op {
      Op_cs(_) => output.push(Op_cs(pdf_tweak_device_rgb_key()))
      _ if pdf_tweak_black_fill_op(op) =>
        output.push(colour.pdf_tweak_fill_op())
      _ => output.push(op)
    }
  }
  output
}

///|
fn PdfDocument::pdf_tweak_black_text_page(
  self : PdfDocument,
  page : PdfPage,
  colour : PdfContentColour,
) -> PdfPage raise PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  {
    ..page,
    content: [pdf_content_stream_of_ops(pdf_black_text_ops(colour, ops))],
  }
}

///|
fn pdf_tweak_black_text_xobject(
  colour : PdfContentColour,
  document : PdfDocument,
  resources : PdfObject,
  streams : ArrayView[PdfObject],
) -> Array[PdfObject] raise PdfError {
  let ops = document.pdf_page_parse_content_ops(resources, streams)
  [pdf_content_stream_of_ops(pdf_black_text_ops(colour, ops))]
}

///|
fn PdfDocument::pdf_tweak_black_lines_page(
  self : PdfDocument,
  page : PdfPage,
  colour : PdfContentColour,
) -> PdfPage raise PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  {
    ..page,
    content: [pdf_content_stream_of_ops(pdf_black_lines_ops(colour, ops))],
  }
}

///|
fn pdf_tweak_black_lines_xobject(
  colour : PdfContentColour,
  document : PdfDocument,
  resources : PdfObject,
  streams : ArrayView[PdfObject],
) -> Array[PdfObject] raise PdfError {
  let ops = document.pdf_page_parse_content_ops(resources, streams)
  [pdf_content_stream_of_ops(pdf_black_lines_ops(colour, ops))]
}

///|
fn PdfDocument::pdf_tweak_black_fills_page(
  self : PdfDocument,
  page : PdfPage,
  colour : PdfContentColour,
) -> PdfPage raise PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  {
    ..page,
    content: [pdf_content_stream_of_ops(pdf_black_fills_ops(colour, ops))],
  }
}

///|
fn pdf_tweak_black_fills_xobject(
  colour : PdfContentColour,
  document : PdfDocument,
  resources : PdfObject,
  streams : ArrayView[PdfObject],
) -> Array[PdfObject] raise PdfError {
  let ops = document.pdf_page_parse_content_ops(resources, streams)
  [pdf_content_stream_of_ops(pdf_black_fills_ops(colour, ops))]
}

///|
/// Paint text on selected one-based pages and Form XObjects with `colour`.
pub fn PdfDocument::black_text(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  colour : PdfContentColour,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      document.process_xobjects(page, fn(
        doc,
        resources,
        streams,
      ) raise PdfError {
        pdf_tweak_black_text_xobject(colour, doc, resources, streams)
      })
      rewritten.push(document.pdf_tweak_black_text_page(page, colour))
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::black_text`.
pub fn pdf_black_text(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  colour : PdfContentColour,
) -> PdfDocument raise PdfError {
  document.black_text(page_numbers, colour)
}

///|
/// Compatibility wrapper matching cpdftweak's `blacktext` name and order.
pub fn pdf_blacktext(
  colour : PdfContentColour,
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.black_text(page_numbers, colour)
}

///|
/// Paint line strokes on selected one-based pages and Form XObjects with `colour`.
pub fn PdfDocument::black_lines(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  colour : PdfContentColour,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      document.process_xobjects(page, fn(
        doc,
        resources,
        streams,
      ) raise PdfError {
        pdf_tweak_black_lines_xobject(colour, doc, resources, streams)
      })
      rewritten.push(document.pdf_tweak_black_lines_page(page, colour))
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::black_lines`.
pub fn pdf_black_lines(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  colour : PdfContentColour,
) -> PdfDocument raise PdfError {
  document.black_lines(page_numbers, colour)
}

///|
/// Compatibility wrapper matching cpdftweak's `blacklines` name and order.
pub fn pdf_blacklines(
  colour : PdfContentColour,
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.black_lines(page_numbers, colour)
}

///|
/// Paint fills on selected one-based pages and Form XObjects with `colour`.
pub fn PdfDocument::black_fills(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  colour : PdfContentColour,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      document.process_xobjects(page, fn(
        doc,
        resources,
        streams,
      ) raise PdfError {
        pdf_tweak_black_fills_xobject(colour, doc, resources, streams)
      })
      rewritten.push(document.pdf_tweak_black_fills_page(page, colour))
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::black_fills`.
pub fn pdf_black_fills(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  colour : PdfContentColour,
) -> PdfDocument raise PdfError {
  document.black_fills(page_numbers, colour)
}

///|
/// Compatibility wrapper matching cpdftweak's `blackfills` name and order.
pub fn pdf_blackfills(
  colour : PdfContentColour,
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.black_fills(page_numbers, colour)
}
