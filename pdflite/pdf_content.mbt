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

///|
fn pdf_content_operand_number(
  operands : ArrayView[PdfObject],
  index : Int,
) -> Double? {
  if index >= operands.length() {
    None
  } else {
    match operands[index] {
      PdfReal(value) => Some(value)
      PdfInteger(value) => Some(value.to_double())
      _ => None
    }
  }
}

///|
fn pdf_content_operand_int(
  operands : ArrayView[PdfObject],
  index : Int,
) -> Int? {
  if index >= operands.length() {
    None
  } else {
    match operands[index] {
      PdfInteger(value) => Some(value)
      PdfReal(value) => Some(value.to_int())
      _ => None
    }
  }
}

///|
fn pdf_content_operand_name(
  operands : ArrayView[PdfObject],
  index : Int,
) -> PdfName? {
  if index >= operands.length() {
    None
  } else {
    match operands[index] {
      PdfNameObject(name) => Some(name)
      _ => None
    }
  }
}

///|
fn pdf_content_operand_string(
  operands : ArrayView[PdfObject],
  index : Int,
) -> PdfBytes? {
  if index >= operands.length() {
    None
  } else {
    match operands[index] {
      PdfString(bytes) => Some(bytes)
      _ => None
    }
  }
}

///|
fn pdf_content_numbers_from_array(object : PdfObject) -> Array[Double]? {
  match object {
    PdfArray(items) => {
      let output : Array[Double] = Array::new(capacity=items.length())
      for item in items {
        match item {
          PdfReal(value) => output.push(value)
          PdfInteger(value) => output.push(value.to_double())
          _ => break None
        }
      } nobreak {
        Some(output)
      }
    }
    _ => None
  }
}

///|
fn pdf_content_numbers_from_operands(
  operands : ArrayView[PdfObject],
) -> Array[Double]? {
  let output : Array[Double] = Array::new(capacity=operands.length())
  for operand in operands {
    match operand {
      PdfReal(value) => output.push(value)
      PdfInteger(value) => output.push(value.to_double())
      _ => break None
    }
  } nobreak {
    Some(output)
  }
}

///|
fn pdf_content_malformed_color_fallback() -> Array[Double] {
  [0.0, 0.0, 0.0]
}

///|
fn pdf_content_numbers_or_malformed_color_fallback(
  operands : ArrayView[PdfObject],
) -> Array[Double] {
  match pdf_content_numbers_from_operands(operands) {
    Some(values) => values
    None => pdf_content_malformed_color_fallback()
  }
}

///|
fn pdf_content_named_color_operands(
  operands : ArrayView[PdfObject],
) -> (PdfName, Array[Double])? {
  if operands.length() == 0 {
    None
  } else {
    match operands[operands.length() - 1] {
      PdfNameObject(name) => {
        let numbers : Array[Double] = Array::new(capacity=operands.length() - 1)
        for i in 0..<(operands.length() - 1) {
          match operands[i] {
            PdfReal(value) => numbers.push(value)
            PdfInteger(value) => numbers.push(value.to_double())
            _ => break None
          }
        } nobreak {
          Some((name, numbers))
        }
      }
      _ => None
    }
  }
}

///|
fn pdf_content_named_color_operands_or_malformed_fallback(
  operands : ArrayView[PdfObject],
) -> (PdfName, Array[Double])? {
  match pdf_content_named_color_operands(operands) {
    Some(named_color) => Some(named_color)
    None =>
      if operands.length() == 0 {
        None
      } else {
        match operands[operands.length() - 1] {
          PdfNameObject(name) =>
            Some((name, pdf_content_malformed_color_fallback()))
          _ => None
        }
      }
  }
}

///|
fn pdf_content_tj_array_from_operand(object : PdfObject) -> PdfObject? {
  match object {
    PdfArray(items) => {
      let output : Array[PdfObject] = Array::new(capacity=items.length())
      for item in items {
        match item {
          PdfString(bytes) => output.push(PdfString(bytes))
          PdfInteger(value) => output.push(PdfReal(value.to_double()))
          PdfReal(value) => output.push(PdfReal(value))
          _ => ()
        }
      }
      Some(PdfArray(output))
    }
    _ => None
  }
}

///|
fn pdf_content_section_unknown(
  operands : ArrayView[PdfObject],
  operator : BytesView,
) -> PdfContentOp raise PdfError {
  Op_Unknown(pdf_content_section_bytes(operands, operator))
}

