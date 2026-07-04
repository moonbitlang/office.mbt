///|
/// Vertical positioning for text within a run.
pub type VerticalAlignment = @document.VerticalAlignment

///|
/// Kind of break represented in the document model.
pub type BreakType = @document.BreakType

///|
/// List numbering metadata attached to a paragraph.
pub type Numbering = @document.Numbering

///|
/// Paragraph indentation values from WordprocessingML.
pub type Indent = @document.Indent

///|
/// Formatting metadata attached to a paragraph.
pub type ParagraphProperties = @document.ParagraphProperties

///|
/// Formatting metadata attached to a run.
pub type RunProperties = @document.RunProperties

///|
/// Formatting metadata attached to a table.
pub type TableProperties = @document.TableProperties

///|
/// Footnote or endnote content in the document model.
pub type Note = @document.Note

///|
/// Word comment metadata and body content.
pub type Comment = @document.Comment

///|
/// Image payload and metadata read from a DOCX package.
pub type Image = @document.Image

///|
/// Node in the Mammoth-style document tree.
pub type DocumentElement = @document.DocumentElement

///|
/// Builds paragraph numbering metadata.
pub fn numbering(is_ordered : Bool, level : Int) -> Numbering {
  @document.numbering(is_ordered, level)
}

///|
/// Builds paragraph indentation metadata.
pub fn indent(
  start? : String? = None,
  end? : String? = None,
  first_line? : String? = None,
  hanging? : String? = None,
) -> Indent {
  @document.indent(start~, end~, first_line~, hanging~)
}

///|
/// Builds paragraph formatting metadata.
pub fn paragraph_properties(
  style_id? : String? = None,
  style_name? : String? = None,
  numbering? : Numbering? = None,
  alignment? : String? = None,
  indent? : Indent = @document.Indent::default(),
) -> ParagraphProperties {
  @document.paragraph_properties(
    style_id~,
    style_name~,
    numbering~,
    alignment~,
    indent~,
  )
}

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
  @document.run_properties(
    style_id~,
    style_name~,
    is_bold~,
    is_underline~,
    is_italic~,
    is_strikethrough~,
    is_all_caps~,
    is_small_caps~,
    vertical_alignment~,
    font~,
    font_size~,
    highlight~,
  )
}

///|
/// Builds table formatting metadata.
pub fn table_properties(
  style_id? : String? = None,
  style_name? : String? = None,
) -> TableProperties {
  @document.table_properties(style_id~, style_name~)
}

///|
/// Builds a document element.
pub fn document(
  children : Array[DocumentElement],
  notes? : Array[Note] = [],
  comments? : Array[Comment] = [],
) -> DocumentElement {
  @document.document(children, notes~, comments~)
}

///|
/// Builds a paragraph element.
pub fn paragraph(
  children : Array[DocumentElement],
  properties? : ParagraphProperties = @document.ParagraphProperties::default(),
) -> DocumentElement {
  @document.paragraph(children, properties~)
}

///|
/// Builds a run element.
pub fn run(
  children : Array[DocumentElement],
  properties? : RunProperties = @document.RunProperties::default(),
) -> DocumentElement {
  @document.run(children, properties~)
}

///|
/// Builds a text element.
pub fn text(value : String) -> DocumentElement {
  @document.text(value)
}

///|
/// Builds a tab element.
pub fn tab() -> DocumentElement {
  @document.tab()
}

///|
/// Builds a checkbox element.
pub fn checkbox(checked : Bool) -> DocumentElement {
  @document.checkbox(checked)
}

///|
/// Builds a hyperlink element.
pub fn hyperlink(
  children : Array[DocumentElement],
  href? : String? = None,
  anchor? : String? = None,
  target_frame? : String? = None,
) -> DocumentElement {
  @document.hyperlink(children, href~, anchor~, target_frame~)
}

///|
/// Builds a note-reference element.
pub fn note_reference(note_type : String, note_id : String) -> DocumentElement {
  @document.note_reference(note_type, note_id)
}

///|
/// Builds a comment-reference element.
pub fn comment_reference(comment_id : String) -> DocumentElement {
  @document.comment_reference(comment_id)
}

///|
/// Builds an image element.
pub fn image(
  content_type : String,
  data : Bytes,
  alt_text? : String? = None,
) -> DocumentElement {
  @document.image(content_type, data, alt_text~)
}

///|
/// Builds a table element.
pub fn table(
  children : Array[DocumentElement],
  properties? : TableProperties = @document.TableProperties::default(),
) -> DocumentElement {
  @document.table(children, properties~)
}

///|
/// Builds a table-row element.
pub fn table_row(
  children : Array[DocumentElement],
  is_header? : Bool = false,
) -> DocumentElement {
  @document.table_row(children, is_header~)
}

///|
/// Builds a table-cell element.
pub fn table_cell(
  children : Array[DocumentElement],
  col_span? : Int = 1,
  row_span? : Int = 1,
) -> DocumentElement {
  @document.table_cell(children, col_span~, row_span~)
}

///|
/// Builds a bookmark-start element.
pub fn bookmark_start(name : String) -> DocumentElement {
  @document.bookmark_start(name)
}

///|
/// Builds a footnote or endnote.
pub fn note(
  note_type : String,
  note_id : String,
  body : Array[DocumentElement],
) -> Note {
  @document.note(note_type, note_id, body)
}

///|
/// Builds a document comment.
pub fn comment(
  comment_id : String,
  body : Array[DocumentElement],
  author_name? : String = "",
  author_initials? : String = "",
) -> Comment {
  @document.comment(comment_id, body, author_name~, author_initials~)
}

///|
/// Builds a line-break element.
pub fn line_break() -> DocumentElement {
  @document.line_break()
}

///|
/// Builds a page-break element.
pub fn page_break() -> DocumentElement {
  @document.page_break()
}

///|
/// Builds a column-break element.
pub fn column_break() -> DocumentElement {
  @document.column_break()
}
