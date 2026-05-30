///|
/// Serialize content operators to PDF content-stream bytes.
///
/// Operators are separated with whitespace. `Op_Unknown` bytes are emitted as
/// captured. Inline images with no filter are Flate-encoded and written with
/// inline `/F /Fl` and `/L` metadata; inline images with existing filters keep
/// their supplied encoded data and decode parameters.
pub fn pdf_content_bytes_of_ops(
  ops : ArrayView[@content.PdfContentOp],
) -> PdfBytes raise PdfError {
  let rendered : Array[(PdfBytes, Bool)] = Array::new(capacity=ops.length())
  let mut length = 0
  for op in ops {
    let bytes = pdf_content_op_bytes(op)
    let has_separator = length > 0
    if has_separator {
      length += 1
    }
    length += bytes.length()
    rendered.push((bytes, has_separator))
  }
  let output = Array::make(length, b' ')
  let mut position = 0
  for entry in rendered {
    if entry.1 {
      output[position] = 32
      position += 1
    }
    position = pdf_content_copy_view(output, position, entry.0)
  }
  Bytes::from_array(output)
}

///|
/// Serialize one content operator to PDF content-stream bytes.
pub fn pdf_content_bytes_of_op(
  op : @content.PdfContentOp,
) -> PdfBytes raise PdfError {
  pdf_content_bytes_of_ops([op])
}

///|
/// Compatibility wrapper for `pdf_content_bytes_of_ops`.
///
/// The name follows CamlPDF, where strings were byte sequences; this function
/// returns `PdfBytes`.
pub fn pdf_string_of_content_ops(
  ops : ArrayView[@content.PdfContentOp],
) -> PdfBytes raise PdfError {
  pdf_content_bytes_of_ops(ops)
}

///|
/// Compatibility wrapper for `pdf_content_bytes_of_op`.
///
/// The name follows CamlPDF, where strings were byte sequences; this function
/// returns `PdfBytes`.
pub fn pdf_string_of_content_op(
  op : @content.PdfContentOp,
) -> PdfBytes raise PdfError {
  pdf_content_bytes_of_op(op)
}

///|
/// Build an uncompressed PDF stream object from content operators.
///
/// The returned stream dictionary contains `/Length` for the serialized byte
/// length and no outer stream filter.
pub fn pdf_content_stream_of_ops(
  ops : ArrayView[@content.PdfContentOp],
) -> PdfObject raise PdfError {
  let data = pdf_content_bytes_of_ops(ops)
  pdf_stream(
    PdfDictionary([(pdf_content_length_name(), PdfInteger(data.length()))]),
    StreamGot(data),
  )
}
