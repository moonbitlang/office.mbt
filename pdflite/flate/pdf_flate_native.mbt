///|
#cfg(target="native")
#borrow(data, status)
extern "C" fn pdf_flate_zlib_encode_ffi(
  data : @core.PdfBytes,
  level : Int,
  status : Ref[Int],
) -> @core.PdfBytes = "pdflite_zlib_compress"

///|
#cfg(target="native")
#borrow(data, status)
extern "C" fn pdf_flate_zlib_decode_ffi(
  data : @core.PdfBytes,
  status : Ref[Int],
) -> @core.PdfBytes = "pdflite_zlib_decompress"

///|
#cfg(target="native")
#coverage.skip
fn pdf_flate_native_payload(
  result : @core.PdfBytes,
  status : Ref[Int],
) -> @core.PdfBytes raise @core.PdfError {
  if status.val != 1 {
    raise InvalidFlateData
  }
  result
}

///|
#cfg(target="native")
#coverage.skip
fn pdf_flate_encode_bytes_native(
  data : @core.PdfBytes,
  level : Int,
) -> @core.PdfBytes raise @core.PdfError {
  let _ = pdf_flate_header_for_level(level)
  let status = Ref::{ val: 0 }
  try
    pdf_flate_native_payload(
      pdf_flate_zlib_encode_ffi(data, level, status),
      status,
    )
  catch {
    _ => pdf_flate_encode_view_with_level_pure(data, level)
  } noraise {
    bytes => bytes
  }
}

///|
#cfg(target="native")
#coverage.skip
fn pdf_flate_decode_bytes_native(
  data : @core.PdfBytes,
) -> @core.PdfBytes raise @core.PdfError {
  if data.length() == 0 {
    Bytes::new(0)
  } else {
    let status = Ref::{ val: 0 }
    try
      pdf_flate_native_payload(pdf_flate_zlib_decode_ffi(data, status), status)
    catch {
      _ => pdf_flate_decode_view_pure(data)
    } noraise {
      bytes => bytes
    }
  }
}
