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
test "read wb: xml encoding parser guard paths" {
  inspect(xml_encoding(b"abc") is None, content="true")

  let with_bom_single_quote =
    b"\xEF\xBB\xBF<?xml version='1.0' encoding='UTF-16'?><x/>"
  inspect(
    match xml_encoding(with_bom_single_quote) {
      Some(value) => value == "UTF-16"
      None => false
    },
    content="true",
  )

  inspect(xml_encoding(b"<?xml version=\"1.0\" encoding=\"UT@8\"?><x/>") is None, content="true")
  inspect(xml_encoding(b"<?xml version=\"1.0\" encoding=\"UTF-8?><x/>") is None, content="true")
}

///|
test "read wb: decode_utf8 invalid paths" {
  let requires_transcoder = try? decode_utf8(
    b"<?xml version=\"1.0\" encoding=\"UTF-16\"?><x/>",
    None,
  )
  inspect(
    match requires_transcoder {
      Err(XlsxError::InvalidXml(msg~)) => msg.contains("requires charset transcoder")
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
    #|<font>
    #|  <b val="1"/><i val="1"/><strike val="1"/><outline val="1"/>
    #|  <shadow val="1"/><condense val="1"/><extend val="1"/>
    #|  <u val="double"/><sz val="11"/><charset val="1"/>
    #|  <name val="Aptos"/><family val="3"/><vertAlign val="superscript"/>
    #|  <scheme val="minor"/><color rgb="ABCDEF12" theme="1" indexed="2" tint="0.5"/>
    #|</font>
    #|,
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
