///|
fn pdf_addtext_rotation_adjustment_offsets(
  rotation : @addtext.PdfAddTextRotation,
  adjustment : Double,
) -> (Double, Double) {
  match rotation {
    PdfAddTextRot0 => (0.0, adjustment)
    PdfAddTextRot90 => (adjustment, 0.0)
    PdfAddTextRot180 => (0.0, -adjustment)
    PdfAddTextRot270 => (-adjustment, 0.0)
  }
}

///|
/// Return cpdf's `(horizontal, vertical)` baseline shift for midline/topline
/// add-text placement.
pub fn pdf_addtext_baseline_offsets(
  font : PdfFont?,
  font_size : Double,
  position : @geometry.PdfPosition,
  rotation : @addtext.PdfAddTextRotation,
  midline : Bool,
  topline : Bool,
) -> (Double, Double) {
  if midline {
    match font {
      Some(PdfFontStandard({ font, .. })) =>
        pdf_addtext_rotation_adjustment_offsets(
          rotation,
          font_size *
          pdf_standard14_baseline_adjustment(font).to_double() /
          1000.0,
        )
      Some(PdfFontSimple({ fontdescriptor: Some(descriptor), .. })) =>
        pdf_addtext_rotation_adjustment_offsets(
          rotation,
          font_size * descriptor.capheight / 2.0 / 1000.0,
        )
      _ => (0.0, 0.0)
    }
  } else if topline {
    match font {
      Some(PdfFontStandard({ font, .. })) => {
        let adjustment = font_size *
          pdf_standard14_baseline_adjustment(font).to_double() *
          2.0 /
          1000.0
        match position {
          PdfPositionDiagonal | PdfPositionReverseDiagonal => (0.0, adjustment)
          _ => pdf_addtext_rotation_adjustment_offsets(rotation, adjustment)
        }
      }
      Some(PdfFontSimple({ fontdescriptor: Some(descriptor), .. })) => {
        let adjustment = font_size * descriptor.capheight / 1000.0
        match position {
          PdfPositionDiagonal | PdfPositionReverseDiagonal => (0.0, adjustment)
          _ => pdf_addtext_rotation_adjustment_offsets(rotation, adjustment)
        }
      }
      _ => (0.0, 0.0)
    }
  } else {
    (0.0, 0.0)
  }
}
