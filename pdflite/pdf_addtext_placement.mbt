///|
fn pdf_addtext_vertical_justification(
  rotation : PdfAddTextRotation,
  justification : PdfAddTextJustification,
) -> PdfAddTextJustification {
  match justification {
    PdfAddTextCentreJustify => PdfAddTextCentreJustify
    PdfAddTextLeftJustify =>
      if rotation == PdfAddTextRot270 {
        PdfAddTextRightJustify
      } else {
        PdfAddTextLeftJustify
      }
    PdfAddTextRightJustify =>
      if rotation == PdfAddTextRot270 {
        PdfAddTextLeftJustify
      } else {
        PdfAddTextRightJustify
      }
  }
}

///|
fn pdf_addtext_horizontal_justification(
  rotation : PdfAddTextRotation,
  justification : PdfAddTextJustification,
) -> PdfAddTextJustification {
  match justification {
    PdfAddTextCentreJustify => PdfAddTextCentreJustify
    PdfAddTextLeftJustify =>
      if rotation == PdfAddTextRot180 {
        PdfAddTextRightJustify
      } else {
        PdfAddTextLeftJustify
      }
    PdfAddTextRightJustify =>
      if rotation == PdfAddTextRot180 {
        PdfAddTextLeftJustify
      } else {
        PdfAddTextRightJustify
      }
  }
}

///|
fn pdf_addtext_vertical_justification_offset(
  delta : Double,
  position : PdfPosition,
  justification : PdfAddTextJustification,
) -> Double {
  match justification {
    PdfAddTextLeftJustify =>
      match position {
        PdfPositionTopLeft(_, _)
        | PdfPositionTopRight(_, _)
        | PdfPositionTop(_)
        | PdfPositionDiagonal
        | PdfPositionReverseDiagonal => 0.0
        PdfPositionLeft(_)
        | PdfPositionPosLeft(_, _)
        | PdfPositionPosCentre(_, _)
        | PdfPositionCentre
        | PdfPositionPosRight(_, _)
        | PdfPositionRight(_) => delta / 2.0
        PdfPositionBottomLeft(_, _)
        | PdfPositionBottom(_)
        | PdfPositionBottomRight(_, _) => delta
      }
    PdfAddTextRightJustify =>
      match position {
        PdfPositionTopLeft(_, _)
        | PdfPositionTopRight(_, _)
        | PdfPositionTop(_) => -delta
        PdfPositionLeft(_)
        | PdfPositionPosLeft(_, _)
        | PdfPositionPosCentre(_, _)
        | PdfPositionCentre
        | PdfPositionPosRight(_, _)
        | PdfPositionRight(_) => -(delta / 2.0)
        PdfPositionBottomLeft(_, _)
        | PdfPositionBottom(_)
        | PdfPositionBottomRight(_, _)
        | PdfPositionDiagonal
        | PdfPositionReverseDiagonal => 0.0
      }
    PdfAddTextCentreJustify =>
      match position {
        PdfPositionTopLeft(_, _)
        | PdfPositionTopRight(_, _)
        | PdfPositionTop(_) => -(delta / 2.0)
        PdfPositionLeft(_)
        | PdfPositionPosLeft(_, _)
        | PdfPositionPosCentre(_, _)
        | PdfPositionCentre
        | PdfPositionPosRight(_, _)
        | PdfPositionRight(_)
        | PdfPositionDiagonal
        | PdfPositionReverseDiagonal => 0.0
        PdfPositionBottomLeft(_, _)
        | PdfPositionBottom(_)
        | PdfPositionBottomRight(_, _) => delta / 2.0
      }
  }
}

