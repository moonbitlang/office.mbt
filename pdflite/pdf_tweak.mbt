///|
fn pdf_tweak_page_selected(
  page_numbers : ArrayView[Int],
  page_number : Int,
) -> Bool {
  for selected in page_numbers {
    if selected == page_number {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_tweak_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_tweak_extgstate_key_name : PdfName = pdf_tweak_name("/ExtGState")

///|
fn pdf_tweak_extgstate_key() -> PdfName {
  pdf_tweak_extgstate_key_name
}

///|
let pdf_tweak_line_width_key_name : PdfName = pdf_tweak_name("/LW")

///|
fn pdf_tweak_line_width_key() -> PdfName {
  pdf_tweak_line_width_key_name
}

///|
fn pdf_tweak_number(object : PdfObject) -> Double? {
  match object {
    PdfReal(value) => Some(value)
    PdfInteger(value) => Some(value.to_double())
    _ => None
  }
}

///|
fn pdf_tweak_ctm_scale(stack : ArrayView[TransformMatrix]) -> Double {
  if stack.length() == 0 {
    1.0
  } else {
    stack[stack.length() - 1].decompose().scale
  }
}

///|
fn pdf_tweak_extgstate_line_width(
  document : PdfDocument,
  resources : PdfObject,
  name : PdfName,
) -> Double? {
  match document.lookup_direct(pdf_tweak_extgstate_key(), resources) {
    Some(extgstate) =>
      match document.lookup_direct(name, extgstate) {
        Some(gdict) =>
          match document.lookup_direct(pdf_tweak_line_width_key(), gdict) {
            Some(value) => pdf_tweak_number(value)
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
/// Remove text rendering-mode operators so hidden text is rendered normally.
pub fn pdf_reveal_hidden_text_ops(
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  for op in ops {
    match op {
      Op_Tr(_) => ()
      _ => output.push(op)
    }
  }
  output
}

///|
fn PdfDocument::pdf_tweak_reveal_hidden_text_page(
  self : PdfDocument,
  page : PdfPage,
) -> PdfPage raise PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  {
    ..page,
    content: [pdf_content_stream_of_ops(pdf_reveal_hidden_text_ops(ops))],
  }
}

///|
fn pdf_tweak_reveal_hidden_text_xobject(
  document : PdfDocument,
  resources : PdfObject,
  streams : ArrayView[PdfObject],
) -> Array[PdfObject] raise PdfError {
  let ops = document.pdf_page_parse_content_ops(resources, streams)
  [pdf_content_stream_of_ops(pdf_reveal_hidden_text_ops(ops))]
}

///|
/// Reveal hidden text on selected one-based pages and their Form XObjects.
///
/// This ports the `cpdftweak.ml` reveal-hidden-text behavior by removing all
/// `Tr` text rendering-mode operators from selected content streams.
pub fn PdfDocument::reveal_hidden_text(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let rewritten : Array[PdfPage] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if pdf_tweak_page_selected(page_numbers, page_number) {
      document.process_xobjects(page, pdf_tweak_reveal_hidden_text_xobject)
      rewritten.push(document.pdf_tweak_reveal_hidden_text_page(page))
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::reveal_hidden_text`.
pub fn pdf_reveal_hidden_text(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.reveal_hidden_text(page_numbers)
}

///|
/// Remove clipping-path setup sequences from parsed content operators.
///
/// This ports `cpdftweak.ml`'s `remove_clipping_ops`: only the exact `W n`
/// sequence is rewritten, becoming just `n`.
pub fn pdf_remove_clipping_ops(
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  let mut index = 0
  while index < ops.length() {
    if index + 1 < ops.length() && ops[index] == Op_W && ops[index + 1] == Op_n {
      output.push(Op_n)
      index += 2
    } else {
      output.push(ops[index])
      index += 1
    }
  }
  output
}

///|
fn PdfDocument::pdf_tweak_remove_clipping_page(
  self : PdfDocument,
  page : PdfPage,
) -> PdfPage raise PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  { ..page, content: [pdf_content_stream_of_ops(pdf_remove_clipping_ops(ops))] }
}

///|
fn pdf_tweak_remove_clipping_xobject(
  document : PdfDocument,
  resources : PdfObject,
  streams : ArrayView[PdfObject],
) -> Array[PdfObject] raise PdfError {
  let ops = document.pdf_page_parse_content_ops(resources, streams)
  [pdf_content_stream_of_ops(pdf_remove_clipping_ops(ops))]
}

///|
/// Remove clipping paths from selected one-based pages and their Form XObjects.
pub fn PdfDocument::remove_clipping(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let rewritten : Array[PdfPage] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if pdf_tweak_page_selected(page_numbers, page_number) {
      document.process_xobjects(page, pdf_tweak_remove_clipping_xobject)
      rewritten.push(document.pdf_tweak_remove_clipping_page(page))
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::remove_clipping`.
pub fn pdf_remove_clipping(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.remove_clipping(page_numbers)
}

///|
/// Rewrite line widths to honor the cpdf thin-lines threshold.
///
/// Positive `width` is a minimum width. Negative `width` uses its absolute
/// value as a maximum width, matching `cpdftweak.ml`.
pub fn pdf_thin_lines_ops(
  document : PdfDocument,
  resources : PdfObject,
  ops : ArrayView[PdfContentOp],
  width : Double,
) -> Array[PdfContentOp] raise PdfError {
  let limit = if width < 0.0 { -width } else { width }
  let is_minimum = width >= 0.0
  let ctm_stack : Array[TransformMatrix] = [transform_identity_matrix]
  let output : Array[PdfContentOp] = []
  for op in ops {
    match op {
      Op_w(line_width) => {
        let adjusted_limit = limit / pdf_tweak_ctm_scale(ctm_stack)
        let keep = if is_minimum {
          line_width >= adjusted_limit
        } else {
          line_width <= adjusted_limit
        }
        if keep {
          output.push(op)
        } else {
          output.push(Op_w(adjusted_limit))
        }
      }
      Op_cm(matrix) => {
        if ctm_stack.length() == 0 {
          raise MatrixMalformed
        }
        let index = ctm_stack.length() - 1
        ctm_stack[index] = transform_matrix_compose(ctm_stack[index], matrix)
        output.push(op)
      }
      Op_q => {
        if ctm_stack.length() == 0 {
          raise MatrixMalformed
        }
        ctm_stack.push(ctm_stack[ctm_stack.length() - 1])
        output.push(op)
      }
      Op_Q => {
        if ctm_stack.length() == 0 {
          raise MatrixMalformed
        }
        ignore(ctm_stack.pop())
        output.push(op)
      }
      Op_gs(name) => {
        output.push(op)
        match pdf_tweak_extgstate_line_width(document, resources, name) {
          Some(line_width) => output.push(Op_w(line_width))
          None => ()
        }
      }
      _ => output.push(op)
    }
  }
  if limit > 1.0 || limit < 1.0 {
    output.insert(0, Op_w(limit))
  }
  output
}

///|
fn PdfDocument::pdf_tweak_thin_lines_page(
  self : PdfDocument,
  page : PdfPage,
  width : Double,
) -> PdfPage raise PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  {
    ..page,
    content: [
      pdf_content_stream_of_ops(
        pdf_thin_lines_ops(self, page.resources, ops, width),
      ),
    ],
  }
}

///|
/// Set a minimum line width on selected one-based pages.
///
/// Passing a negative `width` sets the corresponding maximum line width, as in
/// cpdf's `thinlines` implementation.
pub fn PdfDocument::thin_lines(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  width : Double,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let rewritten : Array[PdfPage] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if pdf_tweak_page_selected(page_numbers, page_number) {
      rewritten.push(document.pdf_tweak_thin_lines_page(page, width))
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::thin_lines`.
pub fn pdf_thin_lines(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  width : Double,
) -> PdfDocument raise PdfError {
  document.thin_lines(page_numbers, width)
}
