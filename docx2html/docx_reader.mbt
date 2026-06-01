///|
priv struct Relationship {
  id : String
  relationship_type : String
  target : String
  target_mode : String?
}

///|
priv struct Relationships {
  relationships : Array[Relationship]
}

///|
priv struct StyleInfo {
  style_id : String
  style_type : String
  name : String
}

///|
priv struct NumberingLevel {
  is_ordered : Bool
  level : Int
  paragraph_style_id : String?
}

///|
priv struct AbstractNumbering {
  levels : Map[String, NumberingLevel]
  num_style_link : String?
}

///|
priv struct NumberingMap {
  nums : Map[String, String]
  abstract_nums : Map[String, AbstractNumbering]
  levels_by_paragraph_style_id : Map[String, NumberingLevel]
  numbering_style_num_ids : Map[String, String]
}

///|
fn NumberingMap::empty() -> NumberingMap {
  {
    nums: {},
    abstract_nums: {},
    levels_by_paragraph_style_id: {},
    numbering_style_num_ids: {},
  }
}

///|
priv struct ContentTypes {
  defaults : Map[String, String]
  overrides : Map[String, String]
}

///|
priv struct DocxReadResult {
  document : DocumentElement
  messages : Array[Message]
}

///|
priv struct ExternalFileAccess {
  enabled : Bool
  read_file : (String) -> Bytes?
}

///|
fn no_external_file_reader(_path : String) -> Bytes? {
  None
}

///|
fn default_external_file_access() -> ExternalFileAccess {
  external_file_access_options(false, no_external_file_reader)
}

///|
fn external_file_access_options(
  enabled : Bool,
  read_file : (String) -> Bytes?,
) -> ExternalFileAccess {
  { enabled, read_file }
}

///|
priv struct NotesReadResult {
  notes : Array[Note]
  messages : Array[Message]
}

///|
priv struct CommentsReadResult {
  comments : Array[Comment]
  messages : Array[Message]
}

///|
pub fn convert_to_html(
  docx : BytesView,
  style_map? : Array[String] = [],
  include_default_style_map? : Bool = true,
  include_embedded_style_map? : Bool = true,
  ignore_empty_paragraphs? : Bool = true,
  id_prefix? : String = "",
  pretty_print? : Bool = false,
  convert_image? : (Image) -> ImageConversion = data_uri_image_converter,
  transform_document? : (DocumentElement) -> DocumentElement = identity_document_transform,
  external_file_access? : Bool = false,
  read_external_file? : (String) -> Bytes? = no_external_file_reader,
) -> ConversionResult raise DocxError {
  let zip = open_zip(docx)
  let read_result = read_docx_zip_with_messages(
    zip,
    external_files=external_file_access_options(
      external_file_access, read_external_file,
    ),
  )
  let style_map = combine_docx_style_maps_from_zip(
    zip,
    style_map,
    include_embedded_style_map~,
  )
  let result = convert_document_to_html(
    read_result.document,
    style_map~,
    include_default_style_map~,
    ignore_empty_paragraphs~,
    id_prefix~,
    pretty_print~,
    convert_image~,
    transform_document~,
  )
  prepend_messages(result, read_result.messages)
}

///|
pub fn convert_to_markdown(
  docx : BytesView,
  style_map? : Array[String] = [],
  include_default_style_map? : Bool = true,
  include_embedded_style_map? : Bool = true,
  ignore_empty_paragraphs? : Bool = true,
  id_prefix? : String = "",
  convert_image? : (Image) -> ImageConversion = data_uri_image_converter,
  transform_document? : (DocumentElement) -> DocumentElement = identity_document_transform,
  external_file_access? : Bool = false,
  read_external_file? : (String) -> Bytes? = no_external_file_reader,
) -> ConversionResult raise DocxError {
  let zip = open_zip(docx)
  let read_result = read_docx_zip_with_messages(
    zip,
    external_files=external_file_access_options(
      external_file_access, read_external_file,
    ),
  )
  let style_map = combine_docx_style_maps_from_zip(
    zip,
    style_map,
    include_embedded_style_map~,
  )
  let result = convert_document_to_markdown(
    read_result.document,
    style_map~,
    include_default_style_map~,
    ignore_empty_paragraphs~,
    id_prefix~,
    convert_image~,
    transform_document~,
  )
  prepend_messages(result, read_result.messages)
}

///|
pub fn extract_raw_text(
  docx : BytesView,
  external_file_access? : Bool = false,
  read_external_file? : (String) -> Bytes? = no_external_file_reader,
) -> ConversionResult raise DocxError {
  let read_result = read_docx_zip_with_messages(
    open_zip(docx),
    external_files=external_file_access_options(
      external_file_access, read_external_file,
    ),
    read_images=false,
  )
  let result = extract_raw_text_from_document(read_result.document)
  prepend_messages(result, read_result.messages)
}

