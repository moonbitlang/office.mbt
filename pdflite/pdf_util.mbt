///|
fn PdfDocument::pdf_util_dict_entry_single_object(
  self : PdfDocument,
  object : PdfObject,
  transform : (PdfObject) -> PdfObject,
) -> PdfObject {
  match object {
    PdfDictionary(entries) => {
      let rewritten = pdf_recurse_dict(
        fn(child) { self.pdf_util_dict_entry_single_object(child, transform) },
        entries,
      )
      transform(rewritten)
    }
    PdfStreamObject(stream) =>
      match stream.dictionary {
        PdfDictionary(entries) => {
          stream.dictionary = pdf_recurse_dict(
            fn(child) {
              self.pdf_util_dict_entry_single_object(child, transform)
            },
            entries,
          )
          transform(PdfStreamObject(stream))
        }
        _ => object
      }
    PdfArray(values) =>
      pdf_recurse_array(
        fn(child) { self.pdf_util_dict_entry_single_object(child, transform) },
        values,
      )
    _ => object
  }
}

///|
fn PdfDocument::pdf_util_rewrite_dict_entries(
  self : PdfDocument,
  transform : (PdfObject) -> PdfObject,
) -> Unit {
  self.map_objects_in_place(fn(object) {
    self.pdf_util_dict_entry_single_object(object, transform)
  })
  self.trailer_dict = self.pdf_util_dict_entry_single_object(
    self.trailer_dict,
    transform,
  )
}

///|
fn pdf_util_string_from_utf8(bytes : BytesView) -> String raise PdfError {
  @utf8.decode(bytes) catch {
    _ => raise InvalidUTF8
  }
}

///|
fn pdf_util_string_from_bytes(bytes : BytesView) -> String raise PdfError {
  @utf8.decode(bytes) catch {
    _ =>
      @ascii.decode(pdf_write_hex_string(bytes)) catch {
        _ => raise InvalidUTF8
      }
  }
}

///|
fn pdf_util_string_from_name(name : PdfName) -> String raise PdfError {
  @ascii.decode(name.bytes()) catch {
    _ =>
      @ascii.decode(pdf_write_object(PdfNameObject(name))) catch {
        _ => raise InvalidUTF8
      }
  }
}

