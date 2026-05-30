///|
fn pdf_text_rectangle_object(rectangle : @geometry.PdfRectangle) -> PdfObject {
  PdfArray([
    PdfReal(rectangle.min_x),
    PdfReal(rectangle.min_y),
    PdfReal(rectangle.max_x),
    PdfReal(rectangle.max_y),
  ])
}

///|
fn pdf_text_type3_charprocs_object(
  charprocs : ArrayView[(PdfName, PdfObject)],
) -> PdfObject {
  PdfDictionary([ for entry in charprocs => entry ])
}

///|
fn pdf_text_type3_resources_entries(
  resources : PdfObject,
) -> Array[(PdfName, PdfObject)] {
  match resources {
    PdfDictionary(entries) if entries.length() == 0 => []
    _ => [(pdf_text_resources_key_name, resources)]
  }
}

///|
fn pdf_text_type3_metrics_entries(
  firstchar : Int,
  lastchar : Int,
  widths : ArrayView[Int],
) -> Array[(PdfName, PdfObject)] {
  if widths.length() == 0 {
    [
      (pdf_text_first_char_key_name, PdfInteger(0)),
      (pdf_text_last_char_key_name, PdfInteger(0)),
      (pdf_text_widths_key_name, PdfArray([PdfReal(0.0)])),
    ]
  } else {
    [
      (pdf_text_first_char_key_name, PdfInteger(firstchar)),
      (pdf_text_last_char_key_name, PdfInteger(lastchar)),
      (
        pdf_text_widths_key_name,
        PdfArray([ for width in widths => PdfInteger(width) ]),
      ),
    ]
  }
}

///|
fn PdfDocument::pdf_text_type3_encoding_entries(
  self : PdfDocument,
  encoding : PdfEncoding,
) -> Array[(PdfName, PdfObject)] raise PdfError {
  match encoding {
    PdfImplicitInFontFile => []
    _ =>
      [(pdf_text_encoding_key_name, PdfIndirect(self.write_encoding(encoding)))]
  }
}

///|
fn PdfDocument::pdf_text_make_type3_font(
  self : PdfDocument,
  data : PdfType3Glyphs,
  firstchar : Int,
  lastchar : Int,
  widths : ArrayView[Int],
  encoding : PdfEncoding,
) -> PdfObject raise PdfError {
  PdfDictionary(
    [
      (pdf_text_type_key_name, PdfNameObject(pdf_text_font_name)),
      (pdf_text_subtype_key_name, PdfNameObject(pdf_text_type3_name)),
      (pdf_text_font_bbox_key_name, pdf_text_rectangle_object(data.fontbbox)),
      (pdf_text_font_matrix_key_name, pdf_object_of_matrix(data.fontmatrix)),
      (
        pdf_text_charprocs_key_name,
        pdf_text_type3_charprocs_object(data.charprocs),
      ),
      ..pdf_text_type3_resources_entries(data.resources),
      ..pdf_text_type3_metrics_entries(firstchar, lastchar, widths),
      ..self.pdf_text_type3_encoding_entries(encoding),
    ],
  )
}