///|
fn prepend_messages(
  result : ConversionResult,
  messages : Array[Message],
) -> ConversionResult {
  if messages.is_empty() {
    result
  } else {
    let combined : Array[Message] = []
    combined.append(messages)
    combined.append(result.messages)
    { value: result.value, messages: dedupe_messages(combined) }
  }
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
pub fn read_docx(
  docx : BytesView,
  external_file_access? : Bool = false,
  read_external_file? : (String) -> Bytes? = no_external_file_reader,
) -> DocumentElement raise DocxError {
  read_docx_zip(
    open_zip(docx),
    external_files=external_file_access_options(
      external_file_access, read_external_file,
    ),
  )
}

///|
fn read_docx_zip(
  zip : ZipArchive,
  external_files? : ExternalFileAccess = default_external_file_access(),
) -> DocumentElement raise DocxError {
  read_docx_zip_with_messages(zip, external_files~).document
}

///|
fn read_docx_zip_with_messages(
  zip : ZipArchive,
  external_files? : ExternalFileAccess = default_external_file_access(),
  read_images? : Bool = true,
) -> DocxReadResult raise DocxError {
  let main_document_path = find_main_document_path(zip)
  let relationships = read_relationships(
    zip,
    relationships_path_for_part(main_document_path),
  )
  let content_types = read_content_types(zip)
  let base_path = split_zip_path(main_document_path).0
  let styles = read_styles(
    zip,
    find_part_path(
      zip,
      relationships,
      relationship_type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles",
      base_path~,
      fallback_path="word/styles.xml",
    ),
  )
  let numbering = read_numbering_for_document(
    zip, relationships, styles, base_path,
  )
  let notes_result = read_notes_for_document(
    zip,
    styles,
    numbering,
    content_types,
    relationships,
    base_path,
    external_files~,
    read_images~,
  )
  let comments_result = read_comments_for_document(
    zip,
    styles,
    numbering,
    content_types,
    relationships,
    base_path,
    external_files~,
    read_images~,
  )
  let xml = read_xml_part(zip, main_document_path)
  let document_result = read_document_xml_with_messages(
    xml,
    styles,
    numbering,
    zip,
    relationships,
    content_types,
    base_path,
    notes_result.notes,
    comments_result.comments,
    external_files~,
    read_images~,
  )
  let messages : Array[Message] = []
  messages.append(notes_result.messages)
  messages.append(comments_result.messages)
  messages.append(document_result.messages)
  { document: document_result.document, messages: dedupe_messages(messages) }
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
    "http://purl.oclc.org/ooxml/drawingml/wordprocessingDrawing": "wp",
    "http://purl.oclc.org/ooxml/drawingml/main": "a",
    "http://purl.oclc.org/ooxml/drawingml/picture": "pic",
    "http://schemas.openxmlformats.org/package/2006/relationships": "relationships",
    "http://schemas.openxmlformats.org/package/2006/content-types": "content-types",
    "http://schemas.openxmlformats.org/markup-compatibility/2006": "mc",
    "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing": "wp",
    "http://schemas.openxmlformats.org/drawingml/2006/main": "a",
    "http://schemas.openxmlformats.org/drawingml/2006/picture": "pic",
    "http://schemas.microsoft.com/office/word/2010/wordml": "wordml",
    "urn:schemas-microsoft-com:office:office": "o",
    "urn:schemas-microsoft-com:office:word": "office-word",
    "urn:schemas-microsoft-com:vml": "v",
  }
}

