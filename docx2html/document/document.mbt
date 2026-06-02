///|
/// Vertical positioning for text within a run.
pub(all) enum VerticalAlignment {
  Baseline
  Superscript
  Subscript
} derive(Debug, Eq)

///|
/// Kind of break represented in the document model.
pub(all) enum BreakType {
  Line
  Page
  Column
} derive(Debug, Eq)

///|
/// List numbering metadata attached to a paragraph.
pub(all) struct Numbering {
  is_ordered : Bool
  level : Int
} derive(Debug, Eq)

///|
/// Builds paragraph numbering metadata.
pub fn numbering(is_ordered : Bool, level : Int) -> Numbering {
  { is_ordered, level }
}

///|
/// Paragraph indentation values from WordprocessingML.
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
/// Builds paragraph indentation metadata.
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
/// Returns empty indentation metadata.
pub fn Indent::default() -> Indent {
  indent()
}

///|
/// Formatting metadata attached to a paragraph.
pub(all) struct ParagraphProperties {
  style_id : String?
  style_name : String?
  numbering : Numbering?
  alignment : String?
  indent : Indent
} derive(Debug, Eq)

///|
/// Builds paragraph formatting metadata.
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
/// Returns default paragraph formatting metadata.
pub fn ParagraphProperties::default() -> ParagraphProperties {
  paragraph_properties()
}

///|
/// Formatting metadata attached to a run.
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
/// Builds run formatting metadata.
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
/// Returns default run formatting metadata.
pub fn RunProperties::default() -> RunProperties {
  run_properties()
}

///|
/// Formatting metadata attached to a table.
pub(all) struct TableProperties {
  style_id : String?
  style_name : String?
} derive(Debug, Eq)

///|
/// Builds table formatting metadata.
pub fn table_properties(
  style_id? : String? = None,
  style_name? : String? = None,
) -> TableProperties {
  { style_id: none_if_empty(style_id), style_name: none_if_empty(style_name) }
}

///|
/// Returns default table formatting metadata.
pub fn TableProperties::default() -> TableProperties {
  table_properties()
}

///|
/// Footnote or endnote content in the document model.
pub(all) struct Note {
  note_type : String
  note_id : String
  body : Array[DocumentElement]
} derive(Debug, Eq)

///|
/// Word comment metadata and body content.
pub(all) struct Comment {
  comment_id : String
  body : Array[DocumentElement]
  author_name : String
  author_initials : String
} derive(Debug, Eq)

///|
/// Image payload and metadata read from a DOCX package.
pub(all) struct Image {
  content_type : String
  alt_text : String?
  data : Bytes
} derive(Debug, Eq)

///|
/// Node in the Mammoth-style document tree.
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
/// Builds a document element.
pub fn document(
  children : Array[DocumentElement],
  notes? : Array[Note] = [],
  comments? : Array[Comment] = [],
) -> DocumentElement {
  Document(children~, notes~, comments~)
}

///|
/// Builds a paragraph element.
pub fn paragraph(
  children : Array[DocumentElement],
  properties? : ParagraphProperties = ParagraphProperties::default(),
) -> DocumentElement {
  Paragraph(children~, properties~)
}

///|
/// Builds a run element.
pub fn run(
  children : Array[DocumentElement],
  properties? : RunProperties = RunProperties::default(),
) -> DocumentElement {
  Run(children~, properties~)
}

///|
/// Builds a text element.
pub fn text(value : String) -> DocumentElement {
  Text(value)
}

///|
/// Builds a tab element.
pub fn tab() -> DocumentElement {
  Tab
}

///|
/// Builds a checkbox element.
pub fn checkbox(checked : Bool) -> DocumentElement {
  Checkbox(checked)
}

///|
/// Builds a hyperlink element.
pub fn hyperlink(
  children : Array[DocumentElement],
  href? : String? = None,
  anchor? : String? = None,
  target_frame? : String? = None,
) -> DocumentElement {
  Hyperlink(children~, href~, anchor~, target_frame~)
}

///|
/// Builds a note-reference element.
pub fn note_reference(note_type : String, note_id : String) -> DocumentElement {
  NoteReference(note_type~, note_id~)
}

///|
/// Builds a comment-reference element.
pub fn comment_reference(comment_id : String) -> DocumentElement {
  CommentReference(comment_id)
}

///|
/// Builds an image element.
pub fn image(
  content_type : String,
  data : Bytes,
  alt_text? : String? = None,
) -> DocumentElement {
  Image({ content_type, alt_text, data })
}

///|
/// Builds a table element.
pub fn table(
  children : Array[DocumentElement],
  properties? : TableProperties = TableProperties::default(),
) -> DocumentElement {
  Table(children~, properties~)
}

///|
/// Builds a table-row element.
pub fn table_row(
  children : Array[DocumentElement],
  is_header? : Bool = false,
) -> DocumentElement {
  TableRow(children~, is_header~)
}

///|
/// Builds a table-cell element.
pub fn table_cell(
  children : Array[DocumentElement],
  col_span? : Int = 1,
  row_span? : Int = 1,
) -> DocumentElement {
  TableCell(children~, col_span~, row_span~)
}

///|
/// Builds a bookmark-start element.
pub fn bookmark_start(name : String) -> DocumentElement {
  BookmarkStart(name)
}

///|
/// Builds a footnote or endnote.
pub fn note(
  note_type : String,
  note_id : String,
  body : Array[DocumentElement],
) -> Note {
  { note_type, note_id, body }
}

///|
/// Builds a document comment.
pub fn comment(
  comment_id : String,
  body : Array[DocumentElement],
  author_name? : String = "",
  author_initials? : String = "",
) -> Comment {
  { comment_id, body, author_name, author_initials }
}

///|
/// Builds a line-break element.
pub fn line_break() -> DocumentElement {
  Break(Line)
}

///|
/// Builds a page-break element.
pub fn page_break() -> DocumentElement {
  Break(Page)
}

///|
/// Builds a column-break element.
pub fn column_break() -> DocumentElement {
  Break(Column)
}
