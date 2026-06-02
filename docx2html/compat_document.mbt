///|
pub type VerticalAlignment = @document.VerticalAlignment

///|
pub type BreakType = @document.BreakType

///|
pub type Numbering = @document.Numbering

///|
pub type Indent = @document.Indent

///|
pub type ParagraphProperties = @document.ParagraphProperties

///|
pub type RunProperties = @document.RunProperties

///|
pub type TableProperties = @document.TableProperties

///|
pub type Note = @document.Note

///|
pub type Comment = @document.Comment

///|
pub type Image = @document.Image

///|
pub type DocumentElement = @document.DocumentElement

///|
pub fn numbering(is_ordered : Bool, level : Int) -> Numbering {
  @document.numbering(is_ordered, level)
}

///|
pub fn indent(
  start? : String? = None,
  end? : String? = None,
  first_line? : String? = None,
  hanging? : String? = None,
) -> Indent {
  @document.indent(start~, end~, first_line~, hanging~)
}

///|
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
pub fn table_properties(
  style_id? : String? = None,
  style_name? : String? = None,
) -> TableProperties {
  @document.table_properties(style_id~, style_name~)
}

///|
pub fn document(
  children : Array[DocumentElement],
  notes? : Array[Note] = [],
  comments? : Array[Comment] = [],
) -> DocumentElement {
  @document.document(children, notes~, comments~)
}

///|
pub fn paragraph(
  children : Array[DocumentElement],
  properties? : ParagraphProperties = @document.ParagraphProperties::default(),
) -> DocumentElement {
  @document.paragraph(children, properties~)
}

///|
pub fn run(
  children : Array[DocumentElement],
  properties? : RunProperties = @document.RunProperties::default(),
) -> DocumentElement {
  @document.run(children, properties~)
}

///|
pub fn text(value : String) -> DocumentElement {
  @document.text(value)
}

///|
pub fn tab() -> DocumentElement {
  @document.tab()
}

///|
pub fn checkbox(checked : Bool) -> DocumentElement {
  @document.checkbox(checked)
}

///|
pub fn hyperlink(
  children : Array[DocumentElement],
  href? : String? = None,
  anchor? : String? = None,
  target_frame? : String? = None,
) -> DocumentElement {
  @document.hyperlink(children, href~, anchor~, target_frame~)
}

///|
pub fn note_reference(note_type : String, note_id : String) -> DocumentElement {
  @document.note_reference(note_type, note_id)
}

///|
pub fn comment_reference(comment_id : String) -> DocumentElement {
  @document.comment_reference(comment_id)
}

///|
pub fn image(
  content_type : String,
  data : Bytes,
  alt_text? : String? = None,
) -> DocumentElement {
  @document.image(content_type, data, alt_text~)
}

///|
pub fn table(
  children : Array[DocumentElement],
  properties? : TableProperties = @document.TableProperties::default(),
) -> DocumentElement {
  @document.table(children, properties~)
}

///|
pub fn table_row(
  children : Array[DocumentElement],
  is_header? : Bool = false,
) -> DocumentElement {
  @document.table_row(children, is_header~)
}

///|
pub fn table_cell(
  children : Array[DocumentElement],
  col_span? : Int = 1,
  row_span? : Int = 1,
) -> DocumentElement {
  @document.table_cell(children, col_span~, row_span~)
}

///|
pub fn bookmark_start(name : String) -> DocumentElement {
  @document.bookmark_start(name)
}

///|
pub fn note(
  note_type : String,
  note_id : String,
  body : Array[DocumentElement],
) -> Note {
  @document.note(note_type, note_id, body)
}

///|
pub fn comment(
  comment_id : String,
  body : Array[DocumentElement],
  author_name? : String = "",
  author_initials? : String = "",
) -> Comment {
  @document.comment(comment_id, body, author_name~, author_initials~)
}

///|
pub fn line_break() -> DocumentElement {
  @document.line_break()
}

///|
pub fn page_break() -> DocumentElement {
  @document.page_break()
}

///|
pub fn column_break() -> DocumentElement {
  @document.column_break()
}
