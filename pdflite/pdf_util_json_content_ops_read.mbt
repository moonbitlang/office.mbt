///|
fn pdf_util_json_op_matrix(
  a : Json,
  b : Json,
  c : Json,
  d : Json,
  e : Json,
  f : Json,
) -> TransformMatrix raise PdfError {
  {
    a: pdf_util_json_op_float(a),
    b: pdf_util_json_op_float(b),
    c: pdf_util_json_op_float(c),
    d: pdf_util_json_op_float(d),
    e: pdf_util_json_op_float(e),
    f: pdf_util_json_op_float(f),
  }
}

///|
fn pdf_util_content_op_of_json(
  json : Json,
) -> @content.PdfContentOp raise PdfError {
  match json {
    Array(items) =>
      match items {
        [String("S")] => Op_S
        [String("s")] => Op_s
        [String("f")] => Op_f
        [String("F")] => Op_F
        [String("f*")] => Op_fstar
        [String("B")] => Op_B
        [String("B*")] => Op_Bstar
        [String("b")] => Op_b
        [String("b*")] => Op_bstar
        [String("n")] => Op_n
        [String("W")] => Op_W
        [String("W*")] => Op_Wstar
        [String("BT")] => Op_BT
        [String("ET")] => Op_ET
        [String("q")] => Op_q
        [String("Q")] => Op_Q
        [String("h")] => Op_h
        [String("T*")] => Op_Tstar
        [String("EMC")] => Op_EMC
        [String("BX")] => Op_BX
        [String("EX")] => Op_EX
        [a, b, c, d, String("re")] =>
          Op_re(
            pdf_util_json_op_float(a),
            pdf_util_json_op_float(b),
            pdf_util_json_op_float(c),
            pdf_util_json_op_float(d),
          )
        [c, m, y, k, String("k")] =>
          Op_k(
            pdf_util_json_op_float(c),
            pdf_util_json_op_float(m),
            pdf_util_json_op_float(y),
            pdf_util_json_op_float(k),
          )
        [a, b, String("m")] =>
          Op_m(pdf_util_json_op_float(a), pdf_util_json_op_float(b))
        [a, b, String("l")] =>
          Op_l(pdf_util_json_op_float(a), pdf_util_json_op_float(b))
        [tag, object, String("BDC")] =>
          Op_BDC(pdf_util_json_op_name(tag), pdf_object_of_json(object))
        [name, String("gs")] => Op_gs(pdf_util_json_op_name(name))
        [name, String("Do")] => Op_Do(pdf_util_json_op_name(name))
        [name, String("CS")] => Op_CS(pdf_util_json_op_name(name))
        [value, String("j")] => Op_j(pdf_util_json_op_int(value))
        [a, b, c, d, e, f, String("cm")] =>
          Op_cm(pdf_util_json_op_matrix(a, b, c, d, e, f))
        [dash, phase, String("d")] =>
          Op_d(
            pdf_util_json_op_float_array(dash),
            pdf_util_json_op_float(phase),
          )
        [value, String("w")] => Op_w(pdf_util_json_op_float(value))
        [value, String("J")] => Op_J(pdf_util_json_op_int(value))
        [value, String("M")] => Op_M(pdf_util_json_op_float(value))
        [name, String("ri")] => Op_ri(pdf_util_json_op_name(name))
        [value, String("i")] => Op_i(pdf_util_json_op_float(value))
        [a, b, c, d, e, f, String("c")] =>
          Op_c(
            pdf_util_json_op_float(a),
            pdf_util_json_op_float(b),
            pdf_util_json_op_float(c),
            pdf_util_json_op_float(d),
            pdf_util_json_op_float(e),
            pdf_util_json_op_float(f),
          )
        [a, b, c, d, String("v")] =>
          Op_v(
            pdf_util_json_op_float(a),
            pdf_util_json_op_float(b),
            pdf_util_json_op_float(c),
            pdf_util_json_op_float(d),
          )
        [a, b, c, d, String("y")] =>
          Op_y(
            pdf_util_json_op_float(a),
            pdf_util_json_op_float(b),
            pdf_util_json_op_float(c),
            pdf_util_json_op_float(d),
          )
        [value, String("Tc")] => Op_Tc(pdf_util_json_op_float(value))
        [value, String("Tw")] => Op_Tw(pdf_util_json_op_float(value))
        [value, String("Tz")] => Op_Tz(pdf_util_json_op_float(value))
        [value, String("TL")] => Op_TL(pdf_util_json_op_float(value))
        [name, size, String("Tf")] =>
          Op_Tf(pdf_util_json_op_name(name), pdf_util_json_op_float(size))
        [value, String("Tr")] => Op_Tr(pdf_util_json_op_int(value))
        [value, String("Ts")] => Op_Ts(pdf_util_json_op_float(value))
        [a, b, String("Td")] =>
          Op_Td(pdf_util_json_op_float(a), pdf_util_json_op_float(b))
        [a, b, String("TD")] =>
          Op_TD(pdf_util_json_op_float(a), pdf_util_json_op_float(b))
        [a, b, c, d, e, f, String("Tm")] =>
          Op_Tm(pdf_util_json_op_matrix(a, b, c, d, e, f))
        [text, String("Tj")] => Op_Tj(pdf_util_json_op_bytes(text))
        [object, String("TJ")] => Op_TJ(pdf_object_of_json(object))
        [text, String("'")] => Op_quote(pdf_util_json_op_bytes(text))
        [word_space, char_space, text, String("''")] =>
          Op_double_quote(
            pdf_util_json_op_float(word_space),
            pdf_util_json_op_float(char_space),
            pdf_util_json_op_bytes(text),
          )
        [width_x, width_y, String("d0")] =>
          Op_d0(
            pdf_util_json_op_float(width_x),
            pdf_util_json_op_float(width_y),
          )
        [width_x, width_y, llx, lly, urx, ury, String("d1")] =>
          Op_d1(
            pdf_util_json_op_float(width_x),
            pdf_util_json_op_float(width_y),
            pdf_util_json_op_float(llx),
            pdf_util_json_op_float(lly),
            pdf_util_json_op_float(urx),
            pdf_util_json_op_float(ury),
          )
        [name, String("cs")] => Op_cs(pdf_util_json_op_name(name))
        [value, String("G")] => Op_G(pdf_util_json_op_float(value))
        [value, String("g")] => Op_g(pdf_util_json_op_float(value))
        [r, g, b, String("RG")] =>
          Op_RG(
            pdf_util_json_op_float(r),
            pdf_util_json_op_float(g),
            pdf_util_json_op_float(b),
          )
        [r, g, b, String("rg")] =>
          Op_rg(
            pdf_util_json_op_float(r),
            pdf_util_json_op_float(g),
            pdf_util_json_op_float(b),
          )
        [c, m, y, k, String("K")] =>
          Op_K(
            pdf_util_json_op_float(c),
            pdf_util_json_op_float(m),
            pdf_util_json_op_float(y),
            pdf_util_json_op_float(k),
          )
        [name, String("sh")] => Op_sh(pdf_util_json_op_name(name))
        [tag, String("MP")] => Op_MP(pdf_util_json_op_name(tag))
        [tag, String("BMC")] => Op_BMC(pdf_util_json_op_name(tag))
        [operator, String("Unknown")] =>
          Op_Unknown(pdf_util_json_op_bytes(operator))
        [tag, object, String("DP")] =>
          Op_DP(pdf_util_json_op_name(tag), pdf_object_of_json(object))
        [dictionary, data, String("InlineImage")] =>
          Op_InlineImage(
            pdf_object_of_json(dictionary),
            None,
            pdf_util_json_op_bytes(data),
          )
        [.. values, String("SCN")] => Op_SCN(pdf_util_json_op_floats(values))
        [.. values, String("SC")] => Op_SC(pdf_util_json_op_floats(values))
        [.. values, String("sc")] => Op_sc(pdf_util_json_op_floats(values))
        [.. values, String("scn")] => Op_scn(pdf_util_json_op_floats(values))
        [.. values, name, String("SCNName")] =>
          Op_SCNName(
            pdf_util_json_op_name(name),
            pdf_util_json_op_floats(values),
          )
        [.. values, name, String("scnName")] =>
          Op_scnName(
            pdf_util_json_op_name(name),
            pdf_util_json_op_floats(values),
          )
        _ => raise BadText
      }
    _ => raise BadText
  }
}