///|
fn find_main_document_path(zip : ZipArchive) -> String raise DocxError {
  let relationships = read_relationships(zip, "_rels/.rels")
  let path = find_part_path(
    zip,
    relationships,
    relationship_type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    base_path="",
    fallback_path="word/document.xml",
  )
  if zip.exists(path) {
    path
  } else {
    raise MissingPart(
      message="Could not find main document part. Are you sure this is a valid .docx file?",
    )
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
  for rel in root.elements_by_tag_name("relationships:Relationship") {
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
fn Relationships::find_targets_by_type(
  self : Relationships,
  relationship_type : String,
) -> Array[String] {
  let targets : Array[String] = []
  for rel in self.relationships {
    if rel.relationship_type == relationship_type {
      targets.push(rel.target)
    }
  }
  targets
}

///|
fn find_part_path(
  zip : ZipArchive,
  relationships : Relationships,
  relationship_type~ : String,
  base_path~ : String,
  fallback_path~ : String,
) -> String {
  for target in relationships.find_targets_by_type(relationship_type) {
    let path = resolve_part_target(base_path, target)
    if zip.exists(path) {
      return path
    }
  }
  fallback_path
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
      for element in root.elements_by_tag_name("content-types:Default") {
        let extension = element.attributes.get_or_default("Extension", "")
        let content_type = element.attributes.get_or_default("ContentType", "")
        if extension != "" && content_type != "" {
          defaults[extension] = content_type
        }
      }
      for element in root.elements_by_tag_name("content-types:Override") {
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
        Some(index) => {
          let extension = normalized[index + 1:].to_owned()
          match self.defaults.get(extension) {
            Some(content_type) => content_type
            None => fallback_content_type(extension)
          }
        }
        None => ""
      }
  }
}

///|
fn fallback_content_type(extension : String) -> String {
  match extension.to_lower() {
    "png" => "image/png"
    "gif" => "image/gif"
    "jpeg" | "jpg" => "image/jpeg"
    "bmp" => "image/bmp"
    "tif" | "tiff" => "image/tiff"
    _ => ""
  }
}

///|
fn read_numbering_for_document(
  zip : ZipArchive,
  document_relationships : Relationships,
  styles : Map[String, StyleInfo],
  base_path : String,
) -> NumberingMap raise DocxError {
  let path = find_part_path(
    zip,
    document_relationships,
    relationship_type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering",
    base_path~,
    fallback_path="word/numbering.xml",
  )
  if zip.exists(path) {
    read_numbering_xml(read_xml_part(zip, path), styles)
  } else {
    NumberingMap::empty()
  }
}

///|
fn read_numbering_xml(
  root : XmlElement,
  styles : Map[String, StyleInfo],
) -> NumberingMap {
  let abstract_nums = read_abstract_numberings(root)
  {
    nums: read_numbering_instances(root),
    abstract_nums,
    levels_by_paragraph_style_id: index_levels_by_paragraph_style_id(
      abstract_nums,
    ),
    numbering_style_num_ids: index_numbering_style_num_ids(styles),
  }
}

///|
fn read_abstract_numberings(
  root : XmlElement,
) -> Map[String, AbstractNumbering] {
  let abstract_nums : Map[String, AbstractNumbering] = {}
  for element in root.elements_by_tag_name("w:abstractNum") {
    match element.attributes.get("w:abstractNumId") {
      Some(id) => abstract_nums[id] = read_abstract_numbering(element)
      None => ()
    }
  }
  abstract_nums
}

///|
fn read_abstract_numbering(element : XmlElement) -> AbstractNumbering {
  let levels : Map[String, NumberingLevel] = {}
  let mut level_without_index : NumberingLevel? = None
  for level_element in element.elements_by_tag_name("w:lvl") {
    let level = read_numbering_level(level_element)
    match level_element.attributes.get("w:ilvl") {
      Some(index) => levels[index] = level
      None => level_without_index = Some(level)
    }
  }
  match level_without_index {
    Some(level) => if !levels.contains("0") { levels["0"] = level }
    None => ()
  }
  {
    levels,
    num_style_link: element.first_or_empty("w:numStyleLink").attributes.get(
      "w:val",
    ),
  }
}

///|
fn read_numbering_level(element : XmlElement) -> NumberingLevel {
  let level_index = @string.parse_int(
    element.attributes.get_or_default("w:ilvl", "0"),
  ) catch {
    _ => 0
  }
  let num_fmt = element.first_or_empty("w:numFmt").attributes.get("w:val")
  {
    is_ordered: num_fmt != Some("bullet"),
    level: level_index + 1,
    paragraph_style_id: element.first_or_empty("w:pStyle").attributes.get(
      "w:val",
    ),
  }
}

///|
fn read_numbering_instances(root : XmlElement) -> Map[String, String] {
  let nums : Map[String, String] = {}
  for element in root.elements_by_tag_name("w:num") {
    let num_id = element.attributes.get_or_default("w:numId", "")
    let abstract_num_id = element.first_or_empty("w:abstractNumId").attributes.get_or_default(
      "w:val", "",
    )
    if num_id != "" && abstract_num_id != "" {
      nums[num_id] = abstract_num_id
    }
  }
  nums
}

///|
fn index_levels_by_paragraph_style_id(
  abstract_nums : Map[String, AbstractNumbering],
) -> Map[String, NumberingLevel] {
  let levels : Map[String, NumberingLevel] = {}
  for item in abstract_nums.to_array() {
    let (_, abstract_num) = item
    for level_item in abstract_num.levels.to_array() {
      let (_, level) = level_item
      match level.paragraph_style_id {
        Some(style_id) => levels[style_id] = level
        None => ()
      }
    }
  }
  levels
}

///|
fn index_numbering_style_num_ids(
  styles : Map[String, StyleInfo],
) -> Map[String, String] {
  let style_num_ids : Map[String, String] = {}
  for item in styles.to_array() {
    let (_, style) = item
    if style.style_type == "numbering" {
      if style.name != "" {
        style_num_ids[style.style_id] = style.name
      }
    }
  }
  style_num_ids
}

///|
fn NumberingMap::find_level(
  self : NumberingMap,
  num_id : String,
  level : String,
) -> Numbering? {
  match self.nums.get(num_id) {
    Some(abstract_num_id) =>
      match self.abstract_nums.get(abstract_num_id) {
        Some(abstract_num) =>
          match abstract_num.num_style_link {
            Some(style_id) =>
              match self.numbering_style_num_ids.get(style_id) {
                Some(linked_num_id) => self.find_level(linked_num_id, level)
                None => None
              }
            None =>
              match abstract_num.levels.get(level) {
                Some(numbering_level) => Some(numbering_level.to_numbering())
                None => None
              }
          }
        None => None
      }
    None => None
  }
}

///|
fn NumberingMap::find_level_by_paragraph_style_id(
  self : NumberingMap,
  style_id : String,
) -> Numbering? {
  match self.levels_by_paragraph_style_id.get(style_id) {
    Some(level) => Some(level.to_numbering())
    None => None
  }
}

///|
fn NumberingLevel::to_numbering(self : NumberingLevel) -> Numbering {
  { is_ordered: self.is_ordered, level: self.level }
}

///|
fn read_notes_for_document(
  zip : ZipArchive,
  styles : Map[String, StyleInfo],
  numbering : NumberingMap,
  content_types : ContentTypes,
  document_relationships : Relationships,
  base_path : String,
  external_files? : ExternalFileAccess = default_external_file_access(),
  read_images? : Bool = true,
) -> NotesReadResult raise DocxError {
  let notes : Array[Note] = []
  let messages : Array[Message] = []
  let footnotes = read_note_part(
    zip,
    note_type="footnote",
    relationship_type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes",
    fallback_path="word/footnotes.xml",
    styles~,
    numbering~,
    content_types~,
    document_relationships~,
    base_path~,
    external_files~,
    read_images~,
  )
  notes.append(footnotes.notes)
  messages.append(footnotes.messages)
  let endnotes = read_note_part(
    zip,
    note_type="endnote",
    relationship_type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/endnotes",
    fallback_path="word/endnotes.xml",
    styles~,
    numbering~,
    content_types~,
    document_relationships~,
    base_path~,
    external_files~,
    read_images~,
  )
  notes.append(endnotes.notes)
  messages.append(endnotes.messages)
  { notes, messages: dedupe_messages(messages) }
}

///|
fn read_note_part(
  zip : ZipArchive,
  note_type~ : String,
  relationship_type~ : String,
  fallback_path~ : String,
  styles~ : Map[String, StyleInfo],
  numbering~ : NumberingMap,
  content_types~ : ContentTypes,
  document_relationships~ : Relationships,
  base_path~ : String,
  external_files? : ExternalFileAccess = default_external_file_access(),
  read_images? : Bool = true,
) -> NotesReadResult raise DocxError {
  let path = find_part_path(
    zip,
    document_relationships,
    relationship_type~,
    base_path~,
    fallback_path~,
  )
  if !zip.exists(path) {
    return { notes: [], messages: [] }
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
    numbering,
    messages: [],
    external_files,
    read_images,
  }
  let root = read_xml_part(zip, path)
  let notes : Array[Note] = []
  for note_element in root.elements_by_tag_name("w:" + note_type) {
    let note_kind = note_element.attributes.get("w:type")
    if note_kind != Some("separator") &&
      note_kind != Some("continuationSeparator") {
      notes.push({
        note_type,
        note_id: note_element.attributes.get_or_default("w:id", ""),
        body: reader.read_children(note_element.children),
      })
    }
  }
  { notes, messages: reader.messages }
}

///|
fn read_comments_for_document(
  zip : ZipArchive,
  styles : Map[String, StyleInfo],
  numbering : NumberingMap,
  content_types : ContentTypes,
  document_relationships : Relationships,
  base_path : String,
  external_files? : ExternalFileAccess = default_external_file_access(),
  read_images? : Bool = true,
) -> CommentsReadResult raise DocxError {
  let path = find_part_path(
    zip,
    document_relationships,
    relationship_type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments",
    base_path~,
    fallback_path="word/comments.xml",
  )
  if !zip.exists(path) {
    return { comments: [], messages: [] }
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
    numbering,
    messages: [],
    external_files,
    read_images,
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
  { comments, messages: reader.messages }
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
          let style_info = read_style_info(style, style_id)
          let key = style_lookup_key(style_info.style_type, style_id)
          if !styles.contains(key) {
            styles[key] = style_info
          }
        }
      }
    }
    None => ()
  }
  styles
}

