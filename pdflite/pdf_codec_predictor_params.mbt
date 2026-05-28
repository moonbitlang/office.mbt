///|
fn pdf_apply_first_predictor(
  dictionary : PdfObject,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  match pdf_first_decodeparms(dictionary) {
    None => data
    Some(decodeparms) => {
      let predictor = pdf_decodeparms_int(decodeparms, pdf_predictor_key(), 1)
      if predictor == 1 {
        data
      } else {
        pdf_decode_predictor(
          predictor,
          pdf_decodeparms_int(decodeparms, pdf_colors_key(), 1),
          pdf_decodeparms_int(decodeparms, pdf_bits_per_component_key(), 8),
          pdf_decodeparms_int(decodeparms, pdf_columns_key(), 1),
          data,
        )
      }
    }
  }
}

///|
fn PdfDocument::pdf_apply_first_predictor_direct(
  self : PdfDocument,
  dictionary : PdfObject,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  match self.pdf_first_decodeparms_direct(dictionary) {
    None => data
    Some(decodeparms) => {
      let predictor = self.pdf_decodeparms_int_direct(
        decodeparms,
        pdf_predictor_key(),
        1,
      )
      if predictor == 1 {
        data
      } else {
        pdf_decode_predictor(
          predictor,
          self.pdf_decodeparms_int_direct(decodeparms, pdf_colors_key(), 1),
          self.pdf_decodeparms_int_direct(
            decodeparms,
            pdf_bits_per_component_key(),
            8,
          ),
          self.pdf_decodeparms_int_direct(decodeparms, pdf_columns_key(), 1),
          data,
        )
      }
    }
  }
}