///|
fn pdf_addtext_horizontal_justification_offset(
  delta : Double,
  position : PdfPosition,
  justification : PdfAddTextJustification,
) -> Double {
  match justification {
    PdfAddTextLeftJustify =>
      match position {
        PdfPositionTopLeft(_, _)
        | PdfPositionLeft(_)
        | PdfPositionPosLeft(_, _)
        | PdfPositionBottomLeft(_, _)
        | PdfPositionDiagonal
        | PdfPositionReverseDiagonal => 0.0
        PdfPositionTop(_)
        | PdfPositionPosCentre(_, _)
        | PdfPositionBottom(_)
        | PdfPositionCentre => delta / 2.0
        PdfPositionTopRight(_, _)
        | PdfPositionBottomRight(_, _)
        | PdfPositionPosRight(_, _)
        | PdfPositionRight(_) => delta
      }
    PdfAddTextRightJustify =>
      match position {
        PdfPositionTopLeft(_, _)
        | PdfPositionLeft(_)
        | PdfPositionPosLeft(_, _)
        | PdfPositionBottomLeft(_, _) => -delta
        PdfPositionTop(_)
        | PdfPositionPosCentre(_, _)
        | PdfPositionBottom(_)
        | PdfPositionCentre => -(delta / 2.0)
        PdfPositionTopRight(_, _)
        | PdfPositionBottomRight(_, _)
        | PdfPositionPosRight(_, _)
        | PdfPositionRight(_)
        | PdfPositionDiagonal
        | PdfPositionReverseDiagonal => 0.0
      }
    PdfAddTextCentreJustify =>
      match position {
        PdfPositionTopLeft(_, _)
        | PdfPositionLeft(_)
        | PdfPositionPosLeft(_, _)
        | PdfPositionBottomLeft(_, _) => -(delta / 2.0)
        PdfPositionTop(_)
        | PdfPositionPosCentre(_, _)
        | PdfPositionBottom(_)
        | PdfPositionCentre
        | PdfPositionDiagonal
        | PdfPositionReverseDiagonal => 0.0
        PdfPositionTopRight(_, _)
        | PdfPositionBottomRight(_, _)
        | PdfPositionPosRight(_, _)
        | PdfPositionRight(_) => delta / 2.0
      }
  }
}

///|
/// Return cpdf's add-text justification offset for the current line.
///
/// `longest_width` is the maximum rendered width among the expanded text lines,
/// and `width` is the current line width.
pub fn pdf_addtext_justification_offset(
  rotation : PdfAddTextRotation,
  longest_width : Double,
  width : Double,
  position : PdfPosition,
  justification : PdfAddTextJustification,
) -> Double {
  let delta = longest_width - width
  match rotation {
    PdfAddTextRot90 | PdfAddTextRot270 =>
      pdf_addtext_vertical_justification_offset(
        delta,
        position,
        pdf_addtext_vertical_justification(rotation, justification),
      )
    PdfAddTextRot0 | PdfAddTextRot180 =>
      pdf_addtext_horizontal_justification_offset(
        delta,
        position,
        pdf_addtext_horizontal_justification(rotation, justification),
      )
  }
}

///|
/// Apply cpdf's scalar justification offset to `(horizontal, vertical)`.
pub fn pdf_addtext_apply_justification_offset(
  rotation : PdfAddTextRotation,
  horizontal_offset : Double,
  vertical_offset : Double,
  justification_offset : Double,
) -> (Double, Double) {
  match rotation {
    PdfAddTextRot90 | PdfAddTextRot270 =>
      (horizontal_offset, vertical_offset - justification_offset)
    PdfAddTextRot0 | PdfAddTextRot180 =>
      (horizontal_offset + justification_offset, vertical_offset)
  }
}

///|
/// Resolve cpdf add-text placement values for one line.
///
/// This combines cpdf's `calculate_position`, diagonal offset correction,
/// justification offset application, explicit text rotation, and
/// rotation-origin offset selection.
pub fn pdf_addtext_line_placement(
  bounds : PdfRectangle,
  position : PdfPosition,
  rotation : PdfAddTextRotation,
  text_width : Double,
  longest_width : Double,
  horizontal_offset : Double,
  vertical_offset : Double,
  justification : PdfAddTextJustification,
) -> PdfAddTextLinePlacement {
  let placed = pdf_calculate_position(false, text_width, bounds, position)
  let justification_offset = pdf_addtext_justification_offset(
    rotation, longest_width, text_width, position, justification,
  )
  let (diagonal_h_offset, diagonal_v_offset) = pdf_addtext_diagonal_offsets(
    bounds,
    position,
    rotation,
    text_width,
    horizontal_offset,
    vertical_offset,
    placed.rotation,
  )
  let (final_h_offset, final_v_offset) = pdf_addtext_apply_justification_offset(
    rotation, diagonal_h_offset, diagonal_v_offset, justification_offset,
  )
  let (rotation_h_offset, rotation_v_offset) = pdf_addtext_rotation_offsets(
    position, rotation, text_width,
  )
  {
    origin: point2(placed.x, placed.y),
    base_rotation: placed.rotation,
    text_rotation: pdf_addtext_rotation_radians(rotation),
    rotation_offset: point2(rotation_h_offset, rotation_v_offset),
    horizontal_offset: final_h_offset,
    vertical_offset: final_v_offset,
    justification_offset,
  }
}
