///|
/// Flat representation of PDF content stream operators.
///
/// Text strings and unknown operators are stored as raw PDF bytes. Inline images
/// carry their image dictionary, optional decode parameters, and image data; the
/// parser decodes supported inline-image filters when it can do so safely.
pub(all) enum PdfContentOp {
  Op_w(Double)
  Op_J(Int)
  Op_j(Int)
  Op_M(Double)
  Op_d(Array[Double], Double)
  Op_ri(PdfName)
  Op_i(Double)
  Op_q
  Op_Q
  Op_cm(TransformMatrix)
  Op_m(Double, Double)
  Op_l(Double, Double)
  Op_c(Double, Double, Double, Double, Double, Double)
  Op_v(Double, Double, Double, Double)
  Op_y(Double, Double, Double, Double)
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
  Op_Tc(Double)
  Op_Tw(Double)
  Op_Tz(Double)
  Op_TL(Double)
  Op_Tf(PdfName, Double)
  Op_Tr(Int)
  Op_Ts(Double)
  Op_Td(Double, Double)
  Op_TD(Double, Double)
  Op_Tm(TransformMatrix)
  Op_Tstar
  Op_Tj(PdfBytes)
  Op_TJ(PdfObject)
  Op_quote(PdfBytes)
  Op_double_quote(Double, Double, PdfBytes)
  Op_d0(Double, Double)
  Op_d1(Double, Double, Double, Double, Double, Double)
  Op_G(Double)
  Op_g(Double)
  Op_RG(Double, Double, Double)
  Op_rg(Double, Double, Double)
  Op_K(Double, Double, Double, Double)
  Op_k(Double, Double, Double, Double)
  Op_gs(PdfName)
  Op_CS(PdfName)
  Op_cs(PdfName)
  Op_SC(Array[Double])
  Op_sc(Array[Double])
  Op_SCN(Array[Double])
  Op_scn(Array[Double])
  Op_SCNName(PdfName, Array[Double])
  Op_scnName(PdfName, Array[Double])
  Op_sh(PdfName)
  Op_Do(PdfName)
  Op_InlineImage(PdfObject, PdfObject?, PdfBytes)
  Op_MP(PdfName)
  Op_DP(PdfName, PdfObject)
  Op_BMC(PdfName)
  Op_BDC(PdfName, PdfObject)
  Op_EMC
  Op_BX
  Op_EX
  Op_Unknown(PdfBytes)
} derive(Debug, Eq, ToJson)

///|
enum PdfContentLexeme {
  ContentOperand(PdfObject)
  ContentOperator(BytesView)
  ContentComment
  ContentEnd
} derive(Debug, Eq, ToJson)

///|
enum PdfContentInlineTextFilter {
  PdfContentInlineAsciiHex
  PdfContentInlineAscii85
} derive(Debug, Eq)

///|
fn pdf_content_ascii(text : String) -> PdfBytes {
  @ascii.encode(text)
}

///|
fn pdf_content_name(text : String) -> PdfName {
  pdf_name_of_bytes(pdf_content_ascii(text))
}

///|
let pdf_content_length_key_name : PdfName = pdf_content_name("/Length")

///|
let pdf_content_inline_l_key_name : PdfName = pdf_content_name("/L")

///|
let pdf_content_artifact_name : PdfName = pdf_content_name("/Artifact")

///|
let pdf_content_begin_artifact_name : PdfName = pdf_content_name(
  "/BeginArtifact",
)

///|
let pdf_content_end_artifact_name : PdfName = pdf_content_name("/EndArtifact")

///|
let pdf_content_inline_image_begin_operator : PdfBytes = pdf_content_ascii("BI")

///|
let pdf_content_inline_image_data_operator : PdfBytes = pdf_content_ascii("ID")

///|
fn pdf_content_length_name() -> PdfName {
  pdf_content_length_key_name
}

///|
fn pdf_content_inline_l_name() -> PdfName {
  pdf_content_inline_l_key_name
}

