///|
fn repeat_comment_text(text : String, count : Int) -> String {
  let sb = StringBuilder::new()
  for _ in 0..<count {
    sb.write_view(text)
  }
  sb.to_string()
}

///|
fn plain_comment(
  cell : String,
  author : String,
  text : String,
) -> @xlsx.Comment {
  {
    cell,
    author,
    author_id: None,
    text,
    paragraph: [],
    width: None,
    height: None,
  }
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
  match workbook.get_comment("Sheet1", "b2") {
    Some(normalized) => inspect(normalized.text, content="Note 1")
    None => fail("expected normalized rich comment")
  }
  let first_write = @xlsx.write(workbook)
  let parsed = @xlsx.read(first_write)
  let second_write = @xlsx.write(parsed)
  let first_archive = @zip.read(first_write)
  let second_archive = @zip.read(second_write)
  match
    (
      first_archive.get("xl/comments1.xml"),
      second_archive.get("xl/comments1.xml"),
    ) {
    (Some(first_comments), Some(second_comments)) =>
      inspect(second_comments == first_comments, content="true")
    _ => fail("expected comments part in both writes")
  }
  match @xlsx.read(second_write).get_comment("Sheet1", "B2") {
    Some(rewritten) => inspect(rewritten.text, content="Note 1")
    None => fail("expected comment after second write")
  }
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
test "comment UTF-16 limits reject without truncation or mutation" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let author_at_limit = repeat_comment_text("a", 253) + "😀"
  sheet.add_comment(plain_comment("A1", author_at_limit, "author boundary"))
  let author_over_limit = author_at_limit + "b"
  let author_result : Result[Unit, Error] = Ok(
    sheet.add_comment(plain_comment("A2", author_over_limit, "too long")),
  ) catch {
    error => Err(error)
  }
  inspect(
    author_result is Err(@xlsx.XlsxError::InvalidComment(_)),
    content="true",
  )
  let content_at_limit = repeat_comment_text("x", 32765) + "😀"
  sheet.add_comment(plain_comment("B1", "Alice", content_at_limit))
  let content_over_limit = content_at_limit + "y"
  let content_result : Result[Unit, Error] = Ok(
    sheet.add_comment(plain_comment("B2", "Alice", content_over_limit)),
  ) catch {
    error => Err(error)
  }
  inspect(
    content_result is Err(@xlsx.XlsxError::InvalidComment(_)),
    content="true",
  )
  inspect(sheet.comments().length(), content="2")
  inspect(sheet.get_comment("A2") is None, content="true")
  inspect(sheet.get_comment("B2") is None, content="true")
  match sheet.get_comment("A1") {
    Some(comment) => inspect(comment.author == author_at_limit, content="true")
    None => fail("expected author boundary comment")
  }
  match sheet.get_comment("B1") {
    Some(comment) => inspect(comment.text == content_at_limit, content="true")
    None => fail("expected content boundary comment")
  }
  ignore(@xlsx.write(workbook))
}

///|
test "comment XML-invalid fields reject atomically" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let invalid_comments : Array[@xlsx.Comment] = [
    plain_comment("A1", "Ali\u{1}ce", "bad author"),
    plain_comment("A2", "Alice", "bad\u{1} text"),
    {
      cell: "A3",
      author: "Alice",
      author_id: None,
      text: "",
      paragraph: [{ text: "bad\u{1} run", font: None }],
      width: None,
      height: None,
    },
  ]
  for comment in invalid_comments {
    let result : Result[Unit, Error] = Ok(sheet.add_comment(comment)) catch {
      error => Err(error)
    }
    inspect(result is Err(@xlsx.XlsxError::InvalidComment(_)), content="true")
  }
  inspect(sheet.comments().length(), content="0")
}

///|
test "comment rich runs are authoritative and conflicts reject" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let runs : Array[@xlsx.RichTextRun] = [
    { text: "rich", font: None },
    { text: " text", font: None },
  ]
  sheet.add_comment({
    cell: "C3",
    author: "Alice",
    author_id: None,
    text: "",
    paragraph: runs,
    width: None,
    height: None,
  })
  match sheet.get_comment("c3") {
    Some(comment) => inspect(comment.text, content="rich text")
    None => fail("expected normalized rich comment")
  }
  let conflicting : @xlsx.Comment = {
    cell: "D4",
    author: "Alice",
    author_id: None,
    text: "different",
    paragraph: [{ text: "rich", font: None }],
    width: None,
    height: None,
  }
  let result : Result[Unit, Error] = Ok(sheet.add_comment(conflicting)) catch {
    error => Err(error)
  }
  inspect(result is Err(@xlsx.XlsxError::InvalidComment(_)), content="true")
  inspect(sheet.comments().length(), content="1")
}

///|
test "comment replace/get/delete lifecycle is deterministic and atomic" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.add_comment("Sheet1", plain_comment("A1", "A", "one"))
  workbook.add_comment("Sheet1", plain_comment("B2", "B", "two"))
  workbook.replace_comment(
    "Sheet1",
    plain_comment("a1", "Updated", "replacement"),
  )
  let comments = workbook.get_comments("Sheet1")
  inspect(comments.length(), content="2")
  inspect(comments[0].cell, content="A1")
  inspect(comments[0].text, content="replacement")
  inspect(comments[1].cell, content="B2")
  match workbook.get_comment("Sheet1", "a1") {
    Some(comment) => inspect(comment.author, content="Updated")
    None => fail("expected replaced comment")
  }
  let invalid_replace : Result[Unit, Error] = Ok(
    workbook.replace_comment(
      "Sheet1",
      plain_comment("A1", repeat_comment_text("z", 256), "invalid"),
    ),
  ) catch {
    error => Err(error)
  }
  inspect(
    invalid_replace is Err(@xlsx.XlsxError::InvalidComment(_)),
    content="true",
  )
  match workbook.get_comment("Sheet1", "A1") {
    Some(comment) => inspect(comment.text, content="replacement")
    None => fail("expected original replacement after failed update")
  }
  let missing_replace : Result[Unit, Error] = Ok(
    workbook.replace_comment("Sheet1", plain_comment("C3", "C", "missing")),
  ) catch {
    error => Err(error)
  }
  inspect(
    missing_replace is Err(@xlsx.XlsxError::CommentNotFound(_)),
    content="true",
  )
  let missing_delete : Result[Unit, Error] = Ok(
    workbook.delete_comment("Sheet1", "C3"),
  ) catch {
    error => Err(error)
  }
  inspect(
    missing_delete is Err(@xlsx.XlsxError::CommentNotFound(_)),
    content="true",
  )
  inspect(workbook.get_comments("Sheet1").length(), content="2")
  workbook.delete_comment("Sheet1", "B2")
  let remaining = workbook.get_comments("Sheet1")
  inspect(remaining.length(), content="1")
  inspect(remaining[0].cell, content="A1")
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