///|
fn style_lookup_key(style_type : String, style_id : String) -> String {
  style_type + ":" + style_id
}

///|
fn Map::find_style(
  self : Map[String, StyleInfo],
  style_type : String,
  style_id : String,
) -> StyleInfo? {
  match self.get(style_lookup_key(style_type, style_id)) {
    Some(style) => Some(style)
    None =>
      match self.get(style_id) {
        Some(style) =>
          if style.style_type == style_type {
            Some(style)
          } else {
            None
          }
        None => None
      }
  }
}

///|
fn read_style_info(element : XmlElement, style_id : String) -> StyleInfo {
  let style_type = element.attributes.get_or_default("w:type", "")
  {
    style_id,
    style_type,
    name: if style_type == "numbering" {
      element
      .first_or_empty("w:pPr")
      .first_or_empty("w:numPr")
      .first_or_empty("w:numId").attributes.get_or_default("w:val", "")
    } else {
      element.first_or_empty("w:name").attributes.get_or_default("w:val", "")
    },
  }
}

///|
fn read_document_xml_with_messages(
  root : XmlElement,
  styles : Map[String, StyleInfo],
  numbering : NumberingMap,
  zip : ZipArchive,
  relationships : Relationships,
  content_types : ContentTypes,
  base_path : String,
  notes : Array[Note],
  comments : Array[Comment],
  external_files? : ExternalFileAccess = default_external_file_access(),
  read_images? : Bool = true,
) -> DocxReadResult raise DocxError {
  let body = match root.first("w:body") {
    Some(body) => body
    None =>
      raise InvalidXml(
        message="Could not find the body element: are you sure this is a docx file?",
      )
  }
  let reader = BodyReader::{
    styles,
    zip,
    relationships,
    content_types,
    base_path,
    numbering,
    messages: [],
    external_files,
    read_images,
  }
  {
    document: document(reader.read_children(body.children), notes~, comments~),
    messages: reader.messages,
  }
}

///|
priv struct BodyReader {
  styles : Map[String, StyleInfo]
  zip : ZipArchive
  relationships : Relationships
  content_types : ContentTypes
  base_path : String
  numbering : NumberingMap
  messages : Array[Message]
  external_files : ExternalFileAccess
  read_images : Bool
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
    "w:sym" => self.read_symbol(element)
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
    "w:br" => self.read_break(element)
    "w:bookmarkStart" =>
      match element.attributes.get("w:name") {
        Some("_GoBack") => []
        None => [BookmarkStart("undefined")]
        Some(name) => [BookmarkStart(name)]
      }
    "w:hyperlink" => self.read_hyperlink(element)
    "w:drawing" | "w:object" => self.read_children(element.children)
    "w:pict" => []
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
    _ =>
      if is_ignored_body_element(element.name) {
        []
      } else {
        self.warn("An unrecognised element was ignored: " + element.name)
        []
      }
  }
}

///|
fn BodyReader::warn(self : BodyReader, message : String) -> Unit {
  self.messages.push(Warning(message))
}

///|
fn is_ignored_body_element(name : String) -> Bool {
  name == "office-word:wrap" ||
  name == "v:shadow" ||
  name == "v:shapetype" ||
  name == "w:annotationRef" ||
  name == "w:bookmarkEnd" ||
  name == "w:sectPr" ||
  name == "w:proofErr" ||
  name == "w:lastRenderedPageBreak" ||
  name == "w:commentRangeStart" ||
  name == "w:commentRangeEnd" ||
  name == "w:del" ||
  name == "w:footnoteRef" ||
  name == "w:endnoteRef" ||
  name == "w:txbxContent" ||
  name == "w:pPr" ||
  name == "w:rPr" ||
  name == "w:tblPr" ||
  name == "w:tblGrid" ||
  name == "w:trPr" ||
  name == "w:tcPr"
}

///|
fn BodyReader::read_symbol(
  self : BodyReader,
  element : XmlElement,
) -> Array[DocumentElement] {
  ignore(self)
  let font = element.attributes.get_or_default("w:font", "")
  let char = element.attributes.get_or_default("w:char", "")
  match symbol_to_unicode(font, char) {
    Some(value) => [text(value)]
    None => {
      self.warn(
        "A w:sym element with an unsupported character was ignored: char " +
        char +
        " in font " +
        font,
      )
      []
    }
  }
}

///|
fn symbol_to_unicode(font : String, char : String) -> String? {
  match parse_dingbat_hex(char) {
    Some(code) =>
      match dingbat_to_unicode(font, code) {
        Some(value) => Some(value)
        None =>
          if char.length() == 4 && char.has_prefix("F0") {
            match parse_dingbat_hex(char[2:].to_owned()) {
              Some(shifted_code) => dingbat_to_unicode(font, shifted_code)
              None => None
            }
          } else {
            None
          }
      }
    None => None
  }
}

