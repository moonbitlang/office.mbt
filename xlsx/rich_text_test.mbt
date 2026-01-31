///|
fn repeat_rich_text(text : String, count : Int) -> String {
  let sb = StringBuilder::new()
  for _ in 0..<count {
    sb.write_view(text)
  }
  sb.to_string()
}

///|
test "rich text set/get" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let font : RichTextFont = {
    bold: true,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extend: false,
    underline: Some("single"),
    size: Some(12.0),
    color: Some("#FF0000"),
    color_theme: None,
    color_indexed: None,
    color_tint: None,
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: Some("Calibri"),
  }
  let runs : Array[RichTextRun] = [
    { text: "Hello ", font: None },
    { text: "World", font: Some(font) },
  ]
  workbook.set_cell_rich_text("Sheet1", "A1", runs)
  inspect(
    workbook.get_cell_rich_text("Sheet1", "A1"),
    content=(
      #|Some([{text: "Hello ", font: None}, {text: "World", font: Some({bold: true, italic: false, strike: false, outline: false, shadow: false, condense: false, extend: false, underline: Some("single"), size: Some(12), color: Some("#FF0000"), color_theme: None, color_indexed: None, color_tint: None, charset: None, family_number: None, scheme: None, vert_align: None, family: Some("Calibri")})}])
    ),
  )
  inspect(
    workbook.get_cell("Sheet1", "A1"),
    content=(
      #|Some("Hello World")
    ),
  )
}

///|
test "rich text get on plain string cell returns single run" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A1", "plain")
  inspect(
    sheet.get_cell_rich_text("A1"),
    content=(
      #|Some([{text: "plain", font: None}])
    ),
  )
}

///|
test "rich text get on non-string cell returns None" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell_value("A1", Numeric(1.0))
  inspect(sheet.get_cell_rich_text("A1"), content="None")
}

///|
test "rich text set updates existing cell" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_cell_rich_text("Sheet1", "A1", [{ text: "v1", font: None }])
  workbook.set_cell_rich_text("Sheet1", "A1", [{ text: "v2", font: None }])
  inspect(workbook.get_cell("Sheet1", "A1"), content="Some(\"v2\")")
}

///|
test "rich text roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let font : RichTextFont = {
    bold: true,
    italic: true,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extend: false,
    underline: None,
    size: Some(11.0),
    color: Some("#00AA00"),
    color_theme: None,
    color_indexed: None,
    color_tint: None,
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: Some("Arial"),
  }
  let runs : Array[RichTextRun] = [
    { text: "Moon", font: Some(font) },
    { text: "Bit", font: None },
  ]
  workbook.set_cell_rich_text("Sheet1", "B2", runs)
  let parsed = read(write(workbook))
  inspect(
    parsed.get_cell_rich_text("Sheet1", "B2"),
    content=(
      #|Some([{text: "Moon", font: Some({bold: true, italic: true, strike: false, outline: false, shadow: false, condense: false, extend: false, underline: None, size: Some(11), color: Some("FF00AA00"), color_theme: None, color_indexed: None, color_tint: None, charset: None, family_number: None, scheme: None, vert_align: None, family: Some("Arial")})}, {text: "Bit", font: None}])
    ),
  )
  inspect(
    parsed.get_cell("Sheet1", "B2"),
    content=(
      #|Some("MoonBit")
    ),
  )
}

///|
test "rich text length limit uses utf16" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let emoji_bytes : Bytes = [0xf0, 0x9f, 0x98, 0x80]
  let emoji = @encoding/utf8.decode(emoji_bytes)
  let text = repeat_rich_text(emoji, 16384)
  let runs : Array[RichTextRun] = [{ text, font: None }]
  let result : Result[Unit, Error] = try? workbook.set_cell_rich_text(
    "Sheet1", "A1", runs,
  )
  inspect(result, content="Err(CellTextTooLong(len=32768))")
}

