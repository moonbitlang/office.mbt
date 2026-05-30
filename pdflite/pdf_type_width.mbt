///|
/// Build a cpdftype-style width table for one-byte PDF text charcodes.
///
/// Widths are returned in user units for the requested font size. This ports the
/// standalone `cpdftype.ml` `font_widths` behavior for standard fonts and simple
/// fonts with explicit metrics. CID fonts and simple fonts without metrics raise
/// `@core.PdfError::FontWidthExpected`.
pub fn pdf_type_font_widths(
  font : PdfFont,
  font_size : Double,
) -> Array[Double] raise @core.PdfError {
  match font {
    PdfFontStandard(data) =>
      [
        for code in 0..<256 => {
          let bytes : FixedArray[Byte] = [code.to_byte()]
          font_size *
          data.text_width(Bytes::from_array(bytes)).to_double() /
          1000.0
        }
      ]
    PdfFontSimple(simple) =>
      match simple.fontmetrics {
        Some(metrics) => [ for width in metrics => font_size * width / 1000.0 ]
        None => raise FontWidthExpected
      }
    PdfFontCIDKeyed(_) => raise FontWidthExpected
  }
}

///|
/// Sum a cpdftype width table for byte-encoded text.
///
/// Each input byte is used directly as a charcode index. A width table shorter
/// than the largest charcode raises `@core.PdfError::FontWidthExpected`.
pub fn pdf_type_width_of_bytes(
  widths : ArrayView[Double],
  text : BytesView,
) -> Double raise @core.PdfError {
  let mut width = 0.0
  for byte in text {
    let code = byte.to_int()
    if code >= widths.length() {
      raise FontWidthExpected
    }
    width += widths[code]
  }
  width
}

///|
/// Source-spelled compatibility alias for cpdftype's byte-string width helper.
pub fn pdf_type_width_of_string(
  widths : ArrayView[Double],
  text : BytesView,
) -> Double raise @core.PdfError {
  pdf_type_width_of_bytes(widths, text)
}

///|
/// Source-spelled compatibility alias for cpdftype's `add_artifacts`.
pub fn pdf_type_add_artifacts(
  ops : ArrayView[@content.PdfContentOp],
) -> Array[@content.PdfContentOp] {
  @content.pdf_content_add_artifacts(ops)
}