///|
fn parse_dingbat_hex(value : String) -> Int? {
  let mut index = 0
  while index < value.length() && is_field_whitespace(value[index]) {
    index += 1
  }
  let start = index
  let mut result = 0
  while index < value.length() {
    match hex_value(value[index]) {
      Some(digit) => {
        result = result * 16 + digit
        index += 1
      }
      None => break
    }
  }
  if index == start {
    None
  } else {
    Some(result)
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
    paragraph(
      self.read_paragraph_children(prefix + element.children),
      properties~,
    ),
  ]
  elements.append(self.read_paragraph_extra_elements(element))
  elements
}

///|
priv enum ComplexField {
  ComplexFieldBegin(checkbox_checked~ : Bool?)
  ComplexHyperlink(href~ : String?, anchor~ : String?)
  ComplexCheckbox(Bool)
  ComplexFieldUnknown
}

///|
fn BodyReader::read_paragraph_children(
  self : BodyReader,
  children : Array[XmlNode],
) -> Array[DocumentElement] raise DocxError {
  let elements : Array[DocumentElement] = []
  let stack : Array[ComplexField] = []
  let mut instruction_text = ""
  for child in children {
    match child {
      XmlElement(element) => {
        instruction_text += collect_instruction_text(element)
        match read_field_char_type(element) {
          Some("begin") => {
            stack.push(
              ComplexFieldBegin(
                checkbox_checked=read_complex_field_checkbox_checked(element),
              ),
            )
            instruction_text = ""
            elements.append(self.read_element(element))
          }
          Some("separate") => {
            match stack.pop() {
              Some(ComplexFieldBegin(checkbox_checked~)) =>
                stack.push(
                  parse_complex_field_instruction(
                    instruction_text, checkbox_checked,
                  ),
                )
              Some(field) => stack.push(field)
              None => ()
            }
            instruction_text = ""
            elements.append(self.read_element(element))
          }
          Some("end") => {
            match stack.pop() {
              Some(ComplexFieldBegin(checkbox_checked~)) =>
                match
                  parse_complex_field_instruction(
                    instruction_text, checkbox_checked,
                  ) {
                  ComplexCheckbox(checked) =>
                    elements.push(run([checkbox(checked)]))
                  _ => ()
                }
              Some(ComplexCheckbox(checked)) =>
                elements.push(run([checkbox(checked)]))
              Some(_) => ()
              None => ()
            }
            instruction_text = ""
            elements.append(self.read_element(element))
          }
          _ =>
            if element.name != "w:instrText" {
              elements.append(
                wrap_with_current_hyperlink(stack, self.read_element(element)),
              )
            }
        }
      }
      XmlText(_) => ()
    }
  }
  elements
}

///|
fn collect_instruction_text(element : XmlElement) -> String raise DocxError {
  let builder = StringBuilder()
  if element.name == "w:instrText" {
    builder.write_string(element.text())
  }
  for child in element.children {
    match child {
      XmlElement(child_element) =>
        builder.write_string(collect_instruction_text(child_element))
      XmlText(_) => ()
    }
  }
  builder.to_string()
}

///|
fn read_field_char_type(element : XmlElement) -> String? {
  if element.name == "w:fldChar" {
    return element.attributes.get("w:fldCharType")
  }
  for child in element.children {
    match child {
      XmlElement(child_element) =>
        match read_field_char_type(child_element) {
          Some(value) => return Some(value)
          None => ()
        }
      XmlText(_) => ()
    }
  }
  None
}

///|
fn read_complex_field_checkbox_checked(element : XmlElement) -> Bool? {
  match first_descendant_or_self(element, "w:fldChar") {
    Some(field_char) =>
      match field_char.first_or_empty("w:ffData").first("w:checkBox") {
        Some(checkbox_element) =>
          match checkbox_element.first("w:checked") {
            Some(checked_element) =>
              Some(read_boolean_element(Some(checked_element)))
            None =>
              Some(read_boolean_element(checkbox_element.first("w:default")))
          }
        None => None
      }
    None => None
  }
}

///|
fn first_descendant_or_self(element : XmlElement, name : String) -> XmlElement? {
  if element.name == name {
    return Some(element)
  }
  for child in element.children {
    match child {
      XmlElement(child_element) =>
        match first_descendant_or_self(child_element, name) {
          Some(result) => return Some(result)
          None => ()
        }
      XmlText(_) => ()
    }
  }
  None
}

///|
fn parse_complex_field_instruction(
  instruction_text : String,
  checkbox_checked : Bool?,
) -> ComplexField {
  match parse_hyperlink_field_instruction(instruction_text) {
    Some(field) => field
    None =>
      parse_non_hyperlink_field_instruction(instruction_text, checkbox_checked)
  }
}

///|
fn parse_non_hyperlink_field_instruction(
  instruction_text : String,
  checkbox_checked : Bool?,
) -> ComplexField {
  if instruction_text.contains("FORMCHECKBOX") {
    ComplexCheckbox(checkbox_checked.unwrap_or(false))
  } else {
    ComplexFieldUnknown
  }
}

///|
fn parse_hyperlink_field_instruction(
  instruction_text : String,
) -> ComplexField? {
  let keyword = "HYPERLINK"
  let mut index = skip_field_whitespace(instruction_text, 0)
  if !field_starts_with_at(instruction_text, index, keyword) {
    None
  } else {
    index = index + keyword.length()
    if index >= instruction_text.length() ||
      !is_field_whitespace(instruction_text[index]) {
      return None
    }
    index = skip_field_whitespace(instruction_text, index)
    let mut is_internal_link = false
    if field_starts_with_at(instruction_text, index, "\\l") {
      let after_switch = index + "\\l".length()
      if after_switch < instruction_text.length() &&
        is_field_whitespace(instruction_text[after_switch]) {
        is_internal_link = true
        index = skip_field_whitespace(instruction_text, after_switch)
      }
    }
    match read_field_location(instruction_text, index) {
      Some(location) =>
        if is_internal_link {
          Some(ComplexHyperlink(href=None, anchor=Some(location)))
        } else {
          Some(ComplexHyperlink(href=Some(location), anchor=None))
        }
      None => None
    }
  }
}

