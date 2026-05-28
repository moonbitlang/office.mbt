///|
fn pdf_ascii_hex_digit(value : Int) -> Byte {
  if value < 10 {
    (48 + value).to_byte()
  } else {
    (55 + value).to_byte()
  }
}

///|
fn pdf_ascii_hex_value(value : Int) -> Int? {
  match value {
    value if value >= 48 && value <= 57 => Some(value - 48)
    value if value >= 65 && value <= 70 => Some(value - 55)
    value if value >= 97 && value <= 102 => Some(value - 87)
    _ => None
  }
}

///|
/// Encode bytes using PDF ASCIIHexDecode syntax.
///
/// The returned bytes are uppercase hexadecimal pairs followed by the `>`
/// end-of-data marker.
pub fn pdf_ascii_hex_encode_view(data : BytesView) -> PdfBytes {
  let output = Array::make(data.length() * 2 + 1, b'>')
  let mut position = 0
  for byte in data {
    let value = byte.to_int()
    output[position] = pdf_ascii_hex_digit(value / 16)
    output[position + 1] = pdf_ascii_hex_digit(value % 16)
    position += 2
  }
  Bytes::from_array(output)
}

///|
/// Owned-byte wrapper for `pdf_ascii_hex_encode_view`.
pub fn pdf_ascii_hex_encode(data : PdfBytes) -> PdfBytes {
  pdf_ascii_hex_encode_view(data)
}

///|
/// Decode PDF ASCIIHexDecode data.
///
/// Whitespace is ignored and a trailing odd nibble is padded with zero when the
/// `>` marker is reached. Invalid hex digits raise `PdfError::InvalidHexEscape`.
pub fn pdf_ascii_hex_decode_view(data : BytesView) -> PdfBytes raise PdfError {
  let output = Array::make((data.length() + 1) / 2, b'\x00')
  let mut position = 0
  let mut high : Int? = None
  let mut done = false
  for byte in data {
    if !done {
      let value = byte.to_int()
      if pdf_is_whitespace_byte(value) {
        ()
      } else if value == 62 {
        match high {
          Some(high_nibble) => {
            output[position] = (high_nibble * 16).to_byte()
            position += 1
          }
          None => ()
        }
        done = true
      } else {
        match pdf_ascii_hex_value(value) {
          Some(nibble) =>
            match high {
              Some(high_nibble) => {
                output[position] = (high_nibble * 16 + nibble).to_byte()
                position += 1
                high = None
              }
              None => high = Some(nibble)
            }
          None => raise InvalidHexEscape
        }
      }
    }
  }
  Bytes::from_array(output[:position])
}

///|
/// Owned-byte wrapper for `pdf_ascii_hex_decode_view`.
pub fn pdf_ascii_hex_decode(data : PdfBytes) -> PdfBytes raise PdfError {
  pdf_ascii_hex_decode_view(data)
}

///|
let pdf_ascii85_zero : Byte = 122

///|
let pdf_ascii85_terminator : Byte = 126

///|
let pdf_ascii85_max_word : UInt64 = 4294967295

///|
fn pdf_ascii85_encode_word(
  output : Array[Byte],
  position : Int,
  word : UInt64,
  output_length : Int,
  compress_zero : Bool,
) -> Int {
  let mut current = position
  if compress_zero && word == 0 {
    output[current] = pdf_ascii85_zero
    current += 1
  } else {
    let digits = Array::make(5, b'!')
    let mut value = word
    for index in 0..<5 {
      digits[index] = ((value % 85).to_int() + 33).to_byte()
      value = value / 85
    }
    for i in 0..<output_length {
      output[current] = digits[4 - i]
      current += 1
    }
  }
  current
}

///|
fn pdf_ascii85_word_from_view(
  data : BytesView,
  start : Int,
  count : Int,
) -> UInt64 {
  let mut word : UInt64 = 0
  for i in 0..<4 {
    let byte = if i < count { data[start + i] } else { 0 }
    word = word * 256 + byte.to_uint64()
  }
  word
}

