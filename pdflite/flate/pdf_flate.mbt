///|
/// Encode borrowed bytes as a zlib-wrapped Flate stream.
/// Levels outside `0..9` raise `InvalidFlateData`.
pub fn pdf_flate_encode_view_with_level(
  data : BytesView,
  level : Int,
) -> @core.PdfBytes raise @core.PdfError {
  guard level >= 0 && level <= 9 else { raise InvalidFlateData }
  pdf_flate_encode_stream(data, level)
}

///|
/// Encode borrowed bytes with the default compression level, 6.
pub fn pdf_flate_encode_view(data : BytesView) -> @core.PdfBytes {
  pdf_flate_encode_stream(data, 6)
}

///|
/// Encode owned bytes as a zlib-wrapped Flate stream.
/// Levels outside `0..9` raise `InvalidFlateData`.
pub fn pdf_flate_encode_with_level(
  data : @core.PdfBytes,
  level : Int,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_flate_encode_view_with_level(data, level)
}

///|
/// Encode owned bytes with the default compression level, 6.
pub fn pdf_flate_encode(data : @core.PdfBytes) -> @core.PdfBytes {
  pdf_flate_encode_view(data)
}

///|
fn pdf_flate_encode_stream(data : BytesView, level : Int) -> Bytes {
  let encoder = @zlib.Encoder(level~)
  let scratch = FixedArray::make(32768, b'\x00')
  let output = @buffer.Buffer()
  for pos = 0 {
    let status = encoder.step(data[pos:], scratch.mut_view(), action=Finish)
    for i in 0..<encoder.last_produced() {
      output.write_byte(scratch[i])
    }
    if status is Done {
      break output.to_bytes()
    }
    continue pos + encoder.last_consumed()
  }
}

///|
/// Decode the first zlib stream. Empty input returns empty output.
/// Trailing bytes are ignored, preserving the native decoder's tolerance for
/// PDF repair paths that recover a stream by scanning damaged end markers.
/// Malformed streams and preset dictionaries raise `InvalidFlateData`.
/// Output exceeding 1 GiB raises `FlateOutputLimitExceeded`.
pub fn pdf_flate_decode_view(
  data : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  let (decoded, _) = pdf_flate_decode_view_prefix(data)
  decoded
}

///|
/// Decode the first zlib stream, with the same rules as the borrowed API.
pub fn pdf_flate_decode(
  data : @core.PdfBytes,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_flate_decode_view(data)
}

///|
/// Decode the first zlib stream and return its encoded length, including the
/// header and checksum. Bytes after that stream remain available to the caller.
/// Empty input returns `(b"", 0)`; output is limited to 1 GiB.
pub fn pdf_flate_decode_view_prefix(
  data : BytesView,
) -> (@core.PdfBytes, Int) raise @core.PdfError {
  pdf_flate_decode_prefix_limited(data, 1 << 30)
}

///|
fn pdf_flate_decode_prefix_limited(
  data : BytesView,
  max_output : Int,
) -> (Bytes, Int) raise @core.PdfError {
  guard data.length() > 0 else { return (b"", 0) }
  let decoder = @zlib.Decoder()
  let scratch = FixedArray::make(32768, b'\x00')
  let output = @buffer.Buffer()
  for pos = 0 {
    let status = decoder.step(data[pos:], scratch.mut_view(), end=true) catch {
      ZlibError(_, _) => raise InvalidFlateData
    }
    let produced = decoder.last_produced()
    guard produced <= max_output - output.length() else {
      raise FlateOutputLimitExceeded(max_output)
    }
    for i in 0..<produced {
      output.write_byte(scratch[i])
    }
    let accepted = pos + decoder.last_consumed()
    match status {
      Done =>
        break (output.to_bytes(), accepted - decoder.unused_input().length())
      NeedMoreInput | NeedMoreOutput => continue accepted
    }
  }
}
