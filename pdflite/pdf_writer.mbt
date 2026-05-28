///|
fn pdf_writer_push_byte(output : Array[Byte], value : Int) -> Unit {
  output.push(value.to_byte())
}

///|
fn pdf_writer_push_view(output : Array[Byte], view : BytesView) -> Unit {
  for byte in view {
    output.push(byte)
  }
}

///|
fn pdf_writer_push_ascii(output : Array[Byte], text : String) -> Unit {
  pdf_writer_push_view(output, @ascii.encode(text))
}

///|
fn pdf_writer_hex_digit(value : Int) -> Byte {
  if value < 10 {
    (48 + value).to_byte()
  } else {
    (55 + value).to_byte()
  }
}

///|
fn pdf_writer_lower_hex_digit(value : Int) -> Byte {
  if value < 10 {
    (48 + value).to_byte()
  } else {
    (87 + value).to_byte()
  }
}

///|
fn pdf_writer_push_hex_escape(output : Array[Byte], value : Int) -> Unit {
  pdf_writer_push_byte(output, 35)
  output.push(pdf_writer_hex_digit(value / 16))
  output.push(pdf_writer_hex_digit(value % 16))
}

///|
fn pdf_writer_push_octal_escape(output : Array[Byte], value : Int) -> Unit {
  pdf_writer_push_byte(output, 92)
  pdf_writer_push_byte(output, 48 + value / 64)
  pdf_writer_push_byte(output, 48 + value / 8 % 8)
  pdf_writer_push_byte(output, 48 + value % 8)
}

///|
let pdf_writer_length_key_name : PdfName = pdf_name_of_bytes(
  Bytes::from_array([47, 76, 101, 110, 103, 116, 104]),
)

///|
fn pdf_writer_length_name() -> PdfName {
  pdf_writer_length_key_name
}

///|
fn pdf_write_stream_dictionary(
  stream : PdfStream,
  length : Int,
) -> PdfObject raise PdfError {
  stream.dictionary.add_dict_entry(pdf_writer_length_name(), PdfInteger(length))
}

///|
fn pdf_write_name_to(output : Array[Byte], name : PdfName) -> Unit {
  let bytes = name.bytes()
  let mut start = 0
  pdf_writer_push_byte(output, 47)
  if bytes.length() > 0 && bytes[0].to_int() == 47 {
    start = 1
  }
  for i in start..<bytes.length() {
    let value = bytes[i].to_int()
    if value < 33 || value > 126 || pdf_is_delimiter_byte(value) || value == 35 {
      pdf_writer_push_hex_escape(output, value)
    } else {
      output.push(bytes[i])
    }
  }
}

///|
fn pdf_write_name_start(bytes : BytesView) -> Int {
  if bytes.length() > 0 && bytes[0].to_int() == 47 {
    1
  } else {
    0
  }
}

///|
fn pdf_write_name_length(bytes : BytesView, start : Int) -> Int {
  let mut length = 1
  for i in start..<bytes.length() {
    let value = bytes[i].to_int()
    if value < 33 || value > 126 || pdf_is_delimiter_byte(value) || value == 35 {
      length += 3
    } else {
      length += 1
    }
  }
  length
}

///|
fn pdf_writer_hex_escape_at(
  output : Array[Byte],
  position : Int,
  value : Int,
) -> Int {
  output[position] = b'#'
  output[position + 1] = pdf_writer_hex_digit(value / 16)
  output[position + 2] = pdf_writer_hex_digit(value % 16)
  position + 3
}

