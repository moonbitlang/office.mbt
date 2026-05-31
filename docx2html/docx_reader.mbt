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
pub fn convert_to_html(
  docx : BytesView,
  style_map? : Array[String] = [],
  include_default_style_map? : Bool = true,
  ignore_empty_paragraphs? : Bool = true,
  id_prefix? : String = "",
  pretty_print? : Bool = false,
) -> ConversionResult raise DocxError {
  let document = read_docx(docx)
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
) -> ConversionResult raise DocxError {
  let document = read_docx(docx)
  convert_document_to_markdown(document, style_map~, include_default_style_map~)
}

///|
pub fn extract_raw_text(docx : BytesView) -> ConversionResult raise DocxError {
  extract_raw_text_from_document(read_docx(docx))
}

///|
pub fn read_docx(docx : BytesView) -> DocumentElement raise DocxError {
  let zip = open_zip(docx)
  let main_document_path = find_main_document_path(zip)
  let styles = read_styles(zip, "word/styles.xml")
  let xml = read_xml_part(zip, main_document_path)
  read_document_xml(xml, styles)
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
) -> DocumentElement raise DocxError {
  let body = root.first_or_empty("w:body")
  let reader = BodyReader::{ styles, }
  document(reader.read_children(body.children))
}

///|
priv struct BodyReader {
  styles : Map[String, StyleInfo]
}

///|
fn BodyReader::read_children(
  self : BodyReader,
  children : Array[XmlNode],
) -> Array[DocumentElement] raise DocxError {
  let elements : Array[DocumentElement] = []
  for child in children {
    match child {
      XmlElement(element) => elements.append(self.read_element(element))
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
    "w:p" => [self.read_paragraph(element)]
    "w:r" => [self.read_run(element)]
    "w:t" => [text(element.text())]
    "w:tab" => [tab()]
    "w:noBreakHyphen" => [text("\u{2011}")]
    "w:softHyphen" => [text("\u{00AD}")]
    "w:br" => [self.read_break(element)]
    "w:bookmarkStart" =>
      match element.attributes.get("w:name") {
        Some("_GoBack") | None => []
        Some(name) => [BookmarkStart(name)]
      }
    "w:hyperlink" => [self.read_hyperlink(element)]
    "w:tbl" => [self.read_table(element)]
    "w:tr" => [self.read_table_row(element)]
    "w:tc" => [self.read_table_cell(element)]
    "w:ins" | "w:smartTag" | "w:sdtContent" =>
      self.read_children(element.children)
    "w:sdt" =>
      self.read_children(element.first_or_empty("w:sdtContent").children)
    _ => []
  }
}

///|
fn BodyReader::read_paragraph(
  self : BodyReader,
  element : XmlElement,
) -> DocumentElement raise DocxError {
  let properties = self.read_paragraph_properties(
    element.first_or_empty("w:pPr"),
  )
  paragraph(self.read_children(element.children), properties~)
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
) -> DocumentElement raise DocxError {
  Hyperlink(
    children=self.read_children(element.children),
    href=None,
    anchor=element.attributes.get("w:anchor"),
    target_frame=element.attributes.get("w:tgtFrame"),
  )
}

///|
fn BodyReader::read_table(
  self : BodyReader,
  element : XmlElement,
) -> DocumentElement raise DocxError {
  Table(
    children=self.read_children(element.children),
    properties=TableProperties::default(),
  )
}

///|
fn BodyReader::read_table_row(
  self : BodyReader,
  element : XmlElement,
) -> DocumentElement raise DocxError {
  let is_header = element.first_or_empty("w:trPr").first("w:tblHeader") != None
  TableRow(children=self.read_children(element.children), is_header~)
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
    row_span=1,
  )
}
