///|
fn pdf_content_read_inline_image(
  cursor : ByteCursor,
  document : PdfDocument?,
  resources : PdfObject,
) -> PdfContentOp raise PdfError {
  let entries : Array[(PdfName, PdfObject)] = []
  let mut decode_parms : PdfObject? = None
  let mut done = false
  while !done {
    match pdf_content_lex_next(cursor) {
      ContentOperator(operator) if operator ==
        pdf_content_inline_image_data_operator => done = true
      ContentOperand(PdfNameObject(key)) =>
        match pdf_content_lex_next(cursor) {
          ContentOperand(value) =>
            if key == pdf_content_inline_dp_name() ||
              key == pdf_content_inline_decode_parms_name() {
              decode_parms = Some(value)
            } else {
              entries.push((key, value))
            }
          _ => raise ContentOperandExpected
        }
      ContentComment => ()
      _ => raise ContentOperandExpected
    }
  }
  let dictionary = @syntax.PdfDictionary(entries)
  if pdf_content_inline_image_uses_dct(dictionary) {
    Op_InlineImage(
      dictionary,
      decode_parms,
      pdf_content_read_dct_inline_image_data(cursor),
    )
  } else {
    match pdf_content_inline_image_text_filter(dictionary) {
      Some(filter) =>
        match
          (
            decode_parms,
            pdf_content_inline_image_single_text_filter(dictionary),
          ) {
          (None, Some(single_filter)) =>
            Op_InlineImage(
              pdf_content_remove_inline_image_filter_metadata(dictionary),
              None,
              pdf_content_read_text_encoded_inline_image_decoded(
                cursor, single_filter,
              ),
            )
          _ => {
            let encoded = pdf_content_read_text_encoded_inline_image_data(
              cursor, filter,
            )
            let (decoded_dictionary, decoded) = pdf_content_decode_inline_image_data(
              dictionary, decode_parms, encoded,
            )
            Op_InlineImage(decoded_dictionary, None, decoded)
          }
        }
      None if pdf_content_inline_image_uses_run_length(dictionary) =>
        if decode_parms is None &&
          pdf_content_inline_image_uses_single_run_length(dictionary) {
          Op_InlineImage(
            pdf_content_remove_inline_image_filter_metadata(dictionary),
            None,
            pdf_content_read_run_length_inline_image_decoded(cursor),
          )
        } else {
          let encoded = pdf_content_read_run_length_inline_image_data(cursor)
          let (decoded_dictionary, decoded) = pdf_content_decode_inline_image_data(
            dictionary, decode_parms, encoded,
          )
          Op_InlineImage(decoded_dictionary, None, decoded)
        }
      None if pdf_content_inline_image_uses_flate(dictionary) =>
        if decode_parms is None &&
          pdf_content_inline_image_uses_single_flate(dictionary) {
          Op_InlineImage(
            pdf_content_remove_inline_image_filter_metadata(dictionary),
            None,
            pdf_content_read_flate_inline_image_decoded(cursor),
          )
        } else {
          let encoded = pdf_content_read_flate_inline_image_data(cursor)
          let (decoded_dictionary, decoded) = pdf_content_decode_inline_image_data(
            dictionary, decode_parms, encoded,
          )
          Op_InlineImage(decoded_dictionary, None, decoded)
        }
      None if pdf_content_inline_image_uses_lzw(dictionary) =>
        if decode_parms is None &&
          pdf_content_inline_image_uses_single_lzw(dictionary) {
          Op_InlineImage(
            pdf_content_remove_inline_image_filter_metadata(dictionary),
            None,
            pdf_content_read_lzw_inline_image_decoded(cursor),
          )
        } else {
          let encoded = pdf_content_read_lzw_inline_image_data(
            cursor, dictionary, decode_parms,
          )
          let (decoded_dictionary, decoded) = pdf_content_decode_inline_image_data(
            dictionary, decode_parms, encoded,
          )
          Op_InlineImage(decoded_dictionary, None, decoded)
        }
      None =>
        Op_InlineImage(
          dictionary,
          decode_parms,
          match
            pdf_content_inline_image_data_length(
              document, resources, dictionary,
            ) {
            Some(length) =>
              pdf_content_read_sized_inline_image_data(cursor, length)
            None => pdf_content_read_inline_image_data(cursor)
          },
        )
    }
  }
}
