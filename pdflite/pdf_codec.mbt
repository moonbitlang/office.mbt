///|
fn pdf_filter_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_filter_crypt_name : PdfName = pdf_filter_name("/Crypt")

///|
let pdf_filter_ascii_hex_decode_name : PdfName = pdf_filter_name(
  "/ASCIIHexDecode",
)

///|
let pdf_filter_ascii_hex_short_name : PdfName = pdf_filter_name("/AHx")

///|
let pdf_filter_ascii85_decode_name : PdfName = pdf_filter_name("/ASCII85Decode")

///|
let pdf_filter_ascii85_short_name : PdfName = pdf_filter_name("/A85")

///|
let pdf_filter_run_length_decode_name : PdfName = pdf_filter_name(
  "/RunLengthDecode",
)

///|
let pdf_filter_run_length_short_name : PdfName = pdf_filter_name("/RL")

///|
let pdf_filter_flate_decode_name : PdfName = pdf_filter_name("/FlateDecode")

///|
let pdf_filter_flate_short_name : PdfName = pdf_filter_name("/Fl")

///|
let pdf_filter_lzw_decode_name : PdfName = pdf_filter_name("/LZWDecode")

///|
let pdf_filter_lzw_short_name : PdfName = pdf_filter_name("/LZW")

///|
let pdf_filter_ccitt_fax_decode_name : PdfName = pdf_filter_name(
  "/CCITTFaxDecode",
)

///|
let pdf_filter_ccitt_fax_short_name : PdfName = pdf_filter_name("/CCF")

///|
/// Stream encoding requested by high-level stream encode helpers.
///
/// CCITT variants carry image columns and rows because those values are needed
/// in `/DecodeParms` when writing fax-compressed image streams.
pub(all) enum PdfStreamEncoding {
  PdfStreamASCIIHex
  PdfStreamASCII85
  PdfStreamRunLength
  PdfStreamFlate
  PdfStreamCCITT(Int, Int)
  PdfStreamCCITTG4(Int, Int)
} derive(Debug, Eq, ToJson)

///|
/// PNG/TIFF predictor requested when encoding stream data.
///
/// Predictor values correspond to PDF `/Predictor` numbers.
pub(all) enum PdfStreamPredictor {
  PdfStreamPredictorTIFF2
  PdfStreamPredictorPNGNone
  PdfStreamPredictorPNGSub
  PdfStreamPredictorPNGUp
  PdfStreamPredictorPNGAverage
  PdfStreamPredictorPNGPaeth
  PdfStreamPredictorPNGOptimum
} derive(Debug, Eq, ToJson)

///|
/// Return the PDF filter name for this stream encoding.
pub fn PdfStreamEncoding::filter_name(self : PdfStreamEncoding) -> PdfName {
  match self {
    PdfStreamASCIIHex => pdf_filter_ascii_hex_decode_name
    PdfStreamASCII85 => pdf_filter_ascii85_decode_name
    PdfStreamRunLength => pdf_filter_run_length_decode_name
    PdfStreamFlate => pdf_filter_flate_decode_name
    PdfStreamCCITT(_, _) | PdfStreamCCITTG4(_, _) =>
      pdf_filter_ccitt_fax_decode_name
  }
}

///|
/// Return the PDF `/Predictor` number for this predictor.
pub fn PdfStreamPredictor::number(self : PdfStreamPredictor) -> Int {
  match self {
    PdfStreamPredictorTIFF2 => 2
    PdfStreamPredictorPNGNone => 10
    PdfStreamPredictorPNGSub => 11
    PdfStreamPredictorPNGUp => 12
    PdfStreamPredictorPNGAverage => 13
    PdfStreamPredictorPNGPaeth => 14
    PdfStreamPredictorPNGOptimum => 15
  }
}

///|
/// Encode 1-bit image data as CCITT Group 3 one-dimensional fax data.
pub fn pdf_ccitt_encode_view(
  columns : Int,
  rows : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  pdf_ccitt_encode_g3_1d_view(data, columns, rows)
}

///|
/// Owned-byte wrapper for `pdf_ccitt_encode_view`.
pub fn pdf_ccitt_encode(
  columns : Int,
  rows : Int,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  pdf_ccitt_encode_view(columns, rows, data)
}

///|
/// Encode 1-bit image data as CCITT Group 4 fax data.
pub fn pdf_ccitt_g4_encode_view(
  columns : Int,
  rows : Int,
  data : BytesView,
) -> PdfBytes raise PdfError {
  pdf_ccitt_encode_g4_view(data, columns, rows)
}