///|
/// Serialize a PDF name object with required delimiter and hex escaping.
///
/// The returned bytes include the leading slash.
pub fn pdf_write_name(name : PdfName) -> PdfBytes {
  let bytes = name.bytes()
  let start = pdf_write_name_start(bytes)
  let output = Array::make(pdf_write_name_length(bytes, start), b'\x00')
  output[0] = b'/'
  let mut position = 1
  for i in start..<bytes.length() {
    let value = bytes[i].to_int()
    if value < 33 || value > 126 || pdf_is_delimiter_byte(value) || value == 35 {
      position = pdf_writer_hex_escape_at(output, position, value)
    } else {
      output[position] = bytes[i]
      position += 1
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_write_string_to(output : Array[Byte], bytes : BytesView) -> Unit {
  pdf_writer_push_byte(output, 40)
  for byte in bytes {
    let value = byte.to_int()
    match value {
      40 => pdf_writer_push_ascii(output, "\\(")
      41 => pdf_writer_push_ascii(output, "\\)")
      92 => pdf_writer_push_ascii(output, "\\\\")
      10 => pdf_writer_push_ascii(output, "\\n")
      13 => pdf_writer_push_ascii(output, "\\r")
      9 => pdf_writer_push_ascii(output, "\\t")
      8 => pdf_writer_push_ascii(output, "\\b")
      12 => pdf_writer_push_ascii(output, "\\f")
      value if value >= 32 && value <= 126 => output.push(byte)
      _ => pdf_writer_push_octal_escape(output, value)
    }
  }
  pdf_writer_push_byte(output, 41)
}

///|
fn pdf_write_literal_string_length(bytes : BytesView) -> Int {
  let mut length = 2
  for byte in bytes {
    let value = byte.to_int()
    match value {
      40 | 41 | 92 | 10 | 13 | 9 | 8 | 12 => length += 2
      value if value >= 32 && value <= 126 => length += 1
      _ => length += 4
    }
  }
  length
}

///|
fn pdf_write_literal_escape_byte(
  output : Array[Byte],
  position : Int,
  value : Byte,
) -> Int {
  output[position] = b'\\'
  output[position + 1] = value
  position + 2
}

///|
/// Serialize bytes as a PDF literal string.
///
/// Delimiters, backslashes, common controls, and non-printable bytes are
/// escaped according to PDF literal-string syntax.
pub fn pdf_write_literal_string(bytes : BytesView) -> PdfBytes {
  let output = Array::make(pdf_write_literal_string_length(bytes), b')')
  output[0] = b'('
  let mut position = 1
  for byte in bytes {
    let value = byte.to_int()
    match value {
      40 => position = pdf_write_literal_escape_byte(output, position, b'(')
      41 => position = pdf_write_literal_escape_byte(output, position, b')')
      92 => position = pdf_write_literal_escape_byte(output, position, b'\\')
      10 => position = pdf_write_literal_escape_byte(output, position, b'n')
      13 => position = pdf_write_literal_escape_byte(output, position, b'r')
      9 => position = pdf_write_literal_escape_byte(output, position, b't')
      8 => position = pdf_write_literal_escape_byte(output, position, b'b')
      12 => position = pdf_write_literal_escape_byte(output, position, b'f')
      value if value >= 32 && value <= 126 => {
        output[position] = byte
        position += 1
      }
      _ => {
        output[position] = b'\\'
        output[position + 1] = (48 + value / 64).to_byte()
        output[position + 2] = (48 + value / 8 % 8).to_byte()
        output[position + 3] = (48 + value % 8).to_byte()
        position += 4
      }
    }
  }
  Bytes::from_array(output)
}

///|
/// Compatibility alias for `pdf_write_literal_string`.
pub fn pdf_make_pdf_string(bytes : BytesView) -> PdfBytes {
  pdf_write_literal_string(bytes)
}

///|
/// Serialize bytes as a lowercase hexadecimal PDF string.
pub fn pdf_write_hex_string(bytes : BytesView) -> PdfBytes {
  let output = Array::make(bytes.length() * 2 + 2, b'>')
  output[0] = b'<'
  let mut position = 1
  for byte in bytes {
    let value = byte.to_int()
    output[position] = pdf_writer_lower_hex_digit(value / 16)
    output[position + 1] = pdf_writer_lower_hex_digit(value % 16)
    position += 2
  }
  Bytes::from_array(output)
}

///|
/// Compatibility alias for `pdf_write_hex_string`.
pub fn pdf_make_hex_pdf_string(bytes : BytesView) -> PdfBytes {
  pdf_write_hex_string(bytes)
}

///|
fn pdf_writer_exponent_marker(text : BytesView) -> Int {
  for i in 0..<text.length() {
    let value = text[i].to_int()
    if value == 69 || value == 101 {
      break i
    }
  } nobreak {
    -1
  }
}

///|
fn pdf_writer_parse_signed_int(
  text : BytesView,
  start : Int,
) -> Int raise PdfError {
  let mut index = start
  let mut sign = 1
  if index < text.length() {
    match text[index].to_int() {
      43 => index += 1
      45 => {
        sign = -1
        index += 1
      }
      _ => ()
    }
  }
  if index >= text.length() {
    raise NumberExpected
  }
  let mut value = 0
  while index < text.length() {
    let digit = text[index].to_int()
    if !pdf_is_digit_byte(digit) {
      raise NumberExpected
    }
    value = value * 10 + digit - 48
    index += 1
  }
  sign * value
}

///|
fn pdf_writer_push_digits(
  output : Array[Byte],
  digits : Array[Byte],
  start : Int,
  end : Int,
) -> Unit {
  for i in start..<end {
    output.push(digits[i])
  }
}

///|
fn pdf_writer_push_rounded_significant_digits(
  output : Array[Byte],
  digits : Array[Byte],
  decimal_position : Int,
) -> Unit {
  let significant_start = for i in 0..<digits.length() {
    if digits[i].to_int() != 48 {
      break i
    }
  } nobreak {
    -1
  }
  if significant_start < 0 {
    pdf_writer_push_byte(output, 48)
  } else {
    let keep_end = significant_start + 12
    let copy_end = if keep_end < digits.length() {
      keep_end
    } else {
      digits.length()
    }
    let rounded : Array[Byte] = []
    for i in significant_start..<copy_end {
      rounded.push(digits[i])
    }
    let mut adjusted_decimal_position = decimal_position - significant_start
    if keep_end < digits.length() && digits[keep_end].to_int() >= 53 {
      let mut carry = true
      let mut carry_index = rounded.length() - 1
      while carry && carry_index >= 0 {
        let next = rounded[carry_index].to_int() - 48 + 1
        if next == 10 {
          rounded[carry_index] = 48
          carry_index -= 1
        } else {
          rounded[carry_index] = (48 + next).to_byte()
          carry = false
        }
      }
      if carry {
        rounded.insert(0, 49)
        adjusted_decimal_position += 1
      }
    }
    let mut end = rounded.length()
    while end > adjusted_decimal_position &&
          end > 0 &&
          rounded[end - 1].to_int() == 48 {
      end -= 1
    }
    if adjusted_decimal_position <= 0 {
      pdf_writer_push_ascii(output, "0.")
      for _ in 0..<-adjusted_decimal_position {
        pdf_writer_push_byte(output, 48)
      }
      pdf_writer_push_digits(output, rounded, 0, end)
    } else if adjusted_decimal_position >= end {
      pdf_writer_push_digits(output, rounded, 0, end)
      for _ in 0..<(adjusted_decimal_position - end) {
        pdf_writer_push_byte(output, 48)
      }
    } else {
      pdf_writer_push_digits(output, rounded, 0, adjusted_decimal_position)
      pdf_writer_push_byte(output, 46)
      pdf_writer_push_digits(output, rounded, adjusted_decimal_position, end)
    }
  }
}

///|
fn pdf_writer_push_int_digits(
  output : Array[Byte],
  digits : ArrayView[Int],
  start : Int,
  end : Int,
) -> Unit {
  for i in start..<end {
    pdf_writer_push_byte(output, 48 + digits[i])
  }
}

///|
fn pdf_writer_push_scientific_real(
  output : Array[Byte],
  text : BytesView,
  exponent_at : Int,
) -> Unit raise PdfError {
  let mut mantissa_start = 0
  if exponent_at > 0 {
    match text[0].to_int() {
      43 => mantissa_start = 1
      45 => {
        pdf_writer_push_byte(output, 45)
        mantissa_start = 1
      }
      _ => ()
    }
  }
  let exponent = pdf_writer_parse_signed_int(text, exponent_at + 1)
  let digits : Array[Byte] = []
  let mut fractional_digits = 0
  let mut seen_decimal = false
  for i in mantissa_start..<exponent_at {
    let value = text[i].to_int()
    if value == 46 {
      seen_decimal = true
    } else if pdf_is_digit_byte(value) {
      digits.push(text[i])
      if seen_decimal {
        fractional_digits += 1
      }
    } else {
      raise NumberExpected
    }
  }
  if digits.length() == 0 {
    pdf_writer_push_byte(output, 48)
  } else {
    let decimal_position = digits.length() + exponent - fractional_digits
    pdf_writer_push_rounded_significant_digits(output, digits, decimal_position)
  }
}

///|
fn pdf_writer_push_plain_significant_real(
  output : Array[Byte],
  text : BytesView,
) -> Unit raise PdfError {
  let mut index = 0
  let mut negative = false
  if text.length() > 0 {
    match text[0].to_int() {
      43 => index = 1
      45 => {
        negative = true
        index = 1
      }
      _ => ()
    }
  }
  let digits : Array[Int] = []
  let mut decimal_position = -1
  while index < text.length() {
    let value = text[index].to_int()
    if value == 46 {
      if decimal_position >= 0 {
        raise NumberExpected
      }
      decimal_position = digits.length()
    } else if pdf_is_digit_byte(value) {
      digits.push(value - 48)
    } else {
      raise NumberExpected
    }
    index += 1
  }
  if decimal_position < 0 {
    pdf_writer_push_view(output, text)
  } else {
    let significant_start = for i in 0..<digits.length() {
      if digits[i] != 0 {
        break i
      }
    } nobreak {
      -1
    }
    if significant_start < 0 {
      pdf_writer_push_byte(output, 48)
    } else {
      let keep_end = significant_start + 12
      let copy_end = if keep_end < digits.length() {
        keep_end
      } else {
        digits.length()
      }
      let mut rounded : Array[Int] = []
      for i in 0..<copy_end {
        rounded.push(digits[i])
      }
      if keep_end < digits.length() && digits[keep_end] >= 5 {
        let mut carry = true
        let mut carry_index = rounded.length() - 1
        while carry && carry_index >= 0 {
          let next = rounded[carry_index] + 1
          if next == 10 {
            rounded[carry_index] = 0
            carry_index -= 1
          } else {
            rounded[carry_index] = next
            carry = false
          }
        }
        if carry {
          let with_carry : Array[Int] = [1]
          with_carry.append(rounded)
          rounded = with_carry
          decimal_position += 1
        }
      }
      let mut end = rounded.length()
      while end > decimal_position && end > 0 && rounded[end - 1] == 0 {
        end -= 1
      }
      if negative {
        pdf_writer_push_byte(output, 45)
      }
      if decimal_position <= 0 {
        pdf_writer_push_ascii(output, "0.")
        pdf_writer_push_int_digits(output, rounded, 0, end)
      } else if decimal_position >= end {
        pdf_writer_push_int_digits(output, rounded, 0, end)
      } else {
        pdf_writer_push_int_digits(output, rounded, 0, decimal_position)
        pdf_writer_push_byte(output, 46)
        pdf_writer_push_int_digits(output, rounded, decimal_position, end)
      }
    }
  }
}

///|
fn pdf_writer_push_fixed_six_real(output : Array[Byte], value : Double) -> Unit {
  if value < 0.0 {
    pdf_writer_push_byte(output, 45)
  }
  pdf_writer_push_ascii(output, "0.")
  let magnitude = if value < 0.0 { -value } else { value }
  let scaled = (magnitude * 1000000.0).round().to_int()
  let mut divisor = 100000
  while divisor > 0 {
    pdf_writer_push_byte(output, 48 + scaled / divisor % 10)
    divisor /= 10
  }
}

///|
fn pdf_writer_push_real(
  output : Array[Byte],
  value : Double,
) -> Unit raise PdfError {
  if value.trunc() != value && value < 0.0001 && value > -0.0001 {
    pdf_writer_push_fixed_six_real(output, value)
  } else {
    let text = @ascii.encode(value.to_string())
    match pdf_writer_exponent_marker(text) {
      -1 => pdf_writer_push_plain_significant_real(output, text)
      exponent_at => pdf_writer_push_scientific_real(output, text, exponent_at)
    }
  }
}

///|
/// Format a PDF real number as bytes.
///
/// Scientific notation is expanded to PDF-compatible decimal form where
/// possible. Non-finite or unparsable numeric text raises `PdfError`.
pub fn pdf_write_real(value : Double) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  pdf_writer_push_real(output, value)
  Bytes::from_array(output)
}

///|
/// Compatibility alias for `pdf_write_real`.
pub fn pdf_format_real(value : Double) -> PdfBytes raise PdfError {
  pdf_write_real(value)
}

///|
fn pdf_write_object_to(
  output : Array[Byte],
  object : PdfObject,
) -> Unit raise PdfError {
  match object {
    PdfNull => pdf_writer_push_ascii(output, "null")
    PdfBoolean(true) => pdf_writer_push_ascii(output, "true")
    PdfBoolean(false) => pdf_writer_push_ascii(output, "false")
    PdfInteger(value) => pdf_writer_push_ascii(output, value.to_string())
    PdfReal(value) => pdf_writer_push_real(output, value)
    PdfString(bytes) => pdf_write_string_to(output, bytes)
    PdfNameObject(name) => pdf_write_name_to(output, name)
    PdfArray(values) => {
      pdf_writer_push_byte(output, 91)
      for i in 0..<values.length() {
        if i > 0 {
          pdf_writer_push_byte(output, 32)
        }
        pdf_write_object_to(output, values[i])
      }
      pdf_writer_push_byte(output, 93)
    }
    PdfDictionary(entries) => {
      pdf_writer_push_ascii(output, "<<")
      for entry in entries {
        let (name, value) = entry
        pdf_writer_push_byte(output, 32)
        pdf_write_name_to(output, name)
        pdf_writer_push_byte(output, 32)
        pdf_write_object_to(output, value)
      }
      pdf_writer_push_ascii(output, " >>")
    }
    PdfStreamObject(stream) => {
      let bytes = pdf_stream_data_view(stream.data)
      pdf_write_object_to(
        output,
        pdf_write_stream_dictionary(stream, bytes.length()),
      )
      pdf_writer_push_ascii(output, "\nstream\n")
      pdf_writer_push_view(output, bytes)
      pdf_writer_push_ascii(output, "\nendstream")
    }
    PdfIndirect(number) => {
      pdf_writer_push_ascii(output, number.to_string())
      pdf_writer_push_ascii(output, " 0 R")
    }
  }
}

///|
/// Serialize a direct PDF object.
///
/// Stream lengths are refreshed from the current stream data while writing.
pub fn pdf_write_object(object : PdfObject) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  pdf_write_object_to(output, object)
  Bytes::from_array(output)
}

///|
/// Compatibility alias for `pdf_write_object`.
pub fn pdf_string_of_pdf(object : PdfObject) -> PdfBytes raise PdfError {
  pdf_write_object(object)
}

///|
/// Compatibility alias for `pdf_write_object`.
///
/// Stream data is included because `PdfStreamObject` serialization writes the
/// stream dictionary, `stream` marker, bytes, and `endstream` marker.
pub fn pdf_string_of_pdf_including_data(
  object : PdfObject,
) -> PdfBytes raise PdfError {
  pdf_write_object(object)
}

///|
/// Serialize one indirect object including `obj` and `endobj` wrappers.
pub fn pdf_write_indirect_object(
  object : PdfParsedIndirectObject,
) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  pdf_writer_push_ascii(output, object.number.to_string())
  pdf_writer_push_byte(output, 32)
  pdf_writer_push_ascii(output, object.generation.to_string())
  pdf_writer_push_ascii(output, " obj\n")
  pdf_write_object_to(output, object.object)
  pdf_writer_push_ascii(output, "\nendobj\n")
  Bytes::from_array(output)
}

