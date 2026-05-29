///|
fn pdf_standard14_char_metric_width(
  widths : ArrayView[(Int, Int)],
  code : Int,
) -> Int {
  for entry in widths {
    let (candidate, width) = entry
    if candidate == code {
      break width
    }
  } nobreak {
    0
  }
}

///|
fn pdf_standard14_normalize_glyphname(name : BytesView) -> BytesView {
  if name.length() > 0 && name[0].to_int() == 0x2F {
    name[1:]
  } else {
    name
  }
}

///|
/// Return the AFM width for a glyph code in the font's built-in encoding.
pub fn pdf_standard14_width_of_charcode(data : PdfAfmData, code : Int) -> Int {
  pdf_standard14_char_metric_width(data.char_metrics, code)
}

///|
/// Return the AFM width for a glyph name.
///
/// `name` may be either slashless (`"A"`) or a PDF name payload with the
/// leading slash (`"/A"`).
pub fn pdf_standard14_width_of_glyphname(
  data : PdfAfmData,
  name : BytesView,
) -> Int {
  let requested = pdf_standard14_normalize_glyphname(name)
  for entry in data.char_name_widths {
    let (candidate, width) = entry
    if @afm.pdf_afm_view_equals(candidate, requested) {
      break width
    }
  } nobreak {
    0
  }
}

///|
/// Return the AFM kerning adjustment between two built-in character codes.
pub fn pdf_standard14_kern(data : PdfAfmData, left : Int, right : Int) -> Int {
  for entry in data.kerns {
    let (candidate_left, candidate_right, kern) = entry
    if candidate_left == left && candidate_right == right {
      break kern
    }
  } nobreak {
    0
  }
}
