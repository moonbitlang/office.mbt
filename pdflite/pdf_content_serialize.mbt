///|
fn pdf_content_copy_view(
  output : Array[Byte],
  position : Int,
  view : BytesView,
) -> Int {
  let mut position = position
  for byte in view {
    output[position] = byte
    position += 1
  }
  position
}

///|
fn pdf_content_section_bytes(
  operands : ArrayView[PdfObject],
  operator : BytesView,
) -> PdfBytes raise PdfError {
  let rendered_operands : Array[PdfBytes] = Array::new(
    capacity=operands.length(),
  )
  let mut length = operator.length()
  for operand in operands {
    let bytes = pdf_write_object(operand)
    length += bytes.length()
    rendered_operands.push(bytes)
  }
  if operands.length() > 0 {
    length += operands.length()
  }
  let output = Array::make(length, b' ')
  let mut position = 0
  for operand in rendered_operands {
    if position > 0 {
      output[position] = b' '
      position += 1
    }
    position = pdf_content_copy_view(output, position, operand)
  }
  if position > 0 {
    output[position] = b' '
    position += 1
  }
  position = pdf_content_copy_view(output, position, operator)
  Bytes::from_array(output[:position])
}

///|
fn pdf_content_number_object(value : Double) -> PdfObject {
  PdfReal(value)
}

///|
fn pdf_content_matrix_operands(matrix : TransformMatrix) -> Array[PdfObject] {
  [
    pdf_content_number_object(matrix.a),
    pdf_content_number_object(matrix.b),
    pdf_content_number_object(matrix.c),
    pdf_content_number_object(matrix.d),
    pdf_content_number_object(matrix.e),
    pdf_content_number_object(matrix.f),
  ]
}

///|
fn pdf_content_number_array(values : ArrayView[Double]) -> PdfObject {
  PdfArray([ for value in values => pdf_content_number_object(value) ])
}

///|
fn pdf_content_number_operands(values : ArrayView[Double]) -> Array[PdfObject] {
  [
    for value in values => pdf_content_number_object(value)
  ]
}

