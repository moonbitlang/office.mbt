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
fn is_invalid_xml_alignment_error(
  result : Result[Alignment?, XlsxError],
  expected_msg : String,
) -> Bool {
  match result {
    Err(XlsxError::InvalidXml(msg~)) => msg == expected_msg
    _ => false
  }
}

///|
fn has_border_type(borders : Array[Border], typ : String) -> Bool {
  for border in borders {
    if border.typ == typ {
      return true
    }
  }
  false
}

///|
fn border_color_by_type(borders : Array[Border], typ : String) -> String? {
  for border in borders {
    if border.typ == typ {
      return border.color
    }
  }
  None
}

///|
fn is_invalid_xml_string_array_error(
  result : Result[Array[String], XlsxError],
  expected_msg : String,
) -> Bool {
  match result {
    Err(XlsxError::InvalidXml(msg~)) => msg == expected_msg
    _ => false
  }
}

///|
fn is_invalid_xml_defined_name_error(
  result : Result[Array[DefinedName], XlsxError],
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
  let requires_transcoder = Ok(
    decode_utf8(b"<?xml version=\"1.0\" encoding=\"Shift_JIS\"?><x/>", None),
  ) catch {
    e => Err(e)
  }
  inspect(
    match requires_transcoder {
      Err(XlsxError::InvalidXml(msg~)) =>
        msg.contains("requires charset transcoder")
      _ => false
    },
    content="true",
  )

  let invalid_utf8 = Ok(decode_utf8(b"\xFF\xFF\xFF", None)) catch {
    e => Err(e)
  }
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
  inspect(font.extended is Some(true), content="true")
  debug_inspect(font.underline, content="Some(\"double\")")
  debug_inspect(font.size, content="Some(11)")
  debug_inspect(font.charset, content="Some(1)")
  debug_inspect(font.family, content="Some(\"Aptos\")")
  debug_inspect(font.family_number, content="Some(3)")
  debug_inspect(font.vert_align, content="Some(\"superscript\")")
  debug_inspect(font.scheme, content="Some(\"minor\")")
  debug_inspect(font.color, content="Some(\"ABCDEF12\")")
  debug_inspect(font.color_theme, content="Some(1)")
  debug_inspect(font.color_indexed, content="Some(2)")
  debug_inspect(font.color_tint, content="Some(0.5)")

  inspect(
    is_invalid_xml_error(
      Ok(parse_font_entry("<font><sz val=\"bad\"/></font>")) catch {
        e => Err(e)
      },
      "font sz invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_error(
      Ok(parse_font_entry("<font><charset val=\"x\"/></font>")) catch {
        e => Err(e)
      },
      "font charset invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_error(
      Ok(parse_font_entry("<font><family val=\"x\"/></font>")) catch {
        e => Err(e)
      },
      "font family invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_error(
      Ok(parse_font_entry("<font><color theme=\"x\"/></font>")) catch {
        e => Err(e)
      },
      "font color theme invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_error(
      Ok(parse_font_entry("<font><color indexed=\"x\"/></font>")) catch {
        e => Err(e)
      },
      "font color indexed invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_error(
      Ok(parse_font_entry("<font><color tint=\"x\"/></font>")) catch {
        e => Err(e)
      },
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
  inspect(font.extended is Some(true), content="true")
  debug_inspect(font.underline, content="Some(\"single\")")
  debug_inspect(font.size, content="None")
  debug_inspect(font.charset, content="None")
  debug_inspect(font.family, content="None")
  debug_inspect(font.family_number, content="None")
  debug_inspect(font.vert_align, content="None")
  debug_inspect(font.scheme, content="None")
}

///|
test "read wb: parse_fill_entry gradient and pattern guard branches" {
  inspect(
    is_invalid_xml_fill_error(
      Ok(parse_fill_entry("<gradientFill bottom=\"bad\"></gradientFill>")) catch {
        e => Err(e)
      },
      "gradientFill bottom invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      Ok(parse_fill_entry("<gradientFill degree=\"bad\"></gradientFill>")) catch {
        e => Err(e)
      },
      "gradientFill degree invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      Ok(parse_fill_entry("<gradientFill left=\"bad\"></gradientFill>")) catch {
        e => Err(e)
      },
      "gradientFill left invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      Ok(parse_fill_entry("<gradientFill right=\"bad\"></gradientFill>")) catch {
        e => Err(e)
      },
      "gradientFill right invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      Ok(parse_fill_entry("<gradientFill top=\"bad\"></gradientFill>")) catch {
        e => Err(e)
      },
      "gradientFill top invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      Ok(
        parse_fill_entry(
          "<gradientFill><stop position=\"bad\"><color rgb=\"FF112233\"/></stop></gradientFill>",
        ),
      ) catch {
        e => Err(e)
      },
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
  debug_inspect(gradient.typ, content="Some(\"gradient\")")
  inspect(gradient.shading is Some(_), content="true")
  inspect(gradient.colors is Some(_), content="true")
  inspect(gradient.transparency is Some(_), content="true")

  let gradient_single_stop = parse_fill_entry(
    "<gradientFill><stop position=\"0\"><color rgb=\"FF112233\"/></stop></gradientFill>",
  )
  debug_inspect(gradient_single_stop.colors, content="None")
  debug_inspect(gradient_single_stop.transparency, content="None")

  let pattern_default = parse_fill_entry(
    "<patternFill><fgColor rgb=\"112233\"/></patternFill>",
  )
  debug_inspect(pattern_default.typ, content="Some(\"pattern\")")
  debug_inspect(pattern_default.pattern, content="Some(0)")
  inspect(pattern_default.colors is Some(_), content="true")

  let pattern_unknown = parse_fill_entry(
    "<patternFill patternType=\"unknown\"><fgColor rgb=\"112233\"/></patternFill>",
  )
  debug_inspect(pattern_unknown.pattern, content="Some(0)")

  inspect(
    is_invalid_xml_fill_error(
      Ok(parse_fill_entry("<patternFill><fgColor theme=\"x\"/></patternFill>")) catch {
        e => Err(e)
      },
      "fill fgColor theme invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      Ok(
        parse_fill_entry("<patternFill><fgColor indexed=\"x\"/></patternFill>"),
      ) catch {
        e => Err(e)
      },
      "fill fgColor indexed invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      Ok(parse_fill_entry("<patternFill><fgColor tint=\"x\"/></patternFill>")) catch {
        e => Err(e)
      },
      "fill fgColor tint invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      Ok(parse_fill_entry("<patternFill><bgColor theme=\"x\"/></patternFill>")) catch {
        e => Err(e)
      },
      "fill bgColor theme invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      Ok(
        parse_fill_entry("<patternFill><bgColor indexed=\"x\"/></patternFill>"),
      ) catch {
        e => Err(e)
      },
      "fill bgColor indexed invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_fill_error(
      Ok(parse_fill_entry("<patternFill><bgColor tint=\"x\"/></patternFill>")) catch {
        e => Err(e)
      },
      "fill bgColor tint invalid",
    ),
    content="true",
  )
}