///|
fn read_field_location(value : String, index : Int) -> String? {
  if index >= value.length() {
    None
  } else if value[index] == '"' {
    let tail = value[index + 1:]
    match tail.rev_find("\"") {
      Some(last_quote) =>
        Some(value[index + 1:index + 1 + last_quote].to_owned())
      None => read_unquoted_field_location(value, index)
    }
  } else {
    read_unquoted_field_location(value, index)
  }
}

///|
fn read_unquoted_field_location(value : String, index : Int) -> String? {
  if index >= value.length() || value[index] == '\\' {
    None
  } else {
    Some(read_until_field_whitespace(value, index))
  }
}

///|
fn read_until_field_whitespace(value : String, start : Int) -> String {
  let mut index = start
  while index < value.length() {
    let char = value[index]
    if is_field_whitespace(char) {
      return value[start:index].to_owned()
    }
    index = index + 1
  }
  value[start:].to_owned()
}

///|
fn skip_field_whitespace(value : String, start : Int) -> Int {
  let mut index = start
  while index < value.length() && is_field_whitespace(value[index]) {
    index = index + 1
  }
  index
}

///|
fn is_field_whitespace(char : UInt16) -> Bool {
  char == ' ' || char == '\t' || char == '\n' || char == '\r'
}

///|
fn field_starts_with_at(value : String, index : Int, prefix : String) -> Bool {
  index + prefix.length() <= value.length() &&
  value[index:index + prefix.length()].to_owned() == prefix
}

///|
fn wrap_with_current_hyperlink(
  stack : Array[ComplexField],
  elements : Array[DocumentElement],
) -> Array[DocumentElement] {
  match current_hyperlink_field(stack) {
    Some((href, anchor)) => {
      let wrapped : Array[DocumentElement] = []
      for element in elements {
        wrapped.push(wrap_element_with_hyperlink(element, href, anchor))
      }
      wrapped
    }
    None => elements
  }
}

///|
fn current_hyperlink_field(stack : Array[ComplexField]) -> (String?, String?)? {
  for index = stack.length() - 1; index >= 0; index = index - 1 {
    match stack[index] {
      ComplexHyperlink(href~, anchor~) => return Some((href, anchor))
      _ => ()
    }
  }
  None
}