///|
/// Return the marked-content operation that begins a PDF/UA artifact.
pub fn pdf_content_begin_artifact() -> PdfContentOp {
  Op_BMC(pdf_content_artifact_name)
}

///|
/// Return the marked-content operation that ends the current PDF/UA artifact.
pub fn pdf_content_end_artifact() -> PdfContentOp {
  Op_EMC
}

///|
/// Mark unmarked content operations as PDF/UA artifacts.
///
/// This ports `cpdftype.ml`'s `add_artifacts` pass. Existing marked-content
/// sections entered with `BDC` are preserved as real content; unmarked runs are
/// wrapped in `/Artifact BMC ... EMC`. Back-channel `/BeginArtifact` and
/// `/EndArtifact` markers are converted to ordinary artifact marked content.
pub fn pdf_content_add_artifacts(
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  let mut in_content = false
  let mut in_artifact = false
  for op in ops {
    match op {
      Op_BMC(name) if name == pdf_content_begin_artifact_name => {
        in_artifact = true
        output.push(Op_BMC(pdf_content_artifact_name))
      }
      Op_BMC(name) if name == pdf_content_end_artifact_name => {
        in_artifact = false
        output.push(Op_EMC)
      }
      Op_BDC(_, _) => {
        if in_artifact {
          output.push(Op_EMC)
        }
        in_content = true
        in_artifact = false
        output.push(op)
      }
      Op_EMC => {
        in_content = false
        output.push(op)
      }
      _ => {
        if !(in_content || in_artifact) {
          in_artifact = true
          output.push(Op_BMC(pdf_content_artifact_name))
        }
        output.push(op)
      }
    }
  }
  if in_artifact {
    output.push(Op_EMC)
  }
  output
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
  pdf_content_push_view(output, pdf_write_object(object))
}

