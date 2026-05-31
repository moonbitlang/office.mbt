///|
pub(all) struct Relationship {
  id : String
  relationship_type : String
  target : String
  target_mode : String?
} derive(Debug, Eq)

///|
pub(all) struct Relationships {
  relationships : Array[Relationship]
} derive(Debug, Eq)

///|
pub(all) struct StyleInfo {
  style_id : String
  style_type : String
  name : String
} derive(Debug, Eq)

///|
pub(all) struct ContentTypes {
  defaults : Map[String, String]
  overrides : Map[String, String]
} derive(Debug, Eq)

///|
pub fn convert_to_html(
  docx : BytesView,
  style_map? : Array[String] = [],
  include_default_style_map? : Bool = true,
  include_embedded_style_map? : Bool = true,
  ignore_empty_paragraphs? : Bool = true,
  id_prefix? : String = "",
  pretty_print? : Bool = false,
) -> ConversionResult raise DocxError {
  let zip = open_zip(docx)
  let document = read_docx_zip(zip)
  let style_map = combine_docx_style_maps_from_zip(
    zip,
    style_map,
    include_embedded_style_map~,
  )
  convert_document_to_html(
    document,
    style_map~,
    include_default_style_map~,
    ignore_empty_paragraphs~,
    id_prefix~,
    pretty_print~,
  )
}

///|
pub fn convert_to_markdown(
  docx : BytesView,
  style_map? : Array[String] = [],
  include_default_style_map? : Bool = true,
  include_embedded_style_map? : Bool = true,
) -> ConversionResult raise DocxError {
  let zip = open_zip(docx)
  let document = read_docx_zip(zip)
  let style_map = combine_docx_style_maps_from_zip(
    zip,
    style_map,
    include_embedded_style_map~,
  )
  convert_document_to_markdown(document, style_map~, include_default_style_map~)
}

///|
pub fn extract_raw_text(docx : BytesView) -> ConversionResult raise DocxError {
  extract_raw_text_from_document(read_docx(docx))
}

///|
pub fn read_embedded_style_map(docx : BytesView) -> String? raise DocxError {
  read_embedded_style_map_from_zip(open_zip(docx))
}

///|
fn combine_docx_style_maps_from_zip(
  zip : ZipArchive,
  explicit_style_map : Array[String],
  include_embedded_style_map~ : Bool,
) -> Array[String] raise DocxError {
  let combined : Array[String] = []
  combined.append(explicit_style_map)
  if include_embedded_style_map {
    match read_embedded_style_map_from_zip(zip) {
      Some(style_map) => combined.append(read_style_map_string(style_map))
      None => ()
    }
  }
  combined
}

///|
fn read_embedded_style_map_from_zip(
  zip : ZipArchive,
) -> String? raise DocxError {
  zip.read_text("mammoth/style-map")
}

///|
pub fn read_docx(docx : BytesView) -> DocumentElement raise DocxError {
  read_docx_zip(open_zip(docx))
}

///|
fn read_docx_zip(zip : ZipArchive) -> DocumentElement raise DocxError {
  let main_document_path = find_main_document_path(zip)
  let relationships = read_relationships(
    zip,
    relationships_path_for_part(main_document_path),
  )
  let content_types = read_content_types(zip)
  let styles = read_styles(zip, "word/styles.xml")
  let base_path = split_zip_path(main_document_path).0
  let notes = read_notes_for_document(
    zip, styles, content_types, relationships, base_path,
  )
  let comments = read_comments_for_document(
    zip, styles, content_types, relationships, base_path,
  )
  let xml = read_xml_part(zip, main_document_path)
  read_document_xml(
    xml, styles, zip, relationships, content_types, base_path, notes, comments,
  )
}

///|
fn read_xml_part(zip : ZipArchive, path : String) -> XmlElement raise DocxError {
  match zip.read_text(path) {
    Some(text) => read_xml_string(text, namespace_map=office_namespace_map())
    None => raise MissingPart(message="missing DOCX part: " + path)
  }
}

