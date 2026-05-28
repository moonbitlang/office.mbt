///|
fn pdf_content_read_inline_image_data(
  cursor : ByteCursor,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  let view = cursor.remaining_view()
  let mut found = false
  let mut index = 0
  let mut data_length = 0
  let mut skip_before_marker = 0
  while !found && index + 1 < view.length() {
    let is_marker = view[index].to_int() == 69 && view[index + 1].to_int() == 73
    let before_ok = index == 0 ||
      pdf_is_whitespace_byte(view[index - 1].to_int())
    let after_index = index + 2
    let after_ok = after_index >= view.length() ||
      pdf_is_whitespace_byte(view[after_index].to_int())
    if is_marker && before_ok && after_ok {
      found = true
      if index > 0 && pdf_is_whitespace_byte(view[index - 1].to_int()) {
        data_length = index - 1
        skip_before_marker = 1
      } else {
        data_length = index
        skip_before_marker = 0
      }
    } else {
      index += 1
    }
  }
  if !found {
    raise ParseEndStreamExpected
  }
  let data = cursor.read_view(data_length).to_owned()
  if skip_before_marker > 0 {
    ignore(cursor.read_view(skip_before_marker))
  }
  ignore(cursor.read_view(2))
  data
}

///|
fn pdf_content_run_length_encoded_length(data : BytesView) -> Int? {
  let mut index = 0
  while index < data.length() {
    let control = data[index].to_int()
    index += 1
    if control < 128 {
      index += control + 1
    } else if control > 128 {
      index += 1
    } else {
      return Some(index)
    }
  }
  None
}

///|
fn pdf_content_ascii_hex_encoded_length(data : BytesView) -> Int? {
  for index in 0..<data.length() {
    if data[index].to_int() == 62 {
      return Some(index + 1)
    }
  }
  None
}

///|
fn pdf_content_ascii85_encoded_length(data : BytesView) -> Int? {
  let mut index = 0
  while index + 1 < data.length() {
    if data[index].to_int() == 126 && data[index + 1].to_int() == 62 {
      return Some(index + 2)
    }
    index += 1
  }
  None
}

///|
fn pdf_content_text_encoded_inline_image_length(
  data : BytesView,
  filter : PdfContentInlineTextFilter,
) -> Int? {
  match filter {
    PdfContentInlineAsciiHex => pdf_content_ascii_hex_encoded_length(data)
    PdfContentInlineAscii85 => pdf_content_ascii85_encoded_length(data)
  }
}

///|
fn pdf_content_read_text_encoded_inline_image_data(
  cursor : ByteCursor,
  filter : PdfContentInlineTextFilter,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  match
    pdf_content_text_encoded_inline_image_length(
      cursor.remaining_view(),
      filter,
    ) {
    Some(length) => {
      let data = cursor.read_view(length).to_owned()
      pdf_content_read_inline_image_end(cursor)
      data
    }
    None => raise ParseEndStreamExpected
  }
}

///|
fn pdf_content_read_text_encoded_inline_image_decoded(
  cursor : ByteCursor,
  filter : PdfContentInlineTextFilter,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  match
    pdf_content_text_encoded_inline_image_length(
      cursor.remaining_view(),
      filter,
    ) {
    Some(length) => {
      let encoded = cursor.read_view(length)
      let decoded = match filter {
        PdfContentInlineAsciiHex => pdf_ascii_hex_decode_view(encoded)
        PdfContentInlineAscii85 => pdf_ascii85_decode_view(encoded)
      }
      pdf_content_read_inline_image_end(cursor)
      decoded
    }
    None => raise ParseEndStreamExpected
  }
}

///|
fn pdf_content_read_flate_inline_image_data(
  cursor : ByteCursor,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  let (_, length) = @flate.pdf_flate_decode_view_prefix(cursor.remaining_view())
  let data = cursor.read_view(length).to_owned()
  pdf_content_read_inline_image_end(cursor)
  data
}

///|
fn pdf_content_read_flate_inline_image_decoded(
  cursor : ByteCursor,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  let (decoded, length) = @flate.pdf_flate_decode_view_prefix(
    cursor.remaining_view(),
  )
  ignore(cursor.read_view(length))
  pdf_content_read_inline_image_end(cursor)
  decoded
}

