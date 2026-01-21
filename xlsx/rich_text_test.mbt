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
    underline: Some("single"),
    size: Some(12.0),
    color: Some("#FF0000"),
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
      #|Some([{text: "Hello ", font: None}, {text: "World", font: Some({bold: true, italic: false, underline: Some("single"), size: Some(12), color: Some("#FF0000"), family: Some("Calibri")})}])
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
test "rich text roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let font : RichTextFont = {
    bold: true,
    italic: true,
    underline: None,
    size: Some(11.0),
    color: Some("#00AA00"),
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
      #|Some([{text: "Moon", font: Some({bold: true, italic: true, underline: None, size: Some(11), color: Some("FF00AA00"), family: Some("Arial")})}, {text: "Bit", font: None}])
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