///|
fn office_namespace_map() -> Map[String, String] {
  {
    "http://schemas.openxmlformats.org/wordprocessingml/2006/main": "w",
    "http://purl.oclc.org/ooxml/wordprocessingml/main": "w",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships": "r",
    "http://purl.oclc.org/ooxml/officeDocument/relationships": "r",
    "http://schemas.openxmlformats.org/package/2006/relationships": "",
    "http://schemas.openxmlformats.org/package/2006/content-types": "",
    "http://schemas.openxmlformats.org/markup-compatibility/2006": "mc",
    "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing": "wp",
    "http://schemas.openxmlformats.org/drawingml/2006/main": "a",
    "http://schemas.openxmlformats.org/drawingml/2006/picture": "pic",
    "http://schemas.microsoft.com/office/word/2010/wordml": "wordml",
    "urn:schemas-microsoft-com:vml": "v",
  }
}

///|
fn find_main_document_path(zip : ZipArchive) -> String raise DocxError {
  let relationships = read_relationships(zip, "_rels/.rels")
  match
    relationships.find_target_by_type(
      "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    ) {
    Some(target) => {
      let normalized = strip_leading_slash(join_zip_path(["", target]))
      if zip.exists(normalized) {
        normalized
      } else if zip.exists("word/document.xml") {
        "word/document.xml"
      } else {
        raise MissingPart(
          message="Could not find main document part. Are you sure this is a valid .docx file?",
        )
      }
    }
    None =>
      if zip.exists("word/document.xml") {
        "word/document.xml"
      } else {
        raise MissingPart(
          message="Could not find main document part. Are you sure this is a valid .docx file?",
        )
      }
  }
}

///|
fn strip_leading_slash(path : String) -> String {
  if path.has_prefix("/") {
    path[1:].to_owned()
  } else {
    path
  }
}

///|
fn read_relationships(
  zip : ZipArchive,
  path : String,
) -> Relationships raise DocxError {
  match zip.read_text(path) {
    Some(text) =>
      read_relationships_xml(
        read_xml_string(text, namespace_map=office_namespace_map()),
      )
    None => { relationships: [] }
  }
}

///|
fn read_relationships_xml(root : XmlElement) -> Relationships {
  let relationships : Array[Relationship] = []
  for rel in root.elements_by_tag_name("Relationship") {
    relationships.push({
      id: rel.attributes.get_or_default("Id", ""),
      relationship_type: rel.attributes.get_or_default("Type", ""),
      target: rel.attributes.get_or_default("Target", ""),
      target_mode: rel.attributes.get("TargetMode"),
    })
  }
  { relationships, }
}

///|
fn Relationships::find_target_by_type(
  self : Relationships,
  relationship_type : String,
) -> String? {
  for rel in self.relationships {
    if rel.relationship_type == relationship_type {
      return Some(rel.target)
    }
  }
  None
}

///|
fn Relationships::find_target_by_id(
  self : Relationships,
  id : String,
) -> String? {
  for rel in self.relationships {
    if rel.id == id {
      return Some(rel.target)
    }
  }
  None
}

///|
fn Relationships::find_by_id(
  self : Relationships,
  id : String,
) -> Relationship? {
  for rel in self.relationships {
    if rel.id == id {
      return Some(rel)
    }
  }
  None
}

///|
fn relationships_path_for_part(path : String) -> String {
  let (dir, base) = split_zip_path(path)
  join_zip_path([dir, "_rels", base + ".rels"])
}

///|
fn read_content_types(zip : ZipArchive) -> ContentTypes raise DocxError {
  let defaults : Map[String, String] = {}
  let overrides : Map[String, String] = {}
  match zip.read_text("[Content_Types].xml") {
    Some(text) => {
      let root = read_xml_string(text, namespace_map=office_namespace_map())
      for element in root.elements_by_tag_name("Default") {
        let extension = element.attributes.get_or_default("Extension", "")
        let content_type = element.attributes.get_or_default("ContentType", "")
        if extension != "" && content_type != "" {
          defaults[extension] = content_type
        }
      }
      for element in root.elements_by_tag_name("Override") {
        let part_name = element.attributes.get_or_default("PartName", "")
        let content_type = element.attributes.get_or_default("ContentType", "")
        if part_name != "" && content_type != "" {
          overrides[strip_leading_slash(part_name)] = content_type
        }
      }
    }
    None => ()
  }
  { defaults, overrides }
}

///|
fn ContentTypes::find_content_type(
  self : ContentTypes,
  path : String,
) -> String {
  let normalized = strip_leading_slash(path)
  match self.overrides.get(normalized) {
    Some(content_type) => content_type
    None =>
      match normalized.rev_find(".") {
        Some(index) =>
          self.defaults.get_or_default(normalized[index + 1:].to_owned(), "")
        None => ""
      }
  }
}

