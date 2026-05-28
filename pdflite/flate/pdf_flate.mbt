///|
/// Encode borrowed bytes as a zlib-wrapped Flate stream.
///
/// `level` must be in the zlib range `0..9`; invalid levels raise
/// `@core.PdfError::InvalidFlateData`. On non-native targets this uses the pure MoonBit encoder.
#cfg(not(target="native"))
pub fn pdf_flate_encode_view_with_level(
  data : BytesView,
  level : Int,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_flate_encode_view_with_level_pure(data, level)
}

///|
/// Encode borrowed bytes as a zlib-wrapped Flate stream.
///
/// `level` must be in the zlib range `0..9`; invalid levels raise
/// `@core.PdfError::InvalidFlateData`. On the native target this tries the zlib FFI first and
/// falls back to the pure MoonBit encoder if the native call fails.
#cfg(target="native")
#coverage.skip
pub fn pdf_flate_encode_view_with_level(
  data : BytesView,
  level : Int,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_flate_encode_bytes_native(data.to_owned(), level)
}

///|
/// Encode borrowed bytes with the default compression level.
///
/// This non-native implementation uses the pure MoonBit encoder.
#cfg(not(target="native"))
pub fn pdf_flate_encode_view(data : BytesView) -> @core.PdfBytes {
  pdf_flate_encode_view_pure(data)
}

///|
/// Encode borrowed bytes with the default compression level.
///
/// On the native target this tries zlib at level `6` and falls back to the pure
/// MoonBit encoder if the native call fails.
#cfg(target="native")
#coverage.skip
pub fn pdf_flate_encode_view(data : BytesView) -> @core.PdfBytes {
  try pdf_flate_encode_bytes_native(data.to_owned(), 6) catch {
    _ => pdf_flate_encode_view_pure(data)
  } noraise {
    bytes => bytes
  }
}

///|
/// Encode owned bytes as a zlib-wrapped Flate stream.
///
/// `level` must be in the zlib range `0..9`; invalid levels raise
/// `@core.PdfError::InvalidFlateData`. This non-native implementation uses the pure MoonBit
/// encoder.
#cfg(not(target="native"))
pub fn pdf_flate_encode_with_level(
  data : @core.PdfBytes,
  level : Int,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_flate_encode_view_with_level_pure(data, level)
}

///|
/// Encode owned bytes as a zlib-wrapped Flate stream.
///
/// `level` must be in the zlib range `0..9`; invalid levels raise
/// `@core.PdfError::InvalidFlateData`. On the native target this uses zlib FFI with a pure
/// MoonBit fallback.
#cfg(target="native")
#coverage.skip
pub fn pdf_flate_encode_with_level(
  data : @core.PdfBytes,
  level : Int,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_flate_encode_bytes_native(data, level)
}

///|
/// Encode owned bytes with the default compression level.
///
/// This non-native implementation uses the pure MoonBit encoder.
#cfg(not(target="native"))
pub fn pdf_flate_encode(data : @core.PdfBytes) -> @core.PdfBytes {
  pdf_flate_encode_view_pure(data)
}

///|
/// Encode owned bytes with the default compression level.
///
/// On the native target this tries zlib at level `6` and falls back to the pure
/// MoonBit encoder if the native call fails.
#cfg(target="native")
#coverage.skip
pub fn pdf_flate_encode(data : @core.PdfBytes) -> @core.PdfBytes {
  try pdf_flate_encode_bytes_native(data, 6) catch {
    _ => pdf_flate_encode_view_pure(data)
  } noraise {
    bytes => bytes
  }
}

///|
/// Decode a zlib-wrapped Flate stream from a borrowed byte view.
///
/// Empty input decodes to empty output. Malformed headers, unsupported preset
/// dictionaries, invalid Deflate data, and Adler-32 mismatches raise
/// `@core.PdfError::InvalidFlateData`.
#cfg(not(target="native"))
pub fn pdf_flate_decode_view(
  data : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_flate_decode_view_pure(data)
}

///|
/// Decode a zlib-wrapped Flate stream from a borrowed byte view.
///
/// On the native target this tries zlib FFI first and falls back to the pure
/// MoonBit decoder if the native call fails. Invalid compressed data raises
/// `@core.PdfError::InvalidFlateData`.
#cfg(target="native")
#coverage.skip
pub fn pdf_flate_decode_view(
  data : BytesView,
) -> @core.PdfBytes raise @core.PdfError {
  if data.length() == 0 {
    Bytes::new(0)
  } else {
    let status = Ref::{ val: 0 }
    try
      pdf_flate_native_payload(
        pdf_flate_zlib_decode_ffi(data.to_owned(), status),
        status,
      )
    catch {
      _ => pdf_flate_decode_view_pure(data)
    } noraise {
      bytes => bytes
    }
  }
}

///|
/// Decode a zlib-wrapped Flate stream from owned bytes.
///
/// Empty input decodes to empty output. Malformed compressed data raises
/// `@core.PdfError::InvalidFlateData`.
#cfg(not(target="native"))
pub fn pdf_flate_decode(
  data : @core.PdfBytes,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_flate_decode_view_pure(data)
}

///|
/// Decode a zlib-wrapped Flate stream from owned bytes.
///
/// On the native target this uses zlib FFI with a pure MoonBit fallback.
#cfg(target="native")
#coverage.skip
pub fn pdf_flate_decode(
  data : @core.PdfBytes,
) -> @core.PdfBytes raise @core.PdfError {
  pdf_flate_decode_bytes_native(data)
}

///|
/// Decode the first zlib-wrapped Flate stream from a byte view.
///
/// Returns the decoded bytes and the number of encoded bytes consumed, which
/// lets callers continue parsing data that follows the compressed stream.
pub fn pdf_flate_decode_view_prefix(
  data : BytesView,
) -> (@core.PdfBytes, Int) raise @core.PdfError {
  if data.length() == 0 {
    (Bytes::new(0), 0)
  } else {
    if data.length() < 6 {
      raise InvalidFlateData
    }
    let cmf = data[0].to_int()
    let flg = data[1].to_int()
    if (cmf & 0x0F) != 8 || ((cmf << 8) + flg) % 31 != 0 || (flg & 0x20) != 0 {
      raise InvalidFlateData
    }
    let (decoded, deflate_length) = pdf_deflate_decode_raw_prefix(data[2:])
    let encoded_length = 2 + deflate_length + 4
    if encoded_length > data.length() {
      raise InvalidFlateData
    }
    pdf_flate_check_adler32(data[:encoded_length], decoded)
    (decoded, encoded_length)
  }
}
