///|
fn PdfDocument::pdf_util_json_of_content_op(
  self : PdfDocument,
  op : PdfContentOp,
  utf8 : Bool,
) -> Json raise PdfError {
  match op {
    Op_S => Json::array([Json::string("S")])
    Op_s => Json::array([Json::string("s")])
    Op_f => Json::array([Json::string("f")])
    Op_F => Json::array([Json::string("F")])
    Op_fstar => Json::array([Json::string("f*")])
    Op_B => Json::array([Json::string("B")])
    Op_Bstar => Json::array([Json::string("B*")])
    Op_b => Json::array([Json::string("b")])
    Op_bstar => Json::array([Json::string("b*")])
    Op_n => Json::array([Json::string("n")])
    Op_W => Json::array([Json::string("W")])
    Op_Wstar => Json::array([Json::string("W*")])
    Op_BT => Json::array([Json::string("BT")])
    Op_ET => Json::array([Json::string("ET")])
    Op_q => Json::array([Json::string("q")])
    Op_Q => Json::array([Json::string("Q")])
    Op_h => Json::array([Json::string("h")])
    Op_Tstar => Json::array([Json::string("T*")])
    Op_EMC => Json::array([Json::string("EMC")])
    Op_BX => Json::array([Json::string("BX")])
    Op_EX => Json::array([Json::string("EX")])
    Op_re(a, b, c, d) =>
      pdf_util_json_op_items(
        [
          pdf_util_json_float_object(a),
          pdf_util_json_float_object(b),
          pdf_util_json_float_object(c),
          pdf_util_json_float_object(d),
        ],
        "re",
      )
    Op_k(c, m, y, k) =>
      pdf_util_json_op_items(
        [
          pdf_util_json_float_object(c),
          pdf_util_json_float_object(m),
          pdf_util_json_float_object(y),
          pdf_util_json_float_object(k),
        ],
        "k",
      )
    Op_m(a, b) =>
      pdf_util_json_op_items(
        [pdf_util_json_float_object(a), pdf_util_json_float_object(b)],
        "m",
      )
    Op_l(a, b) =>
      pdf_util_json_op_items(
        [pdf_util_json_float_object(a), pdf_util_json_float_object(b)],
        "l",
      )
    Op_BDC(tag, object) =>
      pdf_util_json_op_items(
        [
          pdf_util_json_name_object(tag),
          self.pdf_util_json_of_object(object, utf8, false, false, false, false),
        ],
        "BDC",
      )
    Op_gs(name) =>
      pdf_util_json_op_items([pdf_util_json_name_object(name)], "gs")
    Op_Do(name) =>
      pdf_util_json_op_items([pdf_util_json_name_object(name)], "Do")
    Op_CS(name) =>
      pdf_util_json_op_items([pdf_util_json_name_object(name)], "CS")
    Op_j(value) =>
      pdf_util_json_op_items([pdf_util_json_int_object(value)], "j")
    Op_cm(matrix) =>
      pdf_util_json_op_items(
        [
          pdf_util_json_float_object(matrix.a),
          pdf_util_json_float_object(matrix.b),
          pdf_util_json_float_object(matrix.c),
          pdf_util_json_float_object(matrix.d),
          pdf_util_json_float_object(matrix.e),
          pdf_util_json_float_object(matrix.f),
        ],
        "cm",
      )
    Op_d(dash, phase) =>
      pdf_util_json_op_items(
        [
          Json::array(pdf_util_json_float_objects(dash)),
          pdf_util_json_float_object(phase),
        ],
        "d",
      )
    Op_w(value) =>
      pdf_util_json_op_items([pdf_util_json_float_object(value)], "w")
    Op_J(value) =>
      pdf_util_json_op_items([pdf_util_json_int_object(value)], "J")
    Op_M(value) =>
      pdf_util_json_op_items([pdf_util_json_float_object(value)], "M")
    Op_ri(name) =>
      pdf_util_json_op_items([pdf_util_json_name_object(name)], "ri")
    Op_i(value) =>
      pdf_util_json_op_items([pdf_util_json_float_object(value)], "i")
    Op_c(a, b, c, d, e, f) =>
      pdf_util_json_op_items(
        [
          pdf_util_json_float_object(a),
          pdf_util_json_float_object(b),
          pdf_util_json_float_object(c),
          pdf_util_json_float_object(d),
          pdf_util_json_float_object(e),
          pdf_util_json_float_object(f),
        ],
        "c",
      )
    Op_v(a, b, c, d) =>
      pdf_util_json_op_items(
        [
          pdf_util_json_float_object(a),
          pdf_util_json_float_object(b),
          pdf_util_json_float_object(c),
          pdf_util_json_float_object(d),
        ],
        "v",
      )
    Op_y(a, b, c, d) =>
      pdf_util_json_op_items(
        [
          pdf_util_json_float_object(a),
          pdf_util_json_float_object(b),
          pdf_util_json_float_object(c),
          pdf_util_json_float_object(d),
        ],
        "y",
      )
    Op_Tc(value) =>
      pdf_util_json_op_items([pdf_util_json_float_object(value)], "Tc")
    Op_Tw(value) =>
      pdf_util_json_op_items([pdf_util_json_float_object(value)], "Tw")
    Op_Tz(value) =>
      pdf_util_json_op_items([pdf_util_json_float_object(value)], "Tz")
    Op_TL(value) =>
      pdf_util_json_op_items([pdf_util_json_float_object(value)], "TL")
    Op_Tf(name, size) =>
      pdf_util_json_op_items(
        [pdf_util_json_name_object(name), pdf_util_json_float_object(size)],
        "Tf",
      )
    Op_Tr(value) =>
      pdf_util_json_op_items([pdf_util_json_int_object(value)], "Tr")
    Op_Ts(value) =>
      pdf_util_json_op_items([pdf_util_json_float_object(value)], "Ts")
    Op_Td(a, b) =>
      pdf_util_json_op_items(
        [pdf_util_json_float_object(a), pdf_util_json_float_object(b)],
        "Td",
      )
    Op_TD(a, b) =>
      pdf_util_json_op_items(
        [pdf_util_json_float_object(a), pdf_util_json_float_object(b)],
        "TD",
      )
    Op_Tm(matrix) =>
      pdf_util_json_op_items(
        [
          pdf_util_json_float_object(matrix.a),
          pdf_util_json_float_object(matrix.b),
          pdf_util_json_float_object(matrix.c),
          pdf_util_json_float_object(matrix.d),
          pdf_util_json_float_object(matrix.e),
          pdf_util_json_float_object(matrix.f),
        ],
        "Tm",
      )
    Op_Tj(text) => pdf_util_json_op_items([pdf_util_json_op_string(text)], "Tj")
    Op_TJ(object) =>
      pdf_util_json_op_items(
        [self.pdf_util_json_of_object(object, utf8, false, false, false, false)],
        "TJ",
      )
    Op_quote(text) =>
      pdf_util_json_op_items([pdf_util_json_op_string(text)], "'")
    Op_double_quote(word_space, char_space, text) =>
      pdf_util_json_op_items(
        [
          pdf_util_json_float_object(word_space),
          pdf_util_json_float_object(char_space),
          pdf_util_json_op_string(text),
        ],
        "''",
      )
    Op_d0(width_x, width_y) =>
      pdf_util_json_op_items(
        [
          pdf_util_json_float_object(width_x),
          pdf_util_json_float_object(width_y),
        ],
        "d0",
      )
    Op_d1(width_x, width_y, llx, lly, urx, ury) =>
      pdf_util_json_op_items(
        [
          pdf_util_json_float_object(width_x),
          pdf_util_json_float_object(width_y),
          pdf_util_json_float_object(llx),
          pdf_util_json_float_object(lly),
          pdf_util_json_float_object(urx),
          pdf_util_json_float_object(ury),
        ],
        "d1",
      )
    Op_cs(name) =>
      pdf_util_json_op_items([pdf_util_json_name_object(name)], "cs")
    Op_G(value) =>
      pdf_util_json_op_items([pdf_util_json_float_object(value)], "G")
    Op_g(value) =>
      pdf_util_json_op_items([pdf_util_json_float_object(value)], "g")
    Op_RG(r, g, b) =>
      pdf_util_json_op_items(
        [
          pdf_util_json_float_object(r),
          pdf_util_json_float_object(g),
          pdf_util_json_float_object(b),
        ],
        "RG",
      )
    Op_rg(r, g, b) =>
      pdf_util_json_op_items(
        [
          pdf_util_json_float_object(r),
          pdf_util_json_float_object(g),
          pdf_util_json_float_object(b),
        ],
        "rg",
      )
    Op_K(c, m, y, k) =>
      pdf_util_json_op_items(
        [
          pdf_util_json_float_object(c),
          pdf_util_json_float_object(m),
          pdf_util_json_float_object(y),
          pdf_util_json_float_object(k),
        ],
        "K",
      )
    Op_sh(name) =>
      pdf_util_json_op_items([pdf_util_json_name_object(name)], "sh")
    Op_MP(tag) => pdf_util_json_op_items([pdf_util_json_name_object(tag)], "MP")
    Op_BMC(tag) =>
      pdf_util_json_op_items([pdf_util_json_name_object(tag)], "BMC")
    Op_Unknown(bytes) =>
      pdf_util_json_op_items([pdf_util_json_op_string(bytes)], "Unknown")
    Op_DP(tag, object) =>
      pdf_util_json_op_items(
        [
          pdf_util_json_name_object(tag),
          self.pdf_util_json_of_object(object, utf8, false, false, false, false),
        ],
        "DP",
      )
    Op_InlineImage(dictionary, _, data) =>
      pdf_util_json_op_items(
        [
          self.pdf_util_json_of_object(
            dictionary, utf8, false, false, false, false,
          ),
          pdf_util_json_op_string(data),
        ],
        "InlineImage",
      )
    Op_SC(values) =>
      pdf_util_json_op_items(pdf_util_json_float_objects(values), "SC")
    Op_sc(values) =>
      pdf_util_json_op_items(pdf_util_json_float_objects(values), "sc")
    Op_SCN(values) =>
      pdf_util_json_op_items(pdf_util_json_float_objects(values), "SCN")
    Op_scn(values) =>
      pdf_util_json_op_items(pdf_util_json_float_objects(values), "scn")
    Op_SCNName(name, values) => {
      let items = pdf_util_json_float_objects(values)
      items.push(pdf_util_json_name_object(name))
      pdf_util_json_op_items(items, "SCNName")
    }
    Op_scnName(name, values) => {
      let items = pdf_util_json_float_objects(values)
      items.push(pdf_util_json_name_object(name))
      pdf_util_json_op_items(items, "scnName")
    }
  }
}
