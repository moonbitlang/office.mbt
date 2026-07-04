///|
fn pdf_content_parse_resource_section(
  operands : ArrayView[PdfObject],
  operator : BytesView,
) -> PdfContentOp? {
  match operator {
    [115, 104] if operands.length() == 1 =>
      match pdf_content_operand_name(operands, 0) {
        Some(name) => Some(Op_sh(name))
        None => None
      }
    [68, 111] if operands.length() == 1 =>
      match pdf_content_operand_name(operands, 0) {
        Some(name) => Some(Op_Do(name))
        None => None
      }
    _ => None
  }
}