///|
test "read wb: parse_fills and borders structural guard branches" {
  let no_fills = parse_fills("<styleSheet/>")
  inspect(no_fills.length(), content="0")

  let malformed_fill_open = parse_fills("<fills><fill</fills>")
  inspect(malformed_fill_open.length(), content="0")

  let self_closing_fill = parse_fills("<fills><fill/></fills>")
  inspect(self_closing_fill.length(), content="1")

  let missing_fill_close = parse_fills("<fills><fill><patternFill/></fills>")
  inspect(missing_fill_close.length(), content="0")

  let parsed_fill = parse_fills(
    (
      #|<fills>
      #|  <fill><patternFill patternType="solid"><fgColor rgb="FF112233"/></patternFill></fill>
      #|</fills>
      #|,
    ),
  )
  inspect(parsed_fill.length(), content="1")
  debug_inspect(parsed_fill[0].typ, content="Some(\"pattern\")")

  let no_borders = parse_borders("<styleSheet/>")
  inspect(no_borders.length(), content="1")
  inspect(no_borders[0].length(), content="0")

  let empty_borders = parse_borders("<borders></borders>")
  inspect(empty_borders.length(), content="1")
  inspect(empty_borders[0].length(), content="0")

  let malformed_border_open = parse_borders("<borders><border</borders>")
  inspect(malformed_border_open.length(), content="1")
  inspect(malformed_border_open[0].length(), content="0")

  let self_closing_border = parse_borders("<borders><border/></borders>")
  inspect(self_closing_border.length(), content="1")
  inspect(self_closing_border[0].length(), content="0")

  let missing_border_close = parse_borders("<borders><border><left/></borders>")
  inspect(missing_border_close.length(), content="1")
  inspect(missing_border_close[0].length(), content="0")

  let parsed_borders = parse_borders(
    (
      #|<borders>
      #|  <border diagonalUp="1" diagonalDown="1">
      #|    <left style="thin"><foo/></left>
      #|    <right style="thin"><color rgb="80112233"/></right>
      #|    <top style="thin"><color/></top>
      #|    <bottom style="thin"/>
      #|    <diagonal style="thin"/>
      #|    <vertical style="thin"/>
      #|    <horizontal style="thin"/>
      #|  </border>
      #|  <border><diagonal style="thin"/></border>
      #|</borders>
      #|,
    ),
  )
  inspect(parsed_borders.length(), content="2")
  inspect(parsed_borders[0].length(), content="8")
  inspect(parsed_borders[1].length(), content="1")
  inspect(has_border_type(parsed_borders[0], "diagonalUp"), content="true")
  inspect(has_border_type(parsed_borders[0], "diagonalDown"), content="true")
  inspect(has_border_type(parsed_borders[0], "vertical"), content="true")
  inspect(has_border_type(parsed_borders[0], "horizontal"), content="true")
  inspect(has_border_type(parsed_borders[1], "diagonal"), content="true")
  debug_inspect(
    border_color_by_type(parsed_borders[0], "right"),
    content="Some(\"80112233\")",
  )
}

