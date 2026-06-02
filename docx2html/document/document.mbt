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
pub fn numbering(is_ordered : Bool, level : Int) -> Numbering {
  { is_ordered, level }
}

///|
pub(all) struct Indent {
  start : String?
  end : String?
  first_line : String?
  hanging : String?
} derive(Debug, Eq)

///|
fn none_if_empty(value : String?) -> String? {
  match value {
    Some(text) => if text == "" { None } else { Some(text) }
    None => None
  }
}

///|
pub fn indent(
  start? : String? = None,
  end? : String? = None,
  first_line? : String? = None,
  hanging? : String? = None,
) -> Indent {
  {
    start: none_if_empty(start),
    end: none_if_empty(end),
    first_line: none_if_empty(first_line),
    hanging: none_if_empty(hanging),
  }
}

///|
pub fn Indent::default() -> Indent {
  indent()
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
pub fn paragraph_properties(
  style_id? : String? = None,
  style_name? : String? = None,
  numbering? : Numbering? = None,
  alignment? : String? = None,
  indent? : Indent = Indent::default(),
) -> ParagraphProperties {
  {
    style_id: none_if_empty(style_id),
    style_name: none_if_empty(style_name),
    numbering,
    alignment: none_if_empty(alignment),
    indent,
  }
}

///|
pub fn ParagraphProperties::default() -> ParagraphProperties {
  paragraph_properties()
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
pub fn run_properties(
  style_id? : String? = None,
  style_name? : String? = None,
  is_bold? : Bool = false,
  is_underline? : Bool = false,
  is_italic? : Bool = false,
  is_strikethrough? : Bool = false,
  is_all_caps? : Bool = false,
  is_small_caps? : Bool = false,
  vertical_alignment? : VerticalAlignment = Baseline,
  font? : String? = None,
  font_size? : Int? = None,
  highlight? : String? = None,
) -> RunProperties {
  {
    style_id: none_if_empty(style_id),
    style_name: none_if_empty(style_name),
    is_bold,
    is_underline,
    is_italic,
    is_strikethrough,
    is_all_caps,
    is_small_caps,
    vertical_alignment,
    font: none_if_empty(font),
    font_size,
    highlight: none_if_empty(highlight),
  }
}

///|
pub fn RunProperties::default() -> RunProperties {
  run_properties()
}

///|
pub(all) struct TableProperties {
  style_id : String?
  style_name : String?
} derive(Debug, Eq)

///|
pub fn table_properties(
  style_id? : String? = None,
  style_name? : String? = None,
) -> TableProperties {
  { style_id: none_if_empty(style_id), style_name: none_if_empty(style_name) }
}

///|
pub fn TableProperties::default() -> TableProperties {
  table_properties()
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
