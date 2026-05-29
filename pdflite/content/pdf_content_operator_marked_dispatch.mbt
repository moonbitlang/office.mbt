///|
fn pdf_content_parse_marked_section(
  operands : ArrayView[PdfObject],
  operator : BytesView,
) -> PdfContentOp? {
  match operator {
    [69, 77, 67] if operands.length() == 0 => Some(Op_EMC)
    [66, 88] if operands.length() == 0 => Some(Op_BX)
    [69, 88] if operands.length() == 0 => Some(Op_EX)
    [77, 80] if operands.length() == 1 =>
      match pdf_content_operand_name(operands, 0) {
        Some(tag) => Some(Op_MP(tag))
        None => None
      }
    [68, 80] if operands.length() == 2 =>
      match pdf_content_operand_name(operands, 0) {
        Some(tag) => Some(Op_DP(tag, operands[1]))
        None => None
      }
    [66, 77, 67] if operands.length() == 1 =>
      match pdf_content_operand_name(operands, 0) {
        Some(tag) => Some(Op_BMC(tag))
        None => None
      }
    [66, 68, 67] if operands.length() == 2 =>
      match pdf_content_operand_name(operands, 0) {
        Some(tag) => Some(Op_BDC(tag, operands[1]))
        None => None
      }
    _ => None
  }
}