///|
fn pdf_content_read_lzw_inline_image_data(
  cursor : ByteCursor,
  dictionary : PdfObject,
  decode_parms : PdfObject?,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  let with_decode_parms = match decode_parms {
    Some(value) =>
      dictionary.add_dict_entry(pdf_content_inline_dp_name(), value)
    None => dictionary
  }
  let (_, length) = pdf_lzw_decode_view_prefix(
    cursor.remaining_view(),
    early_change=pdf_lzw_early_change(with_decode_parms),
  )
  let data = cursor.read_view(length).to_owned()
  pdf_content_read_inline_image_end(cursor)
  data
}

///|
fn pdf_content_read_lzw_inline_image_decoded(
  cursor : ByteCursor,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  let (decoded, length) = pdf_lzw_decode_view_prefix(cursor.remaining_view())
  ignore(cursor.read_view(length))
  pdf_content_read_inline_image_end(cursor)
  decoded
}

///|
fn pdf_content_read_run_length_inline_image_data(
  cursor : ByteCursor,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  match pdf_content_run_length_encoded_length(cursor.remaining_view()) {
    Some(length) => {
      let data = cursor.read_view(length).to_owned()
      pdf_content_read_inline_image_end(cursor)
      data
    }
    None => raise ParseEndStreamExpected
  }
}

///|
fn pdf_content_run_length_decode_view_prefix(
  data : BytesView,
) -> (PdfBytes, Int) raise PdfError {
  let (output_length, consumed) = pdf_content_run_length_decoded_prefix_length(
    data,
  )
  let output = Array::make(output_length, b'\x00')
  let mut output_index = 0
  let mut index = 0
  while output_index < output_length {
    let control = data[index].to_int()
    index += 1
    if control < 128 {
      let wanted = control + 1
      for i in 0..<wanted {
        output[output_index] = data[index + i]
        output_index += 1
      }
      index += wanted
    } else {
      let value = data[index]
      index += 1
      for _ in 0..<(257 - control) {
        output[output_index] = value
        output_index += 1
      }
    }
  }
  (Bytes::from_array(output), consumed)
}

///|
fn pdf_content_run_length_decoded_prefix_length(
  data : BytesView,
) -> (Int, Int) raise PdfError {
  let mut output_length = 0
  let mut index = 0
  while index < data.length() {
    let control = data[index].to_int()
    index += 1
    if control < 128 {
      let wanted = control + 1
      if index + wanted > data.length() {
        raise ParseEndStreamExpected
      }
      output_length += wanted
      index += wanted
    } else if control > 128 {
      if index >= data.length() {
        raise ParseEndStreamExpected
      }
      index += 1
      output_length += 257 - control
    } else {
      return (output_length, index)
    }
  }
  raise ParseEndStreamExpected
}

///|
fn pdf_content_read_run_length_inline_image_decoded(
  cursor : ByteCursor,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  let (decoded, length) = pdf_content_run_length_decode_view_prefix(
    cursor.remaining_view(),
  )
  ignore(cursor.read_view(length))
  pdf_content_read_inline_image_end(cursor)
  decoded
}

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
  let decoded_data = pdf_stream_data_bytes(decoded.data)
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

///|
fn pdf_content_skip_whitespace(cursor : ByteCursor) -> Unit {
  while pdf_is_whitespace_byte(cursor.peek_byte()) {
    cursor.nudge()
  }
}

///|
fn pdf_content_consume_next_inline_image_end(
  cursor : ByteCursor,
) -> Bool raise PdfError {
  let remaining = cursor.remaining_view()
  if remaining.length() < 2 {
    false
  } else {
    let limit = remaining.length() - 1
    for index in 0..<limit {
      if remaining[index].to_int() == 69 && remaining[index + 1].to_int() == 73 {
        ignore(cursor.read_view(index + 2))
        return true
      }
    }
    false
  }
}

///|
fn pdf_content_read_inline_image_end(
  cursor : ByteCursor,
) -> Unit raise PdfError {
  pdf_content_skip_whitespace(cursor)
  let marker_start = cursor.position()
  match (cursor.read_byte(), cursor.read_byte()) {
    (Some(first), Some(second)) if first.to_int() == 69 && second.to_int() == 73 =>
      ()
    _ => {
      try! cursor.seek(marker_start)
      if !pdf_content_consume_next_inline_image_end(cursor) {
        raise ParseEndStreamExpected
      }
    }
  }
}

///|
fn pdf_content_read_dct_inline_image_data(
  cursor : ByteCursor,
) -> PdfBytes raise PdfError {
  match cursor.peek_byte() {
    value if pdf_is_whitespace_byte(value) => cursor.nudge()
    _ => ()
  }
  let data = cursor.read_jpeg_data()
  pdf_content_read_inline_image_end(cursor)
  data
}

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
  let dictionary = PdfDictionary(entries)
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