///|
fn read_notes_for_document(
  zip : ZipArchive,
  styles : Map[String, StyleInfo],
  content_types : ContentTypes,
  document_relationships : Relationships,
  base_path : String,
) -> Array[Note] raise DocxError {
  let notes : Array[Note] = []
  notes.append(
    read_note_part(
      zip,
      note_type="footnote",
      relationship_type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes",
      fallback_path=join_zip_path([base_path, "footnotes.xml"]),
      styles~,
      content_types~,
      document_relationships~,
      base_path~,
    ),
  )
  notes.append(
    read_note_part(
      zip,
      note_type="endnote",
      relationship_type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/endnotes",
      fallback_path=join_zip_path([base_path, "endnotes.xml"]),
      styles~,
      content_types~,
      document_relationships~,
      base_path~,
    ),
  )
  notes
}

///|
fn read_note_part(
  zip : ZipArchive,
  note_type~ : String,
  relationship_type~ : String,
  fallback_path~ : String,
  styles~ : Map[String, StyleInfo],
  content_types~ : ContentTypes,
  document_relationships~ : Relationships,
  base_path~ : String,
) -> Array[Note] raise DocxError {
  let path = match
    document_relationships.find_target_by_type(relationship_type) {
    Some(target) => resolve_part_target(base_path, target)
    None => fallback_path
  }
  if !zip.exists(path) {
    return []
  }
  let part_relationships = read_relationships(
    zip,
    relationships_path_for_part(path),
  )
  let reader = BodyReader::{
    styles,
    zip,
    relationships: part_relationships,
    content_types,
    base_path: split_zip_path(path).0,
  }
  let root = read_xml_part(zip, path)
  let result : Array[Note] = []
  for note_element in root.elements_by_tag_name("w:" + note_type) {
    let note_kind = note_element.attributes.get("w:type")
    if note_kind != Some("separator") &&
      note_kind != Some("continuationSeparator") {
      result.push({
        note_type,
        note_id: note_element.attributes.get_or_default("w:id", ""),
        body: reader.read_children(note_element.children),
      })
    }
  }
  result
}

///|
fn read_comments_for_document(
  zip : ZipArchive,
  styles : Map[String, StyleInfo],
  content_types : ContentTypes,
  document_relationships : Relationships,
  base_path : String,
) -> Array[Comment] raise DocxError {
  let path = match
    document_relationships.find_target_by_type(
      "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments",
    ) {
    Some(target) => resolve_part_target(base_path, target)
    None => join_zip_path([base_path, "comments.xml"])
  }
  if !zip.exists(path) {
    return []
  }
  let part_relationships = read_relationships(
    zip,
    relationships_path_for_part(path),
  )
  let reader = BodyReader::{
    styles,
    zip,
    relationships: part_relationships,
    content_types,
    base_path: split_zip_path(path).0,
  }
  let root = read_xml_part(zip, path)
  let comments : Array[Comment] = []
  for comment_element in root.elements_by_tag_name("w:comment") {
    comments.push({
      comment_id: comment_element.attributes.get_or_default("w:id", ""),
      body: reader.read_children(comment_element.children),
      author_name: read_optional_attribute(comment_element, "w:author"),
      author_initials: read_optional_attribute(comment_element, "w:initials"),
    })
  }
  comments
}

///|
fn read_optional_attribute(element : XmlElement, name : String) -> String {
  match element.attributes.get(name) {
    Some(value) => {
      let trimmed = value.trim()
      if trimmed.is_empty() {
        ""
      } else {
        trimmed.to_owned()
      }
    }
    None => ""
  }
}

///|
fn read_styles(
  zip : ZipArchive,
  path : String,
) -> Map[String, StyleInfo] raise DocxError {
  let styles : Map[String, StyleInfo] = {}
  match zip.read_text(path) {
    Some(text) => {
      let root = read_xml_string(text, namespace_map=office_namespace_map())
      for style in root.elements_by_tag_name("w:style") {
        let style_id = style.attributes.get_or_default("w:styleId", "")
        if style_id != "" {
          styles[style_id] = {
            style_id,
            style_type: style.attributes.get_or_default("w:type", ""),
            name: style.first_or_empty("w:name").attributes.get_or_default(
              "w:val", "",
            ),
          }
        }
      }
    }
    None => ()
  }
  styles
}

