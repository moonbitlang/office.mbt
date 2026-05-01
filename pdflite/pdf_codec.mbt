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
pub fn pdf_ascii_hex_encode(data : PdfBytes) -> PdfBytes {
  let output : Array[Byte] = []
  for byte in data {
    let value = byte.to_int()
    output.push(pdf_ascii_hex_digit(value / 16))
    output.push(pdf_ascii_hex_digit(value % 16))
  }
  output.push(62)
  Bytes::from_array(output)
}

///|
pub fn pdf_ascii_hex_decode(data : PdfBytes) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  let mut high : Int? = None
  let mut done = false
  for byte in data {
    if !done {
      let value = byte.to_int()
      if pdf_is_whitespace_byte(value) {
        ()
      } else if value == 62 {
        match high {
          Some(high_nibble) => output.push((high_nibble * 16).to_byte())
          None => ()
        }
        done = true
      } else {
        match pdf_ascii_hex_value(value) {
          Some(nibble) =>
            match high {
              Some(high_nibble) => {
                output.push((high_nibble * 16 + nibble).to_byte())
                high = None
              }
              None => high = Some(nibble)
            }
          None => raise InvalidHexEscape
        }
      }
    }
  }
  Bytes::from_array(output)
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
  word : UInt64,
  output_length : Int,
  compress_zero : Bool,
) -> Unit {
  if compress_zero && word == 0 {
    output.push(pdf_ascii85_zero)
  } else {
    let digits : Array[Byte] = []
    let mut value = word
    for _ in 0..<5 {
      digits.push(((value % 85).to_int() + 33).to_byte())
      value = value / 85
    }
    for i in 0..<output_length {
      output.push(digits[4 - i])
    }
  }
}

///|
fn pdf_ascii85_word_from_bytes(
  data : PdfBytes,
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
pub fn pdf_ascii85_encode(data : PdfBytes) -> PdfBytes {
  let output : Array[Byte] = []
  let mut index = 0
  while index < data.length() {
    let remaining = data.length() - index
    let count = if remaining < 4 { remaining } else { 4 }
    let word = pdf_ascii85_word_from_bytes(data, index, count)
    pdf_ascii85_encode_word(output, word, count + 1, count == 4)
    index += count
  }
  output.push(pdf_ascii85_terminator)
  output.push(62)
  Bytes::from_array(output)
}

///|
fn pdf_ascii85_decode_group(
  digits : ArrayView[Int],
  output : Array[Byte],
  output_length : Int,
) -> Unit raise PdfError {
  let mut word : UInt64 = 0
  for digit in digits {
    word = word * 85 + digit.to_uint64()
  }
  if word > pdf_ascii85_max_word {
    raise InvalidASCII85Data
  }
  if output_length >= 1 {
    output.push((word / 16777216).to_byte())
  }
  if output_length >= 2 {
    output.push((word / 65536 % 256).to_byte())
  }
  if output_length >= 3 {
    output.push((word / 256 % 256).to_byte())
  }
  if output_length >= 4 {
    output.push((word % 256).to_byte())
  }
}

///|
fn pdf_ascii85_finish_partial(
  digits : Array[Int],
  output : Array[Byte],
) -> Unit raise PdfError {
  if digits.length() == 1 {
    raise InvalidASCII85Data
  } else if digits.length() > 1 {
    let output_length = digits.length() - 1
    while digits.length() < 5 {
      digits.push(84)
    }
    pdf_ascii85_decode_group(digits[:], output, output_length)
  }
}

///|
pub fn pdf_ascii85_decode(data : PdfBytes) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  let mut digits : Array[Int] = []
  let mut done = false
  for byte in data {
    if !done {
      let value = byte.to_int()
      if pdf_is_whitespace_byte(value) {
        ()
      } else if byte == pdf_ascii85_terminator {
        pdf_ascii85_finish_partial(digits, output)
        done = true
      } else if byte == pdf_ascii85_zero {
        if digits.length() == 0 {
          output.push(0)
          output.push(0)
          output.push(0)
          output.push(0)
        } else {
          raise InvalidASCII85Data
        }
      } else if value >= 33 && value <= 117 {
        digits.push(value - 33)
        if digits.length() == 5 {
          pdf_ascii85_decode_group(digits[:], output, 4)
          digits = []
        }
      } else {
        raise InvalidASCII85Data
      }
    }
  }
  if !done {
    raise InvalidASCII85Data
  }
  Bytes::from_array(output)
}

