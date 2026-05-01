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
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  if bits_per_component != 8 {
    raise PredictorNotSupported(2)
  }
  let scanline_width = pdf_predictor_scanline_width(
    colors, bits_per_component, columns,
  )
  let output = data.to_array()
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
  data : PdfBytes,
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
pub fn pdf_decode_predictor(
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  match predictor {
    1 => data
    2 => pdf_decode_tiff_predictor(colors, bits_per_component, columns, data)
    value if value >= 10 && value <= 15 =>
      pdf_decode_png_predictor(colors, bits_per_component, columns, data)
    _ => raise PredictorNotSupported(predictor)
  }
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
pub fn pdf_decode_stream_onestage(
  object : PdfObject,
) -> PdfObject raise PdfError {
  match object {
    PdfStreamObject(stream) => {
      pdf_stream_dictionary_length(stream.dictionary)
      match stream.data {
        StreamGot(data) =>
          match pdf_stream_first_filter(stream.dictionary) {
            None => {
              let dictionary = pdf_stream_replace_length(
                stream.dictionary,
                data.length(),
              )
              pdf_stream(dictionary, StreamGot(data))
            }
            Some(filter) => {
              let decoded = pdf_decode_filter_bytes(filter, data)
              let unpredicted = pdf_apply_first_predictor(
                stream.dictionary,
                decoded,
              )
              let dictionary = pdf_stream_replace_length(
                pdf_remove_first_decoder(stream.dictionary),
                unpredicted.length(),
              )
              pdf_stream(dictionary, StreamGot(unpredicted))
            }
          }
        _ => raise StreamDataExpected
      }
    }
    _ => raise ParseStreamExpected
  }
}

///|
fn pdf_stream_has_filter(object : PdfObject) -> Bool raise PdfError {
  match object {
    PdfStreamObject(stream) =>
      pdf_stream_first_filter(stream.dictionary) != None
    _ => raise ParseStreamExpected
  }
}

///|
pub fn pdf_decode_stream(object : PdfObject) -> PdfObject raise PdfError {
  let mut current = object
  let mut stages = 0
  while pdf_stream_has_filter(current) {
    if stages >= 1024 {
      raise FilterExpected
    }
    current = pdf_decode_stream_onestage(current)
    stages += 1
  }
  pdf_decode_stream_onestage(current)
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
) -> PdfObject raise PdfError {
  match object {
    PdfStreamObject(stream) =>
      match stream.data {
        StreamGot(data) => {
          let encoded = pdf_encode_filter_bytes(filter, data)
          let dictionary = pdf_stream_replace_length(
            pdf_add_filter_to_dictionary(stream.dictionary, filter),
            encoded.length(),
          )
          pdf_stream(dictionary, StreamGot(encoded))
        }
        _ => raise StreamDataExpected
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