///|
fn wrap_element_with_hyperlink(
  element : DocumentElement,
  href : String?,
  anchor : String?,
) -> DocumentElement {
  match element {
    Run(children~, properties~) =>
      Run(
        children=[Hyperlink(children~, href~, anchor~, target_frame=None)],
        properties~,
      )
    _ => Hyperlink(children=[element], href~, anchor~, target_frame=None)
  }
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
fn BodyReader::read_paragraph_extra_elements(
  self : BodyReader,
  element : XmlElement,
) -> Array[DocumentElement] raise DocxError {
  let elements : Array[DocumentElement] = []
  for child in element.children {
    match child {
      XmlElement(child_element) =>
        match child_element.name {
          "w:pict" =>
            elements.append(self.read_pict_extra_elements(child_element))
          "mc:AlternateContent" =>
            elements.append(self.read_text_box_elements(child_element))
          "w:txbxContent" =>
            elements.append(self.read_text_box_elements(child_element))
          _ =>
            elements.append(self.read_paragraph_extra_elements(child_element))
        }
      XmlText(_) => ()
    }
  }
  elements
}

///|
fn BodyReader::read_pict_extra_elements(
  self : BodyReader,
  element : XmlElement,
) -> Array[DocumentElement] raise DocxError {
  let elements : Array[DocumentElement] = []
  for child in element.children {
    match child {
      XmlElement(child_element) =>
        match child_element.name {
          "mc:AlternateContent" =>
            elements.append(
              self.read_pict_extra_elements(
                child_element.first_or_empty("mc:Fallback"),
              ),
            )
          "w:txbxContent" =>
            elements.append(self.read_children(child_element.children))
          "w:pict"
          | "v:roundrect"
          | "v:shape"
          | "v:textbox"
          | "v:group"
          | "v:rect" =>
            elements.append(self.read_pict_extra_elements(child_element))
          _ => elements.append(self.read_element(child_element))
        }
      XmlText(_) => ()
    }
  }
  elements
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
  let style_id = non_empty_attribute(
    element.first_or_empty("w:pStyle"),
    "w:val",
  )
  let style_name = self.style_name(style_id, "paragraph")
  {
    style_id,
    style_name,
    numbering: self.read_numbering(style_id, element.first_or_empty("w:numPr")),
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
  style_id : String?,
  element : XmlElement,
) -> Numbering? {
  let level = element.first_or_empty("w:ilvl").attributes.get("w:val")
  let num_id = element.first_or_empty("w:numId").attributes.get("w:val")
  match (level, num_id) {
    (Some(level), Some(num_id)) => self.numbering.find_level(num_id, level)
    _ =>
      match style_id {
        Some(style_id) =>
          match self.numbering.find_level_by_paragraph_style_id(style_id) {
            Some(numbering) => Some(numbering)
            None =>
              match num_id {
                Some(num_id) => self.numbering.find_level(num_id, "0")
                None => None
              }
          }
        None =>
          match num_id {
            Some(num_id) => self.numbering.find_level(num_id, "0")
            None => None
          }
      }
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
  let style_id = non_empty_attribute(
    element.first_or_empty("w:rStyle"),
    "w:val",
  )
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
      match self.styles.find_style(style_type, id) {
        Some(style) => if style.name == "" { None } else { Some(style.name) }
        None => {
          self.warn_undefined_style(style_type, id)
          None
        }
      }
    None => None
  }
}

///|
fn BodyReader::warn_undefined_style(
  self : BodyReader,
  style_type : String,
  style_id : String,
) -> Unit {
  self.warn(
    style_warning_label(style_type) +
    " style with ID " +
    style_id +
    " was referenced but not defined in the document",
  )
}

///|
fn style_warning_label(style_type : String) -> String {
  match style_type {
    "paragraph" => "Paragraph"
    "character" => "Run"
    "table" => "Table"
    _ => style_type
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
      if is_ascii_decimal_string(text) {
        try @string.parse_int(text) catch {
          _ => None
        } noraise {
          value => Some(value / 2)
        }
      } else {
        None
      }
    None => None
  }
}

///|
fn is_ascii_decimal_string(value : String) -> Bool {
  let mut is_decimal = value.length() > 0
  for index in 0..<value.length() {
    if value[index] < 48 || value[index] > 57 {
      is_decimal = false
    }
  }
  is_decimal
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
    Some("") | Some("none") | None => None
    Some(value) => Some(value)
  }
}

///|
fn BodyReader::read_break(
  self : BodyReader,
  element : XmlElement,
) -> Array[DocumentElement] {
  match element.attributes.get("w:type") {
    None | Some("textWrapping") => [line_break()]
    Some("page") => [page_break()]
    Some("column") => [column_break()]
    Some(break_type) => {
      self.warn("Unsupported break type: " + break_type)
      []
    }
  }
}

///|
fn BodyReader::read_hyperlink(
  self : BodyReader,
  element : XmlElement,
) -> Array[DocumentElement] raise DocxError {
  let target_frame = non_empty_attribute(element, "w:tgtFrame")
  let anchor = non_empty_attribute(element, "w:anchor")
  match non_empty_attribute(element, "r:id") {
    Some(id) => {
      let href = match self.relationships.find_target_by_id(id) {
        Some(target) =>
          match anchor {
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
      match anchor {
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
  for blip in element.drawing_blips() {
    match self.read_blip(element, blip) {
      Some(image) =>
        results.push(self.wrap_image_with_drawing_hyperlink(element, image))
      None => ()
    }
  }
  results
}

///|
fn XmlElement::drawing_blips(self : XmlElement) -> Array[XmlElement] {
  let blips : Array[XmlElement] = []
  for graphic in self.elements_by_tag_name("a:graphic") {
    for graphic_data in graphic.elements_by_tag_name("a:graphicData") {
      for picture in graphic_data.elements_by_tag_name("pic:pic") {
        for fill in picture.elements_by_tag_name("pic:blipFill") {
          blips.append(fill.elements_by_tag_name("a:blip"))
        }
      }
    }
  }
  blips
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
  for
    link in drawing_element
    .first_or_empty("wp:docPr")
    .elements_by_tag_name("a:hlinkClick") {
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
  if !self.read_images {
    return None
  }
  let message_count = self.messages.length()
  let image = match blip.attributes.get("r:embed") {
    Some(id) =>
      self.read_image_by_relationship(
        id,
        alt_text=read_drawing_alt_text(drawing_element),
      )
    None =>
      match blip.attributes.get("r:link") {
        Some(id) =>
          self.read_linked_image_by_relationship(
            id,
            alt_text=read_drawing_alt_text(drawing_element),
          )
        None => None
      }
  }
  match image {
    Some(image) => Some(image)
    None => {
      if self.messages.length() == message_count {
        self.warn("Could not find image file for a:blip element")
      }
      None
    }
  }
}

///|
fn BodyReader::read_vml_image_data(
  self : BodyReader,
  element : XmlElement,
) -> Array[DocumentElement] {
  if !self.read_images {
    return []
  }
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
    None => {
      self.warn("A v:imagedata element without a relationship ID was ignored")
      []
    }
  }
}

///|
fn BodyReader::read_image_by_relationship(
  self : BodyReader,
  relationship_id : String,
  alt_text~ : String?,
) -> Image? {
  if !self.read_images {
    return None
  }
  match self.relationships.find_by_id(relationship_id) {
    Some(rel) => {
      let path = resolve_part_target(self.base_path, rel.target)
      match self.zip.read_bytes(path) {
        Some(data) => Some(self.make_image(path, data, alt_text~))
        None => None
      }
    }
    None => None
  }
}

///|
fn BodyReader::read_linked_image_by_relationship(
  self : BodyReader,
  relationship_id : String,
  alt_text~ : String?,
) -> Image? {
  if !self.read_images {
    return None
  }
  match self.relationships.find_by_id(relationship_id) {
    Some(rel) => self.read_external_image(rel.target, alt_text~)
    None => None
  }
}

///|
fn BodyReader::read_external_image(
  self : BodyReader,
  target : String,
  alt_text~ : String?,
) -> Image? {
  if !self.external_files.enabled {
    self.messages.push(
      Error(
        "could not read external image '" +
        target +
        "', external file access is disabled",
      ),
    )
    return None
  }
  for path in external_file_candidate_paths(target) {
    match (self.external_files.read_file)(path) {
      Some(data) => return Some(self.make_image(path, data, alt_text~))
      None => ()
    }
  }
  self.messages.push(
    Error(
      "could not find external image '" +
      target +
      "', path of input document is unknown",
    ),
  )
  None
}

///|
fn external_file_candidate_paths(target : String) -> Array[String] {
  let paths = [target]
  match external_uri_to_path(target) {
    Some(path) => if path != target { paths.push(path) }
    None => ()
  }
  paths
}

///|
fn external_uri_to_path(uri : String, platform? : String = "") -> String? {
  let raw_path = if uri.has_prefix("file://") {
    local_file_uri_path(uri)
  } else if is_relative_uri(uri) {
    Some(strip_uri_fragment(uri))
  } else {
    None
  }
  match raw_path {
    Some(path) =>
      match percent_decode_uri_path(path) {
        Some(decoded) =>
          if platform == "win32" && is_windows_file_uri_path(decoded) {
            Some(decoded[1:].to_owned())
          } else {
            Some(decoded)
          }
        None => None
      }
    None => None
  }
}

///|
fn local_file_uri_path(uri : String) -> String? {
  let rest = strip_uri_fragment(uri)["file://".length():]
  if rest.has_prefix("/") {
    Some(rest.to_owned())
  } else if rest.has_prefix("?") {
    Some(rest.to_owned())
  } else if rest.has_prefix("localhost?") {
    Some("/" + rest["localhost".length():].to_owned())
  } else {
    match rest.find("/") {
      Some(slash) => {
        let host = rest[:slash].to_owned()
        if host == "" || host == "localhost" {
          Some(rest[slash:].to_owned())
        } else {
          None
        }
      }
      None =>
        if rest == "" {
          Some("null")
        } else if rest == "localhost" {
          Some("/")
        } else {
          None
        }
    }
  }
}

///|
fn is_relative_uri(uri : String) -> Bool {
  find_uri_scheme_colon(uri) == None
}

///|
fn strip_uri_fragment(uri : String) -> String {
  match uri.find("#") {
    Some(index) => uri[:index].to_owned()
    None => uri
  }
}

///|
fn find_uri_scheme_colon(uri : String) -> Int? {
  if uri.length() == 0 || !is_uri_scheme_start(uri[0]) {
    return None
  }
  for index in 1..<uri.length() {
    let char = uri[index]
    if char == ':' {
      return Some(index)
    } else if char == '/' || char == '\\' || char == '?' || char == '#' {
      return None
    } else if !is_uri_scheme_char(char) {
      return None
    }
  }
  None
}

///|
fn is_uri_scheme_start(char : UInt16) -> Bool {
  (char >= 'A' && char <= 'Z') || (char >= 'a' && char <= 'z')
}

///|
fn is_uri_scheme_char(char : UInt16) -> Bool {
  is_uri_scheme_start(char) ||
  (char >= '0' && char <= '9') ||
  char == '+' ||
  char == '-' ||
  char == '.'
}

///|
fn is_windows_file_uri_path(path : String) -> Bool {
  path.length() >= 3 &&
  path[0] == '/' &&
  is_uri_scheme_start(path[1]) &&
  path[2] == ':'
}

///|
fn percent_decode_uri_path(path : String) -> String? {
  let bytes : Array[Byte] = []
  let mut index = 0
  while index < path.length() {
    if index + 2 < path.length() && path[index] == '%' {
      match (hex_value(path[index + 1]), hex_value(path[index + 2])) {
        (Some(high), Some(low)) => {
          bytes.push((high * 16 + low).to_byte())
          index += 3
          continue
        }
        _ => return None
      }
    } else if path[index] == '%' {
      return None
    }
    bytes.push(path[index].to_int().to_byte())
    index += 1
  }
  try @utf8.decode(Bytes::from_array(bytes)[:]) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn hex_value(char : UInt16) -> Int? {
  if char >= '0' && char <= '9' {
    Some(char.to_int() - '0'.to_int())
  } else if char >= 'A' && char <= 'F' {
    Some(char.to_int() - 'A'.to_int() + 10)
  } else if char >= 'a' && char <= 'f' {
    Some(char.to_int() - 'a'.to_int() + 10)
  } else {
    None
  }
}

///|
fn BodyReader::make_image(
  self : BodyReader,
  path : String,
  data : Bytes,
  alt_text~ : String?,
) -> Image {
  let content_type = self.content_types.find_content_type(path)
  if !is_supported_web_image_type(content_type) {
    self.warn(
      "Image of type " +
      content_type +
      " is unlikely to display in web browsers",
    )
  }
  { content_type, alt_text, data }
}

///|
fn is_supported_web_image_type(content_type : String) -> Bool {
  content_type == "image/png" ||
  content_type == "image/gif" ||
  content_type == "image/jpeg" ||
  content_type == "image/svg+xml" ||
  content_type == "image/tiff"
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
    children=self.calculate_table_row_spans(
      self.read_children(element.children),
    ),
    properties=self.read_table_properties(element.first_or_empty("w:tblPr")),
  )
}

///|
fn BodyReader::read_table_properties(
  self : BodyReader,
  element : XmlElement,
) -> TableProperties {
  let style_id = non_empty_attribute(
    element.first_or_empty("w:tblStyle"),
    "w:val",
  )
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
  let col_span = parse_grid_span(
    properties.first_or_empty("w:gridSpan").attributes.get_or_default(
      "w:val", "1",
    ),
  )
  TableCell(
    children=self.read_children(element.children),
    col_span~,
    row_span=if read_vertical_merge_continue(properties) { 0 } else { 1 },
  )
}

///|
fn parse_grid_span(value : String) -> Int {
  let mut index = 0
  while index < value.length() && is_field_whitespace(value[index]) {
    index += 1
  }
  let mut sign = 1
  if index < value.length() && (value[index] == '+' || value[index] == '-') {
    if value[index] == '-' {
      sign = -1
    }
    index += 1
  }
  let start = index
  let mut result = 0
  while index < value.length() {
    match decimal_digit_value(value[index]) {
      Some(digit) => {
        result = result * 10 + digit
        index += 1
      }
      None => break
    }
  }
  if index == start {
    1
  } else {
    sign * result
  }
}

///|
fn decimal_digit_value(char : UInt16) -> Int? {
  if char >= '0' && char <= '9' {
    Some(char.to_int() - '0'.to_int())
  } else {
    None
  }
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
fn BodyReader::calculate_table_row_spans(
  self : BodyReader,
  elements : Array[DocumentElement],
) -> Array[DocumentElement] {
  let mut unexpected_non_row = false
  for row in elements {
    match row {
      TableRow(..) => ()
      _ => unexpected_non_row = true
    }
  }
  if unexpected_non_row {
    self.warn(
      "unexpected non-row element in table, cell merging may be incorrect",
    )
    return elements
  }
  let mut unexpected_non_cell = false
  for row in elements {
    match row {
      TableRow(children~, ..) =>
        for cell in children {
          match cell {
            TableCell(..) => ()
            _ => unexpected_non_cell = true
          }
        }
      _ => ()
    }
  }
  if unexpected_non_cell {
    self.warn(
      "unexpected non-cell element in table row, cell merging may be incorrect",
    )
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
