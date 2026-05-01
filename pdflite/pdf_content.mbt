///|
pub(all) enum PdfContentOp {
  Op_w(Double)
  Op_J(Int)
  Op_j(Int)
  Op_M(Double)
  Op_q
  Op_Q
  Op_cm(TransformMatrix)
  Op_m(Double, Double)
  Op_l(Double, Double)
  Op_h
  Op_re(Double, Double, Double, Double)
  Op_S
  Op_s
  Op_f
  Op_F
  Op_fstar
  Op_B
  Op_Bstar
  Op_b
  Op_bstar
  Op_n
  Op_W
  Op_Wstar
  Op_BT
  Op_ET
  Op_Tf(PdfName, Double)
  Op_Td(Double, Double)
  Op_TD(Double, Double)
  Op_Tm(TransformMatrix)
  Op_Tstar
  Op_Tj(PdfBytes)
  Op_TJ(PdfObject)
  Op_G(Double)
  Op_g(Double)
  Op_RG(Double, Double, Double)
  Op_rg(Double, Double, Double)
  Op_K(Double, Double, Double, Double)
  Op_k(Double, Double, Double, Double)
  Op_gs(PdfName)
  Op_Do(PdfName)
  Op_Unknown(PdfBytes)
} derive(Debug, Eq, ToJson)

///|
enum PdfContentLexeme {
  ContentOperand(PdfObject)
  ContentOperator(PdfBytes)
  ContentComment
  ContentEnd
} derive(Debug, Eq, ToJson)

///|
fn pdf_content_ascii(text : String) -> PdfBytes {
  @ascii.encode(text)
}

///|
fn pdf_content_length_name() -> PdfName {
  pdf_name_of_bytes(pdf_content_ascii("/Length"))
}

///|
fn pdf_content_push_view(output : Array[Byte], view : BytesView) -> Unit {
  for byte in view {
    output.push(byte)
  }
}

///|
fn pdf_content_push_object(
  output : Array[Byte],
  object : PdfObject,
) -> Unit raise PdfError {
  pdf_content_push_view(output, pdf_write_object(object)[:])
}

///|
fn pdf_content_push_section(
  output : Array[Byte],
  operands : ArrayView[PdfObject],
  operator : PdfBytes,
) -> Unit raise PdfError {
  for operand in operands {
    if output.length() > 0 {
      output.push(32)
    }
    pdf_content_push_object(output, operand)
  }
  if output.length() > 0 {
    output.push(32)
  }
  pdf_content_push_view(output, operator[:])
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
fn pdf_content_op_section(op : PdfContentOp) -> (Array[PdfObject], PdfBytes) {
  match op {
    Op_w(width) => ([pdf_content_number_object(width)], pdf_content_ascii("w"))
    Op_J(cap) => ([PdfInteger(cap)], pdf_content_ascii("J"))
    Op_j(join) => ([PdfInteger(join)], pdf_content_ascii("j"))
    Op_M(limit) => ([pdf_content_number_object(limit)], pdf_content_ascii("M"))
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
    Op_Tf(font, size) =>
      (
        [PdfNameObject(font), pdf_content_number_object(size)],
        pdf_content_ascii("Tf"),
      )
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
    Op_Do(name) => ([PdfNameObject(name)], pdf_content_ascii("Do"))
    Op_Unknown(bytes) => ([], bytes)
  }
}

///|
pub fn pdf_content_bytes_of_ops(
  ops : ArrayView[PdfContentOp],
) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  for op in ops {
    match op {
      Op_Unknown(bytes) => {
        if output.length() > 0 {
          output.push(32)
        }
        pdf_content_push_view(output, bytes[:])
      }
      _ => {
        let (operands, operator) = pdf_content_op_section(op)
        pdf_content_push_section(output, operands, operator)
      }
    }
  }
  Bytes::from_array(output)
}

///|
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
fn pdf_content_concat_streams(streams : ArrayView[PdfBytes]) -> PdfBytes {
  let output : Array[Byte] = []
  for stream in streams {
    if output.length() > 0 {
      output.push(32)
    }
    pdf_content_push_view(output, stream[:])
  }
  Bytes::from_array(output)
}