///|
test "read wb: protection alignment and pivot parser guard branches" {
  inspect(
    parse_protection_entry("<xf><protection/></xf>") is None,
    content="true",
  )
  inspect(
    match parse_protection_entry("<xf><protection hidden=\"1\"/></xf>") {
      Some(value) => value.hidden == Some(true) && value.locked is None
      None => false
    },
    content="true",
  )

  inspect(
    parse_alignment_entry("<xf><alignment/></xf>") is None,
    content="true",
  )
  inspect(
    is_invalid_xml_alignment_error(
      Ok(parse_alignment_entry("<xf><alignment textRotation=\"bad\"/></xf>")) catch {
        e => Err(e)
      },
      "textRotation invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_alignment_error(
      Ok(parse_alignment_entry("<xf><alignment indent=\"bad\"/></xf>")) catch {
        e => Err(e)
      },
      "indent invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_alignment_error(
      Ok(parse_alignment_entry("<xf><alignment readingOrder=\"bad\"/></xf>")) catch {
        e => Err(e)
      },
      "readingOrder invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_alignment_error(
      Ok(parse_alignment_entry("<xf><alignment relativeIndent=\"bad\"/></xf>")) catch {
        e => Err(e)
      },
      "relativeIndent invalid",
    ),
    content="true",
  )
  inspect(
    match parse_alignment_entry("<xf><alignment horizontal=\"center\"/></xf>") {
      Some(value) => value.horizontal == Some("center")
      None => false
    },
    content="true",
  )

  inspect(
    parse_pivot_table_name("<pivotTableDefinition cacheId=\"1\"/>"),
    content="",
  )
  inspect(parse_pivot_table_name("<worksheet/>"), content="")
}