///|
fn pdf_content_op_section(op : PdfContentOp) -> (Array[PdfObject], PdfBytes) {
  match op {
    Op_w(width) => ([pdf_content_number_object(width)], pdf_content_ascii("w"))
    Op_J(cap) => ([PdfInteger(cap)], pdf_content_ascii("J"))
    Op_j(join) => ([PdfInteger(join)], pdf_content_ascii("j"))
    Op_M(limit) => ([pdf_content_number_object(limit)], pdf_content_ascii("M"))
    Op_d(dashes, phase) =>
      (
        [pdf_content_number_array(dashes), pdf_content_number_object(phase)],
        pdf_content_ascii("d"),
      )
    Op_ri(intent) => ([PdfNameObject(intent)], pdf_content_ascii("ri"))
    Op_i(flatness) =>
      ([pdf_content_number_object(flatness)], pdf_content_ascii("i"))
    Op_q => ([], pdf_content_ascii("q"))
    Op_Q => ([], pdf_content_ascii("Q"))
    Op_cm(matrix) =>
      (pdf_content_matrix_operands(matrix), pdf_content_ascii("cm"))
    Op_m(x, y) =>
      (
        [pdf_content_number_object(x), pdf_content_number_object(y)],
        pdf_content_ascii("m"),
      )
    Op_l(x, y) =>
      (
        [pdf_content_number_object(x), pdf_content_number_object(y)],
        pdf_content_ascii("l"),
      )
    Op_c(x1, y1, x2, y2, x3, y3) =>
      (
        [
          pdf_content_number_object(x1),
          pdf_content_number_object(y1),
          pdf_content_number_object(x2),
          pdf_content_number_object(y2),
          pdf_content_number_object(x3),
          pdf_content_number_object(y3),
        ],
        pdf_content_ascii("c"),
      )
    Op_v(x2, y2, x3, y3) =>
      (
        [
          pdf_content_number_object(x2),
          pdf_content_number_object(y2),
          pdf_content_number_object(x3),
          pdf_content_number_object(y3),
        ],
        pdf_content_ascii("v"),
      )
    Op_y(x1, y1, x3, y3) =>
      (
        [
          pdf_content_number_object(x1),
          pdf_content_number_object(y1),
          pdf_content_number_object(x3),
          pdf_content_number_object(y3),
        ],
        pdf_content_ascii("y"),
      )
    Op_h => ([], pdf_content_ascii("h"))
    Op_re(x, y, width, height) =>
      (
        [
          pdf_content_number_object(x),
          pdf_content_number_object(y),
          pdf_content_number_object(width),
          pdf_content_number_object(height),
        ],
        pdf_content_ascii("re"),
      )
    Op_S => ([], pdf_content_ascii("S"))
    Op_s => ([], pdf_content_ascii("s"))
    Op_f => ([], pdf_content_ascii("f"))
    Op_F => ([], pdf_content_ascii("F"))
    Op_fstar => ([], pdf_content_ascii("f*"))
    Op_B => ([], pdf_content_ascii("B"))
    Op_Bstar => ([], pdf_content_ascii("B*"))
    Op_b => ([], pdf_content_ascii("b"))
    Op_bstar => ([], pdf_content_ascii("b*"))
    Op_n => ([], pdf_content_ascii("n"))
    Op_W => ([], pdf_content_ascii("W"))
    Op_Wstar => ([], pdf_content_ascii("W*"))
    Op_BT => ([], pdf_content_ascii("BT"))
    Op_ET => ([], pdf_content_ascii("ET"))
    Op_Tc(spacing) =>
      ([pdf_content_number_object(spacing)], pdf_content_ascii("Tc"))
    Op_Tw(spacing) =>
      ([pdf_content_number_object(spacing)], pdf_content_ascii("Tw"))
    Op_Tz(scale) =>
      ([pdf_content_number_object(scale)], pdf_content_ascii("Tz"))
    Op_TL(leading) =>
      ([pdf_content_number_object(leading)], pdf_content_ascii("TL"))
    Op_Tf(font, size) =>
      (
        [PdfNameObject(font), pdf_content_number_object(size)],
        pdf_content_ascii("Tf"),
      )
    Op_Tr(mode) => ([PdfInteger(mode)], pdf_content_ascii("Tr"))
    Op_Ts(rise) => ([pdf_content_number_object(rise)], pdf_content_ascii("Ts"))
    Op_Td(tx, ty) =>
      (
        [pdf_content_number_object(tx), pdf_content_number_object(ty)],
        pdf_content_ascii("Td"),
      )
    Op_TD(tx, ty) =>
      (
        [pdf_content_number_object(tx), pdf_content_number_object(ty)],
        pdf_content_ascii("TD"),
      )
    Op_Tm(matrix) =>
      (pdf_content_matrix_operands(matrix), pdf_content_ascii("Tm"))
    Op_Tstar => ([], pdf_content_ascii("T*"))
    Op_Tj(text) => ([PdfString(text)], pdf_content_ascii("Tj"))
    Op_TJ(array) => ([array], pdf_content_ascii("TJ"))
    Op_quote(text) => ([PdfString(text)], pdf_content_ascii("'"))
    Op_double_quote(word_space, char_space, text) =>
      (
        [
          pdf_content_number_object(word_space),
          pdf_content_number_object(char_space),
          PdfString(text),
        ],
        pdf_content_ascii("\""),
      )
    Op_d0(width_x, width_y) =>
      (
        [pdf_content_number_object(width_x), pdf_content_number_object(width_y)],
        pdf_content_ascii("d0"),
      )
    Op_d1(width_x, width_y, llx, lly, urx, ury) =>
      (
        [
          pdf_content_number_object(width_x),
          pdf_content_number_object(width_y),
          pdf_content_number_object(llx),
          pdf_content_number_object(lly),
          pdf_content_number_object(urx),
          pdf_content_number_object(ury),
        ],
        pdf_content_ascii("d1"),
      )
    Op_G(gray) => ([pdf_content_number_object(gray)], pdf_content_ascii("G"))
    Op_g(gray) => ([pdf_content_number_object(gray)], pdf_content_ascii("g"))
    Op_RG(r, g, b) =>
      (
        [
          pdf_content_number_object(r),
          pdf_content_number_object(g),
          pdf_content_number_object(b),
        ],
        pdf_content_ascii("RG"),
      )
    Op_rg(r, g, b) =>
      (
        [
          pdf_content_number_object(r),
          pdf_content_number_object(g),
          pdf_content_number_object(b),
        ],
        pdf_content_ascii("rg"),
      )
    Op_K(c, m, y, k) =>
      (
        [
          pdf_content_number_object(c),
          pdf_content_number_object(m),
          pdf_content_number_object(y),
          pdf_content_number_object(k),
        ],
        pdf_content_ascii("K"),
      )
    Op_k(c, m, y, k) =>
      (
        [
          pdf_content_number_object(c),
          pdf_content_number_object(m),
          pdf_content_number_object(y),
          pdf_content_number_object(k),
        ],
        pdf_content_ascii("k"),
      )
    Op_gs(name) => ([PdfNameObject(name)], pdf_content_ascii("gs"))
    Op_CS(name) => ([PdfNameObject(name)], pdf_content_ascii("CS"))
    Op_cs(name) => ([PdfNameObject(name)], pdf_content_ascii("cs"))
    Op_SC(values) =>
      (pdf_content_number_operands(values), pdf_content_ascii("SC"))
    Op_sc(values) =>
      (pdf_content_number_operands(values), pdf_content_ascii("sc"))
    Op_SCN(values) =>
      (pdf_content_number_operands(values), pdf_content_ascii("SCN"))
    Op_scn(values) =>
      (pdf_content_number_operands(values), pdf_content_ascii("scn"))
    Op_SCNName(name, values) =>
      (
        [..pdf_content_number_operands(values), PdfNameObject(name)],
        pdf_content_ascii("SCN"),
      )
    Op_scnName(name, values) =>
      (
        [..pdf_content_number_operands(values), PdfNameObject(name)],
        pdf_content_ascii("scn"),
      )
    Op_sh(name) => ([PdfNameObject(name)], pdf_content_ascii("sh"))
    Op_Do(name) => ([PdfNameObject(name)], pdf_content_ascii("Do"))
    Op_InlineImage(_, _, _) => ([], pdf_content_ascii(""))
    Op_MP(tag) => ([PdfNameObject(tag)], pdf_content_ascii("MP"))
    Op_DP(tag, properties) =>
      ([PdfNameObject(tag), properties], pdf_content_ascii("DP"))
    Op_BMC(tag) => ([PdfNameObject(tag)], pdf_content_ascii("BMC"))
    Op_BDC(tag, properties) =>
      ([PdfNameObject(tag), properties], pdf_content_ascii("BDC"))
    Op_EMC => ([], pdf_content_ascii("EMC"))
    Op_BX => ([], pdf_content_ascii("BX"))
    Op_EX => ([], pdf_content_ascii("EX"))
    Op_Unknown(bytes) => ([], bytes)
  }
}