///|
fn pdf_util_json_number(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn pdf_util_json_integral_number(value : Double) -> Int raise PdfError {
  let integer = value.to_int()
  guard integer.to_double() == value else { raise NumberExpected }
  integer
}

///|
fn pdf_util_json_truncated_number(value : Double) -> Int {
  value.to_int()
}

///|
fn PdfDocument::pdf_util_json_of_object(
  self : PdfDocument,
  object : PdfObject,
  utf8 : Bool,
  clean_strings : Bool,
  no_stream_data : Bool,
  decompress_streams : Bool,
) -> Json raise PdfError {
  match object {
    PdfNull => Json::null()
    PdfBoolean(value) => Json::boolean(value)
    PdfInteger(value) =>
      Json::object(Map::of([("I", pdf_util_json_number(value))]))
    PdfReal(value) => Json::object(Map::of([("F", Json::number(value))]))
    PdfString(bytes) =>
      if utf8 {
        let utf8_bytes = pdf_utf8_of_pdfdocstring(bytes) catch {
          _ => return Json::string(pdf_util_string_from_bytes(bytes))
        }
        Json::object(
          Map::of([("U", Json::string(pdf_util_string_from_utf8(utf8_bytes)))]),
        )
      } else if clean_strings {
        let simplified = pdf_simplify_utf16be(bytes) catch { _ => bytes }
        Json::string(pdf_util_string_from_bytes(simplified))
      } else {
        Json::string(pdf_util_string_from_bytes(bytes))
      }
    PdfNameObject(name) =>
      Json::object(
        Map::of([("N", Json::string(pdf_util_string_from_name(name)))]),
      )
    PdfArray(values) => {
      let json_values : Array[Json] = []
      for value in values {
        json_values.push(
          self.pdf_util_json_of_object(
            value, utf8, clean_strings, no_stream_data, decompress_streams,
          ),
        )
      }
      Json::array(json_values)
    }
    PdfDictionary(entries) => {
      let json_entries : Map[String, Json] = Map([])
      for entry in entries {
        json_entries.set(
          pdf_util_string_from_name(entry.0),
          self.pdf_util_json_of_object(
            entry.1,
            utf8,
            clean_strings,
            no_stream_data,
            decompress_streams,
          ),
        )
      }
      Json::object(json_entries)
    }
    PdfStreamObject(stream) => {
      let output_stream = if decompress_streams {
        self.pdf_decode_stream_until_unknown_value_direct(stream)
      } else {
        stream
      }
      let stream_data_json = if no_stream_data {
        Json::string("<<stream data elided>>")
      } else {
        let stream_data = PdfStreamObject(output_stream).stream_bytes()
        Json::string(pdf_util_string_from_bytes(stream_data))
      }
      Json::object(
        Map::of([
          (
            "S",
            Json::array([
              self.pdf_util_json_of_object(
                output_stream.dictionary,
                utf8,
                clean_strings,
                no_stream_data,
                decompress_streams,
              ),
              stream_data_json,
            ]),
          ),
        ]),
      )
    }
    PdfIndirect(number) => pdf_util_json_number(number)
  }
}

///|
/// Convert a single PDF object to CPDFJSON format.
///
/// This exposes the single-object output side of cpdf's `cpdfjson`
/// conversion. `clean_strings` mirrors cpdf's deprecated
/// `-output-json-clean-strings` behavior for non-UTF8 output, and
/// `no_stream_data` emits cpdf's stream-data elision placeholder. Full
/// document CPDFJSON import/export and parsed content-stream encoding are
/// intentionally separate slices.
pub fn PdfDocument::json_of_object(
  self : PdfDocument,
  object : PdfObject,
  utf8? : Bool = false,
  clean_strings? : Bool = false,
  no_stream_data? : Bool = false,
) -> Json raise PdfError {
  self.pdf_util_json_of_object(
    object, utf8, clean_strings, no_stream_data, false,
  )
}

///|
fn pdf_util_pdf_string_from_json_text(text : String) -> PdfBytes {
  @utf8.encode(text)
}

///|
fn pdf_util_utf8_pdf_string_from_json_text(text : String) -> PdfBytes {
  pdf_pdfdocstring_of_utf8(@utf8.encode(text)) catch {
    _ => @utf8.encode(text)
  }
}

///|
fn pdf_util_name_from_json_text(text : String) -> PdfName {
  pdf_name_of_bytes(@utf8.encode(text))
}

///|
fn pdf_util_stream_of_json_data(
  dictionary_json : Json,
  data : String,
) -> PdfObject raise PdfError {
  let stream_data = pdf_util_pdf_string_from_json_text(data)
  let dictionary = pdf_object_of_json(dictionary_json).add_dict_entry(
    pdf_object_length_name(),
    PdfInteger(stream_data.length()),
  )
  pdf_stream(dictionary, StreamGot(stream_data))
}

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
      let output : Array[Double] = []
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
  let output : Array[Double] = []
  for value in values {
    output.push(pdf_util_json_op_float(value))
  }
  output
}

///|
fn pdf_util_json_float_object(value : Double) -> Json {
  Json::object(Map::of([("F", Json::number(value))]))
}

///|
fn pdf_util_json_int_object(value : Int) -> Json {
  Json::object(Map::of([("I", pdf_util_json_number(value))]))
}

///|
fn pdf_util_json_float_objects(values : ArrayView[Double]) -> Array[Json] {
  [
    for value in values => pdf_util_json_float_object(value)
  ]
}

