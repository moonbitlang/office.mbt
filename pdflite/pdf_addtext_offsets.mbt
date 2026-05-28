///|
fn pdf_addtext_degrees_to_radians(degrees : Double) -> Double {
  degrees * @math.PI / 180.0
}

///|
/// Convert cpdf add-text's explicit rotation enum to content rotation radians.
pub fn pdf_addtext_rotation_radians(rotation : PdfAddTextRotation) -> Double {
  match rotation {
    PdfAddTextRot0 => 0.0
    PdfAddTextRot90 => pdf_addtext_degrees_to_radians(270.0)
    PdfAddTextRot180 => pdf_addtext_degrees_to_radians(180.0)
    PdfAddTextRot270 => pdf_addtext_degrees_to_radians(90.0)
  }
}

///|
/// Return cpdf's rotation-dependent text origin offset.
pub fn pdf_addtext_rotation_offsets(
  position : PdfPosition,
  rotation : PdfAddTextRotation,
  text_width : Double,
) -> (Double, Double) {
  match position {
    PdfPositionTopLeft(_, _) =>
      match rotation {
        PdfAddTextRot0 | PdfAddTextRot90 => (0.0, 0.0)
        PdfAddTextRot180 => (text_width, 0.0)
        PdfAddTextRot270 => (0.0, -text_width)
      }
    PdfPositionTop(_) =>
      match rotation {
        PdfAddTextRot0 => (0.0, 0.0)
        PdfAddTextRot90 => (text_width / 2.0, 0.0)
        PdfAddTextRot180 => (text_width, 0.0)
        PdfAddTextRot270 => (text_width / 2.0, -text_width)
      }
    PdfPositionTopRight(_, _) =>
      match rotation {
        PdfAddTextRot0 => (0.0, 0.0)
        PdfAddTextRot90 | PdfAddTextRot180 => (text_width, 0.0)
        PdfAddTextRot270 => (text_width, -text_width)
      }
    PdfPositionRight(_) | PdfPositionPosRight(_, _) =>
      match rotation {
        PdfAddTextRot0 => (0.0, 0.0)
        PdfAddTextRot90 => (text_width, text_width / 2.0)
        PdfAddTextRot180 => (text_width, 0.0)
        PdfAddTextRot270 => (text_width, -text_width / 2.0)
      }
    PdfPositionBottomRight(_, _) =>
      match rotation {
        PdfAddTextRot0 => (0.0, 0.0)
        PdfAddTextRot90 => (text_width, text_width)
        PdfAddTextRot180 => (text_width, 0.0)
        PdfAddTextRot270 => (text_width, 0.0)
      }
    PdfPositionBottom(_) =>
      match rotation {
        PdfAddTextRot0 => (0.0, 0.0)
        PdfAddTextRot90 => (text_width / 2.0, text_width)
        PdfAddTextRot180 => (text_width, 0.0)
        PdfAddTextRot270 => (text_width / 2.0, 0.0)
      }
    PdfPositionBottomLeft(_, _) =>
      match rotation {
        PdfAddTextRot0 => (0.0, 0.0)
        PdfAddTextRot90 => (0.0, text_width)
        PdfAddTextRot180 => (text_width, 0.0)
        PdfAddTextRot270 => (0.0, 0.0)
      }
    PdfPositionLeft(_) | PdfPositionPosLeft(_, _) =>
      match rotation {
        PdfAddTextRot0 => (0.0, 0.0)
        PdfAddTextRot90 => (0.0, text_width / 2.0)
        PdfAddTextRot180 => (text_width, 0.0)
        PdfAddTextRot270 => (0.0, -text_width / 2.0)
      }
    PdfPositionCentre | PdfPositionPosCentre(_, _) =>
      match rotation {
        PdfAddTextRot0 => (0.0, 0.0)
        PdfAddTextRot90 => (text_width / 2.0, text_width / 2.0)
        PdfAddTextRot180 => (text_width, 0.0)
        PdfAddTextRot270 => (text_width / 2.0, -(text_width / 2.0))
      }
    PdfPositionDiagonal | PdfPositionReverseDiagonal => (0.0, 0.0)
  }
}

///|
/// Adjust cpdf add-text offsets for diagonal and reverse-diagonal placement.
pub fn pdf_addtext_diagonal_offsets(
  bounds : PdfRectangle,
  position : PdfPosition,
  rotation : PdfAddTextRotation,
  text_width : Double,
  horizontal_offset : Double,
  vertical_offset : Double,
  base_rotation : Double,
) -> (Double, Double) {
  match position {
    PdfPositionDiagonal | PdfPositionReverseDiagonal => {
      let rotate = if rotation == PdfAddTextRot180 {
        base_rotation + @math.PI
      } else {
        base_rotation
      }
      let horizontal = -(@math.cos(@math.PI / 2.0 - rotate) * vertical_offset)
      let vertical = @math.sin(@math.PI / 2.0 - rotate) * vertical_offset
      if rotation == PdfAddTextRot180 {
        let angle = @math.atan(
          (bounds.max_y - bounds.min_y) / (bounds.max_x - bounds.min_x),
        )
        let dx = @math.cos(angle) * text_width
        let dy = @math.sin(angle) * text_width
        match position {
          PdfPositionDiagonal => (horizontal - dx, vertical - dy)
          PdfPositionReverseDiagonal => (horizontal - dx, vertical + dy)
          _ => (horizontal, vertical)
        }
      } else {
        (horizontal, vertical)
      }
    }
    _ => (horizontal_offset, vertical_offset)
  }
}

///|
/// Return cpdf's initial `(horizontal, vertical)` offset for a multi-line
/// add-text paragraph.
pub fn pdf_addtext_initial_line_offsets(
  position : PdfPosition,
  line_count : Int,
  line_spacing : Double,
  font_size : Double,
) -> (Double, Double) {
  let line_delta = (line_count - 1).to_double()
  let paragraph_height = line_spacing * font_size * line_delta
  let vertical = match position {
    PdfPositionBottomLeft(_, _)
    | PdfPositionBottom(_)
    | PdfPositionBottomRight(_, _) => -paragraph_height
    PdfPositionLeft(_) | PdfPositionRight(_) => -(paragraph_height / 2.0)
    PdfPositionDiagonal | PdfPositionReverseDiagonal =>
      -(paragraph_height / 2.0)
    _ => 0.0
  }
  (0.0, vertical)
}

///|
/// Return cpdf's per-line `(horizontal, vertical)` advance for add-text.
pub fn pdf_addtext_line_advance(
  rotation : PdfAddTextRotation,
  line_spacing : Double,
  font_size : Double,
) -> (Double, Double) {
  let advance = line_spacing * font_size
  match rotation {
    PdfAddTextRot90 | PdfAddTextRot270 => (advance, 0.0)
    PdfAddTextRot0 | PdfAddTextRot180 => (0.0, advance)
  }
}

///|
fn pdf_addtext_rotation_adjustment_offsets(
  rotation : PdfAddTextRotation,
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
  position : PdfPosition,
  rotation : PdfAddTextRotation,
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
