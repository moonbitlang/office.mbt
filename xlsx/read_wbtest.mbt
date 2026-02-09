///|
fn is_invalid_xml_error(
  result : Result[Font, XlsxError],
  expected_msg : String,
) -> Bool {
  match result {
    Err(XlsxError::InvalidXml(msg~)) => msg == expected_msg
    _ => false
  }
}

///|
fn is_invalid_xml_fill_error(
  result : Result[Fill, XlsxError],
  expected_msg : String,
) -> Bool {
  match result {
    Err(XlsxError::InvalidXml(msg~)) => msg == expected_msg
    _ => false
  }
}

///|
test "read wb: xml encoding parser guard paths" {
  inspect(xml_encoding(b"abc") is None, content="true")
  inspect(xml_encoding(b"<?xml version=\"1.0\"?><x/>") is None, content="true")
  inspect(
    xml_encoding(b"<?xml version=\"1.0\" encoding=\"\"?><x/>") is None,
    content="true",
  )

  let with_bom_single_quote = b"\xEF\xBB\xBF<?xml version='1.0' encoding='UTF-16'?><x/>"
  inspect(
    match xml_encoding(with_bom_single_quote) {
      Some(value) => value == "UTF-16"
      None => false
    },
    content="true",
  )

  inspect(
    xml_encoding(b"<?xml version=\"1.0\" encoding=\"UT@8\"?><x/>") is None,
    content="true",
  )
  inspect(
    xml_encoding(b"<?xml version=\"1.0\" encoding=\"UTF-8?><x/>") is None,
    content="true",
  )
}

///|
test "read wb: decode_utf8 invalid paths" {
  let requires_transcoder = try? decode_utf8(
    b"<?xml version=\"1.0\" encoding=\"UTF-16\"?><x/>",
    None,
  )
  inspect(
    match requires_transcoder {
      Err(XlsxError::InvalidXml(msg~)) =>
        msg.contains("requires charset transcoder")
      _ => false
    },
    content="true",
  )

  let invalid_utf8 = try? decode_utf8(b"\xFF\xFE\xFF", None)
  inspect(
    match invalid_utf8 {
      Err(XlsxError::InvalidXml(msg~)) => msg == "invalid utf8"
      _ => false
    },
    content="true",
  )
}

///|
test "read wb: parse_default_font fallback matrix" {
  inspect(parse_default_font("<styleSheet/>"), content="Calibri")
  inspect(parse_default_font("<fonts></fonts>"), content="Calibri")
  inspect(parse_default_font("<fonts><name"), content="Calibri")
  inspect(
    parse_default_font("<fonts><name val='Calibri\"></name></fonts>"),
    content="Calibri",
  )
  inspect(
    parse_default_font("<fonts><name val=\"Aptos\"/></fonts>"),
    content="Aptos",
  )
}

///|
test "read wb: parse_font_entry attributes and invalid numerics" {
  let font = parse_font_entry(
    (
      #|<font>
      #|  <b val="1"/><i val="1"/><strike val="1"/><outline val="1"/>
      #|  <shadow val="1"/><condense val="1"/><extend val="1"/>
      #|  <u val="double"/><sz val="11"/><charset val="1"/>
      #|  <name val="Aptos"/><family val="3"/><vertAlign val="superscript"/>
      #|  <scheme val="minor"/><color rgb="ABCDEF12" theme="1" indexed="2" tint="0.5"/>
      #|</font>
      #|,
    ),
  )
  inspect(font.bold is Some(true), content="true")
  inspect(font.italic is Some(true), content="true")
  inspect(font.strike is Some(true), content="true")
  inspect(font.outline is Some(true), content="true")
  inspect(font.shadow is Some(true), content="true")
  inspect(font.condense is Some(true), content="true")
  inspect(font.extend is Some(true), content="true")
  inspect(font.underline, content="Some(\"double\")")
  inspect(font.size, content="Some(11)")
  inspect(font.charset, content="Some(1)")
  inspect(font.family, content="Some(\"Aptos\")")
  inspect(font.family_number, content="Some(3)")
  inspect(font.vert_align, content="Some(\"superscript\")")
  inspect(font.scheme, content="Some(\"minor\")")
  inspect(font.color, content="Some(\"ABCDEF12\")")
  inspect(font.color_theme, content="Some(1)")
  inspect(font.color_indexed, content="Some(2)")
  inspect(font.color_tint, content="Some(0.5)")

  inspect(
    is_invalid_xml_error(
      try? parse_font_entry("<font><sz val=\"bad\"/></font>"),
      "font sz invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_error(
      try? parse_font_entry("<font><charset val=\"x\"/></font>"),
      "font charset invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_error(
      try? parse_font_entry("<font><family val=\"x\"/></font>"),
      "font family invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_error(
      try? parse_font_entry("<font><color theme=\"x\"/></font>"),
      "font color theme invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_error(
      try? parse_font_entry("<font><color indexed=\"x\"/></font>"),
      "font color indexed invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_error(
      try? parse_font_entry("<font><color tint=\"x\"/></font>"),
      "font color tint invalid",
    ),
    content="true",
  )
}

