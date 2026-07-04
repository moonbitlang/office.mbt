///|
fn pdf_filter_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_filter_crypt_name : @core.PdfName = pdf_filter_name("/Crypt")

///|
let pdf_filter_ascii_hex_decode_name : @core.PdfName = pdf_filter_name(
  "/ASCIIHexDecode",
)

///|
let pdf_filter_ascii_hex_short_name : @core.PdfName = pdf_filter_name("/AHx")

///|
let pdf_filter_ascii85_decode_name : @core.PdfName = pdf_filter_name(
  "/ASCII85Decode",
)

///|
let pdf_filter_ascii85_short_name : @core.PdfName = pdf_filter_name("/A85")

///|
let pdf_filter_run_length_decode_name : @core.PdfName = pdf_filter_name(
  "/RunLengthDecode",
)

///|
let pdf_filter_run_length_short_name : @core.PdfName = pdf_filter_name("/RL")

///|
let pdf_filter_flate_decode_name : @core.PdfName = pdf_filter_name(
  "/FlateDecode",
)

///|
let pdf_filter_flate_short_name : @core.PdfName = pdf_filter_name("/Fl")

///|
let pdf_filter_lzw_decode_name : @core.PdfName = pdf_filter_name("/LZWDecode")

///|
let pdf_filter_lzw_short_name : @core.PdfName = pdf_filter_name("/LZW")

///|
let pdf_filter_ccitt_fax_decode_name : @core.PdfName = pdf_filter_name(
  "/CCITTFaxDecode",
)

///|
let pdf_filter_ccitt_fax_short_name : @core.PdfName = pdf_filter_name("/CCF")

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
pub fn PdfStreamEncoding::filter_name(
  self : PdfStreamEncoding,
) -> @core.PdfName {
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
) -> @core.PdfBytes raise @core.PdfError {
  pdf_ccitt_encode_g3_1d_view(data, columns, rows)
}

///|
/// Owned-byte wrapper for `pdf_ccitt_encode_view`.
pub fn pdf_ccitt_encode(
  columns : Int,
  rows : Int,
  data : @core.PdfBytes,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_ccitt_encode_view(columns, rows, data)
}

///|
/// Encode 1-bit image data as CCITT Group 4 fax data.
pub fn pdf_ccitt_g4_encode_view(
  columns : Int,
  rows : Int,
  data : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_ccitt_encode_g4_view(data, columns, rows)
}

///|
/// Owned-byte wrapper for `pdf_ccitt_g4_encode_view`.
pub fn pdf_ccitt_g4_encode(
  columns : Int,
  rows : Int,
  data : @core.PdfBytes,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_ccitt_g4_encode_view(columns, rows, data)
}

///|
fn pdf_filter_is_name(filter : @core.PdfName, name : @core.PdfName) -> Bool {
  filter == name
}

///|
fn pdf_filter_is_one_of(
  filter : @core.PdfName,
  first : @core.PdfName,
  second : @core.PdfName,
) -> Bool {
  pdf_filter_is_name(filter, first) || pdf_filter_is_name(filter, second)
}

///|
/// Decode bytes with a single PDF filter name.
///
/// Recognizes long and abbreviated filter names. `/Crypt` is treated as an
/// identity filter at this byte-dispatch layer; unsupported filters raise
/// `@core.PdfError::FilterNotSupported`.
pub fn pdf_decode_filter_view(
  filter : @core.PdfName,
  data : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  if pdf_filter_is_name(filter, pdf_filter_crypt_name) {
    data.to_owned()
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_ascii_hex_decode_name, pdf_filter_ascii_hex_short_name,
    ) {
    @codec.pdf_ascii_hex_decode_view(data)
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_ascii85_decode_name, pdf_filter_ascii85_short_name,
    ) {
    @codec.pdf_ascii85_decode_view(data)
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_run_length_decode_name, pdf_filter_run_length_short_name,
    ) {
    @codec.pdf_run_length_decode_view(data)
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_flate_decode_name, pdf_filter_flate_short_name,
    ) {
    @flate.pdf_flate_decode_view(data)
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_lzw_decode_name, pdf_filter_lzw_short_name,
    ) {
    @codec.pdf_lzw_decode_view(data)
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
  filter : @core.PdfName,
  data : @core.PdfBytes,
) -> @core.PdfBytes raise @core.PdfError {
  if pdf_filter_is_name(filter, pdf_filter_crypt_name) {
    data
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_flate_decode_name, pdf_filter_flate_short_name,
    ) {
    @flate.pdf_flate_decode(data)
  } else {
    pdf_decode_filter_view(filter, data)
  }
}

///|
/// Encode bytes with a single PDF filter name.
pub fn pdf_encode_filter_view(
  filter : @core.PdfName,
  data : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_encode_filter_view_with_optional_flate_level(filter, data, None)
}

///|
/// Encode bytes with a single PDF filter name and explicit Flate level.
///
/// `flate_level` follows the zlib range accepted by the Flate encoder.
pub fn pdf_encode_filter_view_with_flate_level(
  filter : @core.PdfName,
  data : BytesView,
  flate_level : Int,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_encode_filter_view_with_optional_flate_level(
    filter,
    data,
    Some(flate_level),
  )
}

///|
fn pdf_encode_filter_view_with_optional_flate_level(
  filter : @core.PdfName,
  data : BytesView,
  flate_level : Int?,
) -> @core.PdfBytes raise @core.PdfError {
  if pdf_filter_is_name(filter, pdf_filter_crypt_name) {
    data.to_owned()
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_ascii_hex_decode_name, pdf_filter_ascii_hex_short_name,
    ) {
    @codec.pdf_ascii_hex_encode_view(data)
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_ascii85_decode_name, pdf_filter_ascii85_short_name,
    ) {
    @codec.pdf_ascii85_encode_view(data)
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_run_length_decode_name, pdf_filter_run_length_short_name,
    ) {
    @codec.pdf_run_length_encode_view(data)
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_flate_decode_name, pdf_filter_flate_short_name,
    ) {
    match flate_level {
      Some(level) => @flate.pdf_flate_encode_view_with_level(data, level)
      None => @flate.pdf_flate_encode_view(data)
    }
  } else {
    raise FilterNotSupported(filter)
  }
}

///|
/// Encode owned bytes with a single PDF filter name.
pub fn pdf_encode_filter_bytes(
  filter : @core.PdfName,
  data : @core.PdfBytes,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_encode_filter_bytes_with_optional_flate_level(filter, data, None)
}

///|
/// Encode owned bytes with a single PDF filter name and explicit Flate level.
pub fn pdf_encode_filter_bytes_with_flate_level(
  filter : @core.PdfName,
  data : @core.PdfBytes,
  flate_level : Int,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_encode_filter_bytes_with_optional_flate_level(
    filter,
    data,
    Some(flate_level),
  )
}

///|
fn pdf_encode_filter_bytes_with_optional_flate_level(
  filter : @core.PdfName,
  data : @core.PdfBytes,
  flate_level : Int?,
) -> @core.PdfBytes raise @core.PdfError {
  if pdf_filter_is_name(filter, pdf_filter_crypt_name) {
    data
  } else if pdf_filter_is_one_of(
      filter, pdf_filter_flate_decode_name, pdf_filter_flate_short_name,
    ) {
    match flate_level {
      Some(level) => @flate.pdf_flate_encode_with_level(data, level)
      None => @flate.pdf_flate_encode(data)
    }
  } else {
    pdf_encode_filter_view_with_optional_flate_level(filter, data, flate_level)
  }
}