///|
fn pdf_content_matrix_from_operands(
  operands : ArrayView[PdfObject],
) -> TransformMatrix? {
  match
    (
      pdf_content_operand_number(operands, 0),
      pdf_content_operand_number(operands, 1),
      pdf_content_operand_number(operands, 2),
      pdf_content_operand_number(operands, 3),
      pdf_content_operand_number(operands, 4),
      pdf_content_operand_number(operands, 5),
    ) {
    (Some(a), Some(b), Some(c), Some(d), Some(e), Some(f)) =>
      Some({ a, b, c, d, e, f })
    _ => None
  }
}

///|
fn pdf_content_dash_op_from_operands(
  operands : ArrayView[PdfObject],
) -> PdfContentOp? raise PdfError {
  if operands.length() != 2 {
    None
  } else {
    match (operands[0], pdf_content_operand_number(operands, 1)) {
      (PdfArray(_), Some(phase)) =>
        match pdf_content_numbers_from_array(operands[0]) {
          Some(dashes) => Some(Op_d(dashes, phase))
          None => raise NumberExpected
        }
      _ => None
    }
  }
}

///|
fn pdf_content_parse_known_section(
  operands : ArrayView[PdfObject],
  operator : BytesView,
) -> PdfContentOp? raise PdfError {
  match operator {
    [113] if operands.length() == 0 => Some(Op_q)
    [81] if operands.length() == 0 => Some(Op_Q)
    [104] if operands.length() == 0 => Some(Op_h)
    [83] if operands.length() == 0 => Some(Op_S)
    [115] if operands.length() == 0 => Some(Op_s)
    [102] if operands.length() == 0 => Some(Op_f)
    [70] if operands.length() == 0 => Some(Op_F)
    [102, 42] if operands.length() == 0 => Some(Op_fstar)
    [66] if operands.length() == 0 => Some(Op_B)
    [66, 42] if operands.length() == 0 => Some(Op_Bstar)
    [98] if operands.length() == 0 => Some(Op_b)
    [98, 42] if operands.length() == 0 => Some(Op_bstar)
    [110] if operands.length() == 0 => Some(Op_n)
    [87] if operands.length() == 0 => Some(Op_W)
    [87, 42] if operands.length() == 0 => Some(Op_Wstar)
    [66, 84] if operands.length() == 0 => Some(Op_BT)
    [69, 84] if operands.length() == 0 => Some(Op_ET)
    [84, 42] if operands.length() == 0 => Some(Op_Tstar)
    [69, 77, 67] if operands.length() == 0 => Some(Op_EMC)
    [66, 88] if operands.length() == 0 => Some(Op_BX)
    [69, 88] if operands.length() == 0 => Some(Op_EX)
    [119] if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(width) => Some(Op_w(width))
        None => None
      }
    [74] if operands.length() == 1 =>
      match pdf_content_operand_int(operands, 0) {
        Some(cap) => Some(Op_J(cap))
        None => None
      }
    [106] if operands.length() == 1 =>
      match pdf_content_operand_int(operands, 0) {
        Some(join) => Some(Op_j(join))
        None => None
      }
    [77] if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(limit) => Some(Op_M(limit))
        None => None
      }
    [100] => pdf_content_dash_op_from_operands(operands)
    [114, 105] if operands.length() == 1 =>
      match pdf_content_operand_name(operands, 0) {
        Some(intent) => Some(Op_ri(intent))
        None => None
      }
    [105] if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(flatness) => Some(Op_i(flatness))
        None => None
      }
    [99, 109] if operands.length() == 6 =>
      match pdf_content_matrix_from_operands(operands) {
        Some(matrix) => Some(Op_cm(matrix))
        None => None
      }
    [84, 109] if operands.length() == 6 =>
      match pdf_content_matrix_from_operands(operands) {
        Some(matrix) => Some(Op_Tm(matrix))
        None => None
      }
    [109] if operands.length() == 2 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
        ) {
        (Some(x), Some(y)) => Some(Op_m(x, y))
        _ => None
      }
    [108] if operands.length() == 2 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
        ) {
        (Some(x), Some(y)) => Some(Op_l(x, y))
        _ => None
      }
    [99] if operands.length() == 6 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_number(operands, 2),
          pdf_content_operand_number(operands, 3),
          pdf_content_operand_number(operands, 4),
          pdf_content_operand_number(operands, 5),
        ) {
        (Some(x1), Some(y1), Some(x2), Some(y2), Some(x3), Some(y3)) =>
          Some(Op_c(x1, y1, x2, y2, x3, y3))
        _ => None
      }
    [118] if operands.length() == 4 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_number(operands, 2),
          pdf_content_operand_number(operands, 3),
        ) {
        (Some(x2), Some(y2), Some(x3), Some(y3)) => Some(Op_v(x2, y2, x3, y3))
        _ => None
      }
    [121] if operands.length() == 4 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_number(operands, 2),
          pdf_content_operand_number(operands, 3),
        ) {
        (Some(x1), Some(y1), Some(x3), Some(y3)) => Some(Op_y(x1, y1, x3, y3))
        _ => None
      }
    [114, 101] if operands.length() == 4 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_number(operands, 2),
          pdf_content_operand_number(operands, 3),
        ) {
        (Some(x), Some(y), Some(width), Some(height)) =>
          Some(Op_re(x, y, width, height))
        _ => None
      }
    [84, 99] if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(spacing) => Some(Op_Tc(spacing))
        None => None
      }
    [84, 119] if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(spacing) => Some(Op_Tw(spacing))
        None => None
      }
    [84, 122] if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(scale) => Some(Op_Tz(scale))
        None => None
      }
    [84, 76] if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(leading) => Some(Op_TL(leading))
        None => None
      }
    [84, 102] if operands.length() == 2 =>
      match
        (
          pdf_content_operand_name(operands, 0),
          pdf_content_operand_number(operands, 1),
        ) {
        (Some(font), Some(size)) => Some(Op_Tf(font, size))
        _ => None
      }
    [84, 114] if operands.length() == 1 =>
      match pdf_content_operand_int(operands, 0) {
        Some(mode) => Some(Op_Tr(mode))
        None => None
      }
    [84, 115] if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(rise) => Some(Op_Ts(rise))
        None => None
      }
    [84, 100] if operands.length() == 2 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
        ) {
        (Some(tx), Some(ty)) => Some(Op_Td(tx, ty))
        _ => None
      }
    [84, 68] if operands.length() == 2 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
        ) {
        (Some(tx), Some(ty)) => Some(Op_TD(tx, ty))
        _ => None
      }
    [84, 106] if operands.length() == 1 =>
      match pdf_content_operand_string(operands, 0) {
        Some(text) => Some(Op_Tj(text))
        None => None
      }
    [84, 74] if operands.length() == 1 =>
      match pdf_content_tj_array_from_operand(operands[0]) {
        Some(array) => Some(Op_TJ(array))
        None => None
      }
    [39] if operands.length() == 1 =>
      match pdf_content_operand_string(operands, 0) {
        Some(text) => Some(Op_quote(text))
        None => None
      }
    [34] if operands.length() == 3 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_string(operands, 2),
        ) {
        (Some(word_space), Some(char_space), Some(text)) =>
          Some(Op_double_quote(word_space, char_space, text))
        _ => None
      }
    [100, 48] if operands.length() == 2 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
        ) {
        (Some(width_x), Some(width_y)) => Some(Op_d0(width_x, width_y))
        _ => None
      }
    [100, 49] if operands.length() == 6 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_number(operands, 2),
          pdf_content_operand_number(operands, 3),
          pdf_content_operand_number(operands, 4),
          pdf_content_operand_number(operands, 5),
        ) {
        (
          Some(width_x),
          Some(width_y),
          Some(llx),
          Some(lly),
          Some(urx),
          Some(ury),
        ) => Some(Op_d1(width_x, width_y, llx, lly, urx, ury))
        _ => None
      }
    [71] if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(gray) => Some(Op_G(gray))
        None => None
      }
    [103] if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(gray) => Some(Op_g(gray))
        None => None
      }
    [82, 71] if operands.length() == 3 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_number(operands, 2),
        ) {
        (Some(r), Some(g), Some(b)) => Some(Op_RG(r, g, b))
        _ => None
      }
    [114, 103] if operands.length() == 3 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_number(operands, 2),
        ) {
        (Some(r), Some(g), Some(b)) => Some(Op_rg(r, g, b))
        _ => None
      }
    [75] if operands.length() == 4 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_number(operands, 2),
          pdf_content_operand_number(operands, 3),
        ) {
        (Some(c), Some(m), Some(y), Some(k)) => Some(Op_K(c, m, y, k))
        _ => None
      }
    [107] if operands.length() == 4 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_number(operands, 2),
          pdf_content_operand_number(operands, 3),
        ) {
        (Some(c), Some(m), Some(y), Some(k)) => Some(Op_k(c, m, y, k))
        _ => None
      }
    [103, 115] if operands.length() == 1 =>
      match pdf_content_operand_name(operands, 0) {
        Some(name) => Some(Op_gs(name))
        None => None
      }
    [67, 83] if operands.length() == 1 =>
      match pdf_content_operand_name(operands, 0) {
        Some(name) => Some(Op_CS(name))
        None => None
      }
    [99, 115] if operands.length() == 1 =>
      match pdf_content_operand_name(operands, 0) {
        Some(name) => Some(Op_cs(name))
        None => None
      }
    [83, 67] =>
      Some(Op_SC(pdf_content_numbers_or_malformed_color_fallback(operands)))
    [115, 99] =>
      Some(Op_sc(pdf_content_numbers_or_malformed_color_fallback(operands)))
    [83, 67, 78] =>
      match pdf_content_named_color_operands_or_malformed_fallback(operands) {
        Some((name, values)) => Some(Op_SCNName(name, values))
        None =>
          Some(
            Op_SCN(pdf_content_numbers_or_malformed_color_fallback(operands)),
          )
      }
    [115, 99, 110] =>
      match pdf_content_named_color_operands_or_malformed_fallback(operands) {
        Some((name, values)) => Some(Op_scnName(name, values))
        None =>
          Some(
            Op_scn(pdf_content_numbers_or_malformed_color_fallback(operands)),
          )
      }
    [115, 104] if operands.length() == 1 =>
      match pdf_content_operand_name(operands, 0) {
        Some(name) => Some(Op_sh(name))
        None => None
      }
    [68, 111] if operands.length() == 1 =>
      match pdf_content_operand_name(operands, 0) {
        Some(name) => Some(Op_Do(name))
        None => None
      }
    [77, 80] if operands.length() == 1 =>
      match pdf_content_operand_name(operands, 0) {
        Some(tag) => Some(Op_MP(tag))
        None => None
      }
    [68, 80] if operands.length() == 2 =>
      match pdf_content_operand_name(operands, 0) {
        Some(tag) => Some(Op_DP(tag, operands[1]))
        None => None
      }
    [66, 77, 67] if operands.length() == 1 =>
      match pdf_content_operand_name(operands, 0) {
        Some(tag) => Some(Op_BMC(tag))
        None => None
      }
    [66, 68, 67] if operands.length() == 2 =>
      match pdf_content_operand_name(operands, 0) {
        Some(tag) => Some(Op_BDC(tag, operands[1]))
        None => None
      }
    _ => None
  }
}