///|
fn pdf_content_push_section(
  output : Array[Byte],
  operands : ArrayView[PdfObject],
  operator : BytesView,
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
  pdf_content_push_view(output, operator)
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
fn pdf_content_push_inline_image_entry(
  output : Array[Byte],
  key : PdfName,
  value : PdfObject,
) -> Unit raise PdfError {
  output.push(32)
  pdf_content_push_object(output, PdfNameObject(key))
  output.push(32)
  pdf_content_push_object(output, value)
}

///|
fn pdf_content_push_inline_image(
  output : Array[Byte],
  dictionary : PdfObject,
  decode_parms : PdfObject?,
  data : PdfBytes,
) -> Unit raise PdfError {
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
  if output.length() > 0 {
    output.push(32)
  }
  pdf_content_push_view(output, pdf_content_ascii("BI"))
  match dictionary {
    PdfDictionary(entries) =>
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
          pdf_content_push_inline_image_entry(output, key, value)
        }
      }
    _ => raise DictionaryExpected
  }
  for entry in render_extra_entries {
    let (key, value) = entry
    pdf_content_push_inline_image_entry(output, key, value)
  }
  match render_decode_parms {
    Some(value) =>
      pdf_content_push_inline_image_entry(
        output,
        pdf_content_inline_dp_name(),
        value,
      )
    None => ()
  }
  pdf_content_push_view(output, pdf_content_ascii(" ID "))
  pdf_content_push_view(output, render_data)
  pdf_content_push_view(output, pdf_content_ascii(" EI"))
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
  let output : Array[Byte] = []
  for op in ops {
    match op {
      Op_InlineImage(dictionary, decode_parms, data) =>
        pdf_content_push_inline_image(output, dictionary, decode_parms, data)
      Op_Unknown(bytes) => {
        if output.length() > 0 {
          output.push(32)
        }
        pdf_content_push_view(output, bytes)
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

///|
/// Decode and parse a list of content stream objects from this document.
///
/// Each input must resolve to a stream object. Stream filters are decoded before
/// parsing, then the decoded streams are concatenated with whitespace. Use
/// `parse_content_ops_with_resources` when inline-image length inference needs
/// page resources.
pub fn PdfDocument::parse_content_ops(
  self : PdfDocument,
  streams : ArrayView[PdfObject],
) -> Array[PdfContentOp] raise PdfError {
  let raw_streams = self.pdf_content_raw_streams(streams)
  pdf_parse_content_ops_from_view(pdf_content_concat_streams(raw_streams))
}

///|
/// Decode and parse content stream objects with page resources.
///
/// The resource dictionary is used for inline-image color-space component
/// lookup when an unfiltered inline image has no reliable declared length.
pub fn PdfDocument::parse_content_ops_with_resources(
  self : PdfDocument,
  resources : PdfObject,
  streams : ArrayView[PdfObject],
) -> Array[PdfContentOp] raise PdfError {
  let raw_streams = self.pdf_content_raw_streams(streams)
  pdf_parse_content_ops_from_view_with_context(
    pdf_content_concat_streams(raw_streams),
    Some(self),
    resources,
  )
}

///|
/// Parse content bytes with page resources.
///
/// This is the owned-byte wrapper for `parse_content_view_with_resources`.
pub fn PdfDocument::parse_content_bytes_with_resources(
  self : PdfDocument,
  resources : PdfObject,
  data : PdfBytes,
) -> Array[PdfContentOp] raise PdfError {
  self.parse_content_view_with_resources(resources, data)
}

///|
/// Parse a content byte view with page resources.
///
/// The input view is read directly; returned operators own any byte data they
/// need to keep, such as text strings and inline-image data.
pub fn PdfDocument::parse_content_view_with_resources(
  self : PdfDocument,
  resources : PdfObject,
  data : BytesView,
) -> Array[PdfContentOp] raise PdfError {
  pdf_parse_content_ops_from_view_with_context(data, Some(self), resources)
}

///|
fn PdfDocument::pdf_content_raw_streams(
  self : PdfDocument,
  streams : ArrayView[PdfObject],
) -> Array[PdfBytes] raise PdfError {
  let raw_streams : Array[PdfBytes] = []
  for stream_ref in streams {
    match self.direct(stream_ref) {
      PdfStreamObject(stream) =>
        raw_streams.push(
          pdf_stream_data_bytes(
            self.pdf_decode_stream_value_direct(stream).data,
          ),
        )
      _ => raise ParseStreamExpected
    }
  }
  raw_streams
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
    _ => ContentOperator(view)
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
    _ => ContentOperator(cursor.read_pdf_regular_token_view())
  }
}

///|
let pdf_content_inline_decode_parms_key_name : PdfName = pdf_content_name(
  "/DecodeParms",
)

///|
let pdf_content_inline_dp_key_name : PdfName = pdf_content_name("/DP")

///|
let pdf_content_inline_filter_key_name : PdfName = pdf_content_name("/Filter")

///|
let pdf_content_inline_f_key_name : PdfName = pdf_content_name("/F")

///|
let pdf_content_inline_dctdecode_name_value : PdfName = pdf_content_name(
  "/DCTDecode",
)

///|
let pdf_content_inline_dct_name_value : PdfName = pdf_content_name("/DCT")

///|
let pdf_content_inline_ascii_hexdecode_name_value : PdfName = pdf_content_name(
  "/ASCIIHexDecode",
)

///|
let pdf_content_inline_ahx_name_value : PdfName = pdf_content_name("/AHx")

///|
let pdf_content_inline_ascii85decode_name_value : PdfName = pdf_content_name(
  "/ASCII85Decode",
)

///|
let pdf_content_inline_a85_name_value : PdfName = pdf_content_name("/A85")

///|
let pdf_content_inline_runlengthdecode_name_value : PdfName = pdf_content_name(
  "/RunLengthDecode",
)

///|
let pdf_content_inline_rl_name_value : PdfName = pdf_content_name("/RL")

///|
let pdf_content_inline_flatedecode_name_value : PdfName = pdf_content_name(
  "/FlateDecode",
)

///|
let pdf_content_inline_fl_name_value : PdfName = pdf_content_name("/Fl")

///|
let pdf_content_inline_lzwdecode_name_value : PdfName = pdf_content_name(
  "/LZWDecode",
)

///|
let pdf_content_inline_lzw_name_value : PdfName = pdf_content_name("/LZW")

///|
let pdf_content_inline_im_key_name : PdfName = pdf_content_name("/IM")

///|
let pdf_content_inline_image_mask_key_name : PdfName = pdf_content_name(
  "/ImageMask",
)

///|
let pdf_content_inline_cs_key_name : PdfName = pdf_content_name("/CS")

///|
let pdf_content_inline_colorspace_key_name : PdfName = pdf_content_name(
  "/ColorSpace",
)

///|
let pdf_content_inline_g_name : PdfName = pdf_content_name("/G")

///|
let pdf_content_inline_device_gray_name : PdfName = pdf_content_name(
  "/DeviceGray",
)

///|
let pdf_content_inline_rgb_name : PdfName = pdf_content_name("/RGB")

///|
let pdf_content_inline_device_rgb_name : PdfName = pdf_content_name(
  "/DeviceRGB",
)

///|
let pdf_content_inline_cmyk_name : PdfName = pdf_content_name("/CMYK")

///|
let pdf_content_inline_device_cmyk_name : PdfName = pdf_content_name(
  "/DeviceCMYK",
)

///|
let pdf_content_inline_bpc_key_name : PdfName = pdf_content_name("/BPC")

///|
let pdf_content_inline_bits_per_component_key_name : PdfName = pdf_content_name(
  "/BitsPerComponent",
)

///|
let pdf_content_inline_w_key_name : PdfName = pdf_content_name("/W")

///|
let pdf_content_inline_width_key_name : PdfName = pdf_content_name("/Width")

///|
let pdf_content_inline_h_key_name : PdfName = pdf_content_name("/H")

///|
let pdf_content_inline_height_key_name : PdfName = pdf_content_name("/Height")

///|
fn pdf_content_inline_decode_parms_name() -> PdfName {
  pdf_content_inline_decode_parms_key_name
}

///|
fn pdf_content_inline_dp_name() -> PdfName {
  pdf_content_inline_dp_key_name
}

///|
fn pdf_content_inline_filter_name() -> PdfName {
  pdf_content_inline_filter_key_name
}

///|
fn pdf_content_inline_f_name() -> PdfName {
  pdf_content_inline_f_key_name
}

///|
fn pdf_content_inline_dctdecode_name() -> PdfName {
  pdf_content_inline_dctdecode_name_value
}

///|
fn pdf_content_inline_dct_name() -> PdfName {
  pdf_content_inline_dct_name_value
}

///|
fn pdf_content_inline_ascii_hexdecode_name() -> PdfName {
  pdf_content_inline_ascii_hexdecode_name_value
}

///|
fn pdf_content_inline_ahx_name() -> PdfName {
  pdf_content_inline_ahx_name_value
}

///|
fn pdf_content_inline_ascii85decode_name() -> PdfName {
  pdf_content_inline_ascii85decode_name_value
}

///|
fn pdf_content_inline_a85_name() -> PdfName {
  pdf_content_inline_a85_name_value
}

///|
fn pdf_content_inline_runlengthdecode_name() -> PdfName {
  pdf_content_inline_runlengthdecode_name_value
}

///|
fn pdf_content_inline_rl_name() -> PdfName {
  pdf_content_inline_rl_name_value
}

///|
fn pdf_content_inline_flatedecode_name() -> PdfName {
  pdf_content_inline_flatedecode_name_value
}

///|
fn pdf_content_inline_fl_name() -> PdfName {
  pdf_content_inline_fl_name_value
}

///|
fn pdf_content_inline_lzwdecode_name() -> PdfName {
  pdf_content_inline_lzwdecode_name_value
}

///|
fn pdf_content_inline_lzw_name() -> PdfName {
  pdf_content_inline_lzw_name_value
}

///|
fn pdf_content_inline_filter_value(dictionary : PdfObject) -> PdfObject? {
  match dictionary.lookup_immediate(pdf_content_inline_f_name()) {
    Some(value) => Some(value)
    None => dictionary.lookup_immediate(pdf_content_inline_filter_name())
  }
}

///|
fn pdf_content_inline_lookup_orelse(
  dictionary : PdfObject,
  first : PdfName,
  second : PdfName,
) -> PdfObject? {
  match dictionary.lookup_immediate(first) {
    Some(value) => Some(value)
    None => dictionary.lookup_immediate(second)
  }
}

///|
fn pdf_content_inline_int_orelse(
  dictionary : PdfObject,
  first : PdfName,
  second : PdfName,
) -> Int? {
  match pdf_content_inline_lookup_orelse(dictionary, first, second) {
    Some(PdfInteger(value)) if value >= 0 => Some(value)
    _ => None
  }
}

///|
fn pdf_content_inline_image_mask(dictionary : PdfObject) -> Bool {
  match
    pdf_content_inline_lookup_orelse(
      dictionary, pdf_content_inline_im_key_name, pdf_content_inline_image_mask_key_name,
    ) {
    Some(PdfBoolean(true)) => true
    _ => false
  }
}

///|
fn pdf_content_inline_components(
  document : PdfDocument?,
  resources : PdfObject,
  dictionary : PdfObject,
) -> Int? raise PdfError {
  match
    pdf_content_inline_lookup_orelse(
      dictionary, pdf_content_inline_cs_key_name, pdf_content_inline_colorspace_key_name,
    ) {
    Some(PdfNameObject(name)) =>
      if name == pdf_content_inline_g_name ||
        name == pdf_content_inline_device_gray_name {
        Some(1)
      } else if name == pdf_content_inline_rgb_name ||
        name == pdf_content_inline_device_rgb_name {
        Some(3)
      } else if name == pdf_content_inline_cmyk_name ||
        name == pdf_content_inline_device_cmyk_name {
        Some(4)
      } else {
        match document {
          Some(document) =>
            Some(
              document.colour_space_components(resources, PdfNameObject(name)),
            )
          None => None
        }
      }
    Some(colour_space) =>
      match document {
        Some(document) =>
          Some(document.colour_space_components(resources, colour_space))
        None => None
      }
    None if pdf_content_inline_image_mask(dictionary) => Some(1)
    _ => None
  }
}

///|
fn pdf_content_inline_bits_per_component(dictionary : PdfObject) -> Int? {
  match
    pdf_content_inline_int_orelse(
      dictionary, pdf_content_inline_bpc_key_name, pdf_content_inline_bits_per_component_key_name,
    ) {
    Some(value) if value > 0 => Some(value)
    None if pdf_content_inline_image_mask(dictionary) => Some(1)
    _ => None
  }
}

///|
fn pdf_content_inline_declared_data_length(dictionary : PdfObject) -> Int? {
  pdf_content_inline_int_orelse(
    dictionary, pdf_content_inline_l_key_name, pdf_content_length_key_name,
  )
}

///|
fn pdf_content_inline_filter_is_empty(dictionary : PdfObject) -> Bool {
  match pdf_content_inline_filter_value(dictionary) {
    None | Some(PdfArray([])) => true
    _ => false
  }
}

///|
fn pdf_content_inline_image_data_length(
  document : PdfDocument?,
  resources : PdfObject,
  dictionary : PdfObject,
) -> Int? raise PdfError {
  if !pdf_content_inline_filter_is_empty(dictionary) {
    pdf_content_inline_declared_data_length(dictionary)
  } else {
    let declared = pdf_content_inline_declared_data_length(dictionary)
    let metadata_length = try {
      match
        (
          pdf_content_inline_int_orelse(
            dictionary, pdf_content_inline_w_key_name, pdf_content_inline_width_key_name,
          ),
          pdf_content_inline_int_orelse(
            dictionary, pdf_content_inline_h_key_name, pdf_content_inline_height_key_name,
          ),
          pdf_content_inline_bits_per_component(dictionary),
          pdf_content_inline_components(document, resources, dictionary),
        ) {
        (Some(width), Some(height), Some(bits), Some(components)) => {
          let row_bits = width * components * bits
          let row_bytes = if row_bits % 8 == 0 {
            row_bits / 8
          } else {
            row_bits / 8 + 1
          }
          Some(row_bytes * height)
        }
        _ => None
      }
    } catch {
      error =>
        match declared {
          Some(_) => declared
          None => raise error
        }
    }
    match metadata_length {
      Some(length) => Some(length)
      None => declared
    }
  }
}

///|
fn pdf_content_filter_is_inline_dct(filter : PdfObject) -> Bool {
  match filter {
    PdfNameObject(name) =>
      name == pdf_content_inline_dctdecode_name() ||
      name == pdf_content_inline_dct_name()
    PdfArray([PdfNameObject(name), ..]) =>
      name == pdf_content_inline_dctdecode_name() ||
      name == pdf_content_inline_dct_name()
    _ => false
  }
}

///|
fn pdf_content_filter_name_inline_text_filter(
  name : PdfName,
) -> PdfContentInlineTextFilter? {
  if name == pdf_content_inline_ascii_hexdecode_name() ||
    name == pdf_content_inline_ahx_name() {
    Some(PdfContentInlineAsciiHex)
  } else if name == pdf_content_inline_ascii85decode_name() ||
    name == pdf_content_inline_a85_name() {
    Some(PdfContentInlineAscii85)
  } else {
    None
  }
}

///|
fn pdf_content_filter_inline_text_filter(
  filter : PdfObject,
) -> PdfContentInlineTextFilter? {
  match filter {
    PdfNameObject(name) => pdf_content_filter_name_inline_text_filter(name)
    PdfArray([PdfNameObject(name), ..]) =>
      pdf_content_filter_name_inline_text_filter(name)
    _ => None
  }
}

///|
fn pdf_content_filter_single_inline_text_filter(
  filter : PdfObject,
) -> PdfContentInlineTextFilter? {
  match filter {
    PdfNameObject(name) => pdf_content_filter_name_inline_text_filter(name)
    PdfArray([PdfNameObject(name)]) =>
      pdf_content_filter_name_inline_text_filter(name)
    _ => None
  }
}

///|
fn pdf_content_filter_name_is_inline_run_length(name : PdfName) -> Bool {
  name == pdf_content_inline_runlengthdecode_name() ||
  name == pdf_content_inline_rl_name()
}

///|
fn pdf_content_filter_is_inline_run_length(filter : PdfObject) -> Bool {
  match filter {
    PdfNameObject(name) => pdf_content_filter_name_is_inline_run_length(name)
    PdfArray([PdfNameObject(name), ..]) =>
      pdf_content_filter_name_is_inline_run_length(name)
    _ => false
  }
}

///|
fn pdf_content_filter_is_single_inline_run_length(filter : PdfObject) -> Bool {
  match filter {
    PdfNameObject(name) => pdf_content_filter_name_is_inline_run_length(name)
    PdfArray([PdfNameObject(name)]) =>
      pdf_content_filter_name_is_inline_run_length(name)
    _ => false
  }
}

///|
fn pdf_content_filter_name_is_inline_flate(name : PdfName) -> Bool {
  name == pdf_content_inline_flatedecode_name() ||
  name == pdf_content_inline_fl_name()
}

///|
fn pdf_content_filter_is_inline_flate(filter : PdfObject) -> Bool {
  match filter {
    PdfNameObject(name) => pdf_content_filter_name_is_inline_flate(name)
    PdfArray([PdfNameObject(name), ..]) =>
      pdf_content_filter_name_is_inline_flate(name)
    _ => false
  }
}

///|
fn pdf_content_filter_is_single_inline_flate(filter : PdfObject) -> Bool {
  match filter {
    PdfNameObject(name) => pdf_content_filter_name_is_inline_flate(name)
    PdfArray([PdfNameObject(name)]) =>
      pdf_content_filter_name_is_inline_flate(name)
    _ => false
  }
}

///|
fn pdf_content_filter_name_is_inline_lzw(name : PdfName) -> Bool {
  name == pdf_content_inline_lzwdecode_name() ||
  name == pdf_content_inline_lzw_name()
}

///|
fn pdf_content_filter_is_inline_lzw(filter : PdfObject) -> Bool {
  match filter {
    PdfNameObject(name) => pdf_content_filter_name_is_inline_lzw(name)
    PdfArray([PdfNameObject(name), ..]) =>
      pdf_content_filter_name_is_inline_lzw(name)
    _ => false
  }
}

///|
fn pdf_content_filter_is_single_inline_lzw(filter : PdfObject) -> Bool {
  match filter {
    PdfNameObject(name) => pdf_content_filter_name_is_inline_lzw(name)
    PdfArray([PdfNameObject(name)]) =>
      pdf_content_filter_name_is_inline_lzw(name)
    _ => false
  }
}

///|
fn pdf_content_inline_image_uses_dct(dictionary : PdfObject) -> Bool {
  match pdf_content_inline_filter_value(dictionary) {
    Some(filter) => pdf_content_filter_is_inline_dct(filter)
    None => false
  }
}

///|
fn pdf_content_inline_image_text_filter(
  dictionary : PdfObject,
) -> PdfContentInlineTextFilter? {
  match pdf_content_inline_filter_value(dictionary) {
    Some(filter) => pdf_content_filter_inline_text_filter(filter)
    None => None
  }
}

///|
fn pdf_content_inline_image_single_text_filter(
  dictionary : PdfObject,
) -> PdfContentInlineTextFilter? {
  match pdf_content_inline_filter_value(dictionary) {
    Some(filter) => pdf_content_filter_single_inline_text_filter(filter)
    None => None
  }
}

///|
fn pdf_content_inline_image_uses_run_length(dictionary : PdfObject) -> Bool {
  match pdf_content_inline_filter_value(dictionary) {
    Some(filter) => pdf_content_filter_is_inline_run_length(filter)
    None => false
  }
}

///|
fn pdf_content_inline_image_uses_single_run_length(
  dictionary : PdfObject,
) -> Bool {
  match pdf_content_inline_filter_value(dictionary) {
    Some(filter) => pdf_content_filter_is_single_inline_run_length(filter)
    None => false
  }
}

///|
fn pdf_content_inline_image_uses_flate(dictionary : PdfObject) -> Bool {
  match pdf_content_inline_filter_value(dictionary) {
    Some(filter) => pdf_content_filter_is_inline_flate(filter)
    None => false
  }
}

///|
fn pdf_content_inline_image_uses_single_flate(dictionary : PdfObject) -> Bool {
  match pdf_content_inline_filter_value(dictionary) {
    Some(filter) => pdf_content_filter_is_single_inline_flate(filter)
    None => false
  }
}

///|
fn pdf_content_inline_image_uses_lzw(dictionary : PdfObject) -> Bool {
  match pdf_content_inline_filter_value(dictionary) {
    Some(filter) => pdf_content_filter_is_inline_lzw(filter)
    None => false
  }
}

///|
fn pdf_content_inline_image_uses_single_lzw(dictionary : PdfObject) -> Bool {
  match pdf_content_inline_filter_value(dictionary) {
    Some(filter) => pdf_content_filter_is_single_inline_lzw(filter)
    None => false
  }
}

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
  let output : Array[Byte] = []
  let mut index = 0
  while index < data.length() {
    let control = data[index].to_int()
    index += 1
    if control < 128 {
      let wanted = control + 1
      if index + wanted > data.length() {
        raise ParseEndStreamExpected
      }
      for i in 0..<wanted {
        output.push(data[index + i])
      }
      index += wanted
    } else if control > 128 {
      if index >= data.length() {
        raise ParseEndStreamExpected
      }
      let value = data[index]
      index += 1
      for _ in 0..<(257 - control) {
        output.push(value)
      }
    } else {
      return (Bytes::from_array(output), index)
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
      let output : Array[Double] = []
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
  let output : Array[Double] = []
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
        let numbers : Array[Double] = []
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
      let output : Array[PdfObject] = []
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
  let ops : Array[PdfContentOp] = []
  let operands : Array[PdfObject] = []
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
