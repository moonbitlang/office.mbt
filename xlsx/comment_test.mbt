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
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let comment : @xlsx.Comment = {
    cell: "A1",
    author: "Alice",
    author_id: None,
    text: "Hello",
    paragraph: [],
    width: None,
    height: None,
  }
  workbook.add_comment("Sheet1", comment)
  debug_inspect(
    workbook.get_comments("Sheet1"),
    content=(
      #|[
      #|  {
      #|    cell: "A1",
      #|    author: "Alice",
      #|    author_id: None,
      #|    text: "Hello",
      #|    paragraph: [],
      #|    width: None,
      #|    height: None,
      #|  },
      #|]
    ),
  )
  workbook.delete_comment("Sheet1", "A1")
  debug_inspect(workbook.get_comments("Sheet1"), content="[]")
}

///|
test "comment delete keeps other comments" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_comment({
    cell: "A1",
    author: "A",
    author_id: None,
    text: "one",
    paragraph: [],
    width: None,
    height: None,
  })
  sheet.add_comment({
    cell: "B2",
    author: "B",
    author_id: None,
    text: "two",
    paragraph: [],
    width: None,
    height: None,
  })
  sheet.delete_comment("A1")
  debug_inspect(
    sheet.comments().to_owned(),
    content=(
      #|[
      #|  {
      #|    cell: "B2",
      #|    author: "B",
      #|    author_id: None,
      #|    text: "two",
      #|    paragraph: [],
      #|    width: None,
      #|    height: None,
      #|  },
      #|]
    ),
  )
}

///|
test "comment roundtrip" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let font : @xlsx.RichTextFont = {
    bold: true,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extended: false,
    underline: None,
    size: Some(11.0),
    color: None,
    color_theme: None,
    color_indexed: None,
    color_tint: None,
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  let runs : Array[@xlsx.RichTextRun] = [
    { text: "Note", font: Some(font) },
    { text: " 1", font: None },
  ]
  let comment : @xlsx.Comment = {
    cell: "B2",
    author: "Bob",
    author_id: None,
    text: "",
    paragraph: runs,
    width: None,
    height: None,
  }
  workbook.add_comment("Sheet1", comment)
  let parsed = @xlsx.read(@xlsx.write(workbook))
  debug_inspect(
    parsed.get_comments("Sheet1"),
    content=(
      #|[
      #|  {
      #|    cell: "B2",
      #|    author: "Bob",
      #|    author_id: Some(0),
      #|    text: "Note 1",
      #|    paragraph: [
      #|      {
      #|        text: "Note",
      #|        font: Some(
      #|          {
      #|            bold: true,
      #|            italic: false,
      #|            strike: false,
      #|            outline: false,
      #|            shadow: false,
      #|            condense: false,
      #|            extended: false,
      #|            underline: None,
      #|            size: Some(11),
      #|            color: None,
      #|            color_theme: None,
      #|            color_indexed: None,
      #|            color_tint: None,
      #|            charset: None,
      #|            family_number: None,
      #|            scheme: None,
      #|            vert_align: None,
      #|            family: None,
      #|          },
      #|        ),
      #|      },
      #|      { text: " 1", font: None },
      #|    ],
      #|    width: None,
      #|    height: None,
      #|  },
      #|]
    ),
  )
}

///|
test "comment author truncation" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let author = repeat_comment_text("a", 300)
  let comment : @xlsx.Comment = {
    cell: "C3",
    author,
    author_id: None,
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

///|
test "comment rich text truncation preserves run prefix" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let font : @xlsx.RichTextFont = {
    bold: true,
    italic: false,
    strike: false,
    outline: false,
    shadow: false,
    condense: false,
    extended: false,
    underline: None,
    size: None,
    color: None,
    color_theme: None,
    color_indexed: None,
    color_tint: None,
    charset: None,
    family_number: None,
    scheme: None,
    vert_align: None,
    family: None,
  }
  let comment : @xlsx.Comment = {
    cell: "D4",
    author: "Alice",
    author_id: None,
    text: repeat_comment_text("a", 32766),
    paragraph: [{ text: "AB", font: Some(font) }, { text: "Z", font: None }],
    width: None,
    height: None,
  }
  workbook.add_comment("Sheet1", comment)
  let parsed = @xlsx.read(@xlsx.write(workbook))
  let comments = parsed.get_comments("Sheet1")
  inspect(comments.length(), content="1")
  inspect(comments[0].text.length(), content="32767")
  inspect(comments[0].paragraph.length(), content="1")
  inspect(comments[0].paragraph[0].text, content="A")
  inspect(comments[0].paragraph[0].font is Some(_), content="true")
}

///|
test "comment duplicate + invalid sheet name" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let comment : @xlsx.Comment = {
    cell: "A1",
    author: "Alice",
    author_id: None,
    text: "Hello",
    paragraph: [],
    width: None,
    height: None,
  }
  workbook.add_comment("Sheet1", comment)
  let dup : Result[Unit, Error] = Ok(workbook.add_comment("Sheet1", comment)) catch {
    e => Err(e)
  }
  inspect(dup is Err(@xlsx.XlsxError::CommentAlreadyExists(_)), content="true")
  let bad : Result[Unit, Error] = Ok(workbook.add_comment("Sheet:1", comment)) catch {
    e => Err(e)
  }
  inspect(bad is Err(@xlsx.XlsxError::InvalidSheetName(_)), content="true")
}
