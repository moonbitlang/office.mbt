///|
/// Parse a recognized PDF content operator from already parsed operands.
///
/// Unknown operators return `None` so callers can preserve their raw bytes.
pub fn pdf_content_parse_known_section(
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
                  match pdf_content_parse_resource_section(operands, operator) {
                    Some(op) => Some(op)
                    None => pdf_content_parse_marked_section(operands, operator)
                  }
              }
          }
      }
  }
}