///|
fn pdf_writer_push_padded_decimal(
  output : Array[Byte],
  value : Int,
  width : Int,
) -> Unit {
  let text = value.to_string()
  if text.length() < width {
    for _ in 0..<(width - text.length()) {
      pdf_writer_push_byte(output, 48)
    }
  }
  pdf_writer_push_ascii(output, text)
}

///|
fn pdf_writer_push_header(
  output : Array[Byte],
  major : Int,
  minor : Int,
) -> Unit {
  pdf_writer_push_ascii(output, "%PDF-")
  pdf_writer_push_ascii(output, major.to_string())
  pdf_writer_push_byte(output, 46)
  pdf_writer_push_ascii(output, minor.to_string())
  pdf_writer_push_ascii(output, "\n%")
  for value in [226, 227, 207, 211] {
    pdf_writer_push_byte(output, value)
  }
  pdf_writer_push_byte(output, 10)
}

///|
fn pdf_writer_write_document_objects(
  output : Array[Byte],
  document : PdfDocument,
) -> Array[(Int, Int, Int)] raise PdfError {
  let object_numbers = document.object_numbers()
  let xrefs : Array[(Int, Int, Int)] = Array::new(
    capacity=object_numbers.length(),
  )
  for number in object_numbers {
    match document.objects.get_entry(number).unwrap() {
      { data: ObjectParsed(object), generation }
      | { data: ObjectParsedAlreadyDecrypted(object), generation } => {
        xrefs.push((number, output.length(), generation))
        pdf_writer_push_view(
          output,
          pdf_write_indirect_object({ number, generation, object }),
        )
      }
      _ => raise ParsedObjectExpected
    }
  }
  xrefs
}