///|
fn read_document_xml(
  root : XmlElement,
  styles : Map[String, StyleInfo],
  zip : ZipArchive,
  relationships : Relationships,
  content_types : ContentTypes,
  base_path : String,
  notes : Array[Note],
  comments : Array[Comment],
) -> DocumentElement raise DocxError {
  let body = root.first_or_empty("w:body")
  let reader = BodyReader::{
    styles,
    zip,
    relationships,
    content_types,
    base_path,
  }
  document(reader.read_children(body.children), notes~, comments~)
}

///|
priv struct BodyReader {
  styles : Map[String, StyleInfo]
  zip : ZipArchive
  relationships : Relationships
  content_types : ContentTypes
  base_path : String
}

///|
fn BodyReader::read_children(
  self : BodyReader,
  children : Array[XmlNode],
) -> Array[DocumentElement] raise DocxError {
  let elements : Array[DocumentElement] = []
  let deleted_paragraph_contents : Array[XmlNode] = []
  for child in children {
    match child {
      XmlElement(element) =>
        if element.name == "w:p" && is_deleted_paragraph(element) {
          deleted_paragraph_contents.append(element.children)
        } else if element.name == "w:p" &&
          !deleted_paragraph_contents.is_empty() {
          elements.append(
            self.read_paragraph_elements_with_prefix(
              element, deleted_paragraph_contents,
            ),
          )
          deleted_paragraph_contents.clear()
        } else {
          elements.append(self.read_element(element))
        }
      XmlText(_) => ()
    }
  }
  elements
}

///|
fn BodyReader::read_element(
  self : BodyReader,
  element : XmlElement,
) -> Array[DocumentElement] raise DocxError {
  match element.name {
    "w:p" =>
      if is_deleted_paragraph(element) {
        []
      } else {
        self.read_paragraph_elements(element)
      }
    "w:r" => [self.read_run(element)]
    "w:t" => [text(element.text())]
    "w:tab" => [tab()]
    "w:noBreakHyphen" => [text("\u{2011}")]
    "w:softHyphen" => [text("\u{00AD}")]
    "w:footnoteReference" =>
      [
        NoteReference(
          note_type="footnote",
          note_id=element.attributes.get_or_default("w:id", ""),
        ),
      ]
    "w:endnoteReference" =>
      [
        NoteReference(
          note_type="endnote",
          note_id=element.attributes.get_or_default("w:id", ""),
        ),
      ]
    "w:footnoteRef" | "w:endnoteRef" => []
    "w:commentReference" =>
      [CommentReference(element.attributes.get_or_default("w:id", ""))]
    "w:br" => [self.read_break(element)]
    "w:bookmarkStart" =>
      match element.attributes.get("w:name") {
        Some("_GoBack") | None => []
        Some(name) => [BookmarkStart(name)]
      }
    "w:hyperlink" => self.read_hyperlink(element)
    "w:drawing" | "w:pict" | "w:object" => self.read_children(element.children)
    "mc:AlternateContent" =>
      self.read_children(element.first_or_empty("mc:Fallback").children)
    "wp:inline" | "wp:anchor" => self.read_drawing_element(element)
    "v:roundrect" | "v:shape" | "v:textbox" | "v:group" | "v:rect" =>
      self.read_children(element.children)
    "v:imagedata" => self.read_vml_image_data(element)
    "w:tbl" => [self.read_table(element)]
    "w:tr" => self.read_table_row(element)
    "w:tc" => [self.read_table_cell(element)]
    "w:ins" | "w:smartTag" | "w:sdtContent" =>
      self.read_children(element.children)
    "w:sdt" => self.read_structured_document_tag(element)
    _ => []
  }
}

///|
fn is_deleted_paragraph(element : XmlElement) -> Bool {
  element.first_or_empty("w:pPr").first_or_empty("w:rPr").first("w:del") != None
}

///|
fn BodyReader::read_paragraph_elements(
  self : BodyReader,
  element : XmlElement,
) -> Array[DocumentElement] raise DocxError {
  self.read_paragraph_elements_with_prefix(element, [])
}

///|
fn BodyReader::read_paragraph_elements_with_prefix(
  self : BodyReader,
  element : XmlElement,
  prefix : Array[XmlNode],
) -> Array[DocumentElement] raise DocxError {
  let properties = self.read_paragraph_properties(
    element.first_or_empty("w:pPr"),
  )
  let elements = [
    paragraph(self.read_children(prefix + element.children), properties~),
  ]
  elements.append(self.read_text_box_elements(element))
  elements
}

