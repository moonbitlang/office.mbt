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
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
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

///|
/// Compatibility wrapper matching cpdftweak's `thinlines` name and order.
pub fn pdf_thinlines(
  page_numbers : ArrayView[Int],
  width : Double,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.thin_lines(page_numbers, width)
}