///|
test "read wb: defined names merge cells and classic validation guards" {
  let sheet_names : Array[String] = ["Sheet1"]

  let defined_names = parse_defined_names(
    (
      #|<definedNames>
      #|  <definedName name="WBName" comment="note">Sheet1!$A$1</definedName>
      #|  <definedName name="LocalName" localSheetId="0">Sheet1!$B$1</definedName>
      #|</definedNames>
      #|,
    ),
    sheet_names,
  )
  inspect(defined_names.length(), content="2")
  inspect(defined_names[0].name, content="WBName")
  inspect(defined_names[0].comment, content="note")
  inspect(defined_names[0].scope, content="Workbook")
  inspect(defined_names[1].scope, content="Sheet1")

  inspect(
    is_invalid_xml_defined_name_error(
      Ok(
        parse_defined_names(
          "<definedNames><definedName >Sheet1!$A$1</definedName></definedNames>",
          sheet_names,
        ),
      ) catch {
        e => Err(e)
      },
      "definedName name missing",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_defined_name_error(
      Ok(
        parse_defined_names(
          "<definedNames><definedName name=\"A\" localSheetId=\"bad\">Sheet1!$A$1</definedName></definedNames>",
          sheet_names,
        ),
      ) catch {
        e => Err(e)
      },
      "definedName localSheetId invalid",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_defined_name_error(
      Ok(
        parse_defined_names(
          "<definedNames><definedName name=\"A\">Sheet1!$A$1</definedNames>", sheet_names,
        ),
      ) catch {
        e => Err(e)
      },
      "definedName close missing",
    ),
    content="true",
  )
  inspect(
    is_invalid_xml_defined_name_error(
      Ok(
        parse_defined_names(
          "<definedNames><definedName name=\"A\" localSheetId=\"5\">Sheet1!$A$1</definedName></definedNames>",
          sheet_names,
        ),
      ) catch {
        e => Err(e)
      },
      "definedName localSheetId missing",
    ),
    content="true",
  )

  let merged = parse_merge_cells(
    "<mergeCells><mergeCell ref=\"A1\"/></mergeCells>",
  )
  inspect(merged.length(), content="1")
  inspect(merged[0], content="A1:A1")
  inspect(
    is_invalid_xml_string_array_error(
      Ok(parse_merge_cells("<mergeCells><mergeCell /></mergeCells>")) catch {
        e => Err(e)
      },
      "mergeCell ref missing",
    ),
    content="true",
  )

  let validations = parse_data_validations(
    "<dataValidations><dataValidation type=\"whole\" sqref=\"A1\"/></dataValidations>",
  )
  inspect(validations.length(), content="1")
  inspect(validations[0].contains("sqref=\"A1\""), content="true")
  inspect(
    is_invalid_xml_string_array_error(
      Ok(
        parse_data_validations(
          "<dataValidations><dataValidation type=\"whole\"></dataValidations>",
        ),
      ) catch {
        e => Err(e)
      },
      "dataValidation tag not closed",
    ),
    content="true",
  )

  let cf_self_close = parse_conditional_formats(
    "<worksheet><conditionalFormatting sqref=\"A1\"/></worksheet>",
  )
  inspect(cf_self_close.length(), content="1")
  inspect(cf_self_close[0].contains("sqref=\"A1\""), content="true")
}

///|
test "read wb: x14 validation and icon-set helper guard branches" {
  let x14_validations_default = parse_data_validations_x14(
    (
      #|<worksheet>
      #|  <x14:dataValidation >
      #|    <xm:sqref>A1</xm:sqref>
      #|    <x14:formula1>PlainText</x14:formula1>
      #|    <x14:formula2><xm:f>7</xm:f></x14:formula2>
      #|  </x14:dataValidation>
      #|</worksheet>
      #|,
    ),
  )
  inspect(x14_validations_default.length(), content="1")
  inspect(
    x14_validations_default[0].contains("<dataValidation allowBlank=\"0\""),
    content="true",
  )
  inspect(
    x14_validations_default[0].contains("<formula1>PlainText</formula1>"),
    content="true",
  )
  inspect(
    x14_validations_default[0].contains("<formula2>7</formula2>"),
    content="true",
  )

  let x14_validations_no_formula = parse_data_validations_x14(
    (
      #|<worksheet>
      #|  <x14:dataValidation allowBlank="1" type="list">
      #|    <xm:sqref>B1</xm:sqref>
      #|  </x14:dataValidation>
      #|</worksheet>
      #|,
    ),
  )
  inspect(x14_validations_no_formula.length(), content="1")
  inspect(
    x14_validations_no_formula[0].contains("type=\"list\""),
    content="true",
  )
  inspect(!x14_validations_no_formula[0].contains("<formula1>"), content="true")

  inspect(
    is_invalid_xml_string_array_error(
      Ok(
        parse_data_validations_x14(
          "<worksheet><x14:dataValidation allowBlank=\"1\"></x14:dataValidation></worksheet>",
        ),
      ) catch {
        e => Err(e)
      },
      "x14:dataValidation sqref missing",
    ),
    content="true",
  )

  let opt_percent = ConditionalFormatOptions::new("icon_set")
  opt_percent.icon_style = "3Arrows"
  opt_percent.percent = true
  let icon_rule_with_cfvo = build_icon_set_rule_xml_from_x14(
    opt_percent,
    3,
    ["<cfvo type=\"num\" val=\"1\"/>"][:],
  )
  inspect(icon_rule_with_cfvo.contains("percent=\"1\""), content="true")
  inspect(
    icon_rule_with_cfvo.contains("<cfvo type=\"num\" val=\"1\"/>"),
    content="true",
  )

  let opt_unknown = ConditionalFormatOptions::new("icon_set")
  opt_unknown.icon_style = "unknown-style"
  let empty_cfvos : Array[String] = []
  let icon_rule_unknown = build_icon_set_rule_xml_from_x14(
    opt_unknown, 1, empty_cfvos,
  )
  inspect(!icon_rule_unknown.contains("<cfvo"), content="true")

  let x14_cfvos = parse_x14_cfvo_values(
    (
      #|<worksheet>
      #|  <x14:cfvo type="num"><xm:f>5</xm:f></x14:cfvo>
      #|  <x14:cfvo type="num"><f>9</f></x14:cfvo>
      #|  <x14:cfvo type="percent"/>
      #|  <x14:cfvo><xm:f>1</xm:f></x14:cfvo>
      #|</worksheet>
      #|,
    ),
  )
  inspect(x14_cfvos.length(), content="3")
  inspect(x14_cfvos[0], content="<cfvo type=\"num\" val=\"5\"/>")
  inspect(x14_cfvos[1], content="<cfvo type=\"num\" val=\"9\"/>")
  inspect(x14_cfvos[2], content="<cfvo type=\"percent\"/>")

  inspect(color_text_from_rgb_x14("FF112233"), content="#112233")
  inspect(color_text_from_rgb_x14("00112233"), content="#00112233")

  debug_inspect(
    parse_sheet_dimension(
      "<worksheet><dimension ref=\"A1:B2\"></dimension></worksheet>",
    ),
    content="Some(\"A1:B2\")",
  )
  debug_inspect(
    parse_sheet_dimension("<worksheet><dimension/></worksheet>"),
    content="None",
  )
}

///|
test "read wb: sheet views and sheet props parser guard branches part 5" {
  let dimension_err = Ok(
    parse_sheet_dimension("<worksheet><dimension ref=\"A1\""),
  ) catch {
    e => Err(e)
  }
  inspect(
    match dimension_err {
      Err(XlsxError::InvalidXml(msg~)) => msg == "dimension tag not closed"
      _ => false
    },
    content="true",
  )

  let pane_not_closed = Ok(parse_sheet_view_pane("<pane ")) catch {
    e => Err(e)
  }
  inspect(
    match pane_not_closed {
      Err(XlsxError::InvalidXml(msg~)) => msg == "pane tag not closed"
      _ => false
    },
    content="true",
  )
  let pane_bad_xsplit = Ok(parse_sheet_view_pane("<pane xSplit=\"x\"/>")) catch {
    e => Err(e)
  }
  inspect(
    match pane_bad_xsplit {
      Err(XlsxError::InvalidXml(msg~)) => msg == "pane xSplit invalid"
      _ => false
    },
    content="true",
  )
  let pane_bad_ysplit = Ok(parse_sheet_view_pane("<pane ySplit=\"x\"/>")) catch {
    e => Err(e)
  }
  inspect(
    match pane_bad_ysplit {
      Err(XlsxError::InvalidXml(msg~)) => msg == "pane ySplit invalid"
      _ => false
    },
    content="true",
  )
  inspect(
    match parse_sheet_view_pane("<pane />") {
      Some(pane) =>
        pane.active_pane == "" &&
        pane.state == "" &&
        pane.top_left_cell == "" &&
        pane.x_split == 0.0 &&
        pane.y_split == 0.0
      None => false
    },
    content="true",
  )
  inspect(
    match
      parse_sheet_view_pane(
        "<pane activePane=\"bottomRight\" state=\"frozen\" topLeftCell=\"C3\" xSplit=\"1.5\" ySplit=\"2\"/>",
      ) {
      Some(pane) =>
        pane.active_pane == "bottomRight" &&
        pane.state == "frozen" &&
        pane.top_left_cell == "C3" &&
        pane.x_split == 1.5 &&
        pane.y_split == 2.0
      None => false
    },
    content="true",
  )

  let selection_not_closed = Ok(parse_sheet_view_selections("<selection ")) catch {
    e => Err(e)
  }
  inspect(
    match selection_not_closed {
      Err(XlsxError::InvalidXml(msg~)) => msg == "selection tag not closed"
      _ => false
    },
    content="true",
  )
  let selection_defaults = parse_sheet_view_selections("<selection />")
  inspect(selection_defaults.length(), content="1")
  inspect(
    selection_defaults[0].sqref == "" &&
    selection_defaults[0].active_cell == "" &&
    selection_defaults[0].pane == "",
    content="true",
  )
  let selections = parse_sheet_view_selections(
    "<selection sqref=\"B2\" activeCell=\"B2\" pane=\"topRight\"/>",
  )
  inspect(selections.length(), content="1")
  inspect(
    selections[0].sqref == "B2" &&
    selections[0].active_cell == "B2" &&
    selections[0].pane == "topRight",
    content="true",
  )

  let sheet_view_bad_zoom = Ok(
    parse_sheet_views("<sheetViews><sheetView zoomScale=\"x\"/></sheetViews>"),
  ) catch {
    e => Err(e)
  }
  inspect(
    match sheet_view_bad_zoom {
      Err(XlsxError::InvalidXml(msg~)) => msg == "sheetView zoomScale invalid"
      _ => false
    },
    content="true",
  )
  let sheet_view_bad_id = Ok(
    parse_sheet_views(
      "<sheetViews><sheetView workbookViewId=\"x\"/></sheetViews>",
    ),
  ) catch {
    e => Err(e)
  }
  inspect(
    match sheet_view_bad_id {
      Err(XlsxError::InvalidXml(msg~)) =>
        msg == "sheetView workbookViewId invalid"
      _ => false
    },
    content="true",
  )
  let sheet_view_missing_close = Ok(
    parse_sheet_views(
      "<sheetViews><sheetView workbookViewId=\"0\"></sheetViews>",
    ),
  ) catch {
    e => Err(e)
  }
  inspect(
    match sheet_view_missing_close {
      Err(XlsxError::InvalidXml(msg~)) => msg == "sheetView close missing"
      _ => false
    },
    content="true",
  )

  let parsed_views = parse_sheet_views(
    (
      #|<sheetViews>
      #|  <sheetView workbookViewId="2" showRuler="1" view="pageLayout">
      #|    <pane activePane="topRight" state="frozen" topLeftCell="B2" xSplit="1" ySplit="0"/>
      #|    <selection sqref="B2" activeCell="B2" pane="topRight"/>
      #|  </sheetView>
      #|</sheetViews>
      #|,
    ),
  )
  inspect(parsed_views.length(), content="1")
  inspect(
    match parsed_views[0].show_ruler {
      Some(v) => v == true
      None => false
    },
    content="true",
  )
  inspect(
    match parsed_views[0].view {
      Some(v) => v == "pageLayout"
      None => false
    },
    content="true",
  )
  inspect(parsed_views[0].workbook_view_id, content="2")
  inspect(parsed_views[0].pane is Some(_), content="true")
  inspect(parsed_views[0].selection.length(), content="1")

  let parsed_views_default_id = parse_sheet_views(
    "<sheetViews><sheetView showRuler=\"1\"/></sheetViews>",
  )
  inspect(parsed_views_default_id.length(), content="1")
  inspect(parsed_views_default_id[0].workbook_view_id, content="0")

  let props_from_tab_color = parse_sheet_props(
    "<worksheet><tabColor indexed=\"3\" rgb=\"FF112233\" theme=\"4\" tint=\"0.5\"/></worksheet>",
  )
  inspect(props_from_tab_color is Some(_), content="true")
  inspect(
    match props_from_tab_color {
      Some(opts) =>
        opts.tab_color_indexed == Some(3) &&
        opts.tab_color_rgb == Some("FF112233") &&
        opts.tab_color_theme == Some(4) &&
        opts.tab_color_tint == Some(0.5)
      None => false
    },
    content="true",
  )
  let tab_color_bad_indexed = Ok(
    parse_sheet_props("<worksheet><tabColor indexed=\"x\"/></worksheet>"),
  ) catch {
    e => Err(e)
  }
  inspect(
    match tab_color_bad_indexed {
      Err(XlsxError::InvalidXml(msg~)) => msg == "tabColor indexed invalid"
      _ => false
    },
    content="true",
  )
  inspect(
    match
      parse_sheet_props("<worksheet><sheetPr published=\"1\"/></worksheet>") {
      Some(opts) => opts.code_name is None && opts.published == Some(true)
      None => false
    },
    content="true",
  )
}