///|
/// Owned-byte wrapper for `pdf_ccitt_g4_encode_view`.
pub fn pdf_ccitt_g4_encode(
  columns : Int,
  rows : Int,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  pdf_ccitt_g4_encode_view(columns, rows, data)
}

///|
fn pdf_filter_is_name(filter : PdfName, name : PdfName) -> Bool {
  filter == name
}

///|
fn pdf_filter_is_one_of(
  filter : PdfName,
  first : PdfName,
  second : PdfName,
) -> Bool {
  pdf_filter_is_name(filter, first) || pdf_filter_is_name(filter, second)
}

///|
/// Decode bytes with a single PDF filter name.
///
/// Recognizes long and abbreviated filter names. `/Crypt` is treated as an
/// identity filter at this byte-dispatch layer; unsupported filters raise
/// `PdfError::FilterNotSupported`.
pub fn pdf_decode_filter_view(
  filter : PdfName,
  data : BytesView,
) -> PdfBytes raise PdfError {
  if pdf_filter_is_name(filter, pdf_filter_crypt_name) {
    data.to_owned()
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_ascii_hex_decode_name, pdf_filter_ascii_hex_short_name,
    ) {
    pdf_ascii_hex_decode_view(data)
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_ascii85_decode_name, pdf_filter_ascii85_short_name,
    ) {
    pdf_ascii85_decode_view(data)
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_run_length_decode_name, pdf_filter_run_length_short_name,
    ) {
    pdf_run_length_decode_view(data)
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_flate_decode_name, pdf_filter_flate_short_name,
    ) {
    pdf_flate_decode_view(data)
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_lzw_decode_name, pdf_filter_lzw_short_name,
    ) {
    pdf_lzw_decode_view(data)
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_ccitt_fax_decode_name, pdf_filter_ccitt_fax_short_name,
    ) {
    pdf_ccitt_decode_view(data, pdf_ccitt_default_params())
  } else {
    raise FilterNotSupported(filter)
  }
}

///|
/// Decode owned bytes with a single PDF filter name.
///
/// Identity and Flate paths avoid an extra copy where possible.
pub fn pdf_decode_filter_bytes(
  filter : PdfName,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  if pdf_filter_is_name(filter, pdf_filter_crypt_name) {
    data
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_flate_decode_name, pdf_filter_flate_short_name,
    ) {
    pdf_flate_decode(data)
  } else {
    pdf_decode_filter_view(filter, data)
  }
}

///|
/// Encode bytes with a single PDF filter name.
pub fn pdf_encode_filter_view(
  filter : PdfName,
  data : BytesView,
) -> PdfBytes raise PdfError {
  pdf_encode_filter_view_with_optional_flate_level(filter, data, None)
}

///|
/// Encode bytes with a single PDF filter name and explicit Flate level.
///
/// `flate_level` follows the zlib range accepted by the Flate encoder.
pub fn pdf_encode_filter_view_with_flate_level(
  filter : PdfName,
  data : BytesView,
  flate_level : Int,
) -> PdfBytes raise PdfError {
  pdf_encode_filter_view_with_optional_flate_level(
    filter,
    data,
    Some(flate_level),
  )
}

///|
fn pdf_encode_filter_view_with_optional_flate_level(
  filter : PdfName,
  data : BytesView,
  flate_level : Int?,
) -> PdfBytes raise PdfError {
  if pdf_filter_is_name(filter, pdf_filter_crypt_name) {
    data.to_owned()
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_ascii_hex_decode_name, pdf_filter_ascii_hex_short_name,
    ) {
    pdf_ascii_hex_encode_view(data)
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_ascii85_decode_name, pdf_filter_ascii85_short_name,
    ) {
    pdf_ascii85_encode_view(data)
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_run_length_decode_name, pdf_filter_run_length_short_name,
    ) {
    pdf_run_length_encode_view(data)
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_flate_decode_name, pdf_filter_flate_short_name,
    ) {
    match flate_level {
      Some(level) => pdf_flate_encode_view_with_level(data, level)
      None => pdf_flate_encode_view(data)
    }
  } else {
    raise FilterNotSupported(filter)
  }
}

///|
/// Encode owned bytes with a single PDF filter name.
pub fn pdf_encode_filter_bytes(
  filter : PdfName,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  pdf_encode_filter_bytes_with_optional_flate_level(filter, data, None)
}

