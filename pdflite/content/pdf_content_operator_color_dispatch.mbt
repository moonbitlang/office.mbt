///|
fn pdf_content_parse_color_section(
  operands : ArrayView[PdfObject],
  operator : BytesView,
) -> PdfContentOp? {
  match operator {
    [71] if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(gray) => Some(Op_G(gray))
        None => None
      }
    [103] if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(gray) => Some(Op_g(gray))
        None => None
      }
    [82, 71] if operands.length() == 3 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_number(operands, 2),
        ) {
        (Some(r), Some(g), Some(b)) => Some(Op_RG(r, g, b))
        _ => None
      }
    [114, 103] if operands.length() == 3 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_number(operands, 2),
        ) {
        (Some(r), Some(g), Some(b)) => Some(Op_rg(r, g, b))
        _ => None
      }
    [75] if operands.length() == 4 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_number(operands, 2),
          pdf_content_operand_number(operands, 3),
        ) {
        (Some(c), Some(m), Some(y), Some(k)) => Some(Op_K(c, m, y, k))
        _ => None
      }
    [107] if operands.length() == 4 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_number(operands, 2),
          pdf_content_operand_number(operands, 3),
        ) {
        (Some(c), Some(m), Some(y), Some(k)) => Some(Op_k(c, m, y, k))
        _ => None
      }
    [67, 83] if operands.length() == 1 =>
      match pdf_content_operand_name(operands, 0) {
        Some(name) => Some(Op_CS(name))
        None => None
      }
    [99, 115] if operands.length() == 1 =>
      match pdf_content_operand_name(operands, 0) {
        Some(name) => Some(Op_cs(name))
        None => None
      }
    [83, 67] =>
      Some(Op_SC(pdf_content_numbers_or_malformed_color_fallback(operands)))
    [115, 99] =>
      Some(Op_sc(pdf_content_numbers_or_malformed_color_fallback(operands)))
    [83, 67, 78] =>
      match pdf_content_named_color_operands_or_malformed_fallback(operands) {
        Some((name, values)) => Some(Op_SCNName(name, values))
        None =>
          Some(
            Op_SCN(pdf_content_numbers_or_malformed_color_fallback(operands)),
          )
      }
    [115, 99, 110] =>
      match pdf_content_named_color_operands_or_malformed_fallback(operands) {
        Some((name, values)) => Some(Op_scnName(name, values))
        None =>
          Some(
            Op_scn(pdf_content_numbers_or_malformed_color_fallback(operands)),
          )
      }
    _ => None
  }
}
