///|
/// Encode data with a PDF predictor.
///
/// Predictor `1` is identity, `2` is TIFF horizontal differencing, `10..14`
/// use fixed PNG row filters, and `15` chooses the lowest-scoring PNG filter
/// per row.
pub fn pdf_encode_predictor_view(
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  match predictor {
    1 => data.to_owned()
    2 => pdf_encode_tiff_predictor(colors, bits_per_component, columns, data)
    10 =>
      pdf_encode_png_tagged_predictor(
        0, colors, bits_per_component, columns, data,
      )
    11 =>
      pdf_encode_png_sub_predictor(colors, bits_per_component, columns, data)
    12 => pdf_encode_png_up_predictor(colors, bits_per_component, columns, data)
    13 =>
      pdf_encode_png_tagged_predictor(
        3, colors, bits_per_component, columns, data,
      )
    14 =>
      pdf_encode_png_tagged_predictor(
        4, colors, bits_per_component, columns, data,
      )
    15 =>
      pdf_encode_png_optimum_predictor(
        colors, bits_per_component, columns, data,
      )
    _ => raise PredictorNotSupported(predictor)
  }
}

///|
/// Owned-byte wrapper for `pdf_encode_predictor_view`.
///
/// Predictor `1` returns the original owned bytes unchanged.
pub fn pdf_encode_predictor(
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : @core.PdfBytes,
) -> @core.PdfBytes raise @core.PdfError {
  if predictor == 1 {
    data
  } else {
    pdf_encode_predictor_view(
      predictor, colors, bits_per_component, columns, data,
    )
  }
}
