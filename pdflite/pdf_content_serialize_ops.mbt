///|
fn pdf_content_op_section(
  op : @content.PdfContentOp,
) -> (Array[PdfObject], PdfBytes) {
  match op {
    Op_w(width) => ([pdf_content_number_object(width)], pdf_content_ascii("w"))
    Op_J(cap) => ([PdfInteger(cap)], pdf_content_ascii("J"))
    Op_j(join) => ([PdfInteger(join)], pdf_content_ascii("j"))
    Op_M(limit) => ([pdf_content_number_object(limit)], pdf_content_ascii("M"))
    Op_d(dashes, phase) =>
      (
        [pdf_content_number_array(dashes), pdf_content_number_object(phase)],
        pdf_content_ascii("d"),
      )
    Op_ri(intent) => ([PdfNameObject(intent)], pdf_content_ascii("ri"))
    Op_i(flatness) =>
      ([pdf_content_number_object(flatness)], pdf_content_ascii("i"))
    Op_q => ([], pdf_content_ascii("q"))
    Op_Q => ([], pdf_content_ascii("Q"))
    Op_cm(matrix) =>
      (pdf_content_matrix_operands(matrix), pdf_content_ascii("cm"))
    Op_m(x, y) =>
      (
        [pdf_content_number_object(x), pdf_content_number_object(y)],
        pdf_content_ascii("m"),
      )
    Op_l(x, y) =>
      (
        [pdf_content_number_object(x), pdf_content_number_object(y)],
        pdf_content_ascii("l"),
      )
    Op_c(x1, y1, x2, y2, x3, y3) =>
      (
        [
          pdf_content_number_object(x1),
          pdf_content_number_object(y1),
          pdf_content_number_object(x2),
          pdf_content_number_object(y2),
          pdf_content_number_object(x3),
          pdf_content_number_object(y3),
        ],
        pdf_content_ascii("c"),
      )
    Op_v(x2, y2, x3, y3) =>
      (
        [
          pdf_content_number_object(x2),
          pdf_content_number_object(y2),
          pdf_content_number_object(x3),
          pdf_content_number_object(y3),
        ],
        pdf_content_ascii("v"),
      )
    Op_y(x1, y1, x3, y3) =>
      (
        [
          pdf_content_number_object(x1),
          pdf_content_number_object(y1),
          pdf_content_number_object(x3),
          pdf_content_number_object(y3),
        ],
        pdf_content_ascii("y"),
      )
    Op_h => ([], pdf_content_ascii("h"))
    Op_re(x, y, width, height) =>
      (
        [
          pdf_content_number_object(x),
          pdf_content_number_object(y),
          pdf_content_number_object(width),
          pdf_content_number_object(height),
        ],
        pdf_content_ascii("re"),
      )
    Op_S => ([], pdf_content_ascii("S"))
    Op_s => ([], pdf_content_ascii("s"))
    Op_f => ([], pdf_content_ascii("f"))
    Op_F => ([], pdf_content_ascii("F"))
    Op_fstar => ([], pdf_content_ascii("f*"))
    Op_B => ([], pdf_content_ascii("B"))
    Op_Bstar => ([], pdf_content_ascii("B*"))
    Op_b => ([], pdf_content_ascii("b"))
    Op_bstar => ([], pdf_content_ascii("b*"))
    Op_n => ([], pdf_content_ascii("n"))
    Op_W => ([], pdf_content_ascii("W"))
    Op_Wstar => ([], pdf_content_ascii("W*"))
    Op_BT => ([], pdf_content_ascii("BT"))
    Op_ET => ([], pdf_content_ascii("ET"))
    Op_Tc(spacing) =>
      ([pdf_content_number_object(spacing)], pdf_content_ascii("Tc"))
    Op_Tw(spacing) =>
      ([pdf_content_number_object(spacing)], pdf_content_ascii("Tw"))
    Op_Tz(scale) =>
      ([pdf_content_number_object(scale)], pdf_content_ascii("Tz"))
    Op_TL(leading) =>
      ([pdf_content_number_object(leading)], pdf_content_ascii("TL"))
    Op_Tf(font, size) =>
      (
        [PdfNameObject(font), pdf_content_number_object(size)],
        pdf_content_ascii("Tf"),
      )
    Op_Tr(mode) => ([PdfInteger(mode)], pdf_content_ascii("Tr"))
    Op_Ts(rise) => ([pdf_content_number_object(rise)], pdf_content_ascii("Ts"))
    Op_Td(tx, ty) =>
      (
        [pdf_content_number_object(tx), pdf_content_number_object(ty)],
        pdf_content_ascii("Td"),
      )
    Op_TD(tx, ty) =>
      (
        [pdf_content_number_object(tx), pdf_content_number_object(ty)],
        pdf_content_ascii("TD"),
      )
    Op_Tm(matrix) =>
      (pdf_content_matrix_operands(matrix), pdf_content_ascii("Tm"))
    Op_Tstar => ([], pdf_content_ascii("T*"))
    Op_Tj(text) => ([PdfString(text)], pdf_content_ascii("Tj"))
    Op_TJ(array) => ([array], pdf_content_ascii("TJ"))
    Op_quote(text) => ([PdfString(text)], pdf_content_ascii("'"))
    Op_double_quote(word_space, char_space, text) =>
      (
        [
          pdf_content_number_object(word_space),
          pdf_content_number_object(char_space),
          PdfString(text),
        ],
        pdf_content_ascii("\""),
      )
    Op_d0(width_x, width_y) =>
      (
        [pdf_content_number_object(width_x), pdf_content_number_object(width_y)],
        pdf_content_ascii("d0"),
      )
    Op_d1(width_x, width_y, llx, lly, urx, ury) =>
      (
        [
          pdf_content_number_object(width_x),
          pdf_content_number_object(width_y),
          pdf_content_number_object(llx),
          pdf_content_number_object(lly),
          pdf_content_number_object(urx),
          pdf_content_number_object(ury),
        ],
        pdf_content_ascii("d1"),
      )
    Op_G(gray) => ([pdf_content_number_object(gray)], pdf_content_ascii("G"))
    Op_g(gray) => ([pdf_content_number_object(gray)], pdf_content_ascii("g"))
    Op_RG(r, g, b) =>
      (
        [
          pdf_content_number_object(r),
          pdf_content_number_object(g),
          pdf_content_number_object(b),
        ],
        pdf_content_ascii("RG"),
      )
    Op_rg(r, g, b) =>
      (
        [
          pdf_content_number_object(r),
          pdf_content_number_object(g),
          pdf_content_number_object(b),
        ],
        pdf_content_ascii("rg"),
      )
    Op_K(c, m, y, k) =>
      (
        [
          pdf_content_number_object(c),
          pdf_content_number_object(m),
          pdf_content_number_object(y),
          pdf_content_number_object(k),
        ],
        pdf_content_ascii("K"),
      )
    Op_k(c, m, y, k) =>
      (
        [
          pdf_content_number_object(c),
          pdf_content_number_object(m),
          pdf_content_number_object(y),
          pdf_content_number_object(k),
        ],
        pdf_content_ascii("k"),
      )
    Op_gs(name) => ([PdfNameObject(name)], pdf_content_ascii("gs"))
    Op_CS(name) => ([PdfNameObject(name)], pdf_content_ascii("CS"))
    Op_cs(name) => ([PdfNameObject(name)], pdf_content_ascii("cs"))
    Op_SC(values) =>
      (pdf_content_number_operands(values), pdf_content_ascii("SC"))
    Op_sc(values) =>
      (pdf_content_number_operands(values), pdf_content_ascii("sc"))
    Op_SCN(values) =>
      (pdf_content_number_operands(values), pdf_content_ascii("SCN"))
    Op_scn(values) =>
      (pdf_content_number_operands(values), pdf_content_ascii("scn"))
    Op_SCNName(name, values) =>
      (
        [..pdf_content_number_operands(values), PdfNameObject(name)],
        pdf_content_ascii("SCN"),
      )
    Op_scnName(name, values) =>
      (
        [..pdf_content_number_operands(values), PdfNameObject(name)],
        pdf_content_ascii("scn"),
      )
    Op_sh(name) => ([PdfNameObject(name)], pdf_content_ascii("sh"))
    Op_Do(name) => ([PdfNameObject(name)], pdf_content_ascii("Do"))
    Op_InlineImage(_, _, _) => ([], pdf_content_ascii(""))
    Op_MP(tag) => ([PdfNameObject(tag)], pdf_content_ascii("MP"))
    Op_DP(tag, properties) =>
      ([PdfNameObject(tag), properties], pdf_content_ascii("DP"))
    Op_BMC(tag) => ([PdfNameObject(tag)], pdf_content_ascii("BMC"))
    Op_BDC(tag, properties) =>
      ([PdfNameObject(tag), properties], pdf_content_ascii("BDC"))
    Op_EMC => ([], pdf_content_ascii("EMC"))
    Op_BX => ([], pdf_content_ascii("BX"))
    Op_EX => ([], pdf_content_ascii("EX"))
    Op_Unknown(bytes) => ([], bytes)
  }
}