///|
let pdf_writer_root_key_name : PdfName = pdf_name_of_bytes(
  Bytes::from_array([47, 82, 111, 111, 116]),
)

///|
fn pdf_writer_root_name() -> PdfName {
  pdf_writer_root_key_name
}

///|
let pdf_writer_size_key_name : PdfName = pdf_name_of_bytes(
  Bytes::from_array([47, 83, 105, 122, 101]),
)

///|
fn pdf_writer_size_name() -> PdfName {
  pdf_writer_size_key_name
}

///|
let pdf_writer_type_key_name : PdfName = pdf_name_of_bytes(
  Bytes::from_array([47, 84, 121, 112, 101]),
)

///|
fn pdf_writer_type_name() -> PdfName {
  pdf_writer_type_key_name
}

///|
let pdf_writer_xref_key_name : PdfName = pdf_name_of_bytes(
  Bytes::from_array([47, 88, 82, 101, 102]),
)

///|
fn pdf_writer_xref_name() -> PdfName {
  pdf_writer_xref_key_name
}

///|
let pdf_writer_w_key_name : PdfName = pdf_name_of_bytes(
  Bytes::from_array([47, 87]),
)

///|
fn pdf_writer_w_name() -> PdfName {
  pdf_writer_w_key_name
}

///|
let pdf_writer_index_key_name : PdfName = pdf_name_of_bytes(
  Bytes::from_array([47, 73, 110, 100, 101, 120]),
)

///|
fn pdf_writer_index_name() -> PdfName {
  pdf_writer_index_key_name
}

///|
let pdf_writer_prev_key_name : PdfName = pdf_name_of_bytes(
  Bytes::from_array([47, 80, 114, 101, 118]),
)

///|
fn pdf_writer_prev_name() -> PdfName {
  pdf_writer_prev_key_name
}

///|
let pdf_writer_flate_decode_name_value : PdfName = pdf_name_of_bytes(
  Bytes::from_array([47, 70, 108, 97, 116, 101, 68, 101, 99, 111, 100, 101]),
)

///|
fn pdf_writer_flate_decode_name() -> PdfName {
  pdf_writer_flate_decode_name_value
}

///|
fn pdf_writer_trailer_dictionary(
  document : PdfDocument,
) -> PdfObject raise PdfError {
  let mut trailer = document.trailer_dict()
  trailer = trailer.add_dict_entry(
    pdf_writer_size_name(),
    PdfInteger(document.objects.max_object_number() + 1),
  )
  if document.root() != 0 {
    trailer = trailer.add_dict_entry(
      pdf_writer_root_name(),
      PdfIndirect(document.root()),
    )
  }
  trailer
}

///|
fn pdf_writer_push_classic_xref_and_trailer(
  output : Array[Byte],
  document : PdfDocument,
  xrefs : ArrayView[(Int, Int, Int)],
  xref_start : Int,
) -> Unit raise PdfError {
  let size = document.objects.max_object_number() + 1
  pdf_writer_push_ascii(output, "xref\n0 ")
  pdf_writer_push_ascii(output, size.to_string())
  pdf_writer_push_byte(output, 10)
  pdf_writer_push_ascii(output, "0000000000 65535 f \n")
  let mut xref_index = 0
  for number in 1..<size {
    if xref_index < xrefs.length() && xrefs[xref_index].0 == number {
      let (_, offset, generation) = xrefs[xref_index]
      pdf_writer_push_padded_decimal(output, offset, 10)
      pdf_writer_push_byte(output, 32)
      pdf_writer_push_padded_decimal(output, generation, 5)
      pdf_writer_push_ascii(output, " n \n")
      xref_index += 1
    } else {
      pdf_writer_push_ascii(output, "0000000000 65535 f \n")
    }
  }
  pdf_writer_push_ascii(output, "trailer\n")
  let trailer = pdf_writer_trailer_dictionary(document)
  pdf_writer_push_view(output, pdf_write_object(trailer))
  pdf_writer_push_ascii(output, "\nstartxref\n")
  pdf_writer_push_ascii(output, xref_start.to_string())
  pdf_writer_push_ascii(output, "\n%%EOF\n")
}