///|
fn BodyReader::read_text_box_elements(
  self : BodyReader,
  element : XmlElement,
) -> Array[DocumentElement] raise DocxError {
  match element.name {
    "mc:AlternateContent" =>
      self.read_text_box_elements(element.first_or_empty("mc:Fallback"))
    "w:txbxContent" => self.read_children(element.children)
    _ => {
      let elements : Array[DocumentElement] = []
      for child in element.children {
        match child {
          XmlElement(child_element) =>
            elements.append(self.read_text_box_elements(child_element))
          XmlText(_) => ()
        }
      }
      elements
    }
  }
}

///|
fn BodyReader::read_structured_document_tag(
  self : BodyReader,
  element : XmlElement,
) -> Array[DocumentElement] raise DocxError {
  let content = self.read_children(
    element.first_or_empty("w:sdtContent").children,
  )
  match read_structured_checkbox(element.first_or_empty("w:sdtPr")) {
    Some(checked) => {
      let (replaced, found) = replace_first_text_with_checkbox(content, checked)
      if found {
        replaced
      } else {
        [checkbox(checked)]
      }
    }
    None => content
  }
}

///|
fn read_structured_checkbox(element : XmlElement) -> Bool? {
  match element.first("wordml:checkbox") {
    Some(checkbox_element) =>
      match checkbox_element.first("wordml:checked") {
        Some(checked_element) =>
          Some(
            read_boolean_attribute_value(
              checked_element.attributes.get("wordml:val"),
            ),
          )
        None => Some(false)
      }
    None => None
  }
}

///|
fn read_boolean_attribute_value(value : String?) -> Bool {
  value != Some("false") && value != Some("0")
}

///|
fn replace_first_text_with_checkbox(
  elements : Array[DocumentElement],
  checked : Bool,
) -> (Array[DocumentElement], Bool) {
  let replaced : Array[DocumentElement] = []
  let mut found = false
  for element in elements {
    if found {
      replaced.push(element)
    } else {
      let (next, next_found) = replace_first_text_in_element(element, checked)
      replaced.push(next)
      if next_found {
        found = true
      }
    }
  }
  (replaced, found)
}

///|
fn replace_first_text_in_element(
  element : DocumentElement,
  checked : Bool,
) -> (DocumentElement, Bool) {
  match element {
    Text(value) =>
      if value.length() > 0 {
        (checkbox(checked), true)
      } else {
        (element, false)
      }
    Document(children~, notes~, comments~) => {
      let (new_children, found) = replace_first_text_with_checkbox(
        children, checked,
      )
      (Document(children=new_children, notes~, comments~), found)
    }
    Paragraph(children~, properties~) => {
      let (new_children, found) = replace_first_text_with_checkbox(
        children, checked,
      )
      (Paragraph(children=new_children, properties~), found)
    }
    Run(children~, properties~) => {
      let (new_children, found) = replace_first_text_with_checkbox(
        children, checked,
      )
      (Run(children=new_children, properties~), found)
    }
    Hyperlink(children~, href~, anchor~, target_frame~) => {
      let (new_children, found) = replace_first_text_with_checkbox(
        children, checked,
      )
      (Hyperlink(children=new_children, href~, anchor~, target_frame~), found)
    }
    Table(children~, properties~) => {
      let (new_children, found) = replace_first_text_with_checkbox(
        children, checked,
      )
      (Table(children=new_children, properties~), found)
    }
    TableRow(children~, is_header~) => {
      let (new_children, found) = replace_first_text_with_checkbox(
        children, checked,
      )
      (TableRow(children=new_children, is_header~), found)
    }
    TableCell(children~, col_span~, row_span~) => {
      let (new_children, found) = replace_first_text_with_checkbox(
        children, checked,
      )
      (TableCell(children=new_children, col_span~, row_span~), found)
    }
    _ => (element, false)
  }
}

///|
fn BodyReader::read_paragraph_properties(
  self : BodyReader,
  element : XmlElement,
) -> ParagraphProperties {
  let style_id = element.first_or_empty("w:pStyle").attributes.get("w:val")
  let style_name = self.style_name(style_id, "paragraph")
  {
    style_id,
    style_name,
    numbering: self.read_numbering(element.first_or_empty("w:numPr")),
    alignment: element.first_or_empty("w:jc").attributes.get("w:val"),
    indent: self.read_indent(element.first_or_empty("w:ind")),
  }
}

