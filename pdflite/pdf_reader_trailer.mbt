///|
fn pdf_trailer_prev_position(trailer : PdfObject) -> Int? raise PdfError {
  match trailer.lookup_immediate(@reader.pdf_reader_prev_name()) {
    Some(PdfInteger(position)) if position >= 0 => Some(position)
    Some(_) => raise TrailerExpected
    None => None
  }
}

///|
fn pdf_trailer_xref_stream_position(trailer : PdfObject) -> Int? raise PdfError {
  match trailer.lookup_immediate(@reader.pdf_reader_xrefstm_name()) {
    Some(PdfInteger(position)) if position >= 0 => Some(position)
    Some(PdfInteger(_)) => raise XRefExpected
    _ => None
  }
}

///|
fn pdf_reader_sanitize_trailer(
  trailer : PdfObject,
  size : Int,
) -> PdfObject raise PdfError {
  trailer
  .add_dict_entry(@reader.pdf_reader_size_name(), PdfInteger(size))
  .remove_dict_entry(@reader.pdf_reader_w_name())
  .remove_dict_entry(@reader.pdf_reader_type_name())
  .remove_dict_entry(@reader.pdf_reader_index_name())
  .remove_dict_entry(@reader.pdf_reader_prev_name())
  .remove_dict_entry(@reader.pdf_reader_xrefstm_name())
  .remove_dict_entry(@reader.pdf_reader_filter_name())
  .remove_dict_entry(@reader.pdf_reader_decodeparms_name())
}
