///|
fn pdf_page_concat_ops(
  first : ArrayView[@content.PdfContentOp],
  second : ArrayView[@content.PdfContentOp],
) -> Array[@content.PdfContentOp] {
  let output : Array[@content.PdfContentOp] = []
  for op in first {
    output.push(op)
  }
  for op in second {
    output.push(op)
  }
  output
}

///|
fn pdf_page_concat3_ops(
  first : ArrayView[@content.PdfContentOp],
  second : ArrayView[@content.PdfContentOp],
  third : ArrayView[@content.PdfContentOp],
) -> Array[@content.PdfContentOp] {
  pdf_page_concat_ops(pdf_page_concat_ops(first, second), third)
}

///|
/// Return balancing graphics-state operators for an existing operator list.
///
/// If the list contains more `q` saves than `Q` restores, matching restores are
/// returned. Otherwise the result is empty.
pub fn pdf_page_protect(
  ops : ArrayView[@content.PdfContentOp],
) -> Array[@content.PdfContentOp] {
  let mut saves = 0
  let mut restores = 0
  for op in ops {
    match op {
      Op_q => saves += 1
      Op_Q => restores += 1
      _ => ()
    }
  }
  let output : Array[@content.PdfContentOp] = []
  if saves > restores {
    for _ in 0..<(saves - restores) {
      output.push(Op_Q)
    }
  }
  output
}

///|
fn PdfDocument::pdf_page_parse_content_ops(
  self : PdfDocument,
  resources : PdfObject,
  content : ArrayView[PdfObject],
) -> Array[@content.PdfContentOp] raise PdfError {
  self.parse_content_ops_with_resources(resources, content) catch {
    DictionaryKeyNotFound(_) | ColourSpaceExpected =>
      self.parse_content_ops(content)
    error => raise error
  }
}

///|
/// Prepend content operators to a page.
///
/// In normal mode existing content is parsed and merged into a single stream
/// after `ops`. In `fast` mode a new stream is inserted before existing content
/// without parsing the old streams.
pub fn PdfDocument::prepend_operators(
  self : PdfDocument,
  page : @page.PdfPage,
  ops : ArrayView[@content.PdfContentOp],
  fast? : Bool = false,
) -> @page.PdfPage raise PdfError {
  if fast {
    { ..page, content: [pdf_content_stream_of_ops(ops), ..page.content] }
  } else {
    let old_ops = self.pdf_page_parse_content_ops(page.resources, page.content)
    {
      ..page,
      content: [pdf_content_stream_of_ops(pdf_page_concat_ops(ops, old_ops))],
    }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::prepend_operators`.
pub fn pdf_prepend_operators(
  document : PdfDocument,
  operators : ArrayView[@content.PdfContentOp],
  page : @page.PdfPage,
  fast? : Bool = false,
) -> @page.PdfPage raise PdfError {
  document.prepend_operators(page, operators, fast~)
}

///|
/// Append content operators to a page.
///
/// Normal mode parses existing content and wraps it with graphics-state
/// protection before appending `ops`. `fast` mode appends a protected new
/// stream without parsing existing content.
pub fn PdfDocument::postpend_operators(
  self : PdfDocument,
  page : @page.PdfPage,
  ops : ArrayView[@content.PdfContentOp],
  fast? : Bool = false,
) -> @page.PdfPage raise PdfError {
  if fast {
    {
      ..page,
      content: [
        ..page.content,
        pdf_content_stream_of_ops(pdf_page_concat3_ops([Op_q], ops, [Op_Q])),
      ],
    }
  } else {
    let existing_ops = self.pdf_page_parse_content_ops(
      page.resources,
      page.content,
    )
    if existing_ops.length() == 0 {
      { ..page, content: [pdf_content_stream_of_ops(ops)] }
    } else {
      let before_ops : Array[@content.PdfContentOp] = [Op_q]
      let after_ops = pdf_page_concat3_ops(
        pdf_page_protect(existing_ops),
        [Op_Q],
        ops,
      )
      {
        ..page,
        content: [
          pdf_content_stream_of_ops(
            pdf_page_concat3_ops(before_ops, existing_ops, after_ops),
          ),
        ],
      }
    }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::postpend_operators`.
pub fn pdf_postpend_operators(
  document : PdfDocument,
  operators : ArrayView[@content.PdfContentOp],
  page : @page.PdfPage,
  fast? : Bool = false,
) -> @page.PdfPage raise PdfError {
  document.postpend_operators(page, operators, fast~)
}