///|
/// Encode owned bytes with a single PDF filter name and explicit Flate level.
pub fn pdf_encode_filter_bytes_with_flate_level(
  filter : PdfName,
  data : PdfBytes,
  flate_level : Int,
) -> PdfBytes raise PdfError {
  pdf_encode_filter_bytes_with_optional_flate_level(
    filter,
    data,
    Some(flate_level),
  )
}

///|
fn pdf_encode_filter_bytes_with_optional_flate_level(
  filter : PdfName,
  data : PdfBytes,
  flate_level : Int?,
) -> PdfBytes raise PdfError {
  if pdf_filter_is_name(filter, pdf_filter_crypt_name) {
    data
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_flate_decode_name, pdf_filter_flate_short_name,
    ) {
    match flate_level {
      Some(level) => pdf_flate_encode_with_level(data, level)
      None => pdf_flate_encode(data)
    }
  } else {
    pdf_encode_filter_view_with_optional_flate_level(filter, data, flate_level)
  }
}

///|
let pdf_filter_key_name : PdfName = pdf_filter_name("/Filter")

///|
let pdf_short_filter_key_name : PdfName = pdf_filter_name("/F")

///|
let pdf_decodeparms_key_name : PdfName = pdf_filter_name("/DecodeParms")

///|
let pdf_short_decodeparms_key_name : PdfName = pdf_filter_name("/DP")

///|
let pdf_codec_length_key_name : PdfName = pdf_filter_name("/Length")

///|
let pdf_predictor_key_name : PdfName = pdf_filter_name("/Predictor")

///|
let pdf_early_change_key_name : PdfName = pdf_filter_name("/EarlyChange")

///|
let pdf_ccitt_k_key_name : PdfName = pdf_filter_name("/K")

///|
let pdf_ccitt_end_of_line_key_name : PdfName = pdf_filter_name("/EndOfLine")

///|
let pdf_ccitt_encoded_byte_align_key_name : PdfName = pdf_filter_name(
  "/EncodedByteAlign",
)

///|
let pdf_ccitt_rows_key_name : PdfName = pdf_filter_name("/Rows")

///|
let pdf_ccitt_end_of_block_key_name : PdfName = pdf_filter_name("/EndOfBlock")

///|
let pdf_ccitt_black_is_1_key_name : PdfName = pdf_filter_name("/BlackIs1")

///|
let pdf_ccitt_damaged_rows_before_error_key_name : PdfName = pdf_filter_name(
  "/DamagedRowsBeforeError",
)

///|
let pdf_colors_key_name : PdfName = pdf_filter_name("/Colors")

///|
let pdf_bits_per_component_key_name : PdfName = pdf_filter_name(
  "/BitsPerComponent",
)

///|
let pdf_columns_key_name : PdfName = pdf_filter_name("/Columns")

///|
fn pdf_filter_key() -> PdfName {
  pdf_filter_key_name
}

///|
fn pdf_short_filter_key() -> PdfName {
  pdf_short_filter_key_name
}

///|
fn pdf_decodeparms_key() -> PdfName {
  pdf_decodeparms_key_name
}

///|
fn pdf_short_decodeparms_key() -> PdfName {
  pdf_short_decodeparms_key_name
}

///|
fn pdf_codec_length_key() -> PdfName {
  pdf_codec_length_key_name
}

///|
fn pdf_predictor_key() -> PdfName {
  pdf_predictor_key_name
}

///|
fn pdf_early_change_key() -> PdfName {
  pdf_early_change_key_name
}

///|
fn pdf_ccitt_k_key() -> PdfName {
  pdf_ccitt_k_key_name
}

///|
fn pdf_ccitt_end_of_line_key() -> PdfName {
  pdf_ccitt_end_of_line_key_name
}

///|
fn pdf_ccitt_encoded_byte_align_key() -> PdfName {
  pdf_ccitt_encoded_byte_align_key_name
}

///|
fn pdf_ccitt_rows_key() -> PdfName {
  pdf_ccitt_rows_key_name
}

///|
fn pdf_ccitt_end_of_block_key() -> PdfName {
  pdf_ccitt_end_of_block_key_name
}

///|
fn pdf_ccitt_black_is_1_key() -> PdfName {
  pdf_ccitt_black_is_1_key_name
}

