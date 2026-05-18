///|
fn pdf_content_two_byte_charcodes_or_empty(bytes : BytesView) -> Array[Int] {
  if bytes.length() % 2 != 0 {
    []
  } else {
    let output : Array[Int] = []
    let mut index = 0
    while index < bytes.length() {
      let high = bytes[index].to_int()
      let low = bytes[index + 1].to_int()
      output.push((high << 8) | low)
      index += 2
    }
    output
  }
}

///|
/// Split raw PDF string bytes into cpdfcontent character codes for `self`.
///
/// Standard and simple fonts use one byte per character code. CID-keyed fonts
/// use fixed two-byte big-endian character codes, and malformed odd-length
/// inputs return an empty array to match cpdf's `charcodes_of_string`.
pub fn PdfFont::content_charcodes_of_bytes(
  self : PdfFont,
  bytes : BytesView,
) -> Array[Int] {
  match self {
    PdfFontCIDKeyed(_) => pdf_content_two_byte_charcodes_or_empty(bytes)
    _ => [ for byte in bytes => byte.to_int() ]
  }
}

///|
/// Compatibility wrapper for `PdfFont::content_charcodes_of_bytes`.
pub fn pdf_content_charcodes_of_bytes(
  bytes : BytesView,
  font : PdfFont,
) -> Array[Int] {
  font.content_charcodes_of_bytes(bytes)
}

///|
/// Convert a cpdfcontent glyph character code back to raw PDF string bytes.
///
/// CID-keyed fonts write the code as two big-endian bytes. Standard and simple
/// fonts write a single byte. Out-of-range bytes raise `PdfError::InvalidByte`,
/// matching the source helper's `char_of_int` failure cases.
pub fn PdfFont::content_bytes_of_charcode(
  self : PdfFont,
  charcode : Int,
) -> PdfBytes raise PdfError {
  match self {
    PdfFontCIDKeyed(_) =>
      Bytes::from_array([
        pdf_byte_of_int(charcode >> 8),
        pdf_byte_of_int(charcode & 0xFF),
      ])
    _ => Bytes::from_array([pdf_byte_of_int(charcode)])
  }
}

///|
/// Compatibility wrapper for `PdfFont::content_bytes_of_charcode`.
pub fn pdf_content_bytes_of_charcode(
  font : PdfFont,
  charcode : Int,
) -> PdfBytes raise PdfError {
  font.content_bytes_of_charcode(charcode)
}

///|
fn pdf_content_descriptor_extra_metrics(
  descriptor : PdfFontDescriptor,
) -> (Double, Double) {
  let bbox = descriptor.fontbbox
  if bbox.min_x == 0.0 &&
    bbox.min_y == 0.0 &&
    bbox.max_x == 0.0 &&
    bbox.max_y == 0.0 {
    (descriptor.ascent, descriptor.descent)
  } else {
    (bbox.min_y, bbox.max_y)
  }
}

///|
fn pdf_content_afm_header_value(data : PdfAfmData, key : String) -> BytesView? {
  let key_bytes = @ascii.encode(key)
  for entry in data.headers {
    if pdf_afm_view_equals(entry.0, key_bytes) {
      break Some(entry.1[:])
    }
  } nobreak {
    None
  }
}

///|
fn pdf_content_afm_parse_int(value : BytesView) -> Int? {
  let parsed : Result[Int, Error] = try? pdf_afm_parse_int(value)
  match parsed {
    Ok(number) => Some(number)
    Err(_) => None
  }
}

///|
fn pdf_content_afm_header_number(data : PdfAfmData, key : String) -> Double {
  match pdf_content_afm_header_value(data, key) {
    Some(value) => {
      let tokens = pdf_split_whitespace_tokens(value)
      if tokens.length() == 1 {
        let parsed : Result[Double, Error] = try? @strconv.from_str(
          @ascii.decode_lossy(tokens[0]),
        )
        match parsed {
          Ok(number) => number
          Err(_) => 0.0
        }
      } else {
        0.0
      }
    }
    None => 0.0
  }
}

///|
fn pdf_content_standard_font_bbox_metrics(
  data : PdfAfmData,
) -> (Double, Double) {
  match pdf_content_afm_header_value(data, "FontBBox") {
    Some(value) => {
      let tokens = pdf_split_whitespace_tokens(value)
      if tokens.length() == 4 {
        match
          (
            pdf_content_afm_parse_int(tokens[1]),
            pdf_content_afm_parse_int(tokens[3]),
          ) {
          (Some(y0), Some(y1)) =>
            if y0 < y1 {
              (y0.to_double(), y1.to_double())
            } else {
              (y1.to_double(), y0.to_double())
            }
          _ => (0.0, 0.0)
        }
      } else {
        (0.0, 0.0)
      }
    }
    None => (0.0, 0.0)
  }
}

///|
fn pdf_content_standard_font_extra_metrics(
  font : PdfStandardFont,
) -> (Double, Double) {
  let data = font.afm_data()
  let bbox_metrics = pdf_content_standard_font_bbox_metrics(data)
  if bbox_metrics.0 == 0.0 && bbox_metrics.1 == 0.0 {
    (
      pdf_content_afm_header_number(data, "Ascender"),
      pdf_content_afm_header_number(data, "Descender"),
    )
  } else {
    bbox_metrics
  }
}