///|
fn pdf_content_inline_image_entry_bytes(
  key : PdfName,
  value : PdfObject,
) -> PdfBytes raise PdfError {
  let key_bytes = pdf_write_object(PdfNameObject(key))
  let value_bytes = pdf_write_object(value)
  let output = Array::make(
    1 + key_bytes.length() + 1 + value_bytes.length(),
    b' ',
  )
  let mut position = 1
  position = pdf_content_copy_view(output, position, key_bytes)
  position += 1
  let _ = pdf_content_copy_view(output, position, value_bytes)
  Bytes::from_array(output)
}

///|
fn pdf_content_inline_image_bytes(
  dictionary : PdfObject,
  decode_parms : PdfObject?,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  let compress_inline_image = pdf_content_inline_filter_is_empty(dictionary)
  let (render_data, render_decode_parms, render_extra_entries) = if compress_inline_image {
    let encoded = pdf_flate_encode(data)
    (
      encoded,
      None,
      [
        (
          pdf_content_inline_f_name(),
          PdfNameObject(pdf_content_inline_fl_name()),
        ),
        (pdf_content_inline_l_name(), PdfInteger(encoded.length())),
      ],
    )
  } else {
    (data, decode_parms, [])
  }
  match dictionary {
    PdfDictionary(entries) => {
      let decode_parms_entry_count = if render_decode_parms is Some(_) {
        1
      } else {
        0
      }
      let rendered_entries : Array[PdfBytes] = Array::new(
        capacity=entries.length() +
          render_extra_entries.length() +
          decode_parms_entry_count,
      )
      for entry in entries {
        let (key, value) = entry
        if !compress_inline_image ||
          (
            key != pdf_content_inline_filter_name() &&
            key != pdf_content_inline_f_name() &&
            key != pdf_content_inline_decode_parms_name() &&
            key != pdf_content_inline_dp_name() &&
            key != pdf_content_length_name() &&
            key != pdf_content_inline_l_name()
          ) {
          rendered_entries.push(
            pdf_content_inline_image_entry_bytes(key, value),
          )
        }
      }
      for entry in render_extra_entries {
        let (key, value) = entry
        rendered_entries.push(pdf_content_inline_image_entry_bytes(key, value))
      }
      match render_decode_parms {
        Some(value) =>
          rendered_entries.push(
            pdf_content_inline_image_entry_bytes(
              pdf_content_inline_dp_name(),
              value,
            ),
          )
        None => ()
      }
      let data_marker = pdf_content_ascii(" ID ")
      let end_marker = pdf_content_ascii(" EI")
      let mut length = pdf_content_inline_image_begin_operator.length()
      for entry in rendered_entries {
        length += entry.length()
      }
      length += data_marker.length() +
        render_data.length() +
        end_marker.length()
      let output = Array::make(length, b'\x00')
      let mut position = pdf_content_copy_view(
        output, 0, pdf_content_inline_image_begin_operator,
      )
      for entry in rendered_entries {
        position = pdf_content_copy_view(output, position, entry)
      }
      position = pdf_content_copy_view(output, position, data_marker)
      position = pdf_content_copy_view(output, position, render_data)
      let _ = pdf_content_copy_view(output, position, end_marker)
      Bytes::from_array(output)
    }
    _ => raise DictionaryExpected
  }
}