///|
fn BodyReader::read_indent(self : BodyReader, element : XmlElement) -> Indent {
  ignore(self)
  {
    start: first_some(
      element.attributes.get("w:start"),
      element.attributes.get("w:left"),
    ),
    end: first_some(
      element.attributes.get("w:end"),
      element.attributes.get("w:right"),
    ),
    first_line: element.attributes.get("w:firstLine"),
    hanging: element.attributes.get("w:hanging"),
  }
}

///|
fn BodyReader::read_numbering(
  self : BodyReader,
  element : XmlElement,
) -> Numbering? {
  ignore(self)
  match element.first_or_empty("w:numId").attributes.get("w:val") {
    Some(_) => {
      let level = @string.parse_int(
        element.first_or_empty("w:ilvl").attributes.get_or_default("w:val", "0"),
      ) catch {
        _ => 0
      }
      Some({ is_ordered: false, level: level + 1 })
    }
    None => None
  }
}

///|
fn BodyReader::read_run(
  self : BodyReader,
  element : XmlElement,
) -> DocumentElement raise DocxError {
  let properties = self.read_run_properties(element.first_or_empty("w:rPr"))
  run(self.read_children(element.children), properties~)
}

///|
fn BodyReader::read_run_properties(
  self : BodyReader,
  element : XmlElement,
) -> RunProperties {
  let style_id = element.first_or_empty("w:rStyle").attributes.get("w:val")
  let style_name = self.style_name(style_id, "character")
  {
    style_id,
    style_name,
    is_bold: read_boolean_element(element.first("w:b")),
    is_underline: read_underline(element.first("w:u")),
    is_italic: read_boolean_element(element.first("w:i")),
    is_strikethrough: read_boolean_element(element.first("w:strike")),
    is_all_caps: read_boolean_element(element.first("w:caps")),
    is_small_caps: read_boolean_element(element.first("w:smallCaps")),
    vertical_alignment: read_vertical_alignment(
      element.first_or_empty("w:vertAlign").attributes.get("w:val"),
    ),
    font: element.first_or_empty("w:rFonts").attributes.get("w:ascii"),
    font_size: read_font_size(
      element.first_or_empty("w:sz").attributes.get("w:val"),
    ),
    highlight: read_highlight(
      element.first_or_empty("w:highlight").attributes.get("w:val"),
    ),
  }
}

///|
fn BodyReader::style_name(
  self : BodyReader,
  style_id : String?,
  style_type : String,
) -> String? {
  match style_id {
    Some(id) =>
      match self.styles.get(id) {
        Some(style) =>
          if style.style_type == style_type {
            Some(style.name)
          } else {
            None
          }
        None => None
      }
    None => None
  }
}

///|
fn read_boolean_element(element : XmlElement?) -> Bool {
  match element {
    Some(element) => {
      let value = element.attributes.get("w:val")
      value != Some("false") && value != Some("0")
    }
    None => false
  }
}

///|
fn read_underline(element : XmlElement?) -> Bool {
  match element {
    Some(element) => {
      let value = element.attributes.get("w:val")
      value != None &&
      value != Some("false") &&
      value != Some("0") &&
      value != Some("none")
    }
    None => false
  }
}

///|
fn read_vertical_alignment(value : String?) -> VerticalAlignment {
  match value {
    Some("superscript") => Superscript
    Some("subscript") => Subscript
    _ => Baseline
  }
}

///|
fn read_font_size(value : String?) -> Int? {
  match value {
    Some(text) =>
      try @string.parse_int(text) catch {
        _ => None
      } noraise {
        value => Some(value / 2)
      }
    None => None
  }
}

///|
fn[T] first_some(first : T?, second : T?) -> T? {
  match first {
    Some(_) => first
    None => second
  }
}

///|
fn read_highlight(value : String?) -> String? {
  match value {
    Some("none") | None => None
    Some(value) => Some(value)
  }
}

///|
fn BodyReader::read_break(
  self : BodyReader,
  element : XmlElement,
) -> DocumentElement {
  ignore(self)
  match element.attributes.get("w:type") {
    None | Some("textWrapping") => line_break()
    Some("page") => page_break()
    Some("column") => column_break()
    Some(_) => line_break()
  }
}