///|
fn pdf_content_parse_section(
  operands : ArrayView[PdfObject],
  operator : BytesView,
) -> PdfContentOp raise PdfError {
  match pdf_content_parse_known_section(operands, operator) {
    Some(op) => op
    None => pdf_content_section_unknown(operands, operator)
  }
}

///|
/// Parse standalone content bytes without document or resource context.
///
/// This is suitable for ordinary operators and inline images that can be read
/// from explicit length or filter markers. Use the document methods when stream
/// decoding or resource-based inline-image sizing is required.
pub fn pdf_parse_content_ops_from_bytes(
  data : PdfBytes,
) -> Array[PdfContentOp] raise PdfError {
  pdf_parse_content_ops_from_view(data)
}

///|
/// Parse a standalone content byte view without document or resource context.
pub fn pdf_parse_content_ops_from_view(
  data : BytesView,
) -> Array[PdfContentOp] raise PdfError {
  pdf_parse_content_ops_from_view_with_context(data, None, PdfDictionary([]))
}

///|
fn pdf_parse_content_ops_from_view_with_context(
  data : BytesView,
  document : PdfDocument?,
  resources : PdfObject,
) -> Array[PdfContentOp] raise PdfError {
  let cursor = byte_cursor_of_view(data)
  let op_capacity = pdf_content_parse_ops_capacity(data)
  let ops : Array[PdfContentOp] = Array::new(capacity=op_capacity)
  let operands : Array[PdfObject] = Array::new(capacity=8)
  let mut done = false
  while !done {
    match pdf_content_lex_next(cursor) {
      ContentEnd => done = true
      ContentComment => ()
      ContentOperand(object) => operands.push(object)
      ContentOperator(operator) =>
        if operator == pdf_content_inline_image_begin_operator &&
          operands.length() == 0 {
          ops.push(pdf_content_read_inline_image(cursor, document, resources))
        } else {
          ops.push(pdf_content_parse_section(operands, operator))
          operands.clear()
        }
    }
  }
  if operands.length() > 0 {
    raise ContentOperatorExpected
  }
  ops
}

///|
fn pdf_content_parse_ops_capacity(data : BytesView) -> Int {
  let estimated = data.length() / 12
  if estimated < 4 {
    4
  } else if estimated > 4096 {
    4096
  } else {
    estimated
  }
}
