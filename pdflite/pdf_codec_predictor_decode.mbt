///|
/// Decode data after applying a PDF predictor.
///
/// Predictor `1` is identity, `2` is TIFF horizontal differencing, and
/// `10..15` are PNG predictors. Invalid image geometry or unsupported
/// predictors raise `PdfError`.
pub fn pdf_decode_predictor_view(
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  match predictor {
    1 => data.to_owned()
    2 => pdf_decode_tiff_predictor(colors, bits_per_component, columns, data)
    value if value >= 10 && value <= 15 =>
      pdf_decode_png_predictor(colors, bits_per_component, columns, data)
    _ => raise PredictorNotSupported(predictor)
  }
}

///|
/// Owned-byte wrapper for `pdf_decode_predictor_view`.
///
/// Predictor `1` returns the original owned bytes unchanged.
pub fn pdf_decode_predictor(
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  if predictor == 1 {
    data
  } else {
    pdf_decode_predictor_view(
      predictor, colors, bits_per_component, columns, data,
    )
  }
}