///|
fn pdf_ccitt_damaged_rows_before_error_key() -> PdfName {
  pdf_ccitt_damaged_rows_before_error_key_name
}

///|
fn pdf_colors_key() -> PdfName {
  pdf_colors_key_name
}

///|
fn pdf_bits_per_component_key() -> PdfName {
  pdf_bits_per_component_key_name
}

///|
fn pdf_columns_key() -> PdfName {
  pdf_columns_key_name
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
fn pdf_decode_png_current(
  data : BytesView,
  row_start : Int,
  available : Int,
  index : Int,
) -> Int {
  if index < available {
    data[row_start + index].to_int()
  } else {
    0
  }
}

///|
fn pdf_decode_png_decoded_length(data : BytesView, scanline_width : Int) -> Int {
  let mut rows = 0
  let mut index = 0
  while index < data.length() {
    rows += 1
    index += 1
    let available = if index + scanline_width > data.length() {
      data.length() - index
    } else {
      scanline_width
    }
    index += available
  }
  rows * scanline_width
}

///|
fn pdf_decode_png_push_scanline(
  output : Array[Byte],
  position : Int,
  predictor : Int,
  prior_decoded : ArrayView[Int],
  decoded : Array[Int],
  data : BytesView,
  row_start : Int,
  available : Int,
  bytes_per_pixel : Int,
) -> Int raise PdfError {
  let scanline_width = decoded.length()
  let mut output_position = position
  match predictor {
    0 =>
      for i in 0..<scanline_width {
        decoded[i] = pdf_decode_png_current(data, row_start, available, i)
        output[output_position] = decoded[i].to_byte()
        output_position += 1
      }
    1 =>
      for i in 0..<scanline_width {
        let current = pdf_decode_png_current(data, row_start, available, i)
        decoded[i] = (
            current + pdf_predictor_get0(decoded, i - bytes_per_pixel)
          ) %
          256
        output[output_position] = decoded[i].to_byte()
        output_position += 1
      }
    2 =>
      for i in 0..<scanline_width {
        let current = pdf_decode_png_current(data, row_start, available, i)
        decoded[i] = (current + pdf_predictor_get0(prior_decoded, i)) % 256
        output[output_position] = decoded[i].to_byte()
        output_position += 1
      }
    3 =>
      for i in 0..<scanline_width {
        let current = pdf_decode_png_current(data, row_start, available, i)
        decoded[i] = (
            current +
            (
              pdf_predictor_get0(decoded, i - bytes_per_pixel) +
              pdf_predictor_get0(prior_decoded, i)
            ) /
            2
          ) %
          256
        output[output_position] = decoded[i].to_byte()
        output_position += 1
      }
    4 =>
      for i in 0..<scanline_width {
        let current = pdf_decode_png_current(data, row_start, available, i)
        let left = pdf_predictor_get0(decoded, i - bytes_per_pixel)
        let up = pdf_predictor_get0(prior_decoded, i)
        let up_left = pdf_predictor_get0(prior_decoded, i - bytes_per_pixel)
        decoded[i] = (current + pdf_paeth_predictor(left, up, up_left)) % 256
        output[output_position] = decoded[i].to_byte()
        output_position += 1
      }
    _ => raise PredictorNotSupported(predictor)
  }
  output_position
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
  let output = Array::make(
    pdf_decode_png_decoded_length(data, scanline_width),
    b'\x00',
  )
  let mut position = 0
  let mut prior_decoded : Array[Int] = [ for _ in 0..<scanline_width => 0 ]
  let mut decoded : Array[Int] = [ for _ in 0..<scanline_width => 0 ]
  let mut index = 0
  while index < data.length() {
    let predictor = data[index].to_int()
    index += 1
    let available = if index + scanline_width > data.length() {
      data.length() - index
    } else {
      scanline_width
    }
    let row_start = index
    index += available
    position = pdf_decode_png_push_scanline(
      output, position, predictor, prior_decoded, decoded, data, row_start, available,
      bytes_per_pixel,
    )
    let previous = prior_decoded
    prior_decoded = decoded
    decoded = previous
  }
  Bytes::from_array(output[:position])
}

///|
/// Decode data after applying a PDF predictor.
///
/// Predictor `1` is identity, `2` is TIFF horizontal differencing, and
/// `10..15` are PNG predictors. Invalid image geometry or unsupported
/// predictors raise `PdfError`.
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
/// Owned-byte wrapper for `pdf_decode_predictor_view`.
///
/// Predictor `1` returns the original owned bytes unchanged.
pub fn pdf_decode_predictor(
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  if predictor == 1 {
    data
  } else {
    pdf_decode_predictor_view(
      predictor, colors, bits_per_component, columns, data,
    )
  }
}

///|
fn pdf_encode_png_encoded_length(data : BytesView, scanline_width : Int) -> Int {
  data.length() / scanline_width * (scanline_width + 1)
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
  let output = Array::make(
    pdf_encode_png_encoded_length(data, scanline_width),
    b'\x00',
  )
  let mut position = 0
  for row in 0..<(data.length() / scanline_width) {
    position = pdf_encode_png_push_scanline(
      output,
      position,
      1,
      data,
      row * scanline_width,
      scanline_width,
      bytes_per_pixel,
    )
  }
  Bytes::from_array(output[:position])
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
  let output = Array::make(
    pdf_encode_png_encoded_length(data, scanline_width),
    b'\x00',
  )
  let mut position = 0
  for row in 0..<(data.length() / scanline_width) {
    position = pdf_encode_png_push_scanline(
      output,
      position,
      2,
      data,
      row * scanline_width,
      scanline_width,
      bytes_per_pixel,
    )
  }
  Bytes::from_array(output[:position])
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
fn pdf_encode_png_push_scanline(
  output : Array[Byte],
  position : Int,
  predictor : Int,
  data : BytesView,
  row_start : Int,
  scanline_width : Int,
  bytes_per_pixel : Int,
) -> Int raise PdfError {
  let mut current = position
  output[current] = predictor.to_byte()
  current += 1
  for i in 0..<scanline_width {
    let predicted = pdf_encode_png_predictor_value(
      predictor, data, row_start, i, scanline_width, bytes_per_pixel,
    )
    output[current] = pdf_predictor_wrapping_byte(
      data[row_start + i].to_int() - predicted,
    )
    current += 1
  }
  current
}

///|
fn pdf_encode_png_predictor_score(
  predictor : Int,
  data : BytesView,
  row_start : Int,
  scanline_width : Int,
  bytes_per_pixel : Int,
) -> Int raise PdfError {
  let mut score = 0
  for i in 0..<scanline_width {
    let predicted = pdf_encode_png_predictor_value(
      predictor, data, row_start, i, scanline_width, bytes_per_pixel,
    )
    let value = pdf_predictor_wrapping_byte(
      data[row_start + i].to_int() - predicted,
    ).to_int()
    score += if value > 127 { 256 - value } else { value }
  }
  score
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
  let output = Array::make(
    pdf_encode_png_encoded_length(data, scanline_width),
    b'\x00',
  )
  let mut position = 0
  for row in 0..<(data.length() / scanline_width) {
    position = pdf_encode_png_push_scanline(
      output,
      position,
      predictor,
      data,
      row * scanline_width,
      scanline_width,
      bytes_per_pixel,
    )
  }
  Bytes::from_array(output[:position])
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
  let output = Array::make(
    pdf_encode_png_encoded_length(data, scanline_width),
    b'\x00',
  )
  let mut position = 0
  for row in 0..<(data.length() / scanline_width) {
    let row_start = row * scanline_width
    let mut best_predictor = 0
    let mut best_score = pdf_encode_png_predictor_score(
      0, data, row_start, scanline_width, bytes_per_pixel,
    )
    for predictor in 1..<=4 {
      let score = pdf_encode_png_predictor_score(
        predictor, data, row_start, scanline_width, bytes_per_pixel,
      )
      if score < best_score {
        best_predictor = predictor
        best_score = score
      }
    }
    position = pdf_encode_png_push_scanline(
      output, position, best_predictor, data, row_start, scanline_width, bytes_per_pixel,
    )
  }
  Bytes::from_array(output[:position])
}

///|
/// Encode data with a PDF predictor.
///
/// Predictor `1` is identity, `2` is TIFF horizontal differencing, `10..14`
/// use fixed PNG row filters, and `15` chooses the lowest-scoring PNG filter
/// per row.
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
/// Owned-byte wrapper for `pdf_encode_predictor_view`.
///
/// Predictor `1` returns the original owned bytes unchanged.
pub fn pdf_encode_predictor(
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  if predictor == 1 {
    data
  } else {
    pdf_encode_predictor_view(
      predictor, colors, bits_per_component, columns, data,
    )
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
fn pdf_ccitt_first_decodeparms(
  dictionary : PdfObject,
) -> PdfObject? raise PdfError {
  match pdf_decodeparms_value(dictionary) {
    None | Some(PdfNull) | Some(PdfArray([])) | Some(PdfArray([PdfNull, ..])) =>
      None
    Some(PdfDictionary(_) as value) => Some(value)
    Some(PdfArray([PdfDictionary(_) as value, ..])) => Some(value)
    _ => raise CCITTDecodeParmsExpected
  }
}

///|
fn PdfDocument::pdf_ccitt_first_decodeparms_direct(
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
        _ => raise CCITTDecodeParmsExpected
      }
    _ => raise CCITTDecodeParmsExpected
  }
}

///|
fn pdf_ccitt_decodeparms_int(
  dictionary : PdfObject,
  key : PdfName,
  default : Int,
) -> Int raise PdfError {
  match dictionary.lookup_immediate(key) {
    None => default
    Some(PdfInteger(value)) => value
    _ => raise CCITTDecodeParmsExpected
  }
}

///|
fn PdfDocument::pdf_ccitt_decodeparms_int_direct(
  self : PdfDocument,
  dictionary : PdfObject,
  key : PdfName,
  default : Int,
) -> Int raise PdfError {
  match self.lookup_direct(key, dictionary) {
    None => default
    Some(PdfInteger(value)) => value
    _ => raise CCITTDecodeParmsExpected
  }
}

///|
fn pdf_ccitt_decodeparms_bool(
  dictionary : PdfObject,
  key : PdfName,
  default : Bool,
) -> Bool raise PdfError {
  match dictionary.lookup_immediate(key) {
    None => default
    Some(PdfBoolean(value)) => value
    _ => raise CCITTDecodeParmsExpected
  }
}

///|
fn PdfDocument::pdf_ccitt_decodeparms_bool_direct(
  self : PdfDocument,
  dictionary : PdfObject,
  key : PdfName,
  default : Bool,
) -> Bool raise PdfError {
  match self.lookup_direct(key, dictionary) {
    None => default
    Some(PdfBoolean(value)) => value
    _ => raise CCITTDecodeParmsExpected
  }
}

///|
fn pdf_ccitt_params(dictionary : PdfObject) -> PdfCCITTParams raise PdfError {
  let defaults = pdf_ccitt_default_params()
  match pdf_ccitt_first_decodeparms(dictionary) {
    None => defaults
    Some(decodeparms) =>
      {
        k: pdf_ccitt_decodeparms_int(decodeparms, pdf_ccitt_k_key(), defaults.k),
        end_of_line: pdf_ccitt_decodeparms_bool(
          decodeparms,
          pdf_ccitt_end_of_line_key(),
          defaults.end_of_line,
        ),
        encoded_byte_align: pdf_ccitt_decodeparms_bool(
          decodeparms,
          pdf_ccitt_encoded_byte_align_key(),
          defaults.encoded_byte_align,
        ),
        columns: pdf_ccitt_decodeparms_int(
          decodeparms,
          pdf_columns_key(),
          defaults.columns,
        ),
        rows: pdf_ccitt_decodeparms_int(
          decodeparms,
          pdf_ccitt_rows_key(),
          defaults.rows,
        ),
        end_of_block: pdf_ccitt_decodeparms_bool(
          decodeparms,
          pdf_ccitt_end_of_block_key(),
          defaults.end_of_block,
        ),
        black_is_1: pdf_ccitt_decodeparms_bool(
          decodeparms,
          pdf_ccitt_black_is_1_key(),
          defaults.black_is_1,
        ),
        damaged_rows_before_error: pdf_ccitt_decodeparms_int(
          decodeparms,
          pdf_ccitt_damaged_rows_before_error_key(),
          defaults.damaged_rows_before_error,
        ),
      }
  }
}

///|
fn PdfDocument::pdf_ccitt_params_direct(
  self : PdfDocument,
  dictionary : PdfObject,
) -> PdfCCITTParams raise PdfError {
  let defaults = pdf_ccitt_default_params()
  match self.pdf_ccitt_first_decodeparms_direct(dictionary) {
    None => defaults
    Some(decodeparms) =>
      {
        k: self.pdf_ccitt_decodeparms_int_direct(
          decodeparms,
          pdf_ccitt_k_key(),
          defaults.k,
        ),
        end_of_line: self.pdf_ccitt_decodeparms_bool_direct(
          decodeparms,
          pdf_ccitt_end_of_line_key(),
          defaults.end_of_line,
        ),
        encoded_byte_align: self.pdf_ccitt_decodeparms_bool_direct(
          decodeparms,
          pdf_ccitt_encoded_byte_align_key(),
          defaults.encoded_byte_align,
        ),
        columns: self.pdf_ccitt_decodeparms_int_direct(
          decodeparms,
          pdf_columns_key(),
          defaults.columns,
        ),
        rows: self.pdf_ccitt_decodeparms_int_direct(
          decodeparms,
          pdf_ccitt_rows_key(),
          defaults.rows,
        ),
        end_of_block: self.pdf_ccitt_decodeparms_bool_direct(
          decodeparms,
          pdf_ccitt_end_of_block_key(),
          defaults.end_of_block,
        ),
        black_is_1: self.pdf_ccitt_decodeparms_bool_direct(
          decodeparms,
          pdf_ccitt_black_is_1_key(),
          defaults.black_is_1,
        ),
        damaged_rows_before_error: self.pdf_ccitt_decodeparms_int_direct(
          decodeparms,
          pdf_ccitt_damaged_rows_before_error_key(),
          defaults.damaged_rows_before_error,
        ),
      }
  }
}

///|
fn pdf_decode_stream_filter_bytes(
  filter : PdfName,
  dictionary : PdfObject,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  if pdf_filter_is_one_of(
      filter, pdf_filter_lzw_decode_name, pdf_filter_lzw_short_name,
    ) {
    pdf_lzw_decode(data, early_change=pdf_lzw_early_change(dictionary))
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_ccitt_fax_decode_name, pdf_filter_ccitt_fax_short_name,
    ) {
    pdf_ccitt_decode_view(data, pdf_ccitt_params(dictionary))
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
  if pdf_filter_is_one_of(
      filter, pdf_filter_lzw_decode_name, pdf_filter_lzw_short_name,
    ) {
    pdf_lzw_decode(
      data,
      early_change=self.pdf_lzw_early_change_direct(dictionary),
    )
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_ccitt_fax_decode_name, pdf_filter_ccitt_fax_short_name,
    ) {
    pdf_ccitt_decode_view(data, self.pdf_ccitt_params_direct(dictionary))
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
/// Decode exactly one filter stage from a stream object.
///
/// The first filter and matching decode parameters are removed from the stream
/// dictionary, and `/Length` is refreshed. Non-stream objects raise
/// `PdfError::ParseStreamExpected`.
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
/// Decode all supported filter stages from a stream object in this document.
///
/// Indirect filter and decode-parameter objects are resolved through the
/// document. Unsupported filters raise `PdfError::FilterNotSupported`.
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
/// Decode supported filter stages until the first unsupported filter.
///
/// The unsupported filter and remaining filters stay in the stream dictionary;
/// malformed supported filters still raise.
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
fn pdf_decode_stream_until_unknown_value(
  stream : PdfStream,
) -> PdfStream raise PdfError {
  pdf_document_empty().pdf_decode_stream_until_unknown_value_direct(stream)
}

///|
/// Decode supported filter stages on every parsed stream in the document.
///
/// Streams already marked as decrypted stay in that state. Objects are updated
/// in place and logged as altered when their stream data changes.
pub fn PdfDocument::pdf_decode_streams_until_unknown(
  self : PdfDocument,
) -> Unit raise PdfError {
  for number in self.objects.object_numbers() {
    let entry = self.objects.get_entry(number).unwrap()
    match entry.data {
      ObjectParsed(PdfStreamObject(stream)) => {
        let decoded = self.pdf_decode_stream_until_unknown_value_direct(stream)
        self.objects.set_entry(number, {
          data: ObjectParsed(PdfStreamObject(decoded)),
          generation: entry.generation,
        })
        self.objects.log.push((number, ObjectAltered))
      }
      ObjectParsedAlreadyDecrypted(PdfStreamObject(stream)) => {
        let decoded = self.pdf_decode_stream_until_unknown_value_direct(stream)
        self.objects.set_entry(number, {
          data: ObjectParsedAlreadyDecrypted(PdfStreamObject(decoded)),
          generation: entry.generation,
        })
        self.objects.log.push((number, ObjectAltered))
      }
      _ => ()
    }
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
/// Decode all supported filter stages from a direct stream object.
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
/// Encode a stream object with one filter.
///
/// The new filter is prepended to existing filters and `/Length` is refreshed.
/// When `only_if_smaller` is true, the original stream is returned if encoded
/// data is not smaller than the original stream data.
pub fn pdf_encode_stream_with_filter(
  filter : PdfName,
  object : PdfObject,
  only_if_smaller? : Bool = false,
  flate_level? : Int? = None,
) -> PdfObject raise PdfError {
  match object {
    PdfStreamObject(stream) => {
      let data = pdf_stream_data_bytes(stream.data)
      let encoded = match flate_level {
        Some(level) =>
          pdf_encode_filter_bytes_with_flate_level(filter, data, level)
        None => pdf_encode_filter_bytes(filter, data)
      }
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
fn pdf_ccitt_encoding_decodeparms(
  k : Int,
  columns : Int,
  rows : Int,
) -> PdfObject {
  pdf_dictionary([
    (pdf_ccitt_k_key(), PdfInteger(k)),
    (pdf_columns_key(), PdfInteger(columns)),
    (pdf_ccitt_rows_key(), PdfInteger(rows)),
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
fn pdf_encode_stream_with_ccitt(
  columns : Int,
  rows : Int,
  k : Int,
  object : PdfObject,
  only_if_smaller : Bool,
) -> PdfObject raise PdfError {
  match object {
    PdfStreamObject(stream) => {
      let data = pdf_stream_data_bytes(stream.data)
      let encoded = if k < 0 {
        pdf_ccitt_encode_g4_view(data, columns, rows)
      } else {
        pdf_ccitt_encode_g3_1d_view(data, columns, rows)
      }
      if only_if_smaller && !pdf_encoded_stream_is_smaller(encoded, data) {
        object
      } else {
        let dictionary = pdf_stream_replace_length(
          pdf_add_filter_to_dictionary(
            pdf_add_decodeparms_to_dictionary(
              stream.dictionary,
              pdf_ccitt_encoding_decodeparms(k, columns, rows),
            ),
            pdf_filter_ccitt_fax_decode_name,
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
/// Encode a stream after first applying predictor encoding.
///
/// `/DecodeParms` are added for the predictor, the filter is prepended, and
/// `/Length` is refreshed. `only_if_smaller` compares encoded data against the
/// original stream data.
pub fn pdf_encode_stream_with_filter_and_predictor(
  filter : PdfName,
  predictor : Int,
  colors : Int,
  bits_per_component : Int,
  columns : Int,
  object : PdfObject,
  only_if_smaller? : Bool = false,
  flate_level? : Int? = None,
) -> PdfObject raise PdfError {
  match object {
    PdfStreamObject(stream) => {
      let data = pdf_stream_data_bytes(stream.data)
      let predicted = pdf_encode_predictor(
        predictor, colors, bits_per_component, columns, data,
      )
      let encoded = match flate_level {
        Some(level) =>
          pdf_encode_filter_bytes_with_flate_level(filter, predicted, level)
        None => pdf_encode_filter_bytes(filter, predicted)
      }
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
/// Encode a stream using a typed encoding description.
///
/// CCITT encodings write fax `/DecodeParms`; other encodings may optionally
/// apply a predictor before the filter. CCITT does not accept predictors.
pub fn pdf_encode_stream_with_encoding(
  encoding : PdfStreamEncoding,
  object : PdfObject,
  only_if_smaller? : Bool = false,
  predictor? : PdfStreamPredictor? = None,
  predictor_columns? : Int = 1,
  flate_level? : Int? = None,
) -> PdfObject raise PdfError {
  let filter = encoding.filter_name()
  match encoding {
    PdfStreamCCITT(columns, rows) =>
      match predictor {
        None =>
          pdf_encode_stream_with_ccitt(
            columns, rows, 0, object, only_if_smaller,
          )
        Some(_) => raise PredictorExpected
      }
    PdfStreamCCITTG4(columns, rows) =>
      match predictor {
        None =>
          pdf_encode_stream_with_ccitt(
            columns, rows, -1, object, only_if_smaller,
          )
        Some(_) => raise PredictorExpected
      }
    _ =>
      match predictor {
        None =>
          pdf_encode_stream_with_filter(
            filter,
            object,
            only_if_smaller~,
            flate_level~,
          )
        Some(predictor) =>
          pdf_encode_stream_with_filter_and_predictor(
            filter,
            predictor.number(),
            1,
            8,
            predictor_columns,
            object,
            only_if_smaller~,
            flate_level~,
          )
      }
  }
}