///|
/// Return cpdfcontent's extra vertical metrics for text bounding boxes.
///
/// Type 3 fonts transform their font bbox through the font matrix. Other
/// described simple fonts and CID fonts use the descriptor bbox when present,
/// falling back to ascent/descent only for a zero bbox. Standard fonts read the
/// AFM `FontBBox` header, with `Ascender`/`Descender` as the zero-bbox fallback.
pub fn PdfFont::content_extra_metrics(self : PdfFont) -> (Double, Double) {
  match self {
    PdfFontSimple({ fonttype: PdfType3(data), .. }) => {
      let top = data.fontmatrix.apply(point2(0.0, data.fontbbox.max_y))
      let bottom = data.fontmatrix.apply(point2(0.0, data.fontbbox.min_y))
      (top.y, bottom.y)
    }
    PdfFontSimple({ fontdescriptor: Some(descriptor), .. }) =>
      pdf_content_descriptor_extra_metrics(descriptor)
    PdfFontCIDKeyed({ composite: { cid_fontdescriptor: descriptor, .. }, .. }) =>
      pdf_content_descriptor_extra_metrics(descriptor)
    PdfFontStandard({ font, .. }) =>
      pdf_content_standard_font_extra_metrics(font)
    PdfFontSimple(_) => (0.0, 0.0)
  }
}

///|
/// Compatibility wrapper for `PdfFont::content_extra_metrics`.
pub fn pdf_content_extra_metrics(font : PdfFont) -> (Double, Double) {
  font.content_extra_metrics()
}

///|
/// Return whether cpdfcontent treats this font as vertical text.
///
/// This intentionally mirrors cpdfcontent's narrow `vertical` helper: only the
/// predefined `/Identity-V` CMap is vertical among predefined maps, and parsed
/// external CMaps are vertical only when their `wmode` is `1`.
pub fn PdfFont::content_is_vertical(self : PdfFont) -> Bool {
  match self {
    PdfFontCIDKeyed({ encoding: PdfPredefinedCMap(name), .. }) =>
      name == pdf_text_identity_v_name
    PdfFontCIDKeyed(
      { encoding: PdfExternalCMap(_, { wmode: Some(1), .. }), .. }
    ) => true
    _ => false
  }
}

///|
/// Compatibility wrapper for `PdfFont::content_is_vertical`.
pub fn pdf_content_is_vertical(font : PdfFont) -> Bool {
  font.content_is_vertical()
}

///|
fn pdf_content_cid_width_lookup(
  widths : ArrayView[(Int, Double)],
  charcode : Int,
) -> Double? {
  for entry in widths {
    if entry.0 == charcode {
      break Some(entry.1)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_content_cid_vertical_width_lookup(
  widths : ArrayView[(Int, PdfCIDVerticalWidth)],
  charcode : Int,
) -> PdfCIDVerticalWidth? {
  for entry in widths {
    if entry.0 == charcode {
      break Some(entry.1)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_content_cid_default_width2(
  widths : ArrayView[Double],
) -> (Double, Double) {
  if widths.length() >= 2 {
    (widths[0], widths[1])
  } else {
    (0.0, 0.0)
  }
}

///|
fn pdf_content_cid_width_of_charcode(
  font : PdfCIDKeyedFont,
  charcode : Int,
) -> (Double, Double, Double) {
  if PdfFontCIDKeyed(font).content_is_vertical() {
    match
      pdf_content_cid_vertical_width_lookup(
        font.composite.cid_widths2,
        charcode,
      ) {
      Some(width) => (width.width, width.vx, width.vy)
      None =>
        match
          pdf_content_cid_width_lookup(font.composite.cid_widths, charcode) {
          Some(width) => {
            let default = pdf_content_cid_default_width2(
              font.composite.cid_default_width2,
            )
            (width / 2.0, default.0, default.1)
          }
          None => (0.0, 0.0, 0.0)
        }
    }
  } else {
    match pdf_content_cid_width_lookup(font.composite.cid_widths, charcode) {
      Some(width) => (width, 0.0, 0.0)
      None => (font.composite.cid_default_width, 0.0, 0.0)
    }
  }
}

///|
fn pdf_content_simple_width_of_charcode(
  font : PdfSimpleFont,
  charcode : Int,
) -> (Double, Double, Double) {
  match font.fontmetrics {
    Some(metrics) if charcode >= 0 && charcode < metrics.length() => {
      let matrix = match font.fonttype {
        PdfType3(data) => data.fontmatrix
        _ => transform_identity_matrix
      }
      let point = matrix.apply(point2(metrics[charcode], 0.0))
      (point.x, 0.0, 0.0)
    }
    _ => (0.0, 0.0, 0.0)
  }
}

///|
/// Return cpdfcontent's glyph-space width triple for one character code.
///
/// The tuple is `(width, pvx, pvy)`. Horizontal simple and standard fonts use
/// only `width`; vertical CID fonts may also return the vertical displacement
/// vector components from `/W2` or the default vertical metrics.
pub fn PdfFont::content_width_of_charcode(
  self : PdfFont,
  charcode : Int,
) -> (Double, Double, Double) {
  match self {
    PdfFontSimple(font) => pdf_content_simple_width_of_charcode(font, charcode)
    PdfFontStandard({ font, encoding }) =>
      (
        pdf_standard14_width_of_code(font.afm_data(), encoding, charcode).to_double(),
        0.0,
        0.0,
      )
    PdfFontCIDKeyed(font) => pdf_content_cid_width_of_charcode(font, charcode)
  }
}

///|
/// Compatibility wrapper for `PdfFont::content_width_of_charcode`.
pub fn pdf_content_width_of_charcode(
  font : PdfFont,
  charcode : Int,
) -> (Double, Double, Double) {
  font.content_width_of_charcode(charcode)
}
