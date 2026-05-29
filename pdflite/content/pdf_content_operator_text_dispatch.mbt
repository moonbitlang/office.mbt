///|
fn pdf_content_parse_text_section(
  operands : ArrayView[PdfObject],
  operator : BytesView,
) -> PdfContentOp? {
  match operator {
    [66, 84] if operands.length() == 0 => Some(Op_BT)
    [69, 84] if operands.length() == 0 => Some(Op_ET)
    [84, 42] if operands.length() == 0 => Some(Op_Tstar)
    [84, 109] if operands.length() == 6 =>
      match pdf_content_matrix_from_operands(operands) {
        Some(matrix) => Some(Op_Tm(matrix))
        None => None
      }
    [84, 99] if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(spacing) => Some(Op_Tc(spacing))
        None => None
      }
    [84, 119] if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(spacing) => Some(Op_Tw(spacing))
        None => None
      }
    [84, 122] if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(scale) => Some(Op_Tz(scale))
        None => None
      }
    [84, 76] if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(leading) => Some(Op_TL(leading))
        None => None
      }
    [84, 102] if operands.length() == 2 =>
      match
        (
          pdf_content_operand_name(operands, 0),
          pdf_content_operand_number(operands, 1),
        ) {
        (Some(font), Some(size)) => Some(Op_Tf(font, size))
        _ => None
      }
    [84, 114] if operands.length() == 1 =>
      match pdf_content_operand_int(operands, 0) {
        Some(mode) => Some(Op_Tr(mode))
        None => None
      }
    [84, 115] if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(rise) => Some(Op_Ts(rise))
        None => None
      }
    [84, 100] if operands.length() == 2 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
        ) {
        (Some(tx), Some(ty)) => Some(Op_Td(tx, ty))
        _ => None
      }
    [84, 68] if operands.length() == 2 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
        ) {
        (Some(tx), Some(ty)) => Some(Op_TD(tx, ty))
        _ => None
      }
    [84, 106] if operands.length() == 1 =>
      match pdf_content_operand_string(operands, 0) {
        Some(text) => Some(Op_Tj(text))
        None => None
      }
    [84, 74] if operands.length() == 1 =>
      match pdf_content_tj_array_from_operand(operands[0]) {
        Some(array) => Some(Op_TJ(array))
        None => None
      }
    [39] if operands.length() == 1 =>
      match pdf_content_operand_string(operands, 0) {
        Some(text) => Some(Op_quote(text))
        None => None
      }
    [34] if operands.length() == 3 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_string(operands, 2),
        ) {
        (Some(word_space), Some(char_space), Some(text)) =>
          Some(Op_double_quote(word_space, char_space, text))
        _ => None
      }
    [100, 48] if operands.length() == 2 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
        ) {
        (Some(width_x), Some(width_y)) => Some(Op_d0(width_x, width_y))
        _ => None
      }
    [100, 49] if operands.length() == 6 =>
      match
        (
          pdf_content_operand_number(operands, 0),
          pdf_content_operand_number(operands, 1),
          pdf_content_operand_number(operands, 2),
          pdf_content_operand_number(operands, 3),
          pdf_content_operand_number(operands, 4),
          pdf_content_operand_number(operands, 5),
        ) {
        (
          Some(width_x),
          Some(width_y),
          Some(llx),
          Some(lly),
          Some(urx),
          Some(ury),
        ) => Some(Op_d1(width_x, width_y, llx, lly, urx, ury))
        _ => None
      }
    _ => None
  }
}
