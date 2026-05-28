///|
fn pdf_util_json_op_float(json : Json) -> Double raise PdfError {
  match json {
    Object(entries) =>
      if entries.length() == 1 {
        match entries.get("F") {
          Some(Number(value, repr=_)) => value
          _ => raise NumberExpected
        }
      } else {
        raise NumberExpected
      }
    _ => raise NumberExpected
  }
}

///|
fn pdf_util_json_op_int(json : Json) -> Int raise PdfError {
  match json {
    Object(entries) =>
      if entries.length() == 1 {
        match entries.get("I") {
          Some(Number(value, repr=_)) => pdf_util_json_truncated_number(value)
          _ => raise NumberExpected
        }
      } else {
        raise NumberExpected
      }
    _ => raise NumberExpected
  }
}

///|
fn pdf_util_json_op_name(json : Json) -> PdfName raise PdfError {
  match json {
    String(name) => pdf_util_name_from_json_text(name)
    _ => raise BadText
  }
}

///|
fn pdf_util_json_op_bytes(json : Json) -> PdfBytes raise PdfError {
  match json {
    String(text) => pdf_util_pdf_string_from_json_text(text)
    _ => raise BadText
  }
}

///|
fn pdf_util_json_op_float_array(json : Json) -> Array[Double] raise PdfError {
  match json {
    Array(values) => {
      let output : Array[Double] = Array::new(capacity=values.length())
      for value in values {
        output.push(pdf_util_json_op_float(value))
      }
      output
    }
    _ => raise BadText
  }
}

///|
fn pdf_util_json_op_floats(
  values : ArrayView[Json],
) -> Array[Double] raise PdfError {
  let output : Array[Double] = Array::new(capacity=values.length())
  for value in values {
    output.push(pdf_util_json_op_float(value))
  }
  output
}

///|
fn pdf_util_json_float_object(value : Double) -> Json {
  Json::object(Map([("F", Json::number(value))]))
}

///|
fn pdf_util_json_int_object(value : Int) -> Json {
  Json::object(Map([("I", pdf_util_json_number(value))]))
}

///|
fn pdf_util_json_float_objects(values : ArrayView[Double]) -> Array[Json] {
  let output : Array[Json] = Array::new(capacity=values.length())
  for value in values {
    output.push(pdf_util_json_float_object(value))
  }
  output
}

///|
fn pdf_util_json_op_items(items : ArrayView[Json], operator : String) -> Json {
  let output : Array[Json] = Array::new(capacity=items.length() + 1)
  for item in items {
    output.push(item)
  }
  output.push(Json::string(operator))
  Json::array(output)
}

///|
fn pdf_util_json_name_object(name : PdfName) -> Json raise PdfError {
  Json::string(pdf_util_string_from_name(name))
}

///|
fn pdf_util_json_op_string(bytes : PdfBytes) -> Json raise PdfError {
  Json::string(pdf_util_string_from_bytes(bytes))
}

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
fn pdf_util_content_op_of_json(json : Json) -> PdfContentOp raise PdfError {
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

///|
fn pdf_util_stream_of_json_ops(
  dictionary_json : Json,
  op_jsons : ArrayView[Json],
) -> PdfObject raise PdfError {
  let ops : Array[PdfContentOp] = Array::new(capacity=op_jsons.length())
  for op_json in op_jsons {
    ops.push(pdf_util_content_op_of_json(op_json))
  }
  let stream_data = pdf_content_bytes_of_ops(ops)
  let dictionary = pdf_object_of_json(dictionary_json).add_dict_entry(
    pdf_object_length_name(),
    PdfInteger(stream_data.length()),
  )
  pdf_stream(dictionary, StreamGot(stream_data))
}
