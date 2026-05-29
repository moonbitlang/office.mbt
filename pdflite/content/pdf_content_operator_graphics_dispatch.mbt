///|
fn pdf_content_parse_graphics_section(
  operands : ArrayView[PdfObject],
  operator : BytesView,
) -> PdfContentOp? raise PdfError {
  match operator {
    [113] if operands.length() == 0 => Some(Op_q)
    [81] if operands.length() == 0 => Some(Op_Q)
    [119] if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(width) => Some(Op_w(width))
        None => None
      }
    [74] if operands.length() == 1 =>
      match pdf_content_operand_int(operands, 0) {
        Some(cap) => Some(Op_J(cap))
        None => None
      }
    [106] if operands.length() == 1 =>
      match pdf_content_operand_int(operands, 0) {
        Some(join) => Some(Op_j(join))
        None => None
      }
    [77] if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(limit) => Some(Op_M(limit))
        None => None
      }
    [100] => pdf_content_dash_op_from_operands(operands)
    [114, 105] if operands.length() == 1 =>
      match pdf_content_operand_name(operands, 0) {
        Some(intent) => Some(Op_ri(intent))
        None => None
      }
    [105] if operands.length() == 1 =>
      match pdf_content_operand_number(operands, 0) {
        Some(flatness) => Some(Op_i(flatness))
        None => None
      }
    [99, 109] if operands.length() == 6 =>
      match pdf_content_matrix_from_operands(operands) {
        Some(matrix) => Some(Op_cm(matrix))
        None => None
      }
    [103, 115] if operands.length() == 1 =>
      match pdf_content_operand_name(operands, 0) {
        Some(name) => Some(Op_gs(name))
        None => None
      }
    _ => None
  }
}