///|
test "rich text font extended fields roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let font : RichTextFont = {
    bold: true,
    italic: false,
    strike: true,
    outline: true,
    shadow: true,
    condense: true,
    extend: true,
    underline: Some("single"),
    size: Some(10.0),
    color: Some("112233"),
    color_theme: None,
    color_indexed: None,
    color_tint: None,
    charset: Some(1),
    family_number: Some(2),
    scheme: Some("minor"),
    vert_align: Some("superscript"),
    family: Some("Calibri"),
  }
  let runs : Array[RichTextRun] = [{ text: "X", font: Some(font) }]
  workbook.set_cell_rich_text("Sheet1", "C3", runs)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let shared_xml = match archive.get("xl/sharedStrings.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sharedStrings.xml")
  }
  inspect(shared_xml.contains("<strike/>"), content="true")
  inspect(shared_xml.contains("<outline/>"), content="true")
  inspect(shared_xml.contains("<shadow/>"), content="true")
  inspect(shared_xml.contains("<condense/>"), content="true")
  inspect(shared_xml.contains("<extend/>"), content="true")
  inspect(shared_xml.contains("<charset val=\"1\"/>"), content="true")
  inspect(shared_xml.contains("<family val=\"2\"/>"), content="true")
  inspect(
    shared_xml.contains("<vertAlign val=\"superscript\"/>"),
    content="true",
  )
  inspect(shared_xml.contains("<scheme val=\"minor\"/>"), content="true")
  let parsed = read(bytes)
  let parsed_runs = match parsed.get_cell_rich_text("Sheet1", "C3") {
    Some(value) => value
    None => fail("missing rich text")
  }
  let parsed_font = match parsed_runs[0].font {
    Some(value) => value
    None => fail("missing font")
  }
  inspect(
    (
      parsed_font.strike,
      parsed_font.outline,
      parsed_font.shadow,
      parsed_font.condense,
      parsed_font.extend,
      parsed_font.charset,
      parsed_font.family_number,
      parsed_font.scheme,
      parsed_font.vert_align,
    ),
    content="(true, true, true, true, true, Some(1), Some(2), Some(\"minor\"), Some(\"superscript\"))",
  )
}

///|
test "rich text color theme/indexed/tint roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let font_theme : RichTextFont = {
    bold: false,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extend: false,
    underline: None,
    size: None,
    color: None,
    color_theme: Some(1),
    color_indexed: None,
    color_tint: Some(0.5),
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  let font_indexed : RichTextFont = {
    bold: false,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extend: false,
    underline: None,
    size: None,
    color: None,
    color_theme: None,
    color_indexed: Some(64),
    color_tint: None,
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  workbook.set_cell_rich_text("Sheet1", "D4", [
    { text: "T", font: Some(font_theme) },
    { text: "I", font: Some(font_indexed) },
  ])
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let shared_xml = match archive.get("xl/sharedStrings.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing sharedStrings.xml")
  }
  inspect(shared_xml.contains("theme=\"1\""), content="true")
  inspect(shared_xml.contains("tint=\"0.5\""), content="true")
  inspect(shared_xml.contains("indexed=\"64\""), content="true")
  let parsed = read(bytes)
  inspect(
    parsed.get_cell_rich_text("Sheet1", "D4"),
    content=(
      #|Some([{text: "T", font: Some({bold: false, italic: false, strike: false, outline: false, shadow: false, condense: false, extend: false, underline: None, size: None, color: None, color_theme: Some(1), color_indexed: None, color_tint: Some(0.5), charset: None, family_number: None, scheme: None, vert_align: None, family: None})}, {text: "I", font: Some({bold: false, italic: false, strike: false, outline: false, shadow: false, condense: false, extend: false, underline: None, size: None, color: None, color_theme: None, color_indexed: Some(64), color_tint: None, charset: None, family_number: None, scheme: None, vert_align: None, family: None})}])
    ),
  )
}