///|
fn pdf_content_op_bytes(op : PdfContentOp) -> PdfBytes raise PdfError {
  match op {
    Op_InlineImage(dictionary, decode_parms, data) =>
      pdf_content_inline_image_bytes(dictionary, decode_parms, data)
    Op_Unknown(bytes) => bytes
    _ => {
      let (operands, operator) = pdf_content_op_section(op)
      pdf_content_section_bytes(operands, operator)
    }
  }
}

///|
/// Serialize content operators to PDF content-stream bytes.
///
/// Operators are separated with whitespace. `Op_Unknown` bytes are emitted as
/// captured. Inline images with no filter are Flate-encoded and written with
/// inline `/F /Fl` and `/L` metadata; inline images with existing filters keep
/// their supplied encoded data and decode parameters.
pub fn pdf_content_bytes_of_ops(
  ops : ArrayView[PdfContentOp],
) -> PdfBytes raise PdfError {
  let rendered : Array[(PdfBytes, Bool)] = Array::new(capacity=ops.length())
  let mut length = 0
  for op in ops {
    let bytes = pdf_content_op_bytes(op)
    let has_separator = length > 0
    if has_separator {
      length += 1
    }
    length += bytes.length()
    rendered.push((bytes, has_separator))
  }
  let output = Array::make(length, b' ')
  let mut position = 0
  for entry in rendered {
    if entry.1 {
      output[position] = 32
      position += 1
    }
    position = pdf_content_copy_view(output, position, entry.0)
  }
  Bytes::from_array(output)
}

///|
/// Serialize one content operator to PDF content-stream bytes.
pub fn pdf_content_bytes_of_op(op : PdfContentOp) -> PdfBytes raise PdfError {
  pdf_content_bytes_of_ops([op])
}

///|
/// Compatibility wrapper for `pdf_content_bytes_of_ops`.
///
/// The name follows CamlPDF, where strings were byte sequences; this function
/// returns `PdfBytes`.
pub fn pdf_string_of_content_ops(
  ops : ArrayView[PdfContentOp],
) -> PdfBytes raise PdfError {
  pdf_content_bytes_of_ops(ops)
}

///|
/// Compatibility wrapper for `pdf_content_bytes_of_op`.
///
/// The name follows CamlPDF, where strings were byte sequences; this function
/// returns `PdfBytes`.
pub fn pdf_string_of_content_op(op : PdfContentOp) -> PdfBytes raise PdfError {
  pdf_content_bytes_of_op(op)
}

///|
/// Build an uncompressed PDF stream object from content operators.
///
/// The returned stream dictionary contains `/Length` for the serialized byte
/// length and no outer stream filter.
pub fn pdf_content_stream_of_ops(
  ops : ArrayView[PdfContentOp],
) -> PdfObject raise PdfError {
  let data = pdf_content_bytes_of_ops(ops)
  pdf_stream(
    PdfDictionary([(pdf_content_length_name(), PdfInteger(data.length()))]),
    StreamGot(data),
  )
}

///|
/// Concatenate already-decoded content stream views with a single space between them.
pub fn pdf_content_concat_stream_views(
  streams : ArrayView[BytesView],
) -> PdfBytes {
  let mut length = 0
  let mut has_output = false
  for stream in streams {
    if has_output {
      length += 1
    }
    length += stream.length()
    if stream.length() > 0 {
      has_output = true
    }
  }
  if length == 0 {
    return Bytes::new(0)
  }
  let output = Array::make(length, b' ')
  let mut position = 0
  has_output = false
  for stream in streams {
    if has_output {
      output[position] = b' '
      position += 1
    }
    for byte in stream {
      output[position] = byte
      position += 1
    }
    if stream.length() > 0 {
      has_output = true
    }
  }
  Bytes::from_array(output)
}

///|
/// Concatenate already-decoded content streams with a single space between them.
pub fn pdf_content_concat_streams(streams : ArrayView[PdfBytes]) -> PdfBytes {
  let mut length = 0
  let mut has_output = false
  for stream in streams {
    if has_output {
      length += 1
    }
    length += stream.length()
    if stream.length() > 0 {
      has_output = true
    }
  }
  if length == 0 {
    return Bytes::new(0)
  }
  let output = Array::make(length, b' ')
  let mut position = 0
  has_output = false
  for stream in streams {
    if has_output {
      output[position] = b' '
      position += 1
    }
    for byte in stream {
      output[position] = byte
      position += 1
    }
    if stream.length() > 0 {
      has_output = true
    }
  }
  Bytes::from_array(output)
}