///|
fn pdf_filter_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_filter_is_name(filter : PdfName, text : String) -> Bool {
  filter == pdf_filter_name(text)
}

///|
fn pdf_filter_is_one_of(
  filter : PdfName,
  first : String,
  second : String,
) -> Bool {
  pdf_filter_is_name(filter, first) || pdf_filter_is_name(filter, second)
}

///|
pub fn pdf_decode_filter_bytes(
  filter : PdfName,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  if pdf_filter_is_name(filter, "/Crypt") {
    data
  } else if pdf_filter_is_one_of(filter, "/ASCIIHexDecode", "/AHx") {
    pdf_ascii_hex_decode(data)
  } else if pdf_filter_is_one_of(filter, "/ASCII85Decode", "/A85") {
    pdf_ascii85_decode(data)
  } else if pdf_filter_is_one_of(filter, "/RunLengthDecode", "/RL") {
    pdf_run_length_decode(data)
  } else {
    raise FilterNotSupported(filter)
  }
}

///|
pub fn pdf_encode_filter_bytes(
  filter : PdfName,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  if pdf_filter_is_name(filter, "/Crypt") {
    data
  } else if pdf_filter_is_one_of(filter, "/ASCIIHexDecode", "/AHx") {
    pdf_ascii_hex_encode(data)
  } else if pdf_filter_is_one_of(filter, "/ASCII85Decode", "/A85") {
    pdf_ascii85_encode(data)
  } else if pdf_filter_is_one_of(filter, "/RunLengthDecode", "/RL") {
    pdf_run_length_encode(data)
  } else {
    raise FilterNotSupported(filter)
  }
}

///|
fn pdf_run_length_flush_literal(
  output : Array[Byte],
  literal : ArrayView[Byte],
) -> Unit {
  if literal.length() > 0 {
    output.push((literal.length() - 1).to_byte())
    for byte in literal {
      output.push(byte)
    }
  }
}

///|
pub fn pdf_run_length_encode(data : PdfBytes) -> PdfBytes {
  let output : Array[Byte] = []
  let mut literal : Array[Byte] = []
  let mut index = 0
  while index < data.length() {
    let value = data[index]
    let mut run_length = 1
    while index + run_length < data.length() &&
          data[index + run_length] == value &&
          run_length < 128 {
      run_length += 1
    }
    if run_length >= 3 {
      pdf_run_length_flush_literal(output, literal[:])
      literal = []
      output.push((257 - run_length).to_byte())
      output.push(value)
      index += run_length
    } else {
      if literal.length() + run_length > 128 {
        pdf_run_length_flush_literal(output, literal[:])
        literal = []
      }
      for _ in 0..<run_length {
        literal.push(value)
      }
      index += run_length
    }
  }
  pdf_run_length_flush_literal(output, literal[:])
  output.push(128)
  Bytes::from_array(output)
}

///|
pub fn pdf_run_length_decode(data : PdfBytes) -> PdfBytes {
  let output : Array[Byte] = []
  let mut index = 0
  let mut done = false
  while !done && index < data.length() {
    let control = data[index].to_int()
    index += 1
    if control < 128 {
      let wanted = control + 1
      let available = if index + wanted > data.length() {
        data.length() - index
      } else {
        wanted
      }
      for i in 0..<available {
        output.push(data[index + i])
      }
      index += available
    } else if control > 128 {
      if index < data.length() {
        let value = data[index]
        index += 1
        for _ in 0..<(257 - control) {
          output.push(value)
        }
      } else {
        done = true
      }
    } else {
      done = true
    }
  }
  Bytes::from_array(output)
}
