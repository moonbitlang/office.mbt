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
pub fn pdf_ascii_hex_encode_view(data : BytesView) -> PdfBytes {
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
pub fn pdf_ascii_hex_encode(data : PdfBytes) -> PdfBytes {
  pdf_ascii_hex_encode_view(data[:])
}

///|
pub fn pdf_ascii_hex_decode_view(data : BytesView) -> PdfBytes raise PdfError {
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
pub fn pdf_ascii_hex_decode(data : PdfBytes) -> PdfBytes raise PdfError {
  pdf_ascii_hex_decode_view(data[:])
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
pub fn pdf_ascii85_encode_view(data : BytesView) -> PdfBytes {
  let output : Array[Byte] = []
  let mut index = 0
  while index < data.length() {
    let remaining = data.length() - index
    let count = if remaining < 4 { remaining } else { 4 }
    let word = pdf_ascii85_word_from_view(data, index, count)
    pdf_ascii85_encode_word(output, word, count + 1, count == 4)
    index += count
  }
  output.push(pdf_ascii85_terminator)
  output.push(62)
  Bytes::from_array(output)
}

///|
pub fn pdf_ascii85_encode(data : PdfBytes) -> PdfBytes {
  pdf_ascii85_encode_view(data[:])
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
pub fn pdf_ascii85_decode_view(data : BytesView) -> PdfBytes raise PdfError {
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
pub fn pdf_ascii85_decode(data : PdfBytes) -> PdfBytes raise PdfError {
  pdf_ascii85_decode_view(data[:])
}

///|
fn pdf_lzw_next_code(
  bits : BitStream,
  code_length : Int,
) -> Int? raise PdfError {
  try bits.get_value_int(code_length) catch {
    EndOfInput => None
    _ => raise InvalidLZWData
  } noraise {
    value => Some(value)
  }
}

///|
fn pdf_lzw_decode_code(
  code : Int,
  prefix_code : Array[Int],
  append_character : Array[Int],
  next_code : Int,
) -> Array[Int] raise PdfError {
  if code < 0 || code >= next_code || code >= prefix_code.length() {
    raise InvalidLZWData
  }
  let stack : Array[Int] = []
  let mut current = code
  let mut depth = 0
  while current > 255 {
    if current >= next_code || current >= prefix_code.length() || depth > 8192 {
      raise InvalidLZWData
    }
    stack.push(append_character[current])
    current = prefix_code[current]
    depth += 1
  }
  if current < 0 || current > 255 {
    raise InvalidLZWData
  }
  let output : Array[Int] = [current]
  if stack.length() > 0 {
    for i = stack.length() - 1; i >= 0; i = i - 1 {
      output.push(stack[i])
    }
  }
  output
}

///|
fn pdf_lzw_read_non_clear_code(
  bits : BitStream,
  code_length : Int,
) -> Int? raise PdfError {
  let mut code = 256
  while code == 256 {
    match pdf_lzw_next_code(bits, code_length) {
      None => break None
      Some(value) => code = value
    }
  } nobreak {
    Some(code)
  }
}

///|
fn pdf_lzw_output_literal(
  output : Array[Byte],
  code : Int,
) -> Unit raise PdfError {
  if code < 0 || code > 255 {
    raise InvalidLZWData
  }
  output.push(code.to_byte())
}

///|
fn pdf_lzw_consumed_bytes(bits : BitStream) -> Int {
  let count = bits.bits_read()
  if count % 8 == 0 {
    count / 8
  } else {
    count / 8 + 1
  }
}

///|
fn pdf_lzw_decode_view_prefix(
  data : BytesView,
  early_change? : Int = 1,
) -> (PdfBytes, Int) raise PdfError {
  let prefix_code = Array::make(8192, 0)
  let append_character = Array::make(8192, 0)
  let bits = bitstream_of_view(data)
  let output : Array[Byte] = []
  let mut code_length = 9
  let mut next_code = 258
  let mut old_code = 256
  let mut character = 0
  match pdf_lzw_read_non_clear_code(bits, code_length) {
    None => raise InvalidLZWData
    Some(257) => (Bytes::from_array(output), pdf_lzw_consumed_bytes(bits))
    Some(first_code) => {
      pdf_lzw_output_literal(output, first_code)
      old_code = first_code
      character = first_code
      let mut consumed = 0
      let mut finished = false
      while !finished {
        match pdf_lzw_next_code(bits, code_length) {
          None => raise InvalidLZWData
          Some(257) => {
            consumed = pdf_lzw_consumed_bytes(bits)
            finished = true
          }
          Some(256) => {
            code_length = 9
            next_code = 258
            old_code = 256
            match pdf_lzw_read_non_clear_code(bits, code_length) {
              None => raise InvalidLZWData
              Some(257) => {
                consumed = pdf_lzw_consumed_bytes(bits)
                finished = true
              }
              Some(code) => {
                pdf_lzw_output_literal(output, code)
                old_code = code
                character = code
              }
            }
          }
          Some(new_code) => {
            let chars = if new_code == next_code {
              let expanded = pdf_lzw_decode_code(
                old_code, prefix_code, append_character, next_code,
              )
              expanded.push(character)
              expanded
            } else if new_code < next_code {
              pdf_lzw_decode_code(
                new_code, prefix_code, append_character, next_code,
              )
            } else {
              raise InvalidLZWData
            }
            character = chars[0]
            for value in chars {
              pdf_lzw_output_literal(output, value)
            }
            if next_code < prefix_code.length() {
              prefix_code[next_code] = old_code
              append_character[next_code] = character
              next_code += 1
              match next_code + early_change {
                512 | 1024 | 2048 => code_length += 1
                _ => ()
              }
            }
            old_code = new_code
          }
        }
      }
      (Bytes::from_array(output), consumed)
    }
  }
}

///|
pub fn pdf_lzw_decode_view(
  data : BytesView,
  early_change? : Int = 1,
) -> PdfBytes raise PdfError {
  let prefix_code = Array::make(8192, 0)
  let append_character = Array::make(8192, 0)
  let bits = bitstream_of_view(data)
  let output : Array[Byte] = []
  let mut code_length = 9
  let mut next_code = 258
  let mut old_code = 256
  let mut character = 0
  match pdf_lzw_read_non_clear_code(bits, code_length) {
    None | Some(257) => Bytes::from_array(output)
    Some(first_code) => {
      pdf_lzw_output_literal(output, first_code)
      old_code = first_code
      character = first_code
      let mut finished = false
      while !finished {
        match pdf_lzw_next_code(bits, code_length) {
          None => finished = true
          Some(257) => finished = true
          Some(256) => {
            code_length = 9
            next_code = 258
            old_code = 256
            match pdf_lzw_read_non_clear_code(bits, code_length) {
              None | Some(257) => finished = true
              Some(code) => {
                pdf_lzw_output_literal(output, code)
                old_code = code
                character = code
              }
            }
          }
          Some(new_code) => {
            let chars = if new_code == next_code {
              let expanded = pdf_lzw_decode_code(
                old_code, prefix_code, append_character, next_code,
              )
              expanded.push(character)
              expanded
            } else if new_code < next_code {
              pdf_lzw_decode_code(
                new_code, prefix_code, append_character, next_code,
              )
            } else {
              raise InvalidLZWData
            }
            character = chars[0]
            for value in chars {
              pdf_lzw_output_literal(output, value)
            }
            if next_code < prefix_code.length() {
              prefix_code[next_code] = old_code
              append_character[next_code] = character
              next_code += 1
              match next_code + early_change {
                512 | 1024 | 2048 => code_length += 1
                _ => ()
              }
            }
            old_code = new_code
          }
        }
      }
      Bytes::from_array(output)
    }
  }
}

///|
pub fn pdf_lzw_decode(
  data : PdfBytes,
  early_change? : Int = 1,
) -> PdfBytes raise PdfError {
  pdf_lzw_decode_view(data[:], early_change~)
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
pub fn pdf_decode_filter_view(
  filter : PdfName,
  data : BytesView,
) -> PdfBytes raise PdfError {
  if pdf_filter_is_name(filter, "/Crypt") {
    data.to_owned()
  } else if pdf_filter_is_one_of(filter, "/ASCIIHexDecode", "/AHx") {
    pdf_ascii_hex_decode_view(data)
  } else if pdf_filter_is_one_of(filter, "/ASCII85Decode", "/A85") {
    pdf_ascii85_decode_view(data)
  } else if pdf_filter_is_one_of(filter, "/RunLengthDecode", "/RL") {
    pdf_run_length_decode_view(data)
  } else if pdf_filter_is_one_of(filter, "/FlateDecode", "/Fl") {
    pdf_flate_decode_view(data)
  } else if pdf_filter_is_one_of(filter, "/LZWDecode", "/LZW") {
    pdf_lzw_decode_view(data)
  } else {
    raise FilterNotSupported(filter)
  }
}

///|
pub fn pdf_decode_filter_bytes(
  filter : PdfName,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  pdf_decode_filter_view(filter, data[:])
}

///|
pub fn pdf_encode_filter_view(
  filter : PdfName,
  data : BytesView,
) -> PdfBytes raise PdfError {
  if pdf_filter_is_name(filter, "/Crypt") {
    data.to_owned()
  } else if pdf_filter_is_one_of(filter, "/ASCIIHexDecode", "/AHx") {
    pdf_ascii_hex_encode_view(data)
  } else if pdf_filter_is_one_of(filter, "/ASCII85Decode", "/A85") {
    pdf_ascii85_encode_view(data)
  } else if pdf_filter_is_one_of(filter, "/RunLengthDecode", "/RL") {
    pdf_run_length_encode_view(data)
  } else if pdf_filter_is_one_of(filter, "/FlateDecode", "/Fl") {
    pdf_flate_encode_view(data)
  } else {
    raise FilterNotSupported(filter)
  }
}

///|
pub fn pdf_encode_filter_bytes(
  filter : PdfName,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  pdf_encode_filter_view(filter, data[:])
}

///|
fn pdf_filter_key() -> PdfName {
  pdf_filter_name("/Filter")
}

///|
fn pdf_short_filter_key() -> PdfName {
  pdf_filter_name("/F")
}

///|
fn pdf_decodeparms_key() -> PdfName {
  pdf_filter_name("/DecodeParms")
}

///|
fn pdf_short_decodeparms_key() -> PdfName {
  pdf_filter_name("/DP")
}

///|
fn pdf_codec_length_key() -> PdfName {
  pdf_filter_name("/Length")
}

///|
fn pdf_predictor_key() -> PdfName {
  pdf_filter_name("/Predictor")
}

///|
fn pdf_early_change_key() -> PdfName {
  pdf_filter_name("/EarlyChange")
}

///|
fn pdf_colors_key() -> PdfName {
  pdf_filter_name("/Colors")
}

///|
fn pdf_bits_per_component_key() -> PdfName {
  pdf_filter_name("/BitsPerComponent")
}

///|
fn pdf_columns_key() -> PdfName {
  pdf_filter_name("/Columns")
}

///|
fn pdf_stream_dictionary_length(dictionary : PdfObject) -> Unit raise PdfError {
  match dictionary.lookup_immediate(pdf_codec_length_key()) {
    Some(PdfInteger(_)) => ()
    _ => raise StreamLengthExpected
  }
}

///|
fn pdf_stream_filter_value(dictionary : PdfObject) -> PdfObject? {
  match dictionary.lookup_immediate(pdf_filter_key()) {
    Some(value) => Some(value)
    None => dictionary.lookup_immediate(pdf_short_filter_key())
  }
}

///|
fn pdf_stream_first_filter(dictionary : PdfObject) -> PdfName? raise PdfError {
  match pdf_stream_filter_value(dictionary) {
    None => None
    Some(PdfNameObject(name)) => Some(name)
    Some(PdfArray([])) => None
    Some(PdfArray([PdfNameObject(name), ..])) => Some(name)
    _ => raise FilterExpected
  }
}

///|
fn PdfDocument::pdf_stream_filter_entry_direct(
  self : PdfDocument,
  dictionary : PdfObject,
) -> (PdfName, PdfObject)? {
  match self.lookup_direct(pdf_filter_key(), dictionary) {
    Some(value) => Some((pdf_filter_key(), value))
    None =>
      match self.lookup_direct(pdf_short_filter_key(), dictionary) {
        Some(value) => Some((pdf_short_filter_key(), value))
        None => None
      }
  }
}

///|
fn PdfDocument::pdf_stream_first_filter_direct(
  self : PdfDocument,
  dictionary : PdfObject,
) -> PdfName? raise PdfError {
  match self.pdf_stream_first_filter_entry_direct(dictionary) {
    Some((_, _, name)) => Some(name)
    None => None
  }
}

///|
fn PdfDocument::pdf_stream_first_filter_entry_direct(
  self : PdfDocument,
  dictionary : PdfObject,
) -> (PdfName, PdfObject, PdfName)? raise PdfError {
  match self.pdf_stream_filter_entry_direct(dictionary) {
    None => None
    Some((key, PdfNameObject(name) as value)) => Some((key, value, name))
    Some((_, PdfArray([]))) => None
    Some((key, PdfArray([first, ..]) as value)) =>
      match self.direct(first) {
        PdfNameObject(name) => Some((key, value, name))
        _ => raise FilterExpected
      }
    _ => raise FilterExpected
  }
}

///|
fn pdf_remove_first_filter_entry(
  dictionary : PdfObject,
  key : PdfName,
) -> PdfObject raise PdfError {
  match dictionary.lookup_immediate(key) {
    None => dictionary
    Some(PdfNameObject(_)) | Some(PdfArray([_])) =>
      dictionary.remove_dict_entry(key)
    Some(PdfArray([_, .. rest])) =>
      dictionary.replace_dict_entry(
        key,
        PdfArray([ for value in rest => value ]),
      )
    _ => raise FilterExpected
  }
}

///|
fn pdf_remove_first_decodeparms_entry(
  dictionary : PdfObject,
  key : PdfName,
) -> PdfObject raise PdfError {
  match dictionary.lookup_immediate(key) {
    None => dictionary
    Some(PdfDictionary(_)) | Some(PdfArray([])) =>
      dictionary.remove_dict_entry(key)
    Some(PdfArray([_, .. rest])) =>
      dictionary.replace_dict_entry(
        key,
        PdfArray([ for value in rest => value ]),
      )
    _ => raise FilterExpected
  }
}

///|
fn pdf_remove_first_decoder(dictionary : PdfObject) -> PdfObject raise PdfError {
  let without_filter = if dictionary.lookup_immediate(pdf_filter_key()) != None {
    pdf_remove_first_filter_entry(dictionary, pdf_filter_key())
  } else {
    pdf_remove_first_filter_entry(dictionary, pdf_short_filter_key())
  }
  let without_decodeparms = if without_filter.lookup_immediate(
      pdf_decodeparms_key(),
    ) !=
    None {
    pdf_remove_first_decodeparms_entry(without_filter, pdf_decodeparms_key())
  } else {
    pdf_remove_first_decodeparms_entry(
      without_filter,
      pdf_short_decodeparms_key(),
    )
  }
  without_decodeparms
}

///|
fn pdf_remove_first_filter_entry_value(
  dictionary : PdfObject,
  key : PdfName,
  value : PdfObject,
) -> PdfObject raise PdfError {
  match value {
    PdfArray([]) | PdfArray([_]) => dictionary.remove_dict_entry(key)
    PdfArray([_, .. rest]) =>
      dictionary.replace_dict_entry(
        key,
        PdfArray([ for value in rest => value ]),
      )
    _ => dictionary.remove_dict_entry(key)
  }
}

///|
fn pdf_remove_first_decodeparms_entry_value(
  dictionary : PdfObject,
  key : PdfName,
  value : PdfObject,
) -> PdfObject raise PdfError {
  match value {
    PdfArray([_, .. rest]) =>
      dictionary.replace_dict_entry(
        key,
        PdfArray([ for value in rest => value ]),
      )
    _ => dictionary.remove_dict_entry(key)
  }
}

///|
fn PdfDocument::pdf_remove_first_decoder_direct(
  self : PdfDocument,
  dictionary : PdfObject,
  filter_key : PdfName,
  filter_value : PdfObject,
) -> PdfObject raise PdfError {
  let without_filter = pdf_remove_first_filter_entry_value(
    dictionary, filter_key, filter_value,
  )
  match self.pdf_decodeparms_entry_direct(without_filter) {
    Some((key, value)) =>
      pdf_remove_first_decodeparms_entry_value(without_filter, key, value)
    None => without_filter
  }
}

///|
fn pdf_stream_replace_length(
  dictionary : PdfObject,
  length : Int,
) -> PdfObject raise PdfError {
  dictionary.replace_dict_entry(pdf_codec_length_key(), PdfInteger(length))
}

///|
fn pdf_predictor_scanline_width(
  colors : Int,
  bits_per_component : Int,
  columns : Int,
) -> Int raise PdfError {
  if colors <= 0 || bits_per_component <= 0 || columns <= 0 {
    raise PredictorExpected
  }
  (colors * bits_per_component * columns + 7) / 8
}

///|
fn pdf_predictor_bytes_per_pixel(
  colors : Int,
  bits_per_component : Int,
) -> Int raise PdfError {
  if colors <= 0 || bits_per_component <= 0 {
    raise PredictorExpected
  }
  (colors * bits_per_component + 7) / 8
}

///|
fn pdf_predictor_get0(values : ArrayView[Int], index : Int) -> Int {
  if index < 0 {
    0
  } else {
    values[index]
  }
}

///|
fn pdf_predictor_wrapping_byte(value : Int) -> Byte {
  let remainder = value % 256
  if remainder < 0 {
    (remainder + 256).to_byte()
  } else {
    remainder.to_byte()
  }
}

///|
fn pdf_paeth_predictor(a : Int, b : Int, c : Int) -> Int {
  let p = a + b - c
  let pa = (p - a).abs()
  let pb = (p - b).abs()
  let pc = (p - c).abs()
  if pa <= pb && pa <= pc {
    a
  } else if pb <= pc {
    b
  } else {
    c
  }
}

///|
fn pdf_decode_tiff_predictor(
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  if bits_per_component != 8 {
    raise PredictorNotSupported(2)
  }
  let scanline_width = pdf_predictor_scanline_width(
    colors, bits_per_component, columns,
  )
  let output : Array[Byte] = [ for byte in data => byte ]
  for line in 0..<(data.length() / scanline_width) {
    let line_start = line * scanline_width
    let mut position = colors
    while position < scanline_width {
      let index = line_start + position
      output[index] = ((
        output[index - colors].to_int() + output[index].to_int()
      ) %
      256).to_byte()
      position += 1
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_encode_tiff_predictor(
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  if bits_per_component != 8 {
    raise PredictorNotSupported(2)
  }
  let scanline_width = pdf_predictor_scanline_width(
    colors, bits_per_component, columns,
  )
  let output : Array[Byte] = [ for byte in data => byte ]
  for line in 0..<(data.length() / scanline_width) {
    let line_start = line * scanline_width
    let mut position = colors
    while position < scanline_width {
      let index = line_start + position
      output[index] = pdf_predictor_wrapping_byte(
        data[index].to_int() - data[index - colors].to_int(),
      )
      position += 1
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_decode_png_scanline(
  predictor : Int,
  prior_decoded : ArrayView[Int],
  current : ArrayView[Int],
  bytes_per_pixel : Int,
) -> Array[Int] raise PdfError {
  let output : Array[Int] = [ for value in current => value ]
  match predictor {
    0 => ()
    1 =>
      for i in 0..<output.length() {
        output[i] = (
            current[i] + pdf_predictor_get0(output[:], i - bytes_per_pixel)
          ) %
          256
      }
    2 =>
      for i in 0..<output.length() {
        output[i] = (current[i] + pdf_predictor_get0(prior_decoded, i)) % 256
      }
    3 =>
      for i in 0..<output.length() {
        output[i] = (
            current[i] +
            (
              pdf_predictor_get0(output[:], i - bytes_per_pixel) +
              pdf_predictor_get0(prior_decoded, i)
            ) /
            2
          ) %
          256
      }
    4 =>
      for i in 0..<output.length() {
        let left = pdf_predictor_get0(output[:], i - bytes_per_pixel)
        let up = pdf_predictor_get0(prior_decoded, i)
        let up_left = pdf_predictor_get0(prior_decoded, i - bytes_per_pixel)
        output[i] = (current[i] + pdf_paeth_predictor(left, up, up_left)) % 256
      }
    _ => raise PredictorNotSupported(predictor)
  }
  output
}

///|
fn pdf_decode_png_predictor(
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let scanline_width = pdf_predictor_scanline_width(
    colors, bits_per_component, columns,
  )
  let bytes_per_pixel = pdf_predictor_bytes_per_pixel(
    colors, bits_per_component,
  )
  let output : Array[Byte] = []
  let mut prior_decoded : Array[Int] = [ for _ in 0..<scanline_width => 0 ]
  let mut index = 0
  while index < data.length() {
    let predictor = data[index].to_int()
    index += 1
    let current : Array[Int] = [ for _ in 0..<scanline_width => 0 ]
    let available = if index + scanline_width > data.length() {
      data.length() - index
    } else {
      scanline_width
    }
    for i in 0..<available {
      current[i] = data[index + i].to_int()
    }
    index += available
    let decoded = pdf_decode_png_scanline(
      predictor,
      prior_decoded[:],
      current[:],
      bytes_per_pixel,
    )
    for value in decoded {
      output.push(value.to_byte())
    }
    prior_decoded = decoded
  }
  Bytes::from_array(output)
}

///|
pub fn pdf_decode_predictor_view(
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  match predictor {
    1 => data.to_owned()
    2 => pdf_decode_tiff_predictor(colors, bits_per_component, columns, data)
    value if value >= 10 && value <= 15 =>
      pdf_decode_png_predictor(colors, bits_per_component, columns, data)
    _ => raise PredictorNotSupported(predictor)
  }
}

///|
pub fn pdf_decode_predictor(
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  pdf_decode_predictor_view(
    predictor,
    colors,
    bits_per_component,
    columns,
    data[:],
  )
}

///|
fn pdf_encode_png_sub_predictor(
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let scanline_width = pdf_predictor_scanline_width(
    colors, bits_per_component, columns,
  )
  let bytes_per_pixel = pdf_predictor_bytes_per_pixel(
    colors, bits_per_component,
  )
  let output : Array[Byte] = []
  for row in 0..<(data.length() / scanline_width) {
    pdf_encode_png_push_scanline(
      output,
      1,
      data,
      row * scanline_width,
      scanline_width,
      bytes_per_pixel,
    )
  }
  Bytes::from_array(output)
}

///|
fn pdf_encode_png_up_predictor(
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let scanline_width = pdf_predictor_scanline_width(
    colors, bits_per_component, columns,
  )
  let bytes_per_pixel = pdf_predictor_bytes_per_pixel(
    colors, bits_per_component,
  )
  let output : Array[Byte] = []
  for row in 0..<(data.length() / scanline_width) {
    pdf_encode_png_push_scanline(
      output,
      2,
      data,
      row * scanline_width,
      scanline_width,
      bytes_per_pixel,
    )
  }
  Bytes::from_array(output)
}

///|
fn pdf_encode_png_predictor_value(
  predictor : Int,
  data : BytesView,
  row_start : Int,
  index : Int,
  scanline_width : Int,
  bytes_per_pixel : Int,
) -> Int raise PdfError {
  let left = if index < bytes_per_pixel {
    0
  } else {
    data[row_start + index - bytes_per_pixel].to_int()
  }
  let up = if row_start < scanline_width {
    0
  } else {
    data[row_start - scanline_width + index].to_int()
  }
  let up_left = if row_start < scanline_width || index < bytes_per_pixel {
    0
  } else {
    data[row_start - scanline_width + index - bytes_per_pixel].to_int()
  }
  match predictor {
    0 => 0
    1 => left
    2 => up
    3 => (left + up) / 2
    4 => pdf_paeth_predictor(left, up, up_left)
    _ => raise PredictorNotSupported(predictor)
  }
}

///|
fn pdf_encode_png_scanline(
  predictor : Int,
  data : BytesView,
  row_start : Int,
  scanline_width : Int,
  bytes_per_pixel : Int,
) -> Array[Byte] raise PdfError {
  let output : Array[Byte] = [predictor.to_byte()]
  for i in 0..<scanline_width {
    let predicted = pdf_encode_png_predictor_value(
      predictor, data, row_start, i, scanline_width, bytes_per_pixel,
    )
    output.push(
      pdf_predictor_wrapping_byte(data[row_start + i].to_int() - predicted),
    )
  }
  output
}

///|
fn pdf_encode_png_push_scanline(
  output : Array[Byte],
  predictor : Int,
  data : BytesView,
  row_start : Int,
  scanline_width : Int,
  bytes_per_pixel : Int,
) -> Unit raise PdfError {
  for
    byte in pdf_encode_png_scanline(
      predictor, data, row_start, scanline_width, bytes_per_pixel,
    ) {
    output.push(byte)
  }
}

///|
fn pdf_encode_png_tagged_predictor(
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let scanline_width = pdf_predictor_scanline_width(
    colors, bits_per_component, columns,
  )
  let bytes_per_pixel = pdf_predictor_bytes_per_pixel(
    colors, bits_per_component,
  )
  let output : Array[Byte] = []
  for row in 0..<(data.length() / scanline_width) {
    pdf_encode_png_push_scanline(
      output,
      predictor,
      data,
      row * scanline_width,
      scanline_width,
      bytes_per_pixel,
    )
  }
  Bytes::from_array(output)
}

///|
fn pdf_encode_png_score_scanline(encoded : ArrayView[Byte]) -> Int {
  let mut score = 0
  for i in 1..<encoded.length() {
    let value = encoded[i].to_int()
    score += if value > 127 { 256 - value } else { value }
  }
  score
}

///|
fn pdf_encode_png_optimum_predictor(
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  let scanline_width = pdf_predictor_scanline_width(
    colors, bits_per_component, columns,
  )
  let bytes_per_pixel = pdf_predictor_bytes_per_pixel(
    colors, bits_per_component,
  )
  let output : Array[Byte] = []
  for row in 0..<(data.length() / scanline_width) {
    let row_start = row * scanline_width
    let mut best = pdf_encode_png_scanline(
      0, data, row_start, scanline_width, bytes_per_pixel,
    )
    let mut best_score = pdf_encode_png_score_scanline(best[:])
    for predictor in 1..<=4 {
      let candidate = pdf_encode_png_scanline(
        predictor, data, row_start, scanline_width, bytes_per_pixel,
      )
      let score = pdf_encode_png_score_scanline(candidate[:])
      if score < best_score {
        best = candidate
        best_score = score
      }
    }
    for byte in best {
      output.push(byte)
    }
  }
  Bytes::from_array(output)
}

///|
pub fn pdf_encode_predictor_view(
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  match predictor {
    1 => data.to_owned()
    2 => pdf_encode_tiff_predictor(colors, bits_per_component, columns, data)
    10 =>
      pdf_encode_png_tagged_predictor(
        0, colors, bits_per_component, columns, data,
      )
    11 =>
      pdf_encode_png_sub_predictor(colors, bits_per_component, columns, data)
    12 => pdf_encode_png_up_predictor(colors, bits_per_component, columns, data)
    13 =>
      pdf_encode_png_tagged_predictor(
        3, colors, bits_per_component, columns, data,
      )
    14 =>
      pdf_encode_png_tagged_predictor(
        4, colors, bits_per_component, columns, data,
      )
    15 =>
      pdf_encode_png_optimum_predictor(
        colors, bits_per_component, columns, data,
      )
    _ => raise PredictorNotSupported(predictor)
  }
}

///|
pub fn pdf_encode_predictor(
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  pdf_encode_predictor_view(
    predictor,
    colors,
    bits_per_component,
    columns,
    data[:],
  )
}

///|
fn pdf_decodeparms_value(dictionary : PdfObject) -> PdfObject? {
  match dictionary.lookup_immediate(pdf_decodeparms_key()) {
    Some(value) => Some(value)
    None => dictionary.lookup_immediate(pdf_short_decodeparms_key())
  }
}

///|
fn pdf_first_decodeparms(dictionary : PdfObject) -> PdfObject? raise PdfError {
  match pdf_decodeparms_value(dictionary) {
    None | Some(PdfNull) | Some(PdfArray([])) => None
    Some(PdfDictionary(_) as value) => Some(value)
    Some(PdfArray([PdfNull, ..])) => None
    Some(PdfArray([PdfDictionary(_) as value, ..])) => Some(value)
    _ => raise PredictorExpected
  }
}

///|
fn PdfDocument::pdf_decodeparms_value_direct(
  self : PdfDocument,
  dictionary : PdfObject,
) -> PdfObject? {
  match self.pdf_decodeparms_entry_direct(dictionary) {
    Some((_, value)) => Some(value)
    None => None
  }
}

///|
fn PdfDocument::pdf_decodeparms_entry_direct(
  self : PdfDocument,
  dictionary : PdfObject,
) -> (PdfName, PdfObject)? {
  match self.lookup_direct(pdf_decodeparms_key(), dictionary) {
    Some(value) => Some((pdf_decodeparms_key(), value))
    None =>
      match self.lookup_direct(pdf_short_decodeparms_key(), dictionary) {
        Some(value) => Some((pdf_short_decodeparms_key(), value))
        None => None
      }
  }
}

///|
fn PdfDocument::pdf_first_decodeparms_direct(
  self : PdfDocument,
  dictionary : PdfObject,
) -> PdfObject? raise PdfError {
  match self.pdf_decodeparms_value_direct(dictionary) {
    None | Some(PdfNull) | Some(PdfArray([])) => None
    Some(PdfDictionary(_) as value) => Some(value)
    Some(PdfArray([first, ..])) =>
      match self.direct(first) {
        PdfNull => None
        PdfDictionary(_) as value => Some(value)
        _ => raise PredictorExpected
      }
    _ => raise PredictorExpected
  }
}

///|
fn pdf_decodeparms_int(
  dictionary : PdfObject,
  key : PdfName,
  default : Int,
) -> Int raise PdfError {
  match dictionary.lookup_immediate(key) {
    None => default
    Some(PdfInteger(value)) => value
    _ => raise PredictorExpected
  }
}

///|
fn PdfDocument::pdf_decodeparms_int_direct(
  self : PdfDocument,
  dictionary : PdfObject,
  key : PdfName,
  default : Int,
) -> Int raise PdfError {
  match self.lookup_direct(key, dictionary) {
    None => default
    Some(PdfInteger(value)) => value
    _ => raise PredictorExpected
  }
}

///|
fn pdf_apply_first_predictor(
  dictionary : PdfObject,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  match pdf_first_decodeparms(dictionary) {
    None => data
    Some(decodeparms) => {
      let predictor = pdf_decodeparms_int(decodeparms, pdf_predictor_key(), 1)
      if predictor == 1 {
        data
      } else {
        pdf_decode_predictor(
          predictor,
          pdf_decodeparms_int(decodeparms, pdf_colors_key(), 1),
          pdf_decodeparms_int(decodeparms, pdf_bits_per_component_key(), 8),
          pdf_decodeparms_int(decodeparms, pdf_columns_key(), 1),
          data,
        )
      }
    }
  }
}

///|
fn PdfDocument::pdf_apply_first_predictor_direct(
  self : PdfDocument,
  dictionary : PdfObject,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  match self.pdf_first_decodeparms_direct(dictionary) {
    None => data
    Some(decodeparms) => {
      let predictor = self.pdf_decodeparms_int_direct(
        decodeparms,
        pdf_predictor_key(),
        1,
      )
      if predictor == 1 {
        data
      } else {
        pdf_decode_predictor(
          predictor,
          self.pdf_decodeparms_int_direct(decodeparms, pdf_colors_key(), 1),
          self.pdf_decodeparms_int_direct(
            decodeparms,
            pdf_bits_per_component_key(),
            8,
          ),
          self.pdf_decodeparms_int_direct(decodeparms, pdf_columns_key(), 1),
          data,
        )
      }
    }
  }
}

///|
fn pdf_lzw_early_change(dictionary : PdfObject) -> Int raise PdfError {
  match pdf_first_decodeparms(dictionary) {
    None => 1
    Some(decodeparms) =>
      pdf_decodeparms_int(decodeparms, pdf_early_change_key(), 1)
  }
}

///|
fn PdfDocument::pdf_lzw_early_change_direct(
  self : PdfDocument,
  dictionary : PdfObject,
) -> Int raise PdfError {
  match self.pdf_first_decodeparms_direct(dictionary) {
    None => 1
    Some(decodeparms) =>
      self.pdf_decodeparms_int_direct(decodeparms, pdf_early_change_key(), 1)
  }
}

///|
fn pdf_decode_stream_filter_bytes(
  filter : PdfName,
  dictionary : PdfObject,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  if pdf_filter_is_one_of(filter, "/LZWDecode", "/LZW") {
    pdf_lzw_decode(data, early_change=pdf_lzw_early_change(dictionary))
  } else {
    pdf_decode_filter_bytes(filter, data)
  }
}

///|
fn PdfDocument::pdf_decode_stream_filter_bytes_direct(
  self : PdfDocument,
  filter : PdfName,
  dictionary : PdfObject,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  if pdf_filter_is_one_of(filter, "/LZWDecode", "/LZW") {
    pdf_lzw_decode(
      data,
      early_change=self.pdf_lzw_early_change_direct(dictionary),
    )
  } else {
    pdf_decode_filter_bytes(filter, data)
  }
}

///|
fn pdf_decode_stream_onestage_value(
  stream : PdfStream,
) -> PdfStream raise PdfError {
  pdf_stream_dictionary_length(stream.dictionary)
  let data = pdf_stream_data_bytes(stream.data)
  match pdf_stream_first_filter(stream.dictionary) {
    None => {
      let dictionary = pdf_stream_replace_length(
        stream.dictionary,
        data.length(),
      )
      { dictionary, data: StreamGot(data) }
    }
    Some(filter) => {
      let decoded = pdf_decode_stream_filter_bytes(
        filter,
        stream.dictionary,
        data,
      )
      let unpredicted = pdf_apply_first_predictor(stream.dictionary, decoded)
      let dictionary = pdf_stream_replace_length(
        pdf_remove_first_decoder(stream.dictionary),
        unpredicted.length(),
      )
      { dictionary, data: StreamGot(unpredicted) }
    }
  }
}

///|
fn PdfDocument::pdf_stream_dictionary_length_direct(
  self : PdfDocument,
  dictionary : PdfObject,
) -> Unit raise PdfError {
  match self.lookup_direct(pdf_codec_length_key(), dictionary) {
    Some(PdfInteger(_)) => ()
    _ => raise StreamLengthExpected
  }
}

///|
fn PdfDocument::pdf_decode_stream_onestage_value_direct(
  self : PdfDocument,
  stream : PdfStream,
) -> PdfStream raise PdfError {
  self.pdf_stream_dictionary_length_direct(stream.dictionary)
  let data = pdf_stream_data_bytes(stream.data)
  match self.pdf_stream_first_filter_entry_direct(stream.dictionary) {
    None => {
      let dictionary = pdf_stream_replace_length(
        stream.dictionary,
        data.length(),
      )
      { dictionary, data: StreamGot(data) }
    }
    Some((filter_key, filter_value, filter)) => {
      let decoded = self.pdf_decode_stream_filter_bytes_direct(
        filter,
        stream.dictionary,
        data,
      )
      let unpredicted = self.pdf_apply_first_predictor_direct(
        stream.dictionary,
        decoded,
      )
      let dictionary = pdf_stream_replace_length(
        self.pdf_remove_first_decoder_direct(
          stream.dictionary,
          filter_key,
          filter_value,
        ),
        unpredicted.length(),
      )
      { dictionary, data: StreamGot(unpredicted) }
    }
  }
}

///|
pub fn pdf_decode_stream_onestage(
  object : PdfObject,
) -> PdfObject raise PdfError {
  match object {
    PdfStreamObject(stream) =>
      PdfStreamObject(pdf_decode_stream_onestage_value(stream))
    _ => raise ParseStreamExpected
  }
}

///|
fn PdfDocument::pdf_stream_has_filter_value_direct(
  self : PdfDocument,
  stream : PdfStream,
) -> Bool raise PdfError {
  self.pdf_stream_first_filter_direct(stream.dictionary) != None
}

///|
fn PdfDocument::pdf_decode_stream_value_direct(
  self : PdfDocument,
  stream : PdfStream,
) -> PdfStream raise PdfError {
  let mut current = stream
  let mut stages = 0
  while self.pdf_stream_has_filter_value_direct(current) {
    if stages >= 1024 {
      raise FilterExpected
    }
    current = self.pdf_decode_stream_onestage_value_direct(current)
    stages += 1
  }
  self.pdf_decode_stream_onestage_value_direct(current)
}

///|
pub fn PdfDocument::pdf_decode_stream(
  self : PdfDocument,
  object : PdfObject,
) -> PdfObject raise PdfError {
  match self.direct(object) {
    PdfStreamObject(stream) =>
      PdfStreamObject(self.pdf_decode_stream_value_direct(stream))
    _ => raise ParseStreamExpected
  }
}

///|
fn PdfDocument::pdf_decode_stream_until_unknown_value_direct(
  self : PdfDocument,
  stream : PdfStream,
) -> PdfStream raise PdfError {
  let mut current = stream
  let mut stages = 0
  let mut stopped = false
  while !stopped && self.pdf_stream_has_filter_value_direct(current) {
    if stages >= 1024 {
      raise FilterExpected
    }
    try self.pdf_decode_stream_onestage_value_direct(current) catch {
      FilterNotSupported(_) => stopped = true
      error => raise error
    } noraise {
      decoded => {
        current = decoded
        stages += 1
      }
    }
  }
  if stopped {
    current
  } else {
    self.pdf_decode_stream_onestage_value_direct(current)
  }
}

///|
pub fn PdfDocument::pdf_decode_stream_until_unknown(
  self : PdfDocument,
  object : PdfObject,
) -> PdfObject raise PdfError {
  match self.direct(object) {
    PdfStreamObject(stream) =>
      PdfStreamObject(self.pdf_decode_stream_until_unknown_value_direct(stream))
    _ => raise ParseStreamExpected
  }
}

///|
fn pdf_stream_has_filter_value(stream : PdfStream) -> Bool raise PdfError {
  pdf_stream_first_filter(stream.dictionary) != None
}

///|
fn pdf_decode_stream_value(stream : PdfStream) -> PdfStream raise PdfError {
  let mut current = stream
  let mut stages = 0
  while pdf_stream_has_filter_value(current) {
    if stages >= 1024 {
      raise FilterExpected
    }
    current = pdf_decode_stream_onestage_value(current)
    stages += 1
  }
  pdf_decode_stream_onestage_value(current)
}

///|
pub fn pdf_decode_stream(object : PdfObject) -> PdfObject raise PdfError {
  match object {
    PdfStreamObject(stream) => PdfStreamObject(pdf_decode_stream_value(stream))
    _ => raise ParseStreamExpected
  }
}

///|
fn pdf_add_filter_to_dictionary(
  dictionary : PdfObject,
  filter : PdfName,
) -> PdfObject raise PdfError {
  let filter_object = PdfNameObject(filter)
  match dictionary.lookup_immediate(pdf_filter_key()) {
    None => dictionary.add_dict_entry(pdf_filter_key(), filter_object)
    Some(PdfNameObject(existing)) =>
      dictionary.replace_dict_entry(
        pdf_filter_key(),
        PdfArray([filter_object, PdfNameObject(existing)]),
      )
    Some(PdfArray(filters)) =>
      dictionary.replace_dict_entry(
        pdf_filter_key(),
        PdfArray([filter_object, ..filters]),
      )
    _ => raise FilterExpected
  }
}

///|
pub fn pdf_encode_stream_with_filter(
  filter : PdfName,
  object : PdfObject,
  only_if_smaller? : Bool = false,
) -> PdfObject raise PdfError {
  match object {
    PdfStreamObject(stream) => {
      let data = pdf_stream_data_bytes(stream.data)
      let encoded = pdf_encode_filter_bytes(filter, data)
      if only_if_smaller && !pdf_encoded_stream_is_smaller(encoded, data) {
        object
      } else {
        let dictionary = pdf_stream_replace_length(
          pdf_add_filter_to_dictionary(stream.dictionary, filter),
          encoded.length(),
        )
        pdf_stream(dictionary, StreamGot(encoded))
      }
    }
    _ => raise ParseStreamExpected
  }
}

///|
fn pdf_encoded_stream_is_smaller(encoded : PdfBytes, data : PdfBytes) -> Bool {
  encoded.length() + 20 < data.length()
}

///|
fn pdf_predictor_decodeparms(
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
) -> PdfObject {
  pdf_dictionary([
    (pdf_predictor_key(), PdfInteger(predictor)),
    (pdf_colors_key(), PdfInteger(colors)),
    (pdf_bits_per_component_key(), PdfInteger(bits_per_component)),
    (pdf_columns_key(), PdfInteger(columns)),
  ])
}

///|
fn pdf_add_decodeparms_to_dictionary(
  dictionary : PdfObject,
  decodeparms : PdfObject,
) -> PdfObject raise PdfError {
  match dictionary.lookup_immediate(pdf_decodeparms_key()) {
    None => dictionary.add_dict_entry(pdf_decodeparms_key(), decodeparms)
    Some(PdfDictionary(_) as existing) =>
      dictionary.replace_dict_entry(
        pdf_decodeparms_key(),
        PdfArray([decodeparms, existing]),
      )
    Some(PdfArray(values)) =>
      dictionary.replace_dict_entry(
        pdf_decodeparms_key(),
        PdfArray([decodeparms, ..values]),
      )
    _ => raise PredictorExpected
  }
}

///|
pub fn pdf_encode_stream_with_filter_and_predictor(
  filter : PdfName,
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  object : PdfObject,
  only_if_smaller? : Bool = false,
) -> PdfObject raise PdfError {
  match object {
    PdfStreamObject(stream) => {
      let data = pdf_stream_data_bytes(stream.data)
      let predicted = pdf_encode_predictor(
        predictor, colors, bits_per_component, columns, data,
      )
      let encoded = pdf_encode_filter_bytes(filter, predicted)
      if only_if_smaller && !pdf_encoded_stream_is_smaller(encoded, data) {
        object
      } else {
        let dictionary = pdf_stream_replace_length(
          pdf_add_filter_to_dictionary(
            pdf_add_decodeparms_to_dictionary(
              stream.dictionary,
              pdf_predictor_decodeparms(
                predictor, colors, bits_per_component, columns,
              ),
            ),
            filter,
          ),
          encoded.length(),
        )
        pdf_stream(dictionary, StreamGot(encoded))
      }
    }
    _ => raise ParseStreamExpected
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
pub fn pdf_run_length_encode_view(data : BytesView) -> PdfBytes {
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
pub fn pdf_run_length_encode(data : PdfBytes) -> PdfBytes {
  pdf_run_length_encode_view(data[:])
}

///|
pub fn pdf_run_length_decode_view(data : BytesView) -> PdfBytes {
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

///|
pub fn pdf_run_length_decode(data : PdfBytes) -> PdfBytes {
  pdf_run_length_decode_view(data[:])
}