///|
/// Encode bytes using PDF ASCII85Decode syntax.
///
/// Four zero bytes are compressed as `z`, partial final groups are shortened,
/// and the result ends with `~>`.
pub fn pdf_ascii85_encode_view(data : BytesView) -> PdfBytes {
  let output = Array::make((data.length() + 3) / 4 * 5 + 2, b' ')
  let mut position = 0
  let mut index = 0
  while index < data.length() {
    let remaining = data.length() - index
    let count = if remaining < 4 { remaining } else { 4 }
    let word = pdf_ascii85_word_from_view(data, index, count)
    position = pdf_ascii85_encode_word(
      output,
      position,
      word,
      count + 1,
      count == 4,
    )
    index += count
  }
  output[position] = pdf_ascii85_terminator
  output[position + 1] = b'>'
  Bytes::from_array(output[:position + 2])
}

///|
/// Owned-byte wrapper for `pdf_ascii85_encode_view`.
pub fn pdf_ascii85_encode(data : PdfBytes) -> PdfBytes {
  pdf_ascii85_encode_view(data)
}

///|
fn pdf_ascii85_decode_group(
  digits : ArrayView[Int],
  output : Array[Byte],
  position : Int,
  output_length : Int,
) -> Int raise PdfError {
  let mut word : UInt64 = 0
  for digit in digits {
    word = word * 85 + digit.to_uint64()
  }
  if word > pdf_ascii85_max_word {
    raise InvalidASCII85Data
  }
  let mut current = position
  if output_length >= 1 {
    output[current] = (word / 16777216).to_byte()
    current += 1
  }
  if output_length >= 2 {
    output[current] = (word / 65536 % 256).to_byte()
    current += 1
  }
  if output_length >= 3 {
    output[current] = (word / 256 % 256).to_byte()
    current += 1
  }
  if output_length >= 4 {
    output[current] = (word % 256).to_byte()
    current += 1
  }
  current
}

///|
fn pdf_ascii85_finish_partial(
  digits : Array[Int],
  output : Array[Byte],
  position : Int,
) -> Int raise PdfError {
  if digits.length() == 1 {
    raise InvalidASCII85Data
  } else if digits.length() > 1 {
    let output_length = digits.length() - 1
    while digits.length() < 5 {
      digits.push(84)
    }
    pdf_ascii85_decode_group(digits, output, position, output_length)
  } else {
    position
  }
}

///|
/// Decode PDF ASCII85Decode data.
///
/// Whitespace is ignored. Missing terminators, malformed partial groups,
/// invalid `z` placement, and overflowing groups raise `PdfError::InvalidASCII85Data`.
pub fn pdf_ascii85_decode_view(data : BytesView) -> PdfBytes raise PdfError {
  let output = Array::make(data.length() * 4, b'\x00')
  let mut position = 0
  let mut digits : Array[Int] = Array::new(capacity=5)
  let mut done = false
  for byte in data {
    if !done {
      let value = byte.to_int()
      if pdf_is_whitespace_byte(value) {
        ()
      } else if byte == pdf_ascii85_terminator {
        position = pdf_ascii85_finish_partial(digits, output, position)
        done = true
      } else if byte == pdf_ascii85_zero {
        if digits.length() == 0 {
          for _ in 0..<4 {
            output[position] = b'\x00'
            position += 1
          }
        } else {
          raise InvalidASCII85Data
        }
      } else if value >= 33 && value <= 117 {
        digits.push(value - 33)
        if digits.length() == 5 {
          position = pdf_ascii85_decode_group(digits, output, position, 4)
          digits = Array::new(capacity=5)
        }
      } else {
        raise InvalidASCII85Data
      }
    }
  }
  if !done {
    raise InvalidASCII85Data
  }
  Bytes::from_array(output[:position])
}

///|
/// Owned-byte wrapper for `pdf_ascii85_decode_view`.
pub fn pdf_ascii85_decode(data : PdfBytes) -> PdfBytes raise PdfError {
  pdf_ascii85_decode_view(data)
}
