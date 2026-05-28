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
