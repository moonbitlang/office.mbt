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
test "comment read-modify-write reconciles retained VML shapes" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  let custom_vml = "<xml xmlns:v=\"urn:schemas-microsoft-com:vml\" " +
    "xmlns:x=\"urn:schemas-microsoft-com:office:excel\">" +
    "<meta keep=\"true\"/><v:shape id=\"_x0000_s1026\" " +
    "style=\"position:absolute;width:86pt;height:24pt;visibility:visible\" " +
    "fillcolor=\"#123456\"><x:ClientData ObjectType=\"Note\">" +
    "<x:Anchor>0, 1, 0, 1, 1, 1, 1, 1</x:Anchor>" +
    "<x:Row>0</x:Row><x:Column>0</x:Column>" +
    "</x:ClientData></v:shape><tail keep=\"true\"/></xml>"
  sheet.add_vml_drawing_xml(custom_vml)
  sheet.add_comment(plain_comment("A1", "A", "original"))
  let parsed = @xlsx.read(@xlsx.write(workbook))
  parsed.replace_comment("Sheet1", plain_comment("A1", "B", "replacement"))
  let replaced_bytes = @xlsx.write(parsed)
  let replaced_archive = @zip.read(replaced_bytes)
  let replaced_vml = match replaced_archive.get("xl/drawings/vmlDrawing1.vml") {
    Some(bytes) => @encoding/utf8.decode(bytes)
    None => fail("expected VML drawing after comment replacement")
  }
  let mut note_shapes = -1
  for _ in replaced_vml.split("ObjectType=\"Note\"") {
    note_shapes = note_shapes + 1
  }
  let mut first_shape_ids = -1
  for _ in replaced_vml.split("_x0000_s1026") {
    first_shape_ids = first_shape_ids + 1
  }
  inspect(note_shapes, content="1")
  inspect(first_shape_ids, content="1")
  inspect(
    replaced_vml.contains(
      "style=\"position:absolute;width:86pt;height:24pt;visibility:visible\"",
    ),
    content="true",
  )
  inspect(replaced_vml.contains("fillcolor=\"#123456\""), content="true")
  inspect(replaced_vml.contains("<meta keep=\"true\"/>"), content="true")
  inspect(replaced_vml.contains("<tail keep=\"true\"/>"), content="true")
  match @xlsx.read(replaced_bytes).get_comment("Sheet1", "A1") {
    Some(comment) => inspect(comment.text, content="replacement")
    None => fail("expected replacement comment")
  }

  parsed.delete_comment("Sheet1", "A1")
  let deleted_bytes = @xlsx.write(parsed)
  let deleted_archive = @zip.read(deleted_bytes)
  let deleted_vml = match deleted_archive.get("xl/drawings/vmlDrawing1.vml") {
    Some(bytes) => @encoding/utf8.decode(bytes)
    None => fail("expected retained VML wrapper after comment deletion")
  }
  inspect(deleted_vml.contains("ObjectType=\"Note\""), content="false")
  inspect(
    @xlsx.read(deleted_bytes).get_comment("Sheet1", "A1") is None,
    content="true",
  )
}

///|
#cfg(target="native")
async test "excelize Book1 comment replacement preserves retained VML formatting" {
  let source = @async/fs.read_file("fixtures/excelize/test/Book1.xlsx").binary()
  let workbook = @xlsx.read(source)
  workbook.replace_comment(
    "Sheet1",
    plain_comment("A22", "Reviewer", "replacement"),
  )
  let archive = @zip.read(@xlsx.write(workbook))
  let vml = match archive.get("xl/drawings/vmlDrawing1.vml") {
    Some(bytes) => @encoding/utf8.decode(bytes)
    None => fail("expected Book1 VML drawing")
  }
  inspect(vml.contains("margin-left:43pt;margin-top:345pt"), content="true")
  inspect(vml.contains("width:86pt;height:24pt"), content="true")
  inspect(vml.contains("fillcolor=\"#fbf6d6\""), content="true")
  inspect(vml.contains("strokecolor=\"#edeaa1\""), content="true")
  inspect(vml.contains("<x:Row>21</x:Row>"), content="true")
  inspect(vml.contains("<x:Column>0</x:Column>"), content="true")
  let mut note_shapes = -1
  for _ in vml.split("ObjectType=\"Note\"") {
    note_shapes = note_shapes + 1
  }
  inspect(note_shapes, content="1")
}