///|
fn BodyReader::read_hyperlink(
  self : BodyReader,
  element : XmlElement,
) -> Array[DocumentElement] raise DocxError {
  let target_frame = non_empty_attribute(element, "w:tgtFrame")
  match element.attributes.get("r:id") {
    Some(id) => {
      let href = match self.relationships.find_target_by_id(id) {
        Some(target) =>
          match element.attributes.get("w:anchor") {
            Some(anchor) => Some(replace_url_fragment(target, anchor))
            None => Some(target)
          }
        None => None
      }
      [
        Hyperlink(
          children=self.read_children(element.children),
          href~,
          anchor=None,
          target_frame~,
        ),
      ]
    }
    None =>
      match element.attributes.get("w:anchor") {
        Some(anchor) =>
          [
            Hyperlink(
              children=self.read_children(element.children),
              href=None,
              anchor=Some(anchor),
              target_frame~,
            ),
          ]
        None => self.read_children(element.children)
      }
  }
}

///|
fn non_empty_attribute(element : XmlElement, name : String) -> String? {
  match element.attributes.get(name) {
    Some(value) => if value == "" { None } else { Some(value) }
    None => None
  }
}

///|
fn BodyReader::read_drawing_element(
  self : BodyReader,
  element : XmlElement,
) -> Array[DocumentElement] {
  let results : Array[DocumentElement] = []
  for blip in element.descendants_by_tag_name("a:blip") {
    match self.read_blip(element, blip) {
      Some(image) =>
        results.push(self.wrap_image_with_drawing_hyperlink(element, image))
      None => ()
    }
  }
  results
}

///|
fn BodyReader::wrap_image_with_drawing_hyperlink(
  self : BodyReader,
  drawing_element : XmlElement,
  image : Image,
) -> DocumentElement {
  match self.read_drawing_hyperlink(drawing_element) {
    Some(href) =>
      Hyperlink(
        children=[Image(image)],
        href=Some(href),
        anchor=None,
        target_frame=None,
      )
    None => Image(image)
  }
}

///|
fn BodyReader::read_drawing_hyperlink(
  self : BodyReader,
  drawing_element : XmlElement,
) -> String? {
  for link in drawing_element.descendants_by_tag_name("a:hlinkClick") {
    match link.attributes.get("r:id") {
      Some(id) =>
        match self.relationships.find_target_by_id(id) {
          Some(target) => return Some(target)
          None => ()
        }
      None => ()
    }
  }
  None
}

///|
fn BodyReader::read_blip(
  self : BodyReader,
  drawing_element : XmlElement,
  blip : XmlElement,
) -> Image? {
  let relationship_id = match blip.attributes.get("r:embed") {
    Some(id) => Some(id)
    None => blip.attributes.get("r:link")
  }
  match relationship_id {
    Some(id) =>
      self.read_image_by_relationship(
        id,
        alt_text=read_drawing_alt_text(drawing_element),
      )
    None => None
  }
}

///|
fn BodyReader::read_vml_image_data(
  self : BodyReader,
  element : XmlElement,
) -> Array[DocumentElement] {
  match element.attributes.get("r:id") {
    Some(id) =>
      match
        self.read_image_by_relationship(
          id,
          alt_text=element.attributes.get("o:title"),
        ) {
        Some(image) => [Image(image)]
        None => []
      }
    None => []
  }
}

///|
fn BodyReader::read_image_by_relationship(
  self : BodyReader,
  relationship_id : String,
  alt_text~ : String?,
) -> Image? {
  match self.relationships.find_by_id(relationship_id) {
    Some(rel) =>
      if rel.target_mode == Some("External") {
        None
      } else {
        let path = resolve_part_target(self.base_path, rel.target)
        match self.zip.read_bytes(path) {
          Some(data) =>
            Some({
              content_type: self.content_types.find_content_type(path),
              alt_text,
              data,
            })
          None => None
        }
      }
    None => None
  }
}

///|
fn read_drawing_alt_text(element : XmlElement) -> String? {
  let properties = element.first_or_empty("wp:docPr")
  match properties.attributes.get("descr") {
    Some(value) =>
      if value.trim().is_empty() {
        properties.attributes.get("title")
      } else {
        Some(value)
      }
    None => properties.attributes.get("title")
  }
}

