///|
fn pdf_content_parse_known_section(
  operands : ArrayView[PdfObject],
  operator : BytesView,
) -> PdfContentOp? raise PdfError {
  match pdf_content_parse_path_section(operands, operator) {
    Some(op) => Some(op)
    None =>
      match pdf_content_parse_text_section(operands, operator) {
        Some(op) => Some(op)
        None =>
          match pdf_content_parse_color_section(operands, operator) {
            Some(op) => Some(op)
            None =>
              match pdf_content_parse_graphics_section(operands, operator) {
                Some(op) => Some(op)
                None =>
                  match operator {
                    [69, 77, 67] if operands.length() == 0 => Some(Op_EMC)
                    [66, 88] if operands.length() == 0 => Some(Op_BX)
                    [69, 88] if operands.length() == 0 => Some(Op_EX)
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
          }
      }
  }
}