///|
test "read wb: parse_fonts fallback and malformed font chunks" {
  let no_fonts = parse_fonts("<styleSheet/>")
  inspect(no_fonts.length(), content="1")

  let empty_fonts = parse_fonts("<fonts></fonts>")
  inspect(empty_fonts.length(), content="1")

  let missing_open_end = parse_fonts("<fonts><font</fonts>")
  inspect(missing_open_end.length(), content="1")

  let missing_close_tag = parse_fonts("<fonts><font><b/></fonts>")
  inspect(missing_close_tag.length(), content="1")
}

///|
test "read wb: parse_font_entry implicit default and none-attr branches" {
  let font = parse_font_entry(
    (
      #|<font>
      #|  <i/><outline/><condense/><extend/><u/>
      #|  <sz/><charset/><name/><family/><vertAlign/><scheme/>
      #|</font>
      #|,
    ),
  )
  inspect(font.italic is Some(true), content="true")
  inspect(font.outline is Some(true), content="true")
  inspect(font.condense is Some(true), content="true")
  inspect(font.extend is Some(true), content="true")
  inspect(font.underline, content="Some(\"single\")")
  inspect(font.size, content="None")
  inspect(font.charset, content="None")
  inspect(font.family, content="None")
  inspect(font.family_number, content="None")
  inspect(font.vert_align, content="None")
  inspect(font.scheme, content="None")
}

///|
test "read wb: parse_fill_entry gradient and pattern guard branches" {
  inspect(
    is_invalid_xml_fill_error(
      try? parse_fill_entry("<gradientFill bottom=\"bad\"></gradientFill>"),
      "gradientFill bottom invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      try? parse_fill_entry("<gradientFill degree=\"bad\"></gradientFill>"),
      "gradientFill degree invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      try? parse_fill_entry("<gradientFill left=\"bad\"></gradientFill>"),
      "gradientFill left invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      try? parse_fill_entry("<gradientFill right=\"bad\"></gradientFill>"),
      "gradientFill right invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      try? parse_fill_entry("<gradientFill top=\"bad\"></gradientFill>"),
      "gradientFill top invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      try? parse_fill_entry(
        "<gradientFill><stop position=\"bad\"><color rgb=\"FF112233\"/></stop></gradientFill>",
      ),
      "gradientFill stop position invalid",
    ),
    content="true",
  )

  let gradient = parse_fill_entry(
    (
      #|<gradientFill type="path" bottom="0.1" degree="20" left="0.2" right="0.3" top="0.4">
      #|  <stop position="0"><color rgb="112233"/></stop>
      #|  <stop position="1"><color rgb="80112233"/></stop>
      #|</gradientFill>
      #|,
    ),
  )
  inspect(gradient.typ, content="Some(\"gradient\")")
  inspect(gradient.shading is Some(_), content="true")
  inspect(gradient.colors is Some(_), content="true")
  inspect(gradient.transparency is Some(_), content="true")

  let gradient_single_stop = parse_fill_entry(
    "<gradientFill><stop position=\"0\"><color rgb=\"FF112233\"/></stop></gradientFill>",
  )
  inspect(gradient_single_stop.colors, content="None")
  inspect(gradient_single_stop.transparency, content="None")

  let pattern_default = parse_fill_entry(
    "<patternFill><fgColor rgb=\"112233\"/></patternFill>",
  )
  inspect(pattern_default.typ, content="Some(\"pattern\")")
  inspect(pattern_default.pattern, content="Some(0)")
  inspect(pattern_default.colors is Some(_), content="true")

  let pattern_unknown = parse_fill_entry(
    "<patternFill patternType=\"unknown\"><fgColor rgb=\"112233\"/></patternFill>",
  )
  inspect(pattern_unknown.pattern, content="Some(0)")

  inspect(
    is_invalid_xml_fill_error(
      try? parse_fill_entry("<patternFill><fgColor theme=\"x\"/></patternFill>"),
      "fill fgColor theme invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      try? parse_fill_entry(
        "<patternFill><fgColor indexed=\"x\"/></patternFill>",
      ),
      "fill fgColor indexed invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      try? parse_fill_entry("<patternFill><fgColor tint=\"x\"/></patternFill>"),
      "fill fgColor tint invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      try? parse_fill_entry("<patternFill><bgColor theme=\"x\"/></patternFill>"),
      "fill bgColor theme invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      try? parse_fill_entry(
        "<patternFill><bgColor indexed=\"x\"/></patternFill>",
      ),
      "fill bgColor indexed invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      try? parse_fill_entry("<patternFill><bgColor tint=\"x\"/></patternFill>"),
      "fill bgColor tint invalid",
    ),
    content="true",
  )
}
