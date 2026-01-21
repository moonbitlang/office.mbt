///|
fn repeat_comment_text(text : String, count : Int) -> String {
  let sb = StringBuilder::new()
  for _ in 0..<count {
    sb.write_view(text)
  }
  sb.to_string()
}

///|
test "comment add/delete" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let comment : Comment = {
    cell: "A1",
    author: "Alice",
    text: "Hello",
    paragraph: [],
    width: None,
    height: None,
  }
  workbook.add_comment("Sheet1", comment)
  inspect(
    workbook.get_comments("Sheet1"),
    content=(
      #|[{cell: "A1", author: "Alice", text: "Hello", paragraph: [], width: None, height: None}]
    ),
  )
  workbook.delete_comment("Sheet1", "A1")
  inspect(workbook.get_comments("Sheet1"), content="[]")
}

///|
test "comment roundtrip" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let font : RichTextFont = {
    bold: true,
    italic: false,
    underline: None,
    size: Some(11.0),
    color: None,
    family: None,
  }
  let runs : Array[RichTextRun] = [
    { text: "Note", font: Some(font) },
    { text: " 1", font: None },
  ]
  let comment : Comment = {
    cell: "B2",
    author: "Bob",
    text: "",
    paragraph: runs,
    width: None,
    height: None,
  }
  workbook.add_comment("Sheet1", comment)
  let parsed = read(write(workbook))
  inspect(
    parsed.get_comments("Sheet1"),
    content=(
      #|[{cell: "B2", author: "Bob", text: "Note 1", paragraph: [{text: "Note", font: Some({bold: true, italic: false, underline: None, size: Some(11), color: None, family: None})}, {text: " 1", font: None}], width: None, height: None}]
    ),
  )
}

///|
test "comment author truncation" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let author = repeat_comment_text("a", 300)
  let comment : Comment = {
    cell: "C3",
    author,
    text: "Hi",
    paragraph: [],
    width: None,
    height: None,
  }
  workbook.add_comment("Sheet1", comment)
  let comments = workbook.get_comments("Sheet1")
  let author_len = match comments.get(0) {
    Some(entry) => entry.author.length()
    None => 0
  }
  inspect(author_len, content="255")
}
