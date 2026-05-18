///|
/// Text rotation values used by cpdf's add-text positioning helpers.
pub(all) enum PdfAddTextRotation {
  PdfAddTextRot0
  PdfAddTextRot90
  PdfAddTextRot180
  PdfAddTextRot270
} derive(Debug, Eq, ToJson)

///|
/// Text justification values used by cpdf's add-text positioning helpers.
pub(all) enum PdfAddTextJustification {
  PdfAddTextLeftJustify
  PdfAddTextCentreJustify
  PdfAddTextRightJustify
} derive(Debug, Eq, ToJson)

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
