///|
// Encoding no longer depends on the target.
//
// These four entry points used to exist twice each: a native variant calling
// miniz through a C stub, and a pure MoonBit variant everywhere else. That
// split meant the same document compressed to different bytes on different
// backends -- measured at +12% on a Latin PDF page and +24% on a
// one-ideograph page -- so "deterministic output" could only ever be claimed
// per runtime.
//
// `tdefl_compress_zlib` is a port of the vendored miniz's own compressor,
// verified byte-for-byte against it, so there is one implementation and one
// answer. Native output is unchanged, because the port reproduces what the C
// produced; wasm and js output changes to match, and gets smaller doing so.
//
// The FFI is still there and still compiled on native: it is the oracle the
// differential test compares against. It is no longer in the path any document
// takes.

///|
/// Encode borrowed bytes as a zlib-wrapped Flate stream.
///
/// `level` must be in the zlib range `0..9`; invalid levels raise
/// `@core.PdfError::InvalidFlateData`.
pub fn pdf_flate_encode_view_with_level(
  data : BytesView,
  level : Int,
) -> @core.PdfBytes raise @core.PdfError {
  guard level >= 0 && level <= 9 else { raise InvalidFlateData }
  tdefl_compress_zlib(data, level)
}

///|
/// Encode borrowed bytes with the default compression level.
pub fn pdf_flate_encode_view(data : BytesView) -> @core.PdfBytes {
  tdefl_compress_zlib(data, 6)
}

///|
/// Encode owned bytes as a zlib-wrapped Flate stream.
///
/// `level` must be in the zlib range `0..9`; invalid levels raise
/// `@core.PdfError::InvalidFlateData`.
pub fn pdf_flate_encode_with_level(
  data : @core.PdfBytes,
  level : Int,
) -> @core.PdfBytes raise @core.PdfError {
  guard level >= 0 && level <= 9 else { raise InvalidFlateData }
  tdefl_compress_zlib(data, level)
}

///|
/// Encode owned bytes with the default compression level.
pub fn pdf_flate_encode(data : @core.PdfBytes) -> @core.PdfBytes {
  tdefl_compress_zlib(data, 6)
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
    let status = Ref::{ val: 0, }
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
