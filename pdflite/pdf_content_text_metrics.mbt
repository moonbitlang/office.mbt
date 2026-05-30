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
fn pdf_content_afm_header_value(
  data : @afm.PdfAfmData,
  key : String,
) -> BytesView? {
  let key_bytes = @ascii.encode(key)
  for entry in data.headers {
    if @afm.pdf_afm_view_equals(entry.0, key_bytes) {
      break Some(entry.1)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_content_afm_parse_int(value : BytesView) -> Int? {
  let parsed : Result[Int, Error] = try? @afm.pdf_afm_parse_int(value)
  match parsed {
    Ok(number) => Some(number)
    Err(_) => None
  }
}

///|
fn pdf_content_afm_header_number(
  data : @afm.PdfAfmData,
  key : String,
) -> Double {
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
  data : @afm.PdfAfmData,
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
      let top = data.fontmatrix.apply(
        @geometry.point2(0.0, data.fontbbox.max_y),
      )
      let bottom = data.fontmatrix.apply(
        @geometry.point2(0.0, data.fontbbox.min_y),
      )
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
