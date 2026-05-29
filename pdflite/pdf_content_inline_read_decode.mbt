///|
fn pdf_content_decode_inline_image_data(
  dictionary : PdfObject,
  decode_parms : PdfObject?,
  encoded : PdfBytes,
) -> (PdfObject, PdfBytes) raise PdfError {
  let with_decode_parms = match decode_parms {
    Some(value) =>
      dictionary.add_dict_entry(pdf_content_inline_dp_name(), value)
    None => dictionary
  }
  let stream_dictionary = with_decode_parms.add_dict_entry(
    pdf_content_length_name(),
    PdfInteger(encoded.length()),
  )
  let decoded = pdf_decode_stream_until_unknown_value({
    dictionary: stream_dictionary,
    data: StreamGot(encoded),
  })
  let decoded_data = @syntax.pdf_stream_data_bytes(decoded.data)
  if pdf_stream_has_filter_value(decoded) {
    (
      decoded.dictionary
      .remove_dict_entry(pdf_content_length_name())
      .remove_dict_entry(pdf_content_inline_l_name()),
      decoded_data,
    )
  } else {
    (pdf_content_remove_inline_image_filter_metadata(dictionary), decoded_data)
  }
}

///|
fn pdf_content_remove_inline_image_filter_metadata(
  dictionary : PdfObject,
) -> PdfObject raise PdfError {
  dictionary
  .remove_dict_entry(pdf_content_inline_filter_name())
  .remove_dict_entry(pdf_content_inline_f_name())
  .remove_dict_entry(pdf_content_inline_decode_parms_name())
  .remove_dict_entry(pdf_content_inline_dp_name())
  .remove_dict_entry(pdf_content_length_name())
  .remove_dict_entry(pdf_content_inline_l_name())
}

///|
fn pdf_content_read_sized_inline_image_data(
  cursor : ByteCursor,
  length : Int,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  let data = cursor.read_view(length).to_owned() catch {
      EndOfInput => raise ParseEndStreamExpected
      error => raise error
    }
  pdf_content_read_inline_image_end(cursor)
  data
}