///|
pub fn PdfDocument::parse_content_ops(
  self : PdfDocument,
  streams : ArrayView[PdfObject],
) -> Array[PdfContentOp] raise PdfError {
  let raw_streams : Array[PdfBytes] = []
  for stream_ref in streams {
    match pdf_decode_stream(self.direct(stream_ref)) {
      PdfStreamObject({ data: StreamGot(data), .. }) => raw_streams.push(data)
      _ => raise ContentOperandExpected
    }
  }
  pdf_parse_content_ops_from_bytes(pdf_content_concat_streams(raw_streams))
}

///|
fn pdf_content_read_complex_object(
  cursor : ByteCursor,
  first : PdfLexeme,
) -> PdfObject raise PdfError {
  let lexemes : Array[PdfLexeme] = [first]
  let mut array_depth = 0
  let mut dict_depth = 0
  match first {
    LexLeftSquare => array_depth = 1
    LexLeftDict => dict_depth = 1
    _ => ()
  }
  while array_depth > 0 || dict_depth > 0 {
    let token = cursor.lex_pdf_token()
    match token {
      StopLexing | LexNone => raise ParseObjectExpected
      LexLeftSquare => array_depth += 1
      LexRightSquare => array_depth -= 1
      LexLeftDict => dict_depth += 1
      LexRightDict => dict_depth -= 1
      _ => ()
    }
    lexemes.push(token)
  }
  pdf_parse_single_lexeme_object(lexemes)
}

///|
fn pdf_content_read_object(cursor : ByteCursor) -> PdfObject raise PdfError {
  let token = cursor.lex_pdf_token()
  match token {
    StopLexing | LexNone => raise ParseObjectExpected
    LexLeftSquare | LexLeftDict =>
      pdf_content_read_complex_object(cursor, token)
    _ => pdf_parse_single_lexeme_object([token])
  }
}

///|
fn pdf_content_operator_or_literal(view : BytesView) -> PdfContentLexeme {
  match view {
    [116, 114, 117, 101] => ContentOperand(PdfBoolean(true))
    [102, 97, 108, 115, 101] => ContentOperand(PdfBoolean(false))
    [110, 117, 108, 108] => ContentOperand(PdfNull)
    _ => ContentOperator(view.to_owned())
  }
}