///|
fn resolve_part_target(base_path : String, target : String) -> String {
  strip_leading_slash(
    if target.has_prefix("/") {
      target
    } else {
      join_zip_path([base_path, target])
    },
  )
}

///|
fn BodyReader::read_table(
  self : BodyReader,
  element : XmlElement,
) -> DocumentElement raise DocxError {
  Table(
    children=calculate_table_row_spans(self.read_children(element.children)),
    properties=self.read_table_properties(element.first_or_empty("w:tblPr")),
  )
}

///|
fn BodyReader::read_table_properties(
  self : BodyReader,
  element : XmlElement,
) -> TableProperties {
  let style_id = element.first_or_empty("w:tblStyle").attributes.get("w:val")
  { style_id, style_name: self.style_name(style_id, "table") }
}

///|
fn BodyReader::read_table_row(
  self : BodyReader,
  element : XmlElement,
) -> Array[DocumentElement] raise DocxError {
  let properties = element.first_or_empty("w:trPr")
  if properties.first("w:del") != None {
    []
  } else {
    let is_header = properties.first("w:tblHeader") != None
    [TableRow(children=self.read_children(element.children), is_header~)]
  }
}

///|
fn BodyReader::read_table_cell(
  self : BodyReader,
  element : XmlElement,
) -> DocumentElement raise DocxError {
  let properties = element.first_or_empty("w:tcPr")
  let col_span = @string.parse_int(
    properties.first_or_empty("w:gridSpan").attributes.get_or_default(
      "w:val", "1",
    ),
  ) catch {
    _ => 1
  }
  TableCell(
    children=self.read_children(element.children),
    col_span~,
    row_span=if read_vertical_merge_continue(properties) { 0 } else { 1 },
  )
}

///|
fn read_vertical_merge_continue(properties : XmlElement) -> Bool {
  match properties.first("w:vMerge") {
    Some(element) =>
      match element.attributes.get("w:val") {
        None | Some("continue") => true
        _ => false
      }
    None => false
  }
}

///|
fn calculate_table_row_spans(
  elements : Array[DocumentElement],
) -> Array[DocumentElement] {
  let mut can_merge = true
  for row in elements {
    match row {
      TableRow(children~, ..) =>
        for cell in children {
          match cell {
            TableCell(..) => ()
            _ => can_merge = false
          }
        }
      _ => can_merge = false
    }
  }
  if !can_merge {
    return elements
  }
  let row_spans : Array[Array[Int]] = []
  let skip_cells : Array[Array[Bool]] = []
  for row in elements {
    match row {
      TableRow(children~, ..) => {
        let spans : Array[Int] = []
        let skips : Array[Bool] = []
        for _ in children {
          spans.push(1)
          skips.push(false)
        }
        row_spans.push(spans)
        skip_cells.push(skips)
      }
      _ => ()
    }
  }
  let open_cells : Map[Int, (Int, Int)] = {}
  for row_index in 0..<elements.length() {
    match elements[row_index] {
      TableRow(children~, ..) => {
        let mut column_index = 0
        for cell_index in 0..<children.length() {
          match children[cell_index] {
            TableCell(col_span~, row_span~, ..) => {
              if row_span == 0 {
                match open_cells.get(column_index) {
                  Some((origin_row, origin_cell)) => {
                    row_spans[origin_row][origin_cell] = row_spans[origin_row][origin_cell] +
                      1
                    skip_cells[row_index][cell_index] = true
                  }
                  None => open_cells[column_index] = (row_index, cell_index)
                }
              } else {
                open_cells[column_index] = (row_index, cell_index)
              }
              column_index = column_index + col_span
            }
            _ => ()
          }
        }
      }
      _ => ()
    }
  }
  let rows : Array[DocumentElement] = []
  for row_index in 0..<elements.length() {
    match elements[row_index] {
      TableRow(children~, is_header~) => {
        let new_children : Array[DocumentElement] = []
        for cell_index in 0..<children.length() {
          if !skip_cells[row_index][cell_index] {
            match children[cell_index] {
              TableCell(children=cell_children, col_span~, ..) =>
                new_children.push(
                  TableCell(
                    children=cell_children,
                    col_span~,
                    row_span=row_spans[row_index][cell_index],
                  ),
                )
              _ => new_children.push(children[cell_index])
            }
          }
        }
        rows.push(TableRow(children=new_children, is_header~))
      }
      _ => rows.push(elements[row_index])
    }
  }
  rows
}