///|
test "generated comment and form-control VML IDs do not collide" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_vml_drawing_xml(
    "<xml xmlns:v=\"urn:schemas-microsoft-com:vml\" " +
    "xmlns:x=\"urn:schemas-microsoft-com:office:excel\">" +
    "<v:shape id=\"_x0000_s2047\"></v:shape></xml>",
  )
  sheet.add_comment(plain_comment("A1", "Alice", "note"))
  workbook.add_form_control("Sheet1", @xlsx.FormControl::new("B2", "Button"))
  let archive = @zip.read(@xlsx.write(workbook))
  let vml = match archive.get("xl/drawings/vmlDrawing1.vml") {
    Some(bytes) => @encoding/utf8.decode(bytes)
    None => fail("expected mixed comment/control VML drawing")
  }
  let mut comment_shape_ids = -1
  for _ in vml.split("_x0000_s2048") {
    comment_shape_ids = comment_shape_ids + 1
  }
  let mut control_shape_ids = -1
  for _ in vml.split("_x0000_s2049") {
    control_shape_ids = control_shape_ids + 1
  }
  inspect(comment_shape_ids, content="1")
  inspect(control_shape_ids, content="1")
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
test "comment read APIs return detached rich-text arrays" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_comment({
    cell: "A1",
    author: "Alice",
    author_id: None,
    text: "",
    paragraph: [{ text: "stored", font: None }],
    width: None,
    height: None,
  })

  let single = sheet.get_comment("A1").unwrap()
  single.paragraph.push({ text: "single mutation", font: None })
  let workbook_list = workbook.get_comments("Sheet1")
  workbook_list[0].paragraph.push({ text: "list mutation", font: None })
  let sheet_view = sheet.comments()
  sheet_view[0].paragraph.push({ text: "view mutation", font: None })

  match sheet.get_comment("A1") {
    Some(stored) => {
      inspect(stored.text, content="stored")
      inspect(stored.paragraph.length(), content="1")
    }
    None => fail("expected stored comment")
  }
  ignore(@xlsx.write(workbook))
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
  let invalid_font : @xlsx.RichTextFont = {
    bold: false,
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
    family: Some("invalid\u{0}family"),
  }
  let invalid_font_replace : Result[Unit, Error] = Ok(
    workbook.replace_comment("Sheet1", {
      cell: "A1",
      author: "Updated",
      author_id: None,
      text: "",
      paragraph: [{ text: "invalid", font: Some(invalid_font) }],
      width: None,
      height: None,
    }),
  ) catch {
    error => Err(error)
  }
  inspect(
    invalid_font_replace is Err(@xlsx.XlsxError::InvalidComment(_)),
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
  ignore(@xlsx.write(workbook))
}

///|
test "retained maximum VML shape id round-trips without a successor" {
  let max_shape_id = "_x0000_s2147483647"
  let retained_only_vml = "<xml xmlns:v=\"urn:schemas-microsoft-com:vml\">" +
    "<v:shape id=\"\{max_shape_id}\"></v:shape></xml>"
  let retained_only = @xlsx.Workbook::new()
  retained_only.add_sheet("Sheet1").add_vml_drawing_xml(retained_only_vml)
  let retained_archive = @zip.read(@xlsx.write(retained_only))
  let retained_output = match
    retained_archive.get("xl/drawings/vmlDrawing1.vml") {
    Some(bytes) => @encoding/utf8.decode(bytes)
    None => fail("expected retained-only VML drawing")
  }
  inspect(retained_output == retained_only_vml, content="true")

  let retained_note_vml = "<xml xmlns:v=\"urn:schemas-microsoft-com:vml\" " +
    "xmlns:x=\"urn:schemas-microsoft-com:office:excel\">" +
    "<v:shape id=\"\{max_shape_id}\">" +
    "<x:ClientData ObjectType=\"Note\"><x:Row>0</x:Row>" +
    "<x:Column>0</x:Column></x:ClientData></v:shape></xml>"
  let retained_note = @xlsx.Workbook::new()
  let retained_note_sheet = retained_note.add_sheet("Sheet1")
  retained_note_sheet.add_comment(plain_comment("A1", "Alice", "retained"))
  retained_note_sheet.add_vml_drawing_xml(retained_note_vml)
  let retained_note_archive = @zip.read(@xlsx.write(retained_note))
  let retained_note_output = match
    retained_note_archive.get("xl/drawings/vmlDrawing1.vml") {
    Some(bytes) => @encoding/utf8.decode(bytes)
    None => fail("expected retained-note VML drawing")
  }
  inspect(retained_note_output == retained_note_vml, content="true")
}

///|
test "comment delete rejects malformed retained VML without mutation" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_comment(plain_comment("A1", "Alice", "keep"))
  let malformed_vml = "<xml xmlns:v=\"urn:schemas-microsoft-com:vml\" " +
    "xmlns:x=\"urn:schemas-microsoft-com:office:excel\">" +
    "<v:shape id=\"_x0000_s1025\"><x:ClientData ObjectType=\"Note\">" +
    "<x:Column>0</x:Column></x:ClientData></v:shape></xml>"
  sheet.add_vml_drawing_xml(malformed_vml)
  let result : Result[Unit, Error] = Ok(sheet.delete_comment("A1")) catch {
    error => Err(error)
  }
  inspect(result is Err(@xlsx.XlsxError::InvalidVmlDrawing(_)), content="true")
  match sheet.get_comment("A1") {
    Some(comment) => inspect(comment.text, content="keep")
    None => fail("failed deletion must preserve the comment")
  }
  inspect(sheet.vml_drawing_xml() == Some(malformed_vml), content="true")
}

///|
test "comment delete preserves unrelated self-closing VML shapes" {
  let workbook = @xlsx.Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_comment(plain_comment("A1", "Alice", "remove"))
  sheet.add_vml_drawing_xml(
    "<xml xmlns:v=\"urn:schemas-microsoft-com:vml\" " +
    "xmlns:x=\"urn:schemas-microsoft-com:office:excel\">" +
    "<v:shape id=\"_x0000_s2000\"/>" +
    "<v:shape id=\"_x0000_s1025\"><x:ClientData ObjectType=\"Note\">" +
    "<x:Row>0</x:Row><x:Column>0</x:Column>" +
    "</x:ClientData></v:shape></xml>",
  )
  sheet.delete_comment("A1")
  let retained = sheet.vml_drawing_xml().unwrap()
  inspect(retained.contains("<v:shape id=\"_x0000_s2000\"/>"), content="true")
  inspect(retained.contains("_x0000_s1025"), content="false")
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