///|
fn pdf_writer_int_array_contains(values : ArrayView[Int], value : Int) -> Bool {
  for item in values {
    if item == value {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_writer_changed_object_numbers(document : PdfDocument) -> Array[Int] {
  let log = document.event_log()
  let numbers : Array[Int] = Array::new(capacity=log.length() + 1)
  numbers.push(0)
  let seen : @hashmap.HashMap[Int, Bool] = HashMap([])
  seen[0] = true
  for item in log {
    let (number, _) = item
    if number > 0 && !seen.contains(number) {
      seen[number] = true
      numbers.push(number)
    }
  }
  numbers.sort()
  numbers
}

///|
fn pdf_writer_write_document_objects_for_numbers(
  output : Array[Byte],
  document : PdfDocument,
  numbers : ArrayView[Int],
) -> Array[(Int, Int, Int)] raise PdfError {
  let xrefs : Array[(Int, Int, Int)] = Array::new(capacity=numbers.length())
  for number in numbers {
    if number > 0 {
      match document.objects.get_entry(number) {
        Some({ data: ObjectParsed(object), generation })
        | Some({ data: ObjectParsedAlreadyDecrypted(object), generation }) => {
          xrefs.push((number, output.length(), generation))
          pdf_writer_push_view(
            output,
            pdf_write_indirect_object({ number, generation, object }),
          )
        }
        Some(_) => raise ParsedObjectExpected
        None => ()
      }
    }
  }
  xrefs
}

///|
fn pdf_writer_push_classic_xref_entry(
  output : Array[Byte],
  xrefs : ArrayView[(Int, Int, Int)],
  number : Int,
  xref_index : Ref[Int],
) -> Unit {
  if number == 0 {
    pdf_writer_push_ascii(output, "0000000000 65535 f \n")
  } else {
    while xref_index.val < xrefs.length() && xrefs[xref_index.val].0 < number {
      xref_index.val += 1
    }
    if xref_index.val < xrefs.length() && xrefs[xref_index.val].0 == number {
      let (_, offset, generation) = xrefs[xref_index.val]
      pdf_writer_push_padded_decimal(output, offset, 10)
      pdf_writer_push_byte(output, 32)
      pdf_writer_push_padded_decimal(output, generation, 5)
      pdf_writer_push_ascii(output, " n \n")
    } else {
      pdf_writer_push_ascii(output, "0000000000 65535 f \n")
    }
  }
}

///|
fn pdf_writer_push_classic_xref_subsection(
  output : Array[Byte],
  xrefs : ArrayView[(Int, Int, Int)],
  start : Int,
  length : Int,
  xref_index : Ref[Int],
) -> Unit {
  pdf_writer_push_ascii(output, start.to_string())
  pdf_writer_push_byte(output, 32)
  pdf_writer_push_ascii(output, length.to_string())
  pdf_writer_push_byte(output, 10)
  for number in start..<(start + length) {
    pdf_writer_push_classic_xref_entry(output, xrefs, number, xref_index)
  }
}

///|
fn pdf_writer_push_classic_sparse_xref_and_trailer(
  output : Array[Byte],
  document : PdfDocument,
  xrefs : ArrayView[(Int, Int, Int)],
  entry_numbers : ArrayView[Int],
  xref_start : Int,
  previous_xref : Int,
) -> Unit raise PdfError {
  pdf_writer_push_ascii(output, "xref\n")
  let xref_index : Ref[Int] = { val: 0 }
  let mut run_start = -1
  let mut run_length = 0
  for number in entry_numbers {
    if run_length == 0 {
      run_start = number
      run_length = 1
    } else if number == run_start + run_length {
      run_length += 1
    } else {
      pdf_writer_push_classic_xref_subsection(
        output, xrefs, run_start, run_length, xref_index,
      )
      run_start = number
      run_length = 1
    }
  }
  if run_length > 0 {
    pdf_writer_push_classic_xref_subsection(
      output, xrefs, run_start, run_length, xref_index,
    )
  }
  pdf_writer_push_ascii(output, "trailer\n")
  let trailer = pdf_writer_trailer_dictionary(document).add_dict_entry(
    pdf_writer_prev_name(),
    PdfInteger(previous_xref),
  )
  pdf_writer_push_view(output, pdf_write_object(trailer))
  pdf_writer_push_ascii(output, "\nstartxref\n")
  pdf_writer_push_ascii(output, xref_start.to_string())
  pdf_writer_push_ascii(output, "\n%%EOF\n")
}

///|
/// Serialize a complete document with a classic xref table.
pub fn pdf_write_document(document : PdfDocument) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  let (major, minor) = document.version()
  pdf_writer_push_header(output, major, minor)
  let xrefs = pdf_writer_write_document_objects(output, document)
  let xref_start = output.length()
  pdf_writer_push_classic_xref_and_trailer(output, document, xrefs, xref_start)
  Bytes::from_array(output)
}

///|
/// Append a classic incremental update to original PDF bytes.
///
/// Only objects marked as changed in `document` are written. The previous
/// `startxref` position is read from `original` and emitted as `/Prev`.
pub fn pdf_write_document_incremental_update(
  original : PdfBytes,
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  let previous_xref = pdf_read_startxref_position(original)
  let output : Array[Byte] = Array::new(capacity=original.length() + 1)
  for byte in original {
    output.push(byte)
  }
  pdf_writer_push_byte(output, 10)
  let changed_numbers = pdf_writer_changed_object_numbers(document)
  let xrefs = pdf_writer_write_document_objects_for_numbers(
    output, document, changed_numbers,
  )
  let xref_start = output.length()
  pdf_writer_push_classic_sparse_xref_and_trailer(
    output, document, xrefs, changed_numbers, xref_start, previous_xref,
  )
  Bytes::from_array(output)
}

///|
fn pdf_writer_push_big_endian_field(
  output : Array[Byte],
  value : Int,
  width : Int,
) -> Unit {
  let mut divisor = 1
  if width > 1 {
    for _ in 1..<width {
      divisor *= 256
    }
  }
  let mut remaining_divisor = divisor
  while remaining_divisor > 0 {
    pdf_writer_push_byte(output, value / remaining_divisor % 256)
    remaining_divisor /= 256
  }
}

///|
fn pdf_writer_push_xref_stream_entry(
  output : Array[Byte],
  kind : Int,
  field2 : Int,
  field3 : Int,
) -> Unit {
  pdf_writer_push_big_endian_field(output, kind, 1)
  pdf_writer_push_big_endian_field(output, field2, 4)
  pdf_writer_push_big_endian_field(output, field3, 2)
}

///|
fn pdf_writer_xref_stream_data(
  xrefs : ArrayView[(Int, Int, Int)],
  size : Int,
  xref_stream_number : Int,
  xref_stream_offset : Int,
) -> PdfBytes {
  let output : Array[Byte] = Array::new(capacity=size * 7)
  let mut xref_index = 0
  for number in 0..<size {
    if number == 0 {
      pdf_writer_push_xref_stream_entry(output, 0, 0, 65535)
    } else if number == xref_stream_number {
      pdf_writer_push_xref_stream_entry(output, 1, xref_stream_offset, 0)
    } else {
      while xref_index < xrefs.length() && xrefs[xref_index].0 < number {
        xref_index += 1
      }
      if xref_index < xrefs.length() && xrefs[xref_index].0 == number {
        let (_, offset, generation) = xrefs[xref_index]
        pdf_writer_push_xref_stream_entry(output, 1, offset, generation)
      } else {
        pdf_writer_push_xref_stream_entry(output, 0, 0, 65535)
      }
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_writer_xref_stream_entry_numbers(
  document : PdfDocument,
  xref_stream_number : Int,
) -> Array[Int] {
  let numbers = pdf_writer_changed_object_numbers(document)
  if !pdf_writer_int_array_contains(numbers, xref_stream_number) {
    numbers.push(xref_stream_number)
  }
  numbers.sort()
  numbers
}

///|
fn pdf_writer_xref_stream_data_for_numbers(
  xrefs : ArrayView[(Int, Int, Int)],
  entry_numbers : ArrayView[Int],
  xref_stream_number : Int,
  xref_stream_offset : Int,
) -> PdfBytes {
  let output : Array[Byte] = Array::new(capacity=entry_numbers.length() * 7)
  let mut xref_index = 0
  for number in entry_numbers {
    if number == 0 {
      pdf_writer_push_xref_stream_entry(output, 0, 0, 65535)
    } else if number == xref_stream_number {
      pdf_writer_push_xref_stream_entry(output, 1, xref_stream_offset, 0)
    } else {
      while xref_index < xrefs.length() && xrefs[xref_index].0 < number {
        xref_index += 1
      }
      if xref_index < xrefs.length() && xrefs[xref_index].0 == number {
        let (_, offset, generation) = xrefs[xref_index]
        pdf_writer_push_xref_stream_entry(output, 1, offset, generation)
      } else {
        pdf_writer_push_xref_stream_entry(output, 0, 0, 65535)
      }
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_writer_xref_stream_index_pairs(
  entry_numbers : ArrayView[Int],
) -> Array[(Int, Int)] {
  let pairs : Array[(Int, Int)] = Array::new(capacity=entry_numbers.length())
  let mut run_start = -1
  let mut run_length = 0
  for number in entry_numbers {
    if run_length == 0 {
      run_start = number
      run_length = 1
    } else if number == run_start + run_length {
      run_length += 1
    } else {
      pairs.push((run_start, run_length))
      run_start = number
      run_length = 1
    }
  }
  if run_length > 0 {
    pairs.push((run_start, run_length))
  }
  pairs
}

///|
fn pdf_writer_xref_stream_index_object(
  pairs : ArrayView[(Int, Int)],
) -> PdfObject {
  let values : Array[PdfObject] = Array::new(capacity=pairs.length() * 2)
  for pair in pairs {
    let (start, length) = pair
    values.push(PdfInteger(start))
    values.push(PdfInteger(length))
  }
  PdfArray(values)
}

///|
fn pdf_writer_xref_stream_trailer(
  document : PdfDocument,
  size : Int,
  previous_xref : Int?,
) -> PdfObject raise PdfError {
  let trailer = pdf_writer_trailer_dictionary(document)
    .add_dict_entry(
      pdf_writer_type_name(),
      PdfNameObject(pdf_writer_xref_name()),
    )
    .add_dict_entry(pdf_writer_size_name(), PdfInteger(size))
    .add_dict_entry(
      pdf_writer_w_name(),
      PdfArray([PdfInteger(1), PdfInteger(4), PdfInteger(2)]),
    )
  match previous_xref {
    Some(previous) =>
      trailer.add_dict_entry(pdf_writer_prev_name(), PdfInteger(previous))
    None => trailer
  }
}

///|
fn pdf_write_document_with_xref_stream_filter(
  document : PdfDocument,
  filter : PdfName?,
) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  let (major, minor) = document.version()
  if major > 1 || (major == 1 && minor >= 5) {
    pdf_writer_push_header(output, major, minor)
  } else {
    pdf_writer_push_header(output, 1, 5)
  }
  let xrefs = pdf_writer_write_document_objects(output, document)
  let xref_stream_offset = output.length()
  let xref_stream_number = document.objects.max_object_number() + 1
  let size = xref_stream_number + 1
  let xref_data = pdf_writer_xref_stream_data(
    xrefs, size, xref_stream_number, xref_stream_offset,
  )
  let stream = pdf_stream(
    pdf_writer_xref_stream_trailer(document, size, None).add_dict_entry(
      pdf_writer_length_name(),
      PdfInteger(xref_data.length()),
    ),
    StreamGot(xref_data),
  )
  let xref_object = match filter {
    Some(filter) => pdf_encode_stream_with_filter(filter, stream)
    None => stream
  }
  pdf_writer_push_view(
    output,
    pdf_write_indirect_object({
      number: xref_stream_number,
      generation: 0,
      object: xref_object,
    }),
  )
  pdf_writer_push_ascii(output, "startxref\n")
  pdf_writer_push_ascii(output, xref_stream_offset.to_string())
  pdf_writer_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
/// Serialize a complete document with an uncompressed xref stream.
///
/// The output header is at least PDF 1.5, because xref streams require that
/// version.
pub fn pdf_write_document_with_xref_stream(
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  pdf_write_document_with_xref_stream_filter(document, None)
}

///|
fn pdf_write_document_incremental_update_with_xref_stream_filter(
  original : PdfBytes,
  document : PdfDocument,
  filter : PdfName?,
) -> PdfBytes raise PdfError {
  let previous_xref = pdf_read_startxref_position(original)
  let output : Array[Byte] = Array::new(capacity=original.length() + 1)
  for byte in original {
    output.push(byte)
  }
  pdf_writer_push_byte(output, 10)
  let xref_stream_number = document.objects.max_object_number() + 1
  let entry_numbers = pdf_writer_xref_stream_entry_numbers(
    document, xref_stream_number,
  )
  let xrefs = pdf_writer_write_document_objects_for_numbers(
    output, document, entry_numbers,
  )
  let xref_stream_offset = output.length()
  let size = xref_stream_number + 1
  let xref_data = pdf_writer_xref_stream_data_for_numbers(
    xrefs, entry_numbers, xref_stream_number, xref_stream_offset,
  )
  let index_pairs = pdf_writer_xref_stream_index_pairs(entry_numbers)
  let stream = pdf_stream(
    pdf_writer_xref_stream_trailer(document, size, Some(previous_xref))
    .add_dict_entry(
      pdf_writer_index_name(),
      pdf_writer_xref_stream_index_object(index_pairs),
    )
    .add_dict_entry(pdf_writer_length_name(), PdfInteger(xref_data.length())),
    StreamGot(xref_data),
  )
  let xref_object = match filter {
    Some(filter) => pdf_encode_stream_with_filter(filter, stream)
    None => stream
  }
  pdf_writer_push_view(
    output,
    pdf_write_indirect_object({
      number: xref_stream_number,
      generation: 0,
      object: xref_object,
    }),
  )
  pdf_writer_push_ascii(output, "startxref\n")
  pdf_writer_push_ascii(output, xref_stream_offset.to_string())
  pdf_writer_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
/// Append an incremental update using an uncompressed xref stream.
pub fn pdf_write_document_incremental_update_with_xref_stream(
  original : PdfBytes,
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  pdf_write_document_incremental_update_with_xref_stream_filter(
    original,
    document,
    None,
  )
}

///|
/// Serialize a complete document with a Flate-compressed xref stream.
pub fn pdf_write_document_with_compressed_xref_stream(
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  pdf_write_document_with_xref_stream_filter(
    document,
    Some(pdf_writer_flate_decode_name()),
  )
}

///|
/// Append an incremental update using a Flate-compressed xref stream.
pub fn pdf_write_document_incremental_update_with_compressed_xref_stream(
  original : PdfBytes,
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  pdf_write_document_incremental_update_with_xref_stream_filter(
    original,
    document,
    Some(pdf_writer_flate_decode_name()),
  )
}

///|
/// Append an incremental update using the selected xref representation.
pub fn pdf_write_document_incremental_update_with_mode(
  original : PdfBytes,
  document : PdfDocument,
  mode : PdfWriteMode,
) -> PdfBytes raise PdfError {
  match mode {
    PdfWriteClassic => pdf_write_document_incremental_update(original, document)
    PdfWriteXRefStream =>
      pdf_write_document_incremental_update_with_xref_stream(original, document)
    PdfWriteCompressedXRefStream =>
      pdf_write_document_incremental_update_with_compressed_xref_stream(
        original, document,
      )
  }
}

///|
/// Append an incremental update after generating a current trailer ID.
///
/// The generated ID is based on `path` and current document state and is
/// applied to a copy of the document before writing.
pub fn pdf_write_document_incremental_update_with_generated_id(
  original : PdfBytes,
  document : PdfDocument,
  path : String,
  mode? : PdfWriteMode = PdfWriteClassic,
) -> PdfBytes raise PdfError {
  pdf_write_document_incremental_update_with_mode(
    original,
    document.copy_with_current_id(path),
    mode,
  )
}

///|
/// Serialize a complete document using the selected xref representation.
pub fn pdf_write_document_with_mode(
  document : PdfDocument,
  mode : PdfWriteMode,
) -> PdfBytes raise PdfError {
  match mode {
    PdfWriteClassic => pdf_write_document(document)
    PdfWriteXRefStream => pdf_write_document_with_xref_stream(document)
    PdfWriteCompressedXRefStream =>
      pdf_write_document_with_compressed_xref_stream(document)
  }
}

///|
/// Serialize a complete document after generating a current trailer ID.
///
/// The source document is copied before its ID is generated.
pub fn pdf_write_document_with_generated_id(
  document : PdfDocument,
  path : String,
  mode? : PdfWriteMode = PdfWriteClassic,
) -> PdfBytes raise PdfError {
  pdf_write_document_with_mode(document.copy_with_current_id(path), mode)
}

///|
fn pdf_write_required_aes_iv_provider(
  provider : ((Int, Int, Int) -> PdfBytes raise PdfError)?,
) -> ((Int, Int, Int) -> PdfBytes raise PdfError) raise PdfError {
  match provider {
    Some(provider) => provider
    None => raise RandomBytesUnavailable
  }
}

///|
fn pdf_write_required_aesv3_random_provider(
  provider : ((PdfAesV3RandomField, Int) -> PdfBytes raise PdfError)?,
) -> ((PdfAesV3RandomField, Int) -> PdfBytes raise PdfError) raise PdfError {
  match provider {
    Some(provider) => provider
    None => raise RandomBytesUnavailable
  }
}

///|
fn pdf_write_apply_options_encryption(
  document : PdfDocument,
  encryption : PdfWriteEncryption,
  file_id : BytesView,
  aes_iv_provider : ((Int, Int, Int) -> PdfBytes raise PdfError)?,
  aesv3_random_provider : ((PdfAesV3RandomField, Int) -> PdfBytes raise PdfError)?,
) -> PdfDocument raise PdfError {
  match encryption.encryption_method {
    PdfEncryption40Bit =>
      document.encrypt_40bit(
        encryption.user_password,
        encryption.owner_password,
        encryption.denied_permissions,
        file_id~,
      )
    PdfEncryption128Bit =>
      document.encrypt_128bit(
        encryption.user_password,
        encryption.owner_password,
        encryption.denied_permissions,
        file_id~,
      )
    PdfEncryptionAES128(encrypt_metadata) => {
      let iv_provider = pdf_write_required_aes_iv_provider(aes_iv_provider)
      document.encrypt_128bit_aesv2_with_iv_provider(
        encryption.user_password,
        encryption.owner_password,
        encryption.denied_permissions,
        iv_provider,
        encrypt_metadata~,
        file_id~,
      )
    }
    PdfEncryptionAES256(encrypt_metadata) => {
      let random_provider = pdf_write_required_aesv3_random_provider(
        aesv3_random_provider,
      )
      let iv_provider = pdf_write_required_aes_iv_provider(aes_iv_provider)
      document.encrypt_256bit_aesv3_with_providers(
        encryption.user_password,
        encryption.owner_password,
        encryption.denied_permissions,
        random_provider,
        iv_provider,
        encrypt_metadata~,
        file_id~,
      )
    }
    PdfEncryptionAES256ISO(encrypt_metadata) => {
      let random_provider = pdf_write_required_aesv3_random_provider(
        aesv3_random_provider,
      )
      let iv_provider = pdf_write_required_aes_iv_provider(aes_iv_provider)
      document.encrypt_256bit_aesv3_iso_with_providers(
        encryption.user_password,
        encryption.owner_password,
        encryption.denied_permissions,
        random_provider,
        iv_provider,
        encrypt_metadata~,
        file_id~,
      )
    }
    PdfEncryptionAlreadyEncrypted => document.copy()
  }
}

///|
/// One-call writer with optional encryption, IDs, incremental update, and mode.
///
/// The input document is copied before IDs or encryption are applied.
/// `update_from` selects incremental output. `make_id` controls generated
/// trailer IDs for unencrypted writes; encrypted writes always use the provided
/// `file_id` or generate one through the encryption helper. AES modes require
/// the corresponding IV and random providers.
pub fn pdf_write_document_options(
  document : PdfDocument,
  encryption? : PdfWriteEncryption? = None,
  update_from? : PdfBytes? = None,
  make_id? : Bool = true,
  id_path? : String = "",
  mode? : PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
  aes_iv_provider? : ((Int, Int, Int) -> PdfBytes raise PdfError)? = None,
  aesv3_random_provider? : ((PdfAesV3RandomField, Int) -> PdfBytes raise PdfError)? = None,
) -> PdfBytes raise PdfError {
  let prepared = match encryption {
    Some(encryption) =>
      pdf_write_apply_options_encryption(
        document, encryption, file_id, aes_iv_provider, aesv3_random_provider,
      )
    None =>
      if make_id {
        document.copy_with_current_id(id_path)
      } else {
        document.copy()
      }
  }
  match update_from {
    Some(original) =>
      pdf_write_document_incremental_update_with_mode(original, prepared, mode)
    None => pdf_write_document_with_mode(prepared, mode)
  }
}

///|
/// Encrypt with 40-bit ARC4 and serialize in the selected write mode.
pub fn pdf_write_encrypted_40bit_document(
  document : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  mode? : PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
) -> PdfBytes raise PdfError {
  pdf_write_document_with_mode(
    document.encrypt_40bit(
      user_password,
      owner_password,
      denied_permissions,
      file_id~,
    ),
    mode,
  )
}

///|
/// Encrypt with 128-bit ARC4 revision 3 and serialize in the selected mode.
pub fn pdf_write_encrypted_128bit_document(
  document : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  mode? : PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
) -> PdfBytes raise PdfError {
  pdf_write_document_with_mode(
    document.encrypt_128bit(
      user_password,
      owner_password,
      denied_permissions,
      file_id~,
    ),
    mode,
  )
}

///|
/// Encrypt with revision-4 ARC4 crypt filters and serialize.
///
/// `encrypt_metadata=false` follows the PDF revision-4 no-metadata behavior.
pub fn pdf_write_encrypted_128bit_r4_document(
  document : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  encrypt_metadata? : Bool = true,
  mode? : PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
) -> PdfBytes raise PdfError {
  pdf_write_document_with_mode(
    document.encrypt_128bit_r4(
      user_password,
      owner_password,
      denied_permissions,
      encrypt_metadata~,
      file_id~,
    ),
    mode,
  )
}

///|
/// Encrypt with AESV2 and serialize.
///
/// `iv_provider` supplies IVs by object number, generation, and per-object
/// index. This allows deterministic fixtures or secure caller-provided IVs.
pub fn pdf_write_encrypted_aesv2_document_with_iv_provider(
  document : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
  encrypt_metadata? : Bool = true,
  mode? : PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
) -> PdfBytes raise PdfError {
  pdf_write_document_with_mode(
    document.encrypt_128bit_aesv2_with_iv_provider(
      user_password,
      owner_password,
      denied_permissions,
      iv_provider,
      encrypt_metadata~,
      file_id~,
    ),
    mode,
  )
}

///|
/// Encrypt with AESV3/AES-256 and serialize.
///
/// `random_provider` supplies file keys, salts, and permissions padding;
/// `iv_provider` supplies object-data IVs. `iso=true` selects the ISO/PDF 2.0
/// AESV3 hash variant.
pub fn pdf_write_encrypted_aesv3_document_with_providers(
  document : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  random_provider : (PdfAesV3RandomField, Int) -> PdfBytes raise PdfError,
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
  iso? : Bool = false,
  encrypt_metadata? : Bool = true,
  mode? : PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
) -> PdfBytes raise PdfError {
  pdf_write_document_with_mode(
    document.encrypt_256bit_aesv3_with_providers(
      user_password,
      owner_password,
      denied_permissions,
      random_provider,
      iv_provider,
      iso~,
      encrypt_metadata~,
      file_id~,
    ),
    mode,
  )
}

///|
/// Encrypt with the ISO AESV3/AES-256 variant and serialize.
pub fn pdf_write_encrypted_aesv3_iso_document_with_providers(
  document : PdfDocument,
  user_password : BytesView,
  owner_password : BytesView,
  denied_permissions : ArrayView[PdfPermission],
  random_provider : (PdfAesV3RandomField, Int) -> PdfBytes raise PdfError,
  iv_provider : (Int, Int, Int) -> PdfBytes raise PdfError,
  encrypt_metadata? : Bool = true,
  mode? : PdfWriteMode = PdfWriteClassic,
  file_id? : BytesView = [],
) -> PdfBytes raise PdfError {
  pdf_write_encrypted_aesv3_document_with_providers(
    document,
    user_password,
    owner_password,
    denied_permissions,
    random_provider,
    iv_provider,
    iso=true,
    encrypt_metadata~,
    mode~,
    file_id~,
  )
}
