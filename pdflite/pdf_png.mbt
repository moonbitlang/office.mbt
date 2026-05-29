///|
let pdf_png_ihdr_chunk_type : UInt = 0x49484452U

///|
let pdf_png_idat_chunk_type : UInt = 0x49444154U

///|
let pdf_png_max_int64 : Int64 = 2147483647L

///|
/// Parsed PNG metadata and concatenated IDAT payload.
///
/// This mirrors the small `Cpdfpng` surface needed for image insertion:
/// non-palette, non-interlaced PNGs with their compressed IDAT bytes preserved.
pub(all) struct PdfPNG {
  width : Int
  height : Int
  bit_depth : Int
  color_type : Int
  idat : PdfBytes
} derive(Debug, Eq, ToJson)

///|
fn pdf_png_u32_to_int(value : UInt, context : String) -> Int raise PdfError {
  let wide = value.to_int64()
  if wide > pdf_png_max_int64 {
    raise BadPNG(context)
  }
  wide.to_int()
}

///|
fn pdf_png_read_chunk(cursor : ByteCursor) -> (UInt, PdfBytes) raise PdfError {
  let length = pdf_png_u32_to_int(
    byte_cursor_read_u32_be(cursor),
    "read_png: chunk too large",
  )
  let chunk_type = byte_cursor_read_u32_be(cursor)
  let chunk_data = cursor.read_bytes(length)
  ignore(byte_cursor_read_u32_be(cursor))
  (chunk_type, chunk_data)
}

///|
fn pdf_png_concat(chunks : ArrayView[PdfBytes]) -> PdfBytes {
  let mut length = 0
  for chunk in chunks {
    length += chunk.length()
  }
  let output = Array::make(length, b'\x00')
  let mut position = 0
  for chunk in chunks {
    for index in 0..<chunk.length() {
      output[position] = chunk[index]
      position += 1
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_read_png_view_inner(data : BytesView) -> PdfPNG raise PdfError {
  let cursor = byte_cursor_of_view(data, source="png")
  try! cursor.seek(8)
  let (first_chunk_type, first_chunk_data) = pdf_png_read_chunk(cursor)
  if first_chunk_type != pdf_png_ihdr_chunk_type {
    raise BadPNG("read_png: first table not IHDR")
  }
  let header = byte_cursor_of_view(first_chunk_data, source="png IHDR")
  let width = pdf_png_u32_to_int(
    byte_cursor_read_u32_be(header),
    "read_png: width too large",
  )
  let height = pdf_png_u32_to_int(
    byte_cursor_read_u32_be(header),
    "read_png: height too large",
  )
  let bit_depth = match header.read_byte() {
    Some(byte) => byte.to_int()
    None => raise EndOfInput
  }
  let color_type = match header.read_byte() {
    Some(byte) => byte.to_int()
    None => raise EndOfInput
  }
  if color_type != 0 && color_type != 2 && color_type != 4 && color_type != 6 {
    raise BadPNG("read_png: only non-palette PNGs")
  }
  match header.read_byte() {
    Some(_) => ()
    None => raise EndOfInput
  }
  match header.read_byte() {
    Some(_) => ()
    None => raise EndOfInput
  }
  let interlace_method = match header.read_byte() {
    Some(byte) => byte.to_int()
    None => raise EndOfInput
  }
  if interlace_method != 0 {
    raise BadPNG("read_png: interlaced PNGs not supported")
  }
  let idat_chunks : Array[PdfBytes] = []
  let mut done = false
  while !done {
    try pdf_png_read_chunk(cursor) catch {
      _ => done = true
    } noraise {
      (chunk_type, chunk_data) =>
        if chunk_type == pdf_png_idat_chunk_type {
          idat_chunks.push(chunk_data)
        }
    }
  }
  { width, height, bit_depth, color_type, idat: pdf_png_concat(idat_chunks) }
}

///|
/// Read a non-palette, non-interlaced PNG from a byte view.
pub fn pdf_read_png_view(data : BytesView) -> PdfPNG raise PdfError {
  pdf_read_png_view_inner(data) catch {
    BadPNG(message) => raise BadPNG(message)
    EndOfInput => raise BadPNG("read_png: truncated input")
    InvalidReadLength(length) =>
      raise BadPNG("read_png: invalid chunk length " + length.to_string())
    error => raise error
  }
}

///|
/// Read a non-palette, non-interlaced PNG from owned bytes.
pub fn pdf_read_png(data : PdfBytes) -> PdfPNG raise PdfError {
  pdf_read_png_view(data)
}