///|
fn pdf_content_lex_next(cursor : ByteCursor) -> PdfContentLexeme raise PdfError {
  cursor.drop_pdf_whitespace()
  let value = cursor.peek_byte()
  match value {
    value if value == pdf_no_more => ContentEnd
    37 => {
      ignore(cursor.lex_pdf_comment())
      ContentComment
    }
    47 | 40 | 91 | 60 => ContentOperand(pdf_content_read_object(cursor))
    value if pdf_is_number_start_byte(value) =>
      ContentOperand(pdf_content_read_object(cursor))
    116 | 102 | 110 =>
      pdf_content_operator_or_literal(cursor.read_pdf_regular_token_view())
    _ => ContentOperator(cursor.read_pdf_regular_token_view().to_owned())
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
fn pdf_content_section_unknown(
  operands : ArrayView[PdfObject],
  operator : PdfBytes,
) -> PdfContentOp raise PdfError {
  let output : Array[Byte] = []
  pdf_content_push_section(output, operands, operator)
  Op_Unknown(Bytes::from_array(output))
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
fn pdf_content_parse_known_section(
  operands : ArrayView[PdfObject],
  operator : PdfBytes,
) -> PdfContentOp? {
  let text = @ascii.decode(operator[:]) catch { _ => "" }
  match text {
    "q" if operands.length() == 0 => Some(Op_q)
    "Q" if operands.length() == 0 => Some(Op_Q)
    "h" if operands.length() == 0 => Some(Op_h)
    "S" if operands.length() == 0 => Some(Op_S)
    "s" if operands.length() == 0 => Some(Op_s)
    "f" if operands.length() == 0 => Some(Op_f)
    "F" if operands.length() == 0 => Some(Op_F)
    "f*" if operands.length() == 0 => Some(Op_fstar)
    "B" if operands.length() == 0 => Some(Op_B)
    "B*" if operands.length() == 0 => Some(Op_Bstar)
    "b" if operands.length() == 0 => Some(Op_b)
    "b*" if operands.length() == 0 => Some(Op_bstar)
    "n" if operands.length() == 0 => Some(Op_n)
    "W" if operands.length() == 0 => Some(Op_W)
    "W*" if operands.length() == 0 => Some(Op_Wstar)
    "BT" if operands.length() == 0 => Some(Op_BT)
    "ET" if operands.length() == 0 => Some(Op_ET)
    "T*" if operands.length() == 0 => Some(Op_Tstar)
    "w" if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(width) => Some(Op_w(width))
        None => None
      }
    "J" if operands.length() == 1 =>
      match pdf_content_operand_int(operands, 0) {
        Some(cap) => Some(Op_J(cap))
        None => None
      }
    "j" if operands.length() == 1 =>
      match pdf_content_operand_int(operands, 0) {
        Some(join) => Some(Op_j(join))
        None => None
      }
    "M" if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(limit) => Some(Op_M(limit))
        None => None
      }
    "cm" if operands.length() == 6 =>
      match pdf_content_matrix_from_operands(operands) {
        Some(matrix) => Some(Op_cm(matrix))
        None => None
      }
    "Tm" if operands.length() == 6 =>
      match pdf_content_matrix_from_operands(operands) {
        Some(matrix) => Some(Op_Tm(matrix))
        None => None
      }
    "m" if operands.length() == 2 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
        ) {
        (Some(x), Some(y)) => Some(Op_m(x, y))
        _ => None
      }
    "l" if operands.length() == 2 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
        ) {
        (Some(x), Some(y)) => Some(Op_l(x, y))
        _ => None
      }
    "re" if operands.length() == 4 =>
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
    "Tf" if operands.length() == 2 =>
      match
        (
          pdf_content_operand_name(operands, 0),
          pdf_content_operand_number(operands, 1),
        ) {
        (Some(font), Some(size)) => Some(Op_Tf(font, size))
        _ => None
      }
    "Td" if operands.length() == 2 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
        ) {
        (Some(tx), Some(ty)) => Some(Op_Td(tx, ty))
        _ => None
      }
    "TD" if operands.length() == 2 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
        ) {
        (Some(tx), Some(ty)) => Some(Op_TD(tx, ty))
        _ => None
      }
    "Tj" if operands.length() == 1 =>
      match pdf_content_operand_string(operands, 0) {
        Some(text) => Some(Op_Tj(text))
        None => None
      }
    "TJ" if operands.length() == 1 => Some(Op_TJ(operands[0]))
    "G" if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(gray) => Some(Op_G(gray))
        None => None
      }
    "g" if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(gray) => Some(Op_g(gray))
        None => None
      }
    "RG" if operands.length() == 3 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_number(operands, 2),
        ) {
        (Some(r), Some(g), Some(b)) => Some(Op_RG(r, g, b))
        _ => None
      }
    "rg" if operands.length() == 3 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_number(operands, 2),
        ) {
        (Some(r), Some(g), Some(b)) => Some(Op_rg(r, g, b))
        _ => None
      }
    "K" if operands.length() == 4 =>
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
    "k" if operands.length() == 4 =>
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
    "gs" if operands.length() == 1 =>
      match pdf_content_operand_name(operands, 0) {
        Some(name) => Some(Op_gs(name))
        None => None
      }
    "Do" if operands.length() == 1 =>
      match pdf_content_operand_name(operands, 0) {
        Some(name) => Some(Op_Do(name))
        None => None
      }
    _ => None
  }
}

///|
fn pdf_content_parse_section(
  operands : ArrayView[PdfObject],
  operator : PdfBytes,
) -> PdfContentOp raise PdfError {
  match pdf_content_parse_known_section(operands, operator) {
    Some(op) => op
    None => pdf_content_section_unknown(operands, operator)
  }
}

///|
pub fn pdf_parse_content_ops_from_bytes(
  data : PdfBytes,
) -> Array[PdfContentOp] raise PdfError {
  let cursor = byte_cursor_of_bytes(data)
  let ops : Array[PdfContentOp] = []
  let operands : Array[PdfObject] = []
  let mut done = false
  while !done {
    match pdf_content_lex_next(cursor) {
      ContentEnd => done = true
      ContentComment => ()
      ContentOperand(object) => operands.push(object)
      ContentOperator(operator) => {
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
