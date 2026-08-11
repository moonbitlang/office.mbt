///|
let pdf_png_ihdr_chunk_type : UInt = 0x49484452U

///|
let pdf_png_idat_chunk_type : UInt = 0x49444154U

///|
let pdf_png_plte_chunk_type : UInt = 0x504C5445U

///|
let pdf_png_trns_chunk_type : UInt = 0x74524E53U

///|
let pdf_png_max_int64 : Int64 = 2147483647L

///|
/// Parsed PNG metadata and concatenated IDAT payload.
///
/// This mirrors the small `Cpdfpng` surface needed for image insertion,
/// with the compressed IDAT bytes preserved. `idat` is always a
/// *non-interlaced* datastream — an Adam7 source is rebuilt into the
/// equivalent sequential one when it is read, so consumers never see
/// interlacing. `palette` carries the PLTE payload (RGB triples) for
/// colour type 3 and is `None` for every other type.
pub(all) struct PdfPNG {
  width : Int
  height : Int
  bit_depth : Int
  color_type : Int
  idat : @core.PdfBytes
  palette : @core.PdfBytes?
} derive(Debug, Eq, ToJson)

///|
fn pdf_png_u32_to_int(
  value : UInt,
  context : String,
) -> Int raise @core.PdfError {
  let wide = value.to_int64()
  if wide > pdf_png_max_int64 {
    raise BadPNG(context)
  }
  wide.to_int()
}

///|
fn pdf_png_read_chunk(
  cursor : @core.ByteCursor,
) -> (UInt, @core.PdfBytes) raise @core.PdfError {
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
fn pdf_png_concat(chunks : ArrayView[@core.PdfBytes]) -> @core.PdfBytes {
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
fn pdf_read_png_view_inner(data : BytesView) -> PdfPNG raise @core.PdfError {
  let cursor = @core.byte_cursor_of_view(data, source="png")
  try! cursor.seek(8)
  let (first_chunk_type, first_chunk_data) = pdf_png_read_chunk(cursor)
  if first_chunk_type != pdf_png_ihdr_chunk_type {
    raise BadPNG("read_png: first table not IHDR")
  }
  let header = @core.byte_cursor_of_view(first_chunk_data, source="png IHDR")
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
  if color_type != 0 &&
    color_type != 2 &&
    color_type != 3 &&
    color_type != 4 &&
    color_type != 6 {
    raise BadPNG("read_png: unknown colour type " + color_type.to_string())
  }
  // Palette depth is validated here even on the sequential path (which
  // historically checks no depths): indices cap at one byte, and a
  // 16-bit depth passed through would emit an /Indexed image PDF forbids
  // rather than fail.
  if color_type == 3 &&
    bit_depth != 1 &&
    bit_depth != 2 &&
    bit_depth != 4 &&
    bit_depth != 8 {
    raise BadPNG(
      "read_png: bit depth " +
      bit_depth.to_string() +
      " invalid for a palette image",
    )
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
  if interlace_method != 0 && interlace_method != 1 {
    raise BadPNG(
      "read_png: unknown interlace method " + interlace_method.to_string(),
    )
  }
  let idat_chunks : Array[@core.PdfBytes] = []
  let mut palette : @core.PdfBytes? = None
  let mut trns_entries : Int? = None
  let mut done = false
  while !done {
    try pdf_png_read_chunk(cursor) catch {
      _ => done = true
    } noraise {
      (chunk_type, chunk_data) =>
        if chunk_type == pdf_png_idat_chunk_type {
          idat_chunks.push(chunk_data)
        } else if chunk_type == pdf_png_plte_chunk_type {
          palette = Some(chunk_data)
        } else if chunk_type == pdf_png_trns_chunk_type && color_type == 3 {
          // A palette with real per-entry alpha would need the
          // transparency rebuilt as an /SMask, which forces a full decode
          // this passthrough deliberately avoids. Refusing keeps the loss
          // visible (the caller reports the image unreadable) instead of
          // drawing it opaque, which would be quietly wrong.
          //
          // A tRNS whose entries are all 255 declares no transparency at
          // all, though — every listed entry is fully opaque and PNG
          // defines the unlisted rest as opaque too — so that common
          // encoder artefact takes the normal path rather than losing the
          // picture. tRNS on colour types 0/2 (a transparent colour key)
          // stays ignored, as it always was.
          for index in 0..<chunk_data.length() {
            if chunk_data[index] != b'\xff' {
              raise BadPNG("read_png: palette transparency not supported")
            }
          }
          trns_entries = Some(chunk_data.length())
        }
    }
  }
  let palette = match (palette, color_type) {
    (Some(plte), 3) => {
      if plte.length() == 0 || plte.length() % 3 != 0 || plte.length() > 768 {
        raise BadPNG(
          "read_png: malformed palette of " +
          plte.length().to_string() +
          " bytes",
        )
      }
      // tRNS may not name more entries than the palette has. Checked
      // here rather than at the chunk, because the scan is
      // order-independent and the palette may not have been seen yet.
      match trns_entries {
        Some(entries) =>
          if entries > plte.length() / 3 {
            raise BadPNG("read_png: tRNS longer than the palette")
          }
        None => ()
      }
      Some(plte)
    }
    (None, 3) => raise BadPNG("read_png: palette image without a PLTE chunk")
    // PLTE on a truecolour image is a quantisation hint; on greyscale it
    // is invalid. Neither affects how the pixels decode, so it is dropped
    // rather than carried.
    (_, _) => None
  }
  let concatenated = pdf_png_concat(idat_chunks)
  let idat = if interlace_method == 1 {
    pdf_png_deinterlace(width, height, bit_depth, color_type, concatenated)
  } else {
    concatenated
  }
  { width, height, bit_depth, color_type, idat, palette }
}

///|
/// Read a PNG from a byte view, de-interlacing an Adam7 image into a
/// sequential IDAT stream. Palette images carry their PLTE; real palette
/// transparency (a tRNS entry below 255) is refused rather than dropped.
pub fn pdf_read_png_view(data : BytesView) -> PdfPNG raise @core.PdfError {
  pdf_read_png_view_inner(data) catch {
    BadPNG(message) => raise BadPNG(message)
    EndOfInput => raise BadPNG("read_png: truncated input")
    InvalidReadLength(length) =>
      raise BadPNG("read_png: invalid chunk length " + length.to_string())
    error => raise error
  }
}

///|
/// Read a PNG from owned bytes, de-interlacing an Adam7 image into a
/// sequential IDAT stream. Palette images carry their PLTE; real palette
/// transparency (a tRNS entry below 255) is refused rather than dropped.
pub fn pdf_read_png(data : @core.PdfBytes) -> PdfPNG raise @core.PdfError {
  pdf_read_png_view(data)
}
