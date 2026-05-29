///|
fn pdf_content_parse_path_section(
  operands : ArrayView[PdfObject],
  operator : BytesView,
) -> PdfContentOp? {
  match operator {
    [104] if operands.length() == 0 => Some(Op_h)
    [83] if operands.length() == 0 => Some(Op_S)
    [115] if operands.length() == 0 => Some(Op_s)
    [102] if operands.length() == 0 => Some(Op_f)
    [70] if operands.length() == 0 => Some(Op_F)
    [102, 42] if operands.length() == 0 => Some(Op_fstar)
    [66] if operands.length() == 0 => Some(Op_B)
    [66, 42] if operands.length() == 0 => Some(Op_Bstar)
    [98] if operands.length() == 0 => Some(Op_b)
    [98, 42] if operands.length() == 0 => Some(Op_bstar)
    [110] if operands.length() == 0 => Some(Op_n)
    [87] if operands.length() == 0 => Some(Op_W)
    [87, 42] if operands.length() == 0 => Some(Op_Wstar)
    [109] if operands.length() == 2 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
        ) {
        (Some(x), Some(y)) => Some(Op_m(x, y))
        _ => None
      }
    [108] if operands.length() == 2 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
        ) {
        (Some(x), Some(y)) => Some(Op_l(x, y))
        _ => None
      }
    [99] if operands.length() == 6 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_number(operands, 2),
          pdf_content_operand_number(operands, 3),
          pdf_content_operand_number(operands, 4),
          pdf_content_operand_number(operands, 5),
        ) {
        (Some(x1), Some(y1), Some(x2), Some(y2), Some(x3), Some(y3)) =>
          Some(Op_c(x1, y1, x2, y2, x3, y3))
        _ => None
      }
    [118] if operands.length() == 4 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_number(operands, 2),
          pdf_content_operand_number(operands, 3),
        ) {
        (Some(x2), Some(y2), Some(x3), Some(y3)) => Some(Op_v(x2, y2, x3, y3))
        _ => None
      }
    [121] if operands.length() == 4 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_number(operands, 2),
          pdf_content_operand_number(operands, 3),
        ) {
        (Some(x1), Some(y1), Some(x3), Some(y3)) => Some(Op_y(x1, y1, x3, y3))
        _ => None
      }
    [114, 101] if operands.length() == 4 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_number(operands, 2),
          pdf_content_operand_number(operands, 3),
        ) {
        (Some(x), Some(y), Some(width), Some(height)) =>
          Some(Op_re(x, y, width, height))
        _ => None
      }
    _ => None
  }
}
