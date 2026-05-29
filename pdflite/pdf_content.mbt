///|
fn pdf_content_parse_section(
  operands : ArrayView[PdfObject],
  operator : BytesView,
) -> PdfContentOp raise PdfError {
  match @content.pdf_content_parse_known_section(operands, operator) {
    Some(op) => op
    None => pdf_content_section_unknown(operands, operator)
  }
}

///|
fn pdf_content_section_unknown(
  operands : ArrayView[PdfObject],
  operator : BytesView,
) -> PdfContentOp raise PdfError {
  Op_Unknown(pdf_content_section_bytes(operands, operator))
}

///|
/// Parse standalone content bytes without document or resource context.
///
/// This is suitable for ordinary operators and inline images that can be read
/// from explicit length or filter markers. Use the document methods when stream
/// decoding or resource-based inline-image sizing is required.
pub fn pdf_parse_content_ops_from_bytes(
  data : PdfBytes,
) -> Array[PdfContentOp] raise PdfError {
  pdf_parse_content_ops_from_view(data)
}

///|
/// Parse a standalone content byte view without document or resource context.
pub fn pdf_parse_content_ops_from_view(
  data : BytesView,
) -> Array[PdfContentOp] raise PdfError {
  pdf_parse_content_ops_from_view_with_context(
    data,
    pdf_content_parse_context(None),
  )
}

///|
fn pdf_parse_content_ops_from_view_with_context(
  data : BytesView,
  context : PdfContentParseContext,
) -> Array[PdfContentOp] raise PdfError {
  let cursor = byte_cursor_of_view(data)
  let op_capacity = pdf_content_parse_ops_capacity(data)
  let ops : Array[PdfContentOp] = Array::new(capacity=op_capacity)
  let operands : Array[PdfObject] = Array::new(capacity=8)
  let mut done = false
  while !done {
    match pdf_content_lex_next(cursor) {
      ContentEnd => done = true
      ContentComment => ()
      ContentOperand(object) => operands.push(object)
      ContentOperator(operator) =>
        if operator == pdf_content_inline_image_begin_operator &&
          operands.length() == 0 {
          ops.push(pdf_content_read_inline_image(cursor, context))
        } else {
          ops.push(pdf_content_parse_section(operands, operator))
          operands.clear()
        }
    }
  }
  if operands.length() > 0 {
    raise ContentOperatorExpected
  }
  ops
}

///|
fn pdf_content_parse_ops_capacity(data : BytesView) -> Int {
  let estimated = data.length() / 12
  if estimated < 4 {
    4
  } else if estimated > 4096 {
    4096
  } else {
    estimated
  }
}

///|
fn pdf_content_parse_context(
  colour_space_components : PdfContentColourSpaceComponents?,
) -> PdfContentParseContext {
  {
    decode_stream: pdf_decode_stream_until_unknown_value,
    colour_space_components,
  }
}
