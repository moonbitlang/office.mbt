///|
fn pdf_content_parse_known_section(
  operands : ArrayView[PdfObject],
  operator : BytesView,
) -> PdfContentOp? raise PdfError {
  match pdf_content_parse_path_section(operands, operator) {
    Some(op) => Some(op)
    None =>
      match operator {
        [113] if operands.length() == 0 => Some(Op_q)
        [81] if operands.length() == 0 => Some(Op_Q)
        [66, 84] if operands.length() == 0 => Some(Op_BT)
        [69, 84] if operands.length() == 0 => Some(Op_ET)
        [84, 42] if operands.length() == 0 => Some(Op_Tstar)
        [69, 77, 67] if operands.length() == 0 => Some(Op_EMC)
        [66, 88] if operands.length() == 0 => Some(Op_BX)
        [69, 88] if operands.length() == 0 => Some(Op_EX)
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
        [103, 115] if operands.length() == 1 =>
          match pdf_content_operand_name(operands, 0) {
            Some(name) => Some(Op_gs(name))
            None => None
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
          match
            pdf_content_named_color_operands_or_malformed_fallback(operands) {
            Some((name, values)) => Some(Op_SCNName(name, values))
            None =>
              Some(
                Op_SCN(
                  pdf_content_numbers_or_malformed_color_fallback(operands),
                ),
              )
          }
        [115, 99, 110] =>
          match
            pdf_content_named_color_operands_or_malformed_fallback(operands) {
            Some((name, values)) => Some(Op_scnName(name, values))
            None =>
              Some(
                Op_scn(
                  pdf_content_numbers_or_malformed_color_fallback(operands),
                ),
              )
          }
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
