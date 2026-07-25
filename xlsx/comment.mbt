///|
pub(all) struct Comment {
  cell : String
  author : String
  author_id : Int?
  text : String
  paragraph : Array[RichTextRun]
  width : Int?
  height : Int?
} derive(Debug)

///|
fn clone_comment(comment : Comment) -> Comment {
  let paragraph : Array[RichTextRun] = []
  for run in comment.paragraph {
    paragraph.push(run)
  }
  {
    cell: comment.cell,
    author: comment.author,
    author_id: comment.author_id,
    text: comment.text,
    paragraph,
    width: comment.width,
    height: comment.height,
  }
}

///|
let max_comment_author_chars = 255

///|
let max_comment_content_chars = 32767

///|
fn validate_comment_xml_text(
  value : StringView,
  field : StringView,
) -> Unit raise XlsxError {
  for character in value {
    if !is_valid_xml_output_character(character) {
      raise InvalidComment(
        msg="\{field} contains forbidden XML code point \{character.to_int()}",
      )
    }
  }
}

///|
fn validate_comment_rich_text_font(font : RichTextFont) -> Unit raise XlsxError {
  match font.underline {
    Some(value) => validate_comment_xml_text(value, "comment font underline")
    None => ()
  }
  match font.color {
    Some(value) => validate_comment_xml_text(value, "comment font color")
    None => ()
  }
  match font.scheme {
    Some(value) => validate_comment_xml_text(value, "comment font scheme")
    None => ()
  }
  match font.vert_align {
    Some(value) => validate_comment_xml_text(value, "comment font vert_align")
    None => ()
  }
  match font.family {
    Some(value) => validate_comment_xml_text(value, "comment font family")
    None => ()
  }
}

///|
fn comment_rich_text_value(runs : ArrayView[RichTextRun]) -> String {
  let text = StringBuilder::new()
  for run in runs {
    text.write_view(run.text)
  }
  text.to_string()
}

///|
fn normalize_comment(comment : Comment) -> Comment raise XlsxError {
  let (row, col) = cell_ref_to_rc(comment.cell)
  let cell = cell_ref_from(row, col)
  let author = if comment.author == "" { "Author" } else { comment.author }
  validate_comment_xml_text(author, "comment author")
  let author_units = count_utf16_units(author)
  if author_units > max_comment_author_chars {
    raise InvalidComment(
      msg="comment author exceeds \{max_comment_author_chars} UTF-16 units " +
        "(actual \{author_units})",
    )
  }
  validate_comment_xml_text(comment.text, "comment text")
  let paragraph : Array[RichTextRun] = []
  for run in comment.paragraph {
    validate_comment_xml_text(run.text, "comment rich-text run")
    match run.font {
      Some(font) => validate_comment_rich_text_font(font)
      None => ()
    }
    paragraph.push(run)
  }
  let rich_text = comment_rich_text_value(paragraph)
  let text = if paragraph.length() == 0 {
    comment.text
  } else {
    if comment.text != "" && comment.text != rich_text {
      raise InvalidComment(
        msg="comment text must be empty or exactly match the concatenated " +
          "rich-text runs",
      )
    }
    rich_text
  }
  let content_units = count_utf16_units(text)
  if content_units > max_comment_content_chars {
    raise InvalidComment(
      msg="comment content exceeds \{max_comment_content_chars} UTF-16 units " +
        "(actual \{content_units})",
    )
  }
  {
    cell,
    author,
    author_id: comment.author_id,
    text,
    paragraph,
    width: comment.width,
    height: comment.height,
  }
}
