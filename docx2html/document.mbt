///|
pub(all) enum VerticalAlignment {
  Baseline
  Superscript
  Subscript
} derive(Debug, Eq)

///|
pub(all) enum BreakType {
  Line
  Page
  Column
} derive(Debug, Eq)

///|
pub(all) struct Numbering {
  is_ordered : Bool
  level : Int
} derive(Debug, Eq)

///|
pub(all) struct Indent {
  start : String?
  end : String?
  first_line : String?
  hanging : String?
} derive(Debug, Eq)

///|
pub fn Indent::default() -> Indent {
  { start: None, end: None, first_line: None, hanging: None }
}

///|
pub(all) struct ParagraphProperties {
  style_id : String?
  style_name : String?
  numbering : Numbering?
  alignment : String?
  indent : Indent
} derive(Debug, Eq)

///|
pub fn ParagraphProperties::default() -> ParagraphProperties {
  {
    style_id: None,
    style_name: None,
    numbering: None,
    alignment: None,
    indent: Indent::default(),
  }
}

///|
pub(all) struct RunProperties {
  style_id : String?
  style_name : String?
  is_bold : Bool
  is_underline : Bool
  is_italic : Bool
  is_strikethrough : Bool
  is_all_caps : Bool
  is_small_caps : Bool
  vertical_alignment : VerticalAlignment
  font : String?
  font_size : Int?
  highlight : String?
} derive(Debug, Eq)

///|
pub fn RunProperties::default() -> RunProperties {
  {
    style_id: None,
    style_name: None,
    is_bold: false,
    is_underline: false,
    is_italic: false,
    is_strikethrough: false,
    is_all_caps: false,
    is_small_caps: false,
    vertical_alignment: Baseline,
    font: None,
    font_size: None,
    highlight: None,
  }
}

///|
pub(all) struct TableProperties {
  style_id : String?
  style_name : String?
} derive(Debug, Eq)

///|
pub fn TableProperties::default() -> TableProperties {
  { style_id: None, style_name: None }
}

///|
pub(all) struct Note {
  note_type : String
  note_id : String
  body : Array[DocumentElement]
} derive(Debug, Eq)

///|
pub(all) struct Comment {
  comment_id : String
  body : Array[DocumentElement]
  author_name : String
  author_initials : String
} derive(Debug, Eq)

///|
pub(all) struct Image {
  content_type : String
  alt_text : String?
  data : Bytes
} derive(Debug, Eq)

///|
pub(all) enum DocumentElement {
  Document(
    children~ : Array[DocumentElement],
    notes~ : Array[Note],
    comments~ : Array[Comment]
  )
  Paragraph(
    children~ : Array[DocumentElement],
    properties~ : ParagraphProperties
  )
  Run(children~ : Array[DocumentElement], properties~ : RunProperties)
  Text(String)
  Tab
  Checkbox(Bool)
  Hyperlink(
    children~ : Array[DocumentElement],
    href~ : String?,
    anchor~ : String?,
    target_frame~ : String?
  )
  NoteReference(note_type~ : String, note_id~ : String)
  CommentReference(String)
  Image(Image)
  Table(children~ : Array[DocumentElement], properties~ : TableProperties)
  TableRow(children~ : Array[DocumentElement], is_header~ : Bool)
  TableCell(
    children~ : Array[DocumentElement],
    col_span~ : Int,
    row_span~ : Int
  )
  Break(BreakType)
  BookmarkStart(String)
} derive(Debug, Eq)

///|
pub fn document(
  children : Array[DocumentElement],
  notes? : Array[Note] = [],
  comments? : Array[Comment] = [],
) -> DocumentElement {
  Document(children~, notes~, comments~)
}

///|
pub fn paragraph(
  children : Array[DocumentElement],
  properties? : ParagraphProperties = ParagraphProperties::default(),
) -> DocumentElement {
  Paragraph(children~, properties~)
}

///|
pub fn run(
  children : Array[DocumentElement],
  properties? : RunProperties = RunProperties::default(),
) -> DocumentElement {
  Run(children~, properties~)
}

///|
pub fn text(value : String) -> DocumentElement {
  Text(value)
}

///|
pub fn tab() -> DocumentElement {
  Tab
}

///|
pub fn checkbox(checked : Bool) -> DocumentElement {
  Checkbox(checked)
}

///|
pub fn hyperlink(
  children : Array[DocumentElement],
  href? : String? = None,
  anchor? : String? = None,
  target_frame? : String? = None,
) -> DocumentElement {
  Hyperlink(children~, href~, anchor~, target_frame~)
}

///|
pub fn note_reference(note_type : String, note_id : String) -> DocumentElement {
  NoteReference(note_type~, note_id~)
}

///|
pub fn comment_reference(comment_id : String) -> DocumentElement {
  CommentReference(comment_id)
}

///|
pub fn image(
  content_type : String,
  data : Bytes,
  alt_text? : String? = None,
) -> DocumentElement {
  Image({ content_type, alt_text, data })
}

///|
pub fn table(
  children : Array[DocumentElement],
  properties? : TableProperties = TableProperties::default(),
) -> DocumentElement {
  Table(children~, properties~)
}

///|
pub fn table_row(
  children : Array[DocumentElement],
  is_header? : Bool = false,
) -> DocumentElement {
  TableRow(children~, is_header~)
}

///|
pub fn table_cell(
  children : Array[DocumentElement],
  col_span? : Int = 1,
  row_span? : Int = 1,
) -> DocumentElement {
  TableCell(children~, col_span~, row_span~)
}

///|
pub fn bookmark_start(name : String) -> DocumentElement {
  BookmarkStart(name)
}

///|
pub fn note(
  note_type : String,
  note_id : String,
  body : Array[DocumentElement],
) -> Note {
  { note_type, note_id, body }
}

///|
pub fn comment(
  comment_id : String,
  body : Array[DocumentElement],
  author_name? : String = "",
  author_initials? : String = "",
) -> Comment {
  { comment_id, body, author_name, author_initials }
}

///|
pub fn line_break() -> DocumentElement {
  Break(Line)
}

///|
pub fn page_break() -> DocumentElement {
  Break(Page)
}

///|
pub fn column_break() -> DocumentElement {
  Break(Column)
}