///|
fn pdf_util_json_op_items(items : ArrayView[Json], operator : String) -> Json {
  let output : Array[Json] = []
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
          self.pdf_util_json_of_object(object, utf8, false, false, false),
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
        [self.pdf_util_json_of_object(object, utf8, false, false, false)],
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
          self.pdf_util_json_of_object(object, utf8, false, false, false),
        ],
        "DP",
      )
    Op_InlineImage(dictionary, _, data) =>
      pdf_util_json_op_items(
        [
          self.pdf_util_json_of_object(dictionary, utf8, false, false, false),
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
  let ops : Array[PdfContentOp] = []
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

///|
fn pdf_util_object_of_json_object(
  entries : Map[String, Json],
) -> PdfObject raise PdfError {
  if entries.length() == 1 {
    match entries.get("U") {
      Some(String(text)) =>
        return PdfString(pdf_util_utf8_pdf_string_from_json_text(text))
      _ => ()
    }
    match entries.get("I") {
      Some(Number(value, repr=_)) =>
        return PdfInteger(pdf_util_json_truncated_number(value))
      _ => ()
    }
    match entries.get("F") {
      Some(Number(value, repr=_)) => return PdfReal(value)
      _ => ()
    }
    match entries.get("N") {
      Some(String(name)) =>
        return PdfNameObject(pdf_util_name_from_json_text(name))
      _ => ()
    }
    match entries.get("S") {
      Some(Array([dictionary_json, String(data)])) =>
        return pdf_util_stream_of_json_data(dictionary_json, data)
      Some(Array([dictionary_json, Array(op_jsons)])) =>
        return pdf_util_stream_of_json_ops(dictionary_json, op_jsons)
      _ => ()
    }
  }
  let output : Array[(PdfName, PdfObject)] = []
  for entry in entries {
    output.push(
      (pdf_util_name_from_json_text(entry.0), pdf_object_of_json(entry.1)),
    )
  }
  PdfDictionary(output)
}

///|
/// Convert a single CPDFJSON object to a PDF object.
///
/// This ports the ordinary object side of cpdf's `object_of_json`: primitive
/// JSON values, CPDFJSON integer/real/name/string wrappers, dictionaries,
/// arrays, indirect references, streams with embedded string data, and streams
/// with parsed content-operation arrays are supported.
pub fn pdf_object_of_json(json : Json) -> PdfObject raise PdfError {
  match json {
    Null => PdfNull
    True => PdfBoolean(true)
    False => PdfBoolean(false)
    Number(value, repr=_) => PdfIndirect(pdf_util_json_integral_number(value))
    String(text) => PdfString(pdf_util_pdf_string_from_json_text(text))
    Array(values) => {
      let output : Array[PdfObject] = []
      for value in values {
        output.push(pdf_object_of_json(value))
      }
      PdfArray(output)
    }
    Object(entries) => pdf_util_object_of_json_object(entries)
  }
}

///|
let pdf_util_cpdfjson_stream_data_included_key_name : PdfName = pdf_util_name_from_json_text(
  "/CPDFJSONstreamdataincluded",
)

///|
fn pdf_util_cpdfjson_stream_data_included_key() -> PdfName {
  pdf_util_cpdfjson_stream_data_included_key_name
}

///|
let pdf_util_cpdfjson_major_version_key_name : PdfName = pdf_util_name_from_json_text(
  "/CPDFJSONmajorpdfversion",
)

///|
fn pdf_util_cpdfjson_major_version_key() -> PdfName {
  pdf_util_cpdfjson_major_version_key_name
}

///|
let pdf_util_cpdfjson_minor_version_key_name : PdfName = pdf_util_name_from_json_text(
  "/CPDFJSONminorpdfversion",
)

///|
fn pdf_util_cpdfjson_minor_version_key() -> PdfName {
  pdf_util_cpdfjson_minor_version_key_name
}

///|
let pdf_util_cpdfjson_root_key_name : PdfName = pdf_util_name_from_json_text(
  "/Root",
)

///|
fn pdf_util_cpdfjson_root_key() -> PdfName {
  pdf_util_cpdfjson_root_key_name
}

///|
let pdf_util_cpdfjson_contents_key_name : PdfName = pdf_util_name_from_json_text(
  "/Contents",
)

///|
fn pdf_util_cpdfjson_contents_key() -> PdfName {
  pdf_util_cpdfjson_contents_key_name
}

///|
let pdf_util_cpdfjson_subtype_key_name : PdfName = pdf_util_name_from_json_text(
  "/Subtype",
)

///|
fn pdf_util_cpdfjson_subtype_key() -> PdfName {
  pdf_util_cpdfjson_subtype_key_name
}

///|
let pdf_util_cpdfjson_form_name : PdfName = pdf_util_name_from_json_text(
  "/Form",
)

///|
fn pdf_util_cpdfjson_form() -> PdfName {
  pdf_util_cpdfjson_form_name
}

///|
let pdf_util_cpdfjson_type_key_name : PdfName = pdf_util_name_from_json_text(
  "/Type",
)

///|
fn pdf_util_cpdfjson_type_key() -> PdfName {
  pdf_util_cpdfjson_type_key_name
}

///|
let pdf_util_cpdfjson_pattern_name : PdfName = pdf_util_name_from_json_text(
  "/Pattern",
)

///|
fn pdf_util_cpdfjson_pattern() -> PdfName {
  pdf_util_cpdfjson_pattern_name
}

///|
let pdf_util_cpdfjson_filter_key_name : PdfName = pdf_util_name_from_json_text(
  "/Filter",
)

///|
fn pdf_util_cpdfjson_filter_key() -> PdfName {
  pdf_util_cpdfjson_filter_key_name
}

///|
fn pdf_util_cpdfjson_integer_field(
  object : PdfObject,
  key : PdfName,
) -> Int raise PdfError {
  match object.lookup_immediate(key) {
    Some(PdfInteger(value)) => value
    _ => raise BadText
  }
}

///|
fn pdf_util_cpdfjson_check_stream_data(
  params : PdfObject,
) -> Unit raise PdfError {
  match params.lookup_immediate(pdf_util_cpdfjson_stream_data_included_key()) {
    Some(PdfBoolean(false)) => raise BadText
    _ => ()
  }
}

///|
fn pdf_util_cpdfjson_root_number(trailer : PdfObject) -> Int raise PdfError {
  match trailer {
    PdfDictionary(_) =>
      match trailer.lookup_immediate(pdf_util_cpdfjson_root_key()) {
        Some(PdfIndirect(number)) => number
        _ => raise RootExpected
      }
    _ => raise RootExpected
  }
}

///|
fn pdf_util_cpdfjson_item_number(json : Json) -> Int raise PdfError {
  match json {
    Number(value, repr=_) => pdf_util_json_integral_number(value)
    _ => raise BadText
  }
}

///|
fn pdf_util_cpdfjson_read_item(
  json : Json,
  params : Ref[PdfObject],
  trailer : Ref[PdfObject],
  objects : Array[(Int, PdfObject)],
) -> Unit raise PdfError {
  match json {
    Array([number_json, object_json]) => {
      let number = pdf_util_cpdfjson_item_number(number_json)
      match number {
        -1 => params.val = pdf_object_of_json(object_json)
        0 => trailer.val = pdf_object_of_json(object_json)
        value if value < 0 => ()
        value => objects.push((value, pdf_object_of_json(object_json)))
      }
    }
    _ => raise BadText
  }
}

///|
/// Convert a CPDFJSON top-level array into an in-memory PDF document.
///
/// This ports cpdf's `pdf_of_json` document-input path. Object `-1` supplies
/// CPDFJSON parameters, object `0` supplies the trailer dictionary, positive
/// object numbers populate the document object table, and other negative
/// object numbers are ignored. `/CPDFJSONstreamdataincluded false` is rejected
/// because the stream bytes needed for reconstruction are not present.
pub fn pdf_document_of_json(json : Json) -> PdfDocument raise PdfError {
  let items = match json {
    Array(values) => values
    _ => raise BadText
  }
  let params : Ref[PdfObject] = { val: PdfNull }
  let trailer : Ref[PdfObject] = { val: PdfNull }
  let objects : Array[(Int, PdfObject)] = []
  for item in items {
    pdf_util_cpdfjson_read_item(item, params, trailer, objects)
  }
  pdf_util_cpdfjson_check_stream_data(params.val)
  let major = pdf_util_cpdfjson_integer_field(
    params.val,
    pdf_util_cpdfjson_major_version_key(),
  )
  let minor = pdf_util_cpdfjson_integer_field(
    params.val,
    pdf_util_cpdfjson_minor_version_key(),
  )
  let root = pdf_util_cpdfjson_root_number(trailer.val)
  let document = pdf_document_empty()
  document.set_version(major, minor)
  document.set_root(root)
  document.set_trailer_dict(trailer.val)
  for entry in objects {
    document.load_object_given_number(entry.0, entry.1)
  }
  document
}

///|
fn pdf_util_int_array_contains(values : ArrayView[Int], value : Int) -> Bool {
  for item in values {
    if item == value {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_util_push_unique_int(values : Array[Int], value : Int) -> Unit {
  if !pdf_util_int_array_contains(values, value) {
    values.push(value)
  }
}

///|
fn PdfDocument::pdf_util_mark_contents_value(
  self : PdfDocument,
  value : PdfObject,
  numbers : Array[Int],
) -> Unit {
  match value {
    PdfIndirect(number) =>
      match self.lookup_object_or_null(number) {
        PdfArray(values) =>
          for item in values {
            match item {
              PdfIndirect(item_number) =>
                pdf_util_push_unique_int(numbers, item_number)
              _ => ()
            }
          }
        _ => pdf_util_push_unique_int(numbers, number)
      }
    PdfArray(values) =>
      for item in values {
        match item {
          PdfIndirect(number) => pdf_util_push_unique_int(numbers, number)
          _ => ()
        }
      }
    _ => ()
  }
}

///|
fn PdfDocument::pdf_util_indirect_marks_content_stream(
  self : PdfDocument,
  number : Int,
) -> Bool {
  match self.lookup_object_or_null(number) {
    PdfStreamObject(stream) =>
      match
        self.lookup_direct(
          pdf_util_cpdfjson_subtype_key(),
          PdfStreamObject(stream),
        ) {
        Some(PdfNameObject(name)) if name == pdf_util_cpdfjson_form() => true
        _ =>
          match
            self.lookup_direct(
              pdf_util_cpdfjson_type_key(),
              PdfStreamObject(stream),
            ) {
            Some(PdfNameObject(name)) if name == pdf_util_cpdfjson_pattern() =>
              true
            _ => false
          }
      }
    _ => false
  }
}

///|
fn PdfDocument::pdf_util_collect_content_stream_numbers(
  self : PdfDocument,
  object : PdfObject,
  numbers : Array[Int],
) -> Unit {
  match object {
    PdfDictionary(entries) =>
      for entry in entries {
        if entry.0 == pdf_util_cpdfjson_contents_key() {
          self.pdf_util_mark_contents_value(entry.1, numbers)
        }
        self.pdf_util_collect_content_stream_numbers(entry.1, numbers)
      }
    PdfStreamObject(stream) =>
      self.pdf_util_collect_content_stream_numbers(stream.dictionary, numbers)
    PdfArray(values) =>
      for value in values {
        self.pdf_util_collect_content_stream_numbers(value, numbers)
      }
    PdfIndirect(number) =>
      if self.pdf_util_indirect_marks_content_stream(number) {
        pdf_util_push_unique_int(numbers, number)
      }
    _ => ()
  }
}

///|
fn PdfDocument::pdf_util_content_stream_numbers(
  self : PdfDocument,
) -> Array[Int] {
  let numbers : Array[Int] = []
  self.pdf_util_collect_content_stream_numbers(self.trailer_dict(), numbers)
  for number in self.object_numbers() {
    self.pdf_util_collect_content_stream_numbers(
      self.lookup_object_or_null(number),
      numbers,
    )
  }
  numbers
}

///|
fn PdfDocument::pdf_util_json_of_parsed_content_stream(
  self : PdfDocument,
  object : PdfObject,
  utf8 : Bool,
  clean_strings : Bool,
  no_stream_data : Bool,
) -> Json raise PdfError {
  match object {
    PdfStreamObject(stream) => {
      let decoded = self.pdf_decode_stream_until_unknown_value_direct(stream)
      let data = pdf_stream_data_bytes(decoded.data)
      let ops = pdf_parse_content_ops_from_bytes(data)
      let dictionary = decoded.dictionary
        .remove_dict_entry(pdf_object_length_name())
        .remove_dict_entry(pdf_util_cpdfjson_filter_key())
      let op_jsons : Array[Json] = []
      for op in ops {
        op_jsons.push(self.pdf_util_json_of_content_op(op, utf8))
      }
      Json::object(
        Map::of([
          (
            "S",
            Json::array([
              self.pdf_util_json_of_object(
                dictionary, utf8, clean_strings, no_stream_data, false,
              ),
              Json::array(op_jsons),
            ]),
          ),
        ]),
      )
    }
    _ => raise ParseStreamExpected
  }
}

///|
fn PdfDocument::pdf_util_precombine_page_content(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  let rewritten : Array[PdfPage] = []
  let mut changed = false
  for page in pages {
    if page.content.length() <= 1 {
      rewritten.push(page)
    } else {
      let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
      rewritten.push({ ..page, content: [pdf_content_stream_of_ops(ops)] })
      changed = true
    }
  }
  if changed {
    self.change_pages(rewritten, change_references=true)
  } else {
    self
  }
}

///|
fn PdfDocument::pdf_util_document_params_json(
  self : PdfDocument,
  utf8 : Bool,
  parse_content : Bool,
  no_stream_data : Bool,
) -> Json raise PdfError {
  let (major, minor) = self.version()
  self.pdf_util_json_of_object(
    PdfDictionary([
      (pdf_util_name_from_json_text("/CPDFJSONformatversion"), PdfInteger(3)),
      (
        pdf_util_name_from_json_text("/CPDFJSONcontentparsed"),
        PdfBoolean(parse_content),
      ),
      (
        pdf_util_cpdfjson_stream_data_included_key(),
        PdfBoolean(!no_stream_data),
      ),
      (pdf_util_cpdfjson_major_version_key(), PdfInteger(major)),
      (pdf_util_cpdfjson_minor_version_key(), PdfInteger(minor)),
    ]),
    utf8,
    false,
    false,
    false,
  )
}

///|
fn pdf_util_document_json_entry(number : Int, object : Json) -> Json {
  Json::array([pdf_util_json_number(number), object])
}

///|
fn PdfDocument::pdf_util_reachable_document_object_numbers(
  self : PdfDocument,
) -> Array[Int] {
  let referenced : @hashmap.HashMap[Int, Bool] = HashMap([])
  if self.trailer_dict().lookup_immediate(pdf_util_cpdfjson_root_key()) is None &&
    self.root() > 0 {
    referenced[self.root()] = true
    for
      number in self.referenced_object_numbers(
        self.lookup_object_or_null(self.root()),
      ) {
      referenced[number] = true
    }
  }
  for number in self.referenced_object_numbers(self.trailer_dict()) {
    referenced[number] = true
  }
  let numbers : Array[Int] = []
  for number in self.object_numbers() {
    if referenced.contains(number) {
      numbers.push(number)
    }
  }
  numbers
}

///|
/// Convert an in-memory document to CPDFJSON format with stream data included.
///
/// This ports the basic document-output shape from cpdf's `json_of_pdf`:
/// object `-1` carries CPDFJSON metadata, object `0` carries the trailer, and
/// positive object numbers reachable from the trailer or stored root are
/// emitted in ascending order. When `parse_content` is set, page `/Contents`
/// streams plus referenced Form XObject and Pattern streams are emitted as
/// cpdf-style operation arrays, after multi-stream pages are precombined on a
/// prepared copy of the document. When `clean_strings` is set for non-UTF8
/// output, UTF-16BE strings in positive objects are simplified while the
/// trailer dictionary is left unchanged to match cpdf's `/ID` precaution. When
/// `no_stream_data` is set, ordinary stream data is elided and CPDFJSON
/// metadata records that omission. When `decompress_streams` is set, positive
/// object streams are decoded through supported filters until the first
/// unknown filter.
pub fn PdfDocument::json_of_document(
  self : PdfDocument,
  utf8? : Bool = false,
  parse_content? : Bool = false,
  clean_strings? : Bool = false,
  no_stream_data? : Bool = false,
  decompress_streams? : Bool = false,
) -> Json raise PdfError {
  let document = if parse_content {
    self.pdf_util_precombine_page_content()
  } else {
    self
  }
  let entries : Array[Json] = []
  entries.push(
    pdf_util_document_json_entry(
      -1,
      document.pdf_util_document_params_json(
        utf8, parse_content, no_stream_data,
      ),
    ),
  )
  entries.push(
    pdf_util_document_json_entry(
      0,
      document.pdf_util_json_of_object(
        document.trailer_dict(),
        utf8,
        false,
        no_stream_data,
        false,
      ),
    ),
  )
  let content_stream_numbers = if parse_content {
    document.pdf_util_content_stream_numbers()
  } else {
    []
  }
  for number in document.pdf_util_reachable_document_object_numbers() {
    let object = document.lookup_object_or_null(number)
    let object_json = if pdf_util_int_array_contains(
        content_stream_numbers, number,
      ) {
      document.pdf_util_json_of_parsed_content_stream(
        object, utf8, clean_strings, no_stream_data,
      )
    } else {
      document.pdf_util_json_of_object(
        object, utf8, clean_strings, no_stream_data, decompress_streams,
      )
    }
    entries.push(pdf_util_document_json_entry(number, object_json))
  }
  Json::array(entries)
}

///|
fn PdfDocument::pdf_util_collect_dict_entry_values(
  self : PdfDocument,
  object : PdfObject,
  key : PdfName,
  output : Array[PdfObject],
) -> Unit {
  match object {
    PdfDictionary(entries) => {
      for entry in entries {
        self.pdf_util_collect_dict_entry_values(entry.1, key, output)
      }
      match self.lookup_direct(key, object) {
        Some(value) => output.push(value)
        None => ()
      }
    }
    PdfStreamObject(stream) => {
      match stream.dictionary {
        PdfDictionary(entries) =>
          for entry in entries {
            self.pdf_util_collect_dict_entry_values(entry.1, key, output)
          }
        _ => ()
      }
      match self.lookup_direct(key, object) {
        Some(value) => output.push(value)
        None => ()
      }
    }
    PdfArray(values) =>
      for value in values {
        self.pdf_util_collect_dict_entry_values(value, key, output)
      }
    _ => ()
  }
}

///|
fn PdfDocument::pdf_util_remove_entry_transform(
  self : PdfDocument,
  key : PdfName,
  search : PdfObject?,
) -> (PdfObject) -> PdfObject {
  fn(object) {
    match search {
      None => try! object.remove_dict_entry(key)
      Some(expected) =>
        match self.lookup_direct(key, object) {
          Some(value) if value == expected => try! object.remove_dict_entry(key)
          _ => object
        }
    }
  }
}

///|
fn PdfDocument::pdf_util_replace_entry_transform(
  self : PdfDocument,
  key : PdfName,
  value : PdfObject,
  search : PdfObject?,
) -> (PdfObject) -> PdfObject {
  fn(object) {
    match search {
      None => {
        let replaced : Result[PdfObject, Error] = try? object.replace_dict_entry(
          key, value,
        )
        match replaced {
          Ok(updated) => updated
          Err(_) => object
        }
      }
      Some(expected) =>
        match self.lookup_direct(key, object) {
          Some(found) if found == expected =>
            try! object.replace_dict_entry(key, value)
          _ => object
        }
    }
  }
}

///|
/// Remove dictionary entries named `key` throughout parsed objects and trailer.
///
/// When `search` is supplied, an entry is removed only when its resolved value
/// equals `search`. Nested dictionaries, arrays, and stream dictionaries are
/// traversed recursively; deferred document objects are left untouched.
pub fn PdfDocument::remove_dict_entry_everywhere(
  self : PdfDocument,
  key : PdfName,
  search? : PdfObject? = None,
) -> Unit {
  self.pdf_util_rewrite_dict_entries(
    self.pdf_util_remove_entry_transform(key, search),
  )
}

///|
/// Replace dictionary entries named `key` throughout parsed objects and trailer.
///
/// Missing keys are ignored. When `search` is supplied, only entries whose
/// resolved current value equals `search` are replaced.
pub fn PdfDocument::replace_dict_entry_everywhere(
  self : PdfDocument,
  key : PdfName,
  value : PdfObject,
  search? : PdfObject? = None,
) -> Unit {
  self.pdf_util_rewrite_dict_entries(
    self.pdf_util_replace_entry_transform(key, value, search),
  )
}

///|
/// Return resolved values for dictionary entries named `key`.
///
/// Traversal mirrors cpdf's dictionary-entry reporting helpers: direct nested
/// dictionaries, arrays, stream dictionaries, all parsed document objects, and
/// the trailer are scanned. The matching value itself is resolved through the
/// document object table.
pub fn PdfDocument::dict_entry_values(
  self : PdfDocument,
  key : PdfName,
) -> Array[PdfObject] {
  let output : Array[PdfObject] = []
  for number in self.object_numbers() {
    self.pdf_util_collect_dict_entry_values(
      self.lookup_object_or_null(number),
      key,
      output,
    )
  }
  self.pdf_util_collect_dict_entry_values(self.trailer_dict, key, output)
  output
}

///|
/// Render dictionary entry values as PDF object syntax.
///
/// This is the side-effect-free native equivalent of cpdf's `print_dict_entry`.
pub fn PdfDocument::dict_entry_rendered_values(
  self : PdfDocument,
  key : PdfName,
) -> Array[PdfBytes] raise PdfError {
  let rendered : Array[PdfBytes] = []
  for value in self.dict_entry_values(key) {
    rendered.push(pdf_write_object(value))
  }
  rendered
}

///|
/// Return dictionary entry values in cpdf-style JSON format.
pub fn PdfDocument::dict_entries_json(
  self : PdfDocument,
  key : PdfName,
  utf8? : Bool = false,
) -> PdfBytes raise PdfError {
  let values : Array[Json] = []
  for value in self.dict_entry_values(key) {
    values.push(self.pdf_util_json_of_object(value, utf8, false, false, false))
  }
  @utf8.encode(Json::array(values).stringify())
}

///|
/// Compatibility wrapper for `PdfDocument::dict_entry_values`.
pub fn pdf_dict_entry_values(
  document : PdfDocument,
  key : PdfName,
) -> Array[PdfObject] {
  document.dict_entry_values(key)
}

///|
/// Compatibility wrapper for `PdfDocument::dict_entry_rendered_values`.
pub fn pdf_print_dict_entry(
  document : PdfDocument,
  key : PdfName,
) -> Array[PdfBytes] raise PdfError {
  document.dict_entry_rendered_values(key)
}

///|
/// Compatibility wrapper for `PdfDocument::dict_entries_json`.
pub fn pdf_get_dict_entries(
  document : PdfDocument,
  key : PdfName,
  utf8? : Bool = false,
) -> PdfBytes raise PdfError {
  document.dict_entries_json(key, utf8~)
}

///|
/// Compatibility wrapper for `PdfDocument::json_of_object`.
pub fn pdf_json_of_object(
  document : PdfDocument,
  object : PdfObject,
  utf8? : Bool = false,
  clean_strings? : Bool = false,
  no_stream_data? : Bool = false,
) -> Json raise PdfError {
  document.json_of_object(object, utf8~, clean_strings~, no_stream_data~)
}

///|
/// Compatibility wrapper for `PdfDocument::json_of_document`.
pub fn pdf_json_of_document(
  document : PdfDocument,
  utf8? : Bool = false,
  parse_content? : Bool = false,
  clean_strings? : Bool = false,
  no_stream_data? : Bool = false,
  decompress_streams? : Bool = false,
) -> Json raise PdfError {
  document.json_of_document(
    utf8~,
    parse_content~,
    clean_strings~,
    no_stream_data~,
    decompress_streams~,
  )
}

///|
/// Compatibility wrapper for `PdfDocument::remove_dict_entry_everywhere`.
pub fn pdf_remove_dict_entry(
  document : PdfDocument,
  key : PdfName,
  search? : PdfObject? = None,
) -> Unit {
  document.remove_dict_entry_everywhere(key, search~)
}

///|
/// Compatibility wrapper for `PdfDocument::replace_dict_entry_everywhere`.
pub fn pdf_replace_dict_entry(
  document : PdfDocument,
  key : PdfName,
  value : PdfObject,
  search? : PdfObject? = None,
) -> Unit {
  document.replace_dict_entry_everywhere(key, value, search~)
}

///|
fn pdf_injectible_char(char : Char) -> Bool {
  char == '&' || char == '|' || char == '\n' || char == '`' || char == '$'
}

///|
/// Check that a path-like string is safe to pass through shell-style contexts.
///
/// This ports cpdf's injectible-character guard, but reports a checked
/// `PdfError::InsecurePathName` instead of terminating the process.
pub fn pdf_check_injectible(text : String) -> Unit raise PdfError {
  for char in text.iter() {
    if pdf_injectible_char(char) {
      raise InsecurePathName(text)
    }
  }
}
