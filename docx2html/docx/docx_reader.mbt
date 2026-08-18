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
/// One input-linear index shared by package projection and strict annotation
/// validation. Values stay arrays so duplicate relationship IDs retain their
/// fail-closed meaning instead of being silently overwritten.
priv struct RelationshipIndex {
  by_id : StableStringMap[Array[Relationship]]
}

///|
fn RelationshipIndex::build(relationships : Relationships) -> RelationshipIndex {
  let by_id : StableStringMap[Array[Relationship]] = SortedMap([])
  for relationship in relationships.relationships {
    let matches = match by_id.get(relationship.id) {
      Some(existing) => existing
      None => {
        let fresh : Array[Relationship] = []
        by_id[relationship.id] = fresh
        fresh
      }
    }
    matches.push(relationship)
  }
  { by_id, }
}

///|
/// Relationship IDs are package-scoped identities. Missing and duplicate IDs
/// are both unresolved here: callers must never choose an attacker-controlled
/// first declaration from an ambiguous relationship set.
fn RelationshipIndex::find_unique_by_id(
  self : RelationshipIndex,
  id : String,
) -> Relationship? {
  match self.by_id.get(id) {
    Some([relationship]) => Some(relationship)
    _ => None
  }
}

///|
fn RelationshipIndex::find_unique_target_by_id(
  self : RelationshipIndex,
  id : String,
) -> String? {
  match self.find_unique_by_id(id) {
    Some(relationship) => Some(relationship.target)
    None => None
  }
}

///|
const TRANSITIONAL_OFFICE_DOCUMENT_RELATIONSHIP : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"

///|
const STRICT_OFFICE_DOCUMENT_RELATIONSHIP : String = "http://purl.oclc.org/ooxml/officeDocument/relationships/officeDocument"

///|
const PACKAGE_RELATIONSHIPS_ROOT : String = "{http://schemas.openxmlformats.org/package/2006/relationships}Relationships"

///|
const PACKAGE_RELATIONSHIP_ELEMENT : String = "{http://schemas.openxmlformats.org/package/2006/relationships}Relationship"

///|
const TRANSITIONAL_COMMENTS_RELATIONSHIP : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments"

///|
const STRICT_COMMENTS_RELATIONSHIP : String = "http://purl.oclc.org/ooxml/officeDocument/relationships/comments"

///|
const COMMENTS_EXTENDED_RELATIONSHIP : String = "http://schemas.microsoft.com/office/2011/relationships/commentsExtended"

///|
const TRANSITIONAL_HEADER_RELATIONSHIP : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/header"

///|
const TRANSITIONAL_FOOTER_RELATIONSHIP : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer"

///|
const TRANSITIONAL_FOOTNOTES_RELATIONSHIP : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes"

///|
const TRANSITIONAL_ENDNOTES_RELATIONSHIP : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/endnotes"

///|
const STRICT_HEADER_RELATIONSHIP : String = "http://purl.oclc.org/ooxml/officeDocument/relationships/header"

///|
const STRICT_FOOTER_RELATIONSHIP : String = "http://purl.oclc.org/ooxml/officeDocument/relationships/footer"

///|
const STRICT_FOOTNOTES_RELATIONSHIP : String = "http://purl.oclc.org/ooxml/officeDocument/relationships/footnotes"

///|
const STRICT_ENDNOTES_RELATIONSHIP : String = "http://purl.oclc.org/ooxml/officeDocument/relationships/endnotes"

///|
const TRANSITIONAL_STYLES_RELATIONSHIP : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles"

///|
const STRICT_STYLES_RELATIONSHIP : String = "http://purl.oclc.org/ooxml/officeDocument/relationships/styles"

///|
const TRANSITIONAL_NUMBERING_RELATIONSHIP : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering"

///|
const STRICT_NUMBERING_RELATIONSHIP : String = "http://purl.oclc.org/ooxml/officeDocument/relationships/numbering"

///|
const STYLES_CONTENT_TYPE : String = "application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"

///|
const NUMBERING_CONTENT_TYPE : String = "application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"

///|
const COMMENTS_CONTENT_TYPE : String = "application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml"

///|
const COMMENTS_EXTENDED_CONTENT_TYPE : String = "application/vnd.openxmlformats-officedocument.wordprocessingml.commentsExtended+xml"

///|
const FOOTNOTES_CONTENT_TYPE : String = "application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml"

///|
const ENDNOTES_CONTENT_TYPE : String = "application/vnd.openxmlformats-officedocument.wordprocessingml.endnotes+xml"

///|
const HEADER_CONTENT_TYPE : String = "application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"

///|
const FOOTER_CONTENT_TYPE : String = "application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"

///|
priv enum OoxmlDialect {
  TransitionalOoxml
  StrictOoxml
}

///|
fn same_ooxml_dialect(left : OoxmlDialect, right : OoxmlDialect) -> Bool {
  match (left, right) {
    (TransitionalOoxml, TransitionalOoxml) | (StrictOoxml, StrictOoxml) => true
    _ => false
  }
}

///|
fn wordprocessing_dialect(uri : String) -> OoxmlDialect? {
  match uri {
    WORDPROCESSINGML_NAMESPACE => Some(TransitionalOoxml)
    STRICT_WORDPROCESSINGML_NAMESPACE => Some(StrictOoxml)
    _ => None
  }
}

///|
fn office_relationship_dialect(relationship_type : String) -> OoxmlDialect? {
  match relationship_type {
    TRANSITIONAL_OFFICE_DOCUMENT_RELATIONSHIP => Some(TransitionalOoxml)
    STRICT_OFFICE_DOCUMENT_RELATIONSHIP => Some(StrictOoxml)
    _ => None
  }
}

///|
fn OoxmlDialect::namespace_uri(self : OoxmlDialect) -> String {
  match self {
    TransitionalOoxml => WORDPROCESSINGML_NAMESPACE
    StrictOoxml => STRICT_WORDPROCESSINGML_NAMESPACE
  }
}

///|
fn OoxmlDialect::comments_relationship_type(self : OoxmlDialect) -> String {
  match self {
    TransitionalOoxml => TRANSITIONAL_COMMENTS_RELATIONSHIP
    StrictOoxml => STRICT_COMMENTS_RELATIONSHIP
  }
}

///|
/// One normalized main-relationship target whose XML can carry annotation
/// markers or paragraph identities. `kind` is one of header/footer/footnotes/
/// endnotes. Relationship order is preserved; normalized duplicate targets are
/// emitted once.
priv struct ReachableAnnotationStoryPart {
  kind : String
  path : String
  relationship_dialect : OoxmlDialect
}

///|
priv struct RelatedWordprocessingPart {
  path : String
  relationship_dialect : OoxmlDialect
}

///|
priv enum WordprocessingPartRole {
  StylesPartRole
  NumberingPartRole
}

///|
fn WordprocessingPartRole::label(self : WordprocessingPartRole) -> String {
  match self {
    StylesPartRole => "styles"
    NumberingPartRole => "numbering"
  }
}

///|
fn WordprocessingPartRole::content_type(
  self : WordprocessingPartRole,
) -> String {
  match self {
    StylesPartRole => STYLES_CONTENT_TYPE
    NumberingPartRole => NUMBERING_CONTENT_TYPE
  }
}

///|
fn same_wordprocessing_part_role(
  left : WordprocessingPartRole,
  right : WordprocessingPartRole,
) -> Bool {
  match (left, right) {
    (StylesPartRole, StylesPartRole) | (NumberingPartRole, NumberingPartRole) =>
      true
    _ => false
  }
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
  levels : StableStringMap[NumberingLevel]
  num_style_link : String?
}

///|
priv enum NumberingLinkResolution {
  ResolvedAbstractNumbering(String)
  UnresolvableNumbering
}

///|
priv struct NumberingMap {
  abstract_nums : StableStringMap[AbstractNumbering]
  levels_by_paragraph_style_id : StableStringMap[NumberingLevel]
  resolved_abstract_num_ids : StableStringMap[NumberingLinkResolution]
}

///|
fn NumberingMap::empty() -> NumberingMap {
  {
    abstract_nums: SortedMap([]),
    levels_by_paragraph_style_id: SortedMap([]),
    resolved_abstract_num_ids: SortedMap([]),
  }
}

///|
priv struct ContentTypes {
  defaults : StableStringMap[String]
  overrides : StableStringMap[String]
}

///|
/// Document tree plus diagnostics produced while reading a DOCX package.
pub(all) struct DocxReadResult {
  document : DocumentElement
  messages : Array[Message]
} derive(Debug, Eq)

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
  // Raw identity attributes stay aligned with `notes`. The package
  // projection intentionally keeps Mammoth's legacy `"undefined"` spelling;
  // D2 derives its missing-id spelling from this lossless source separately.
  annotation_ids : Array[String?]
  messages : Array[Message]
}

///|
priv struct CommentsReadResult {
  comments : Array[Comment]
  // Raw identity attributes stay aligned with `comments`; see
  // `NotesReadResult::annotation_ids` above.
  annotation_ids : Array[String?]
  messages : Array[Message]
}

///|
priv struct TableRowForSpan {
  cells : Array[TableCellForSpan]
  is_header : Bool
  // None while the `w:sdt` legacy island can still hand this pass erased
  // rows; those rebuild as `Legacy` below
  source : ReaderNode?
}

///|
priv struct TableCellForSpan {
  children : Array[ReaderItem]
  col_span : Int
  row_span : Int
  source : ReaderNode?
}

///|
/// Converts DOCX bytes to HTML.
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
  convert(
    docx,
    output_format=Html,
    style_map~,
    include_default_style_map~,
    include_embedded_style_map~,
    ignore_empty_paragraphs~,
    id_prefix~,
    pretty_print~,
    convert_image~,
    transform_document~,
    external_file_access~,
    read_external_file~,
  )
}

///|
/// Converts DOCX bytes to Markdown.
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
  convert(
    docx,
    output_format=Markdown,
    style_map~,
    include_default_style_map~,
    include_embedded_style_map~,
    ignore_empty_paragraphs~,
    id_prefix~,
    convert_image~,
    transform_document~,
    external_file_access~,
    read_external_file~,
  )
}

///|
/// Converts DOCX bytes using the requested output format.
pub fn convert(
  docx : BytesView,
  output_format? : OutputFormat = Html,
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
  let result = convert_document(
    read_result.document,
    output_format~,
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
/// Extracts raw text from DOCX bytes.
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
    { value: result.value, messages: @core.dedupe_messages(combined) }
  }
}

///|
/// Reads the embedded style map from DOCX bytes, if present.
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
/// Reads DOCX bytes into a document tree.
pub fn read_docx(
  docx : BytesView,
  external_file_access? : Bool = false,
  read_external_file? : (String) -> Bytes? = no_external_file_reader,
) -> DocumentElement raise DocxError {
  read_docx_with_messages(docx, external_file_access~, read_external_file~).document
}

///|
/// Reads DOCX bytes into a document tree and diagnostics.
pub fn read_docx_with_messages(
  docx : BytesView,
  external_file_access? : Bool = false,
  read_external_file? : (String) -> Bytes? = no_external_file_reader,
) -> DocxReadResult raise DocxError {
  read_docx_zip_with_messages(
    open_zip(docx),
    external_files=external_file_access_options(
      external_file_access, read_external_file,
    ),
  )
}

///|
/// The package projection retains Mammoth's JavaScript-derived `"undefined"`
/// sentinel. D2 identity is derived separately from the raw optional
/// attribute retained beside each parsed annotation definition.
fn annotation_id_or_missing(value : String?) -> String {
  match value {
    Some(id) => id
    None => "undefined"
  }
}

///|
/// The assembled per-document reading context: every part-derived input the
/// body/story readers need. Shared by `read_docx_zip_with_messages` (the
/// frozen body-only surface) and `read_docx_package` (body + sections +
/// header/footer stories).
priv struct DocumentParts {
  zip : ZipArchive
  xml_budget : @xml.XmlReadBudget?
  diagnostics : ReaderDiagnosticCollector?
  main_document_path : String
  main_relationship_dialect : OoxmlDialect?
  root : XmlElement
  styles : StableStringMap[StyleInfo]
  numbering : NumberingMap
  content_types : ContentTypes
  relationships : Relationships
  relationship_index : RelationshipIndex
  base_path : String
  notes_result : NotesReadResult
  comments_result : CommentsReadResult
  // Authoritative main-part relationship targets. `None` means no such
  // relationship was declared; legacy filename fallbacks remain reader-only
  // and are never exposed as wired annotation parts.
  comments_part_path : String?
  comments_extended_part_path : String?
  footnotes_part_path : String?
  endnotes_part_path : String?
  external_files : ExternalFileAccess
  read_images : Bool
}

///|
fn DocumentParts::build(
  zip : ZipArchive,
  external_files? : ExternalFileAccess = default_external_file_access(),
  read_images? : Bool = true,
  xml_budget? : @xml.XmlReadBudget,
  diagnostics? : ReaderDiagnosticCollector,
  expected_main_document_path? : String,
  strict_main_document? : Bool = false,
) -> DocumentParts raise DocxError {
  let main_document = find_main_document(
    zip,
    xml_budget?,
    expected_main_document_path?,
  )
  let main_document_path = main_document.path
  let relationships = read_relationships(
    zip,
    relationships_path_for_part(zip, main_document_path),
    xml_budget?,
  )
  let relationship_index = RelationshipIndex::build(relationships)
  let content_types = read_content_types(zip, xml_budget?)
  let logical_main_document_path = zip
    .logical_path(main_document_path)
    .unwrap_or(main_document_path)
  let base_path = split_zip_path(logical_main_document_path).0
  let comments_part_path = resolve_unique_internal_part(
    zip,
    relationships,
    [TRANSITIONAL_COMMENTS_RELATIONSHIP, STRICT_COMMENTS_RELATIONSHIP],
    base_path,
    "comments",
    reject_multiple_relationships=true,
  )
  let comments_extended_part_path = resolve_unique_internal_part(
    zip,
    relationships,
    [COMMENTS_EXTENDED_RELATIONSHIP],
    base_path,
    "commentsExtended",
    reject_multiple_relationships=true,
  )
  let footnotes_part_path = resolve_unique_internal_part(
    zip,
    relationships,
    [TRANSITIONAL_FOOTNOTES_RELATIONSHIP, STRICT_FOOTNOTES_RELATIONSHIP],
    base_path,
    "footnotes",
    reject_multiple_relationships=true,
  )
  let endnotes_part_path = resolve_unique_internal_part(
    zip,
    relationships,
    [TRANSITIONAL_ENDNOTES_RELATIONSHIP, STRICT_ENDNOTES_RELATIONSHIP],
    base_path,
    "endnotes",
    reject_multiple_relationships=true,
  )
  content_types.require_annotation_part(zip, comments_part_path, "comments")
  content_types.require_annotation_part(
    zip, comments_extended_part_path, "commentsExtended",
  )
  content_types.require_annotation_part(zip, footnotes_part_path, "footnotes")
  content_types.require_annotation_part(zip, endnotes_part_path, "endnotes")
  let styles_part = resolve_unique_wordprocessing_part(
    zip,
    relationships,
    base_path,
    StylesPartRole,
    main_document.relationship_dialect,
  )
  let numbering_part = resolve_unique_wordprocessing_part(
    zip,
    relationships,
    base_path,
    NumberingPartRole,
    main_document.relationship_dialect,
  )
  let styles = match styles_part {
    Some(part) => {
      content_types.require_wordprocessing_part(zip, part, StylesPartRole)
      read_styles_xml(
        read_wordprocessing_role_xml_part(
          zip,
          part,
          StylesPartRole,
          xml_budget?,
        ),
      )
    }
    None => SortedMap([])
  }
  let numbering = match numbering_part {
    Some(part) => {
      content_types.require_wordprocessing_part(zip, part, NumberingPartRole)
      read_numbering_xml(
        read_wordprocessing_role_xml_part(
          zip,
          part,
          NumberingPartRole,
          xml_budget?,
        ),
        styles,
      )
    }
    None => NumberingMap::empty()
  }
  let notes_result = read_notes_for_document(
    zip,
    styles,
    numbering,
    content_types,
    footnotes_path=footnotes_part_path.unwrap_or("word/footnotes.xml"),
    endnotes_path=endnotes_part_path.unwrap_or("word/endnotes.xml"),
    external_files~,
    read_images~,
    xml_budget?,
    diagnostics?,
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
    xml_budget?,
    comments_part_path?,
    diagnostics?,
  )
  // Every public package projection uses the tolerant reader semantics.
  // Mutation-safe annotated reads validate the same source again through the
  // strict identity gate before exposing byte spans, without substituting the
  // strict parser's normalized DOM into the returned document model.
  let root = read_xml_part(zip, main_document_path, xml_budget?)
  if strict_main_document {
    validate_xml_part_strict_locally(zip, main_document_path)
  }
  {
    zip,
    xml_budget,
    diagnostics,
    main_document_path,
    main_relationship_dialect: main_document.relationship_dialect,
    root,
    styles,
    numbering,
    content_types,
    relationships,
    relationship_index,
    base_path,
    notes_result,
    comments_result,
    comments_part_path,
    comments_extended_part_path,
    footnotes_part_path,
    endnotes_part_path,
    external_files,
    read_images,
  }
}

///|
fn DocumentParts::read_document(
  self : DocumentParts,
) -> DocxReadResult raise DocxError {
  read_document_xml_with_messages(
    self.root,
    self.styles,
    self.numbering,
    self.zip,
    self.relationship_index,
    self.content_types,
    self.base_path,
    self.notes_result.notes,
    self.comments_result.comments,
    external_files=self.external_files,
    read_images=self.read_images,
    diagnostics?=self.diagnostics,
  )
}

///|
fn read_docx_zip_with_messages(
  zip : ZipArchive,
  external_files? : ExternalFileAccess = default_external_file_access(),
  read_images? : Bool = true,
) -> DocxReadResult raise DocxError {
  let parts = DocumentParts::build(zip, external_files~, read_images~)
  let document_result = parts.read_document()
  let messages : Array[Message] = []
  messages.append(parts.notes_result.messages)
  messages.append(parts.comments_result.messages)
  messages.append(document_result.messages)
  {
    document: document_result.document,
    messages: @core.dedupe_messages(messages),
  }
}

///|
fn read_xml_part(
  zip : ZipArchive,
  path : String,
  xml_budget? : @xml.XmlReadBudget,
) -> XmlElement raise DocxError {
  read_xml_part_with_root_namespace_uri(zip, path, xml_budget?).1
}

///|
/// Reads one tolerant XML part while retaining the namespace identity of its
/// document element. The DOM's canonical name alone cannot distinguish a
/// bound QName from an identical literal name whose prefix is unbound.
fn read_xml_part_with_root_namespace_uri(
  zip : ZipArchive,
  path : String,
  xml_budget? : @xml.XmlReadBudget,
) -> (String?, XmlElement) raise DocxError {
  match zip.read_bytes(path) {
    Some(bytes) =>
      match xml_budget {
        Some(budget) =>
          @xml.read_xml_bytes_limited_with_root_namespace_uri(
            bytes,
            budget,
            namespace_map=office_namespace_map(),
          )
        None => {
          let text = @utf8.decode(bytes, ignore_bom=true) catch {
            _ => raise InvalidXml(message="part is not valid UTF-8: " + path)
          }
          @xml.read_xml_string_with_root_namespace_uri(
            text,
            namespace_map=office_namespace_map(),
          )
        }
      }
    None => raise MissingPart(message="missing DOCX part: " + path)
  }
}

///|
/// Strictly validates the mutation-safe main story without charging its source
/// twice to the caller's cumulative retained-DOM budget. The tolerant DOM was
/// already charged by `read_xml_part`; this discarded validation DOM receives
/// an input-linear transient budget of its own.
fn validate_xml_part_strict_locally(
  zip : ZipArchive,
  path : String,
) -> Unit raise DocxError {
  guard zip.read_bytes(path) is Some(bytes) else {
    raise MissingPart(message="missing DOCX part: " + path)
  }
  @xml.read_xml_bytes_strict_limited(
    bytes,
    local_input_linear_xml_budget(bytes),
    namespace_map=office_namespace_map(),
  )
  |> ignore
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
    "http://schemas.microsoft.com/office/word/2010/wordml": "w14",
    "http://schemas.microsoft.com/office/word/2012/wordml": "w15",
    "urn:schemas-microsoft-com:office:office": "o",
    "urn:schemas-microsoft-com:office:word": "office-word",
    "urn:schemas-microsoft-com:vml": "v",
  }
}

///|
fn wordprocessing_role_namespace_map(
  dialect : OoxmlDialect,
) -> Map[String, String] {
  let namespaces = office_namespace_map()
  match dialect {
    TransitionalOoxml =>
      namespaces[STRICT_WORDPROCESSINGML_NAMESPACE] = "w-incompatible"
    StrictOoxml => namespaces[WORDPROCESSINGML_NAMESPACE] = "w-incompatible"
  }
  namespaces
}

///|
fn read_wordprocessing_role_xml_part(
  zip : ZipArchive,
  part : RelatedWordprocessingPart,
  role : WordprocessingPartRole,
  xml_budget? : @xml.XmlReadBudget,
) -> XmlElement raise DocxError {
  guard zip.read_bytes(part.path) is Some(bytes) else {
    raise MissingPart(message="missing DOCX part: " + part.path)
  }
  let namespace_map = wordprocessing_role_namespace_map(
    part.relationship_dialect,
  )
  let root = match xml_budget {
    Some(budget) =>
      @xml.read_xml_bytes_strict_limited(bytes, budget, namespace_map~)
    None => {
      let text = @utf8.decode(bytes, ignore_bom=true) catch {
        _ => raise InvalidXml(message="part is not valid UTF-8: " + part.path)
      }
      @xml.read_xml_string_strict(text, namespace_map~)
    }
  }
  let kind = role.label()
  let expected_root = "w:" + kind
  if root.name != expected_root {
    raise Unsupported(
      message="the \{kind} relationship target '\{part.path}' has root '\{root.name}', expected '\{expected_root}' in the relationship dialect",
    )
  }
  root
}

///|
priv struct MainDocumentPart {
  path : String
  relationship_dialect : OoxmlDialect?
}

///|
fn find_main_document(
  zip : ZipArchive,
  xml_budget? : @xml.XmlReadBudget,
  expected_main_document_path? : String,
) -> MainDocumentPart raise DocxError {
  let relationships = read_relationships(zip, "_rels/.rels", xml_budget?)
  let path = resolve_unique_internal_part(
    zip,
    relationships,
    [
      TRANSITIONAL_OFFICE_DOCUMENT_RELATIONSHIP,
      STRICT_OFFICE_DOCUMENT_RELATIONSHIP,
    ],
    "",
    "officeDocument",
    reject_multiple_relationships=true,
  )
  fn authoritative_part(authoritative : String) -> MainDocumentPart {
    let mut relationship_dialect : OoxmlDialect? = None
    for relationship in relationships.relationships {
      match office_relationship_dialect(relationship.relationship_type) {
        Some(dialect) => relationship_dialect = Some(dialect)
        None => ()
      }
    }
    { path: authoritative, relationship_dialect }
  }
  match expected_main_document_path {
    Some(expected) =>
      match path {
        Some(authoritative) if authoritative == expected =>
          authoritative_part(authoritative)
        Some(_) =>
          raise Unsupported(
            message="the DOCX reader selected a different main document part than structural validation",
          )
        None =>
          raise Unsupported(
            message="the structurally validated officeDocument relationship was not recognized by the DOCX reader",
          )
      }
    None =>
      match path {
        Some(authoritative) => authoritative_part(authoritative)
        None =>
          match zip.resolve_path("word/document.xml") {
            Some(actual) => { path: actual, relationship_dialect: None }
            None =>
              raise MissingPart(
                message="Could not find main document part. Are you sure this is a valid .docx file?",
              )
          }
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
  xml_budget? : @xml.XmlReadBudget,
) -> Relationships raise DocxError {
  match zip.read_bytes(path) {
    Some(bytes) => decode_relationships_bytes(bytes, xml_budget?)
    None => { relationships: [] }
  }
}

///|
fn decode_relationships_bytes(
  bytes : BytesView,
  xml_budget? : @xml.XmlReadBudget,
) -> Relationships raise DocxError {
  let budget = match xml_budget {
    Some(value) => value
    None => local_input_linear_xml_budget(bytes)
  }
  read_relationships_xml(@opc.read_opc_relationships_xml_limited(bytes, budget))
}

///|
/// Strict DTD-free relationship read for security-sensitive identity walks.
/// The caller-owned budget is cumulative across the relationship graph and all
/// subsequently visited story parts.
fn read_relationships_strict_limited(
  zip : ZipArchive,
  path : String,
  xml_budget : @xml.XmlReadBudget,
) -> Relationships raise DocxError {
  match zip.read_bytes(path) {
    Some(bytes) => decode_relationships_bytes(bytes, xml_budget~)
    None => { relationships: [] }
  }
}

///|
fn read_relationships_xml(root : XmlElement) -> Relationships {
  let relationships : Array[Relationship] = []
  for node in root.children {
    guard node is XmlElement(rel) &&
      (
        rel.name == PACKAGE_RELATIONSHIP_ELEMENT ||
        rel.name == "relationships:Relationship"
      ) else {
      continue
    }
    relationships.push({
      id: @xml.collapse_xml_schema_whitespace(
        rel.attributes.get_or_default("Id", ""),
      ),
      relationship_type: @xml.collapse_xml_schema_whitespace(
        rel.attributes.get_or_default("Type", ""),
      ),
      target: @xml.collapse_xml_schema_whitespace(
        rel.attributes.get_or_default("Target", ""),
      ),
      target_mode: rel.attributes.get("TargetMode"),
    })
  }
  { relationships, }
}

///|
/// Gives otherwise-unbounded library reads an input-linear strict XML budget.
/// Namespace expansion can materialize substantially more text than the
/// compact source, so derived work receives a conservative constant factor.
fn local_input_linear_xml_budget(bytes : BytesView) -> @xml.XmlReadBudget {
  let scaled = bytes.length().to_int64() * 32L
  let allowance = if scaled <= 0L {
    1
  } else if scaled > 2147483647L {
    2147483647
  } else {
    scaled.to_int()
  }
  @xml.xml_read_budget(
    max_source_units=bytes.length(),
    max_tokens=allowance,
    max_materialized_chars=allowance,
    max_token_chars=if bytes.length() > 0 { bytes.length() } else { 1 },
  )
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
/// Resolves one authoritative internal relationship target. Distinct targets,
/// external/invalid modes, empty targets, and missing declared targets fail
/// closed. Callers may apply a legacy filename fallback only when this returns
/// `None`, which means no matching relationship was declared at all.
fn resolve_unique_internal_part(
  zip : ZipArchive,
  relationships : Relationships,
  relationship_types : ReadOnlyArray[String],
  base_path : String,
  label : String,
  reject_multiple_relationships? : Bool = false,
) -> String? raise DocxError {
  let targets : Array[String] = []
  let seen : StableStringSet = SortedSet([])
  let mut matches = 0
  for relationship in relationships.relationships {
    if relationship_types.search(relationship.relationship_type) is None {
      continue
    }
    matches += 1
    match relationship.target_mode {
      None | Some("Internal") => ()
      _ =>
        raise Unsupported(message="the \{label} relationship must be internal")
    }
    if relationship.target == "" {
      raise Unsupported(message="the \{label} relationship has no target")
    }
    guard @opc.resolve_part_target(base_path, relationship.target)
      is Some(resolved) else {
      raise Unsupported(message="the \{label} relationship target is invalid")
    }
    guard zip.resolve_path(resolved) is Some(actual) else {
      raise MissingPart(
        message="the \{label} relationship targets a missing part",
      )
    }
    if !seen.contains(actual) {
      seen.add(actual)
      targets.push(actual)
    }
  }
  match targets {
    [] => None
    [target] =>
      if reject_multiple_relationships && matches > 1 {
        raise Unsupported(
          message="the document declares multiple \{label} relationships",
        )
      } else {
        Some(target)
      }
    _ =>
      raise Unsupported(
        message="the document declares multiple distinct \{label} relationship targets",
      )
  }
}

///|
fn wordprocessing_role_relationship_identity(
  relationship_type : String,
) -> (WordprocessingPartRole, OoxmlDialect)? {
  match relationship_type {
    TRANSITIONAL_STYLES_RELATIONSHIP =>
      Some((StylesPartRole, TransitionalOoxml))
    STRICT_STYLES_RELATIONSHIP => Some((StylesPartRole, StrictOoxml))
    TRANSITIONAL_NUMBERING_RELATIONSHIP =>
      Some((NumberingPartRole, TransitionalOoxml))
    STRICT_NUMBERING_RELATIONSHIP => Some((NumberingPartRole, StrictOoxml))
    _ => None
  }
}

///|
/// Styles and numbering are optional relationship roles, not conventional
/// filenames. A declared role must match the main package dialect and resolve
/// to exactly one internal part before any XML from that target is consumed.
fn resolve_unique_wordprocessing_part(
  zip : ZipArchive,
  relationships : Relationships,
  base_path : String,
  role : WordprocessingPartRole,
  main_dialect : OoxmlDialect?,
) -> RelatedWordprocessingPart? raise DocxError {
  let kind = role.label()
  let parts : Array[RelatedWordprocessingPart] = []
  let seen : StableStringSet = SortedSet([])
  let mut matches = 0
  for relationship in relationships.relationships {
    guard wordprocessing_role_relationship_identity(
        relationship.relationship_type,
      )
      is Some((relationship_kind, relationship_dialect)) else {
      continue
    }
    if !same_wordprocessing_part_role(relationship_kind, role) {
      continue
    }
    match main_dialect {
      Some(expected) if !same_ooxml_dialect(expected, relationship_dialect) =>
        raise Unsupported(
          message="the \{kind} relationship dialect does not match the main document relationship",
        )
      _ => ()
    }
    matches += 1
    match relationship.target_mode {
      None | Some("Internal") => ()
      _ =>
        raise Unsupported(message="the \{kind} relationship must be internal")
    }
    if relationship.target == "" {
      raise Unsupported(message="the \{kind} relationship has no target")
    }
    guard @opc.resolve_part_target(base_path, relationship.target)
      is Some(resolved) else {
      raise Unsupported(message="the \{kind} relationship target is invalid")
    }
    guard zip.resolve_path(resolved) is Some(actual) else {
      raise MissingPart(
        message="the \{kind} relationship targets a missing part",
      )
    }
    if !seen.contains(actual) {
      seen.add(actual)
      parts.push({ path: actual, relationship_dialect })
    }
  }
  if matches > 1 {
    raise Unsupported(
      message="the document declares multiple \{kind} relationships",
    )
  }
  match parts {
    [] => None
    [part] => Some(part)
    _ =>
      raise Unsupported(
        message="the document declares multiple distinct \{kind} relationship targets",
      )
  }
}

///|
fn annotation_story_relationship_identity(
  relationship_type : String,
) -> (String, OoxmlDialect)? {
  match relationship_type {
    TRANSITIONAL_COMMENTS_RELATIONSHIP => Some(("comments", TransitionalOoxml))
    STRICT_COMMENTS_RELATIONSHIP => Some(("comments", StrictOoxml))
    TRANSITIONAL_HEADER_RELATIONSHIP => Some(("header", TransitionalOoxml))
    STRICT_HEADER_RELATIONSHIP => Some(("header", StrictOoxml))
    TRANSITIONAL_FOOTER_RELATIONSHIP => Some(("footer", TransitionalOoxml))
    STRICT_FOOTER_RELATIONSHIP => Some(("footer", StrictOoxml))
    TRANSITIONAL_FOOTNOTES_RELATIONSHIP =>
      Some(("footnotes", TransitionalOoxml))
    STRICT_FOOTNOTES_RELATIONSHIP => Some(("footnotes", StrictOoxml))
    TRANSITIONAL_ENDNOTES_RELATIONSHIP => Some(("endnotes", TransitionalOoxml))
    STRICT_ENDNOTES_RELATIONSHIP => Some(("endnotes", StrictOoxml))
    _ => None
  }
}

///|
/// Resolves every annotation-bearing main-part relationship authoritatively.
/// External, empty, missing, or cross-kind aliasing targets fail closed; same-
/// kind aliases that normalize to one OPC path are deduplicated.
fn resolve_reachable_annotation_story_parts(
  zip : ZipArchive,
  relationships : Relationships,
  base_path : String,
) -> Array[ReachableAnnotationStoryPart] raise DocxError {
  let resolved_parts : Array[ReachableAnnotationStoryPart] = []
  let kind_by_path : StableStringMap[String] = SortedMap([])
  let dialect_by_path : StableStringMap[OoxmlDialect] = SortedMap([])
  for relationship in relationships.relationships {
    guard annotation_story_relationship_identity(relationship.relationship_type)
      is Some((kind, relationship_dialect)) else {
      continue
    }
    match relationship.target_mode {
      None | Some("Internal") => ()
      _ =>
        raise Unsupported(message="the \{kind} relationship must be internal")
    }
    if relationship.target == "" {
      raise Unsupported(message="the \{kind} relationship has no target")
    }
    guard @opc.resolve_part_target(base_path, relationship.target) is Some(path) else {
      raise Unsupported(message="the \{kind} relationship target is invalid")
    }
    guard zip.resolve_path(path) is Some(actual) else {
      raise MissingPart(
        message="the \{kind} relationship targets missing part '\{path}'",
      )
    }
    match kind_by_path.get(actual) {
      Some(existing_kind) if existing_kind != kind =>
        raise Unsupported(
          message="annotation story part '\{actual}' is targeted as both \{existing_kind} and \{kind}",
        )
      Some(_) => {
        guard dialect_by_path.get(actual) is Some(existing_dialect) else {
          raise Unsupported(
            message="the \{kind} relationship dialect could not be determined",
          )
        }
        if !same_ooxml_dialect(existing_dialect, relationship_dialect) {
          raise Unsupported(
            message="annotation story part '\{actual}' has conflicting Strict and Transitional \{kind} relationships",
          )
        }
        continue
      }
      None => ()
    }
    kind_by_path[actual] = kind
    dialect_by_path[actual] = relationship_dialect
    resolved_parts.push({ kind, path: actual, relationship_dialect })
  }
  resolved_parts
}

///|
/// Resolves a section's header/footer reference through exactly one internal
/// relationship of the matching semantic type. This is shared by the tolerant
/// package projection and the strict annotation-identity gate so the two paths
/// cannot disagree about what a section reference means.
fn resolve_header_footer_reference_part(
  zip : ZipArchive,
  relationship_index : RelationshipIndex,
  base_path : String,
  id : String,
  is_header : Bool,
) -> String raise DocxError {
  let kind = if is_header { "header" } else { "footer" }
  guard relationship_index.by_id.get(id) is Some(matches) else {
    raise Unsupported(
      message="the \{kind} reference names unknown relationship id '\{id}'",
    )
  }
  if matches.length() != 1 {
    raise Unsupported(
      message="the \{kind} reference names duplicate relationship id '\{id}'",
    )
  }
  let relationship = matches[0]
  let type_matches = if is_header {
    relationship.relationship_type == TRANSITIONAL_HEADER_RELATIONSHIP ||
    relationship.relationship_type == STRICT_HEADER_RELATIONSHIP
  } else {
    relationship.relationship_type == TRANSITIONAL_FOOTER_RELATIONSHIP ||
    relationship.relationship_type == STRICT_FOOTER_RELATIONSHIP
  }
  if !type_matches {
    raise Unsupported(
      message="the \{kind} reference relationship '\{id}' is not a \{kind} relationship",
    )
  }
  match relationship.target_mode {
    None | Some("Internal") => ()
    _ =>
      raise Unsupported(
        message="the \{kind} reference relationship '\{id}' must be internal",
      )
  }
  if relationship.target == "" {
    raise Unsupported(
      message="the \{kind} reference relationship '\{id}' has no target",
    )
  }
  guard @opc.resolve_part_target(base_path, relationship.target) is Some(path) else {
    raise Unsupported(
      message="the \{kind} reference relationship '\{id}' has an invalid target",
    )
  }
  match zip.resolve_path(path) {
    Some(actual) => actual
    None =>
      raise MissingPart(
        message="the \{kind} reference relationship '\{id}' targets missing part '\{path}'",
      )
  }
}

///|
fn relationships_path_for_part(zip : ZipArchive, path : String) -> String {
  let logical_path = zip.logical_path(path).unwrap_or(path)
  let (dir, base) = split_zip_path(logical_path)
  join_zip_path([dir, "_rels", base + ".rels"])
}

///|
fn read_content_types(
  zip : ZipArchive,
  xml_budget? : @xml.XmlReadBudget,
) -> ContentTypes raise DocxError {
  let defaults : StableStringMap[String] = SortedMap([])
  let overrides : StableStringMap[String] = SortedMap([])
  match zip.read_bytes("[Content_Types].xml") {
    Some(_) => {
      let root = read_xml_part(zip, "[Content_Types].xml", xml_budget?)
      for element in root.elements_by_tag_name("content-types:Default") {
        let extension = element.attributes.get_or_default("Extension", "")
        let content_type = element.attributes.get_or_default("ContentType", "")
        if extension != "" && content_type != "" {
          defaults[@opc.part_name_key(extension)] = content_type
        }
      }
      for element in root.elements_by_tag_name("content-types:Override") {
        let part_name = element.attributes.get_or_default("PartName", "")
        let content_type = element.attributes.get_or_default("ContentType", "")
        if part_name != "" && content_type != "" {
          match @opc.resolve_part_target("", part_name) {
            Some(logical) if "/" + logical == part_name =>
              overrides[@opc.part_name_key(logical)] = content_type
            _ => ()
          }
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
  zip? : ZipArchive,
) -> String {
  let requested = strip_leading_slash(path)
  let logical = match zip {
    Some(archive) => archive.logical_path(requested).unwrap_or(requested)
    None => requested
  }
  let normalized = @opc.part_name_key(logical)
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
fn expected_annotation_content_type(kind : String) -> String? {
  match kind {
    "comments" => Some(COMMENTS_CONTENT_TYPE)
    "commentsExtended" => Some(COMMENTS_EXTENDED_CONTENT_TYPE)
    "footnotes" => Some(FOOTNOTES_CONTENT_TYPE)
    "endnotes" => Some(ENDNOTES_CONTENT_TYPE)
    "header" => Some(HEADER_CONTENT_TYPE)
    "footer" => Some(FOOTER_CONTENT_TYPE)
    _ => None
  }
}

///|
/// Relationship roles, target existence, root QNames, and content types form one
/// identity contract. A generic XML default is not sufficient for an OOXML
/// annotation story even when the target's root element looks plausible.
fn ContentTypes::require_annotation_part(
  self : ContentTypes,
  zip : ZipArchive,
  path : String?,
  kind : String,
) -> Unit raise DocxError {
  guard path is Some(path) else { return }
  guard expected_annotation_content_type(kind) is Some(expected) else { return }
  let actual = self.find_content_type(path, zip~)
  if actual.to_lower() != expected.to_lower() {
    let declared = if actual == "" { "<undeclared>" } else { actual }
    raise Unsupported(
      message="the \{kind} relationship target '\{path}' has content type '\{declared}', expected '\{expected}'",
    )
  }
}

///|
fn ContentTypes::require_wordprocessing_part(
  self : ContentTypes,
  zip : ZipArchive,
  part : RelatedWordprocessingPart,
  role : WordprocessingPartRole,
) -> Unit raise DocxError {
  let kind = role.label()
  let expected = role.content_type()
  let actual = self.find_content_type(part.path, zip~)
  if actual.to_lower() != expected.to_lower() {
    let declared = if actual == "" { "<undeclared>" } else { actual }
    raise Unsupported(
      message="the \{kind} relationship target '\{part.path}' has content type '\{declared}', expected '\{expected}'",
    )
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
fn read_numbering_xml(
  root : XmlElement,
  styles : StableStringMap[StyleInfo],
) -> NumberingMap {
  let abstract_nums = read_abstract_numberings(root)
  let nums = read_numbering_instances(root)
  let numbering_style_num_ids = index_numbering_style_num_ids(styles)
  {
    abstract_nums,
    levels_by_paragraph_style_id: index_levels_by_paragraph_style_id(
      abstract_nums,
    ),
    resolved_abstract_num_ids: resolve_numbering_style_links(
      nums, abstract_nums, numbering_style_num_ids,
    ),
  }
}

///|
fn read_abstract_numberings(
  root : XmlElement,
) -> StableStringMap[AbstractNumbering] {
  let abstract_nums : StableStringMap[AbstractNumbering] = SortedMap([])
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
  let levels : StableStringMap[NumberingLevel] = SortedMap([])
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
fn read_numbering_instances(root : XmlElement) -> StableStringMap[String] {
  let nums : StableStringMap[String] = SortedMap([])
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
  abstract_nums : StableStringMap[AbstractNumbering],
) -> StableStringMap[NumberingLevel] {
  let levels : StableStringMap[NumberingLevel] = SortedMap([])
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
  styles : StableStringMap[StyleInfo],
) -> StableStringMap[String] {
  let style_num_ids : StableStringMap[String] = SortedMap([])
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
fn resolve_numbering_style_links(
  nums : StableStringMap[String],
  abstract_nums : StableStringMap[AbstractNumbering],
  numbering_style_num_ids : StableStringMap[String],
) -> StableStringMap[NumberingLinkResolution] {
  let resolved : StableStringMap[NumberingLinkResolution] = SortedMap([])
  // Every successful loop iteration consumes one previously unresolved
  // `<w:num>` node and resolves the entire path on exit. This explicit budget
  // pins total graph work to O(number of numbering instances), including
  // cycles and links to missing ids.
  let mut remaining = nums.length()
  for start, _ in nums {
    if resolved.contains(start) {
      continue
    }
    let path : Array[String] = []
    let path_ids : StableStringSet = SortedSet([])
    let mut current = start
    let mut resolution = UnresolvableNumbering
    let mut done = false
    while !done {
      match resolved.get(current) {
        Some(cached) => {
          resolution = cached
          done = true
        }
        None =>
          if path_ids.contains(current) {
            resolution = UnresolvableNumbering
            done = true
          } else {
            match nums.get(current) {
              None => {
                resolution = UnresolvableNumbering
                done = true
              }
              Some(abstract_num_id) => {
                if remaining <= 0 {
                  resolution = UnresolvableNumbering
                  done = true
                  continue
                }
                remaining = remaining - 1
                path.push(current)
                path_ids.add(current)
                match abstract_nums.get(abstract_num_id) {
                  None => {
                    resolution = UnresolvableNumbering
                    done = true
                  }
                  Some(abstract_num) =>
                    match abstract_num.num_style_link {
                      None => {
                        resolution = ResolvedAbstractNumbering(abstract_num_id)
                        done = true
                      }
                      Some(style_id) =>
                        match numbering_style_num_ids.get(style_id) {
                          Some(linked_num_id) => current = linked_num_id
                          None => {
                            resolution = UnresolvableNumbering
                            done = true
                          }
                        }
                    }
                }
              }
            }
          }
      }
    }
    for num_id in path {
      resolved[num_id] = resolution
    }
  }
  resolved
}

///|
fn NumberingMap::find_level(
  self : NumberingMap,
  num_id : String,
  level : String,
) -> Numbering? {
  guard self.resolved_abstract_num_ids.get(num_id)
    is Some(ResolvedAbstractNumbering(abstract_num_id)) else {
    return None
  }
  guard self.abstract_nums.get(abstract_num_id) is Some(abstract_num) else {
    return None
  }
  match abstract_num.levels.get(level) {
    Some(numbering_level) => Some(numbering_level.to_numbering())
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
  styles : StableStringMap[StyleInfo],
  numbering : NumberingMap,
  content_types : ContentTypes,
  footnotes_path~ : String,
  endnotes_path~ : String,
  external_files? : ExternalFileAccess = default_external_file_access(),
  read_images? : Bool = true,
  xml_budget? : @xml.XmlReadBudget,
  diagnostics? : ReaderDiagnosticCollector,
) -> NotesReadResult raise DocxError {
  let notes : Array[Note] = []
  let annotation_ids : Array[String?] = []
  let messages : Array[Message] = []
  let footnotes = read_note_part_at_path(
    zip,
    note_type="footnote",
    path=footnotes_path,
    styles~,
    numbering~,
    content_types~,
    external_files~,
    read_images~,
    xml_budget?,
    diagnostics?,
  )
  notes.append(footnotes.notes)
  annotation_ids.append(footnotes.annotation_ids)
  messages.append(footnotes.messages)
  let endnotes = read_note_part_at_path(
    zip,
    note_type="endnote",
    path=endnotes_path,
    styles~,
    numbering~,
    content_types~,
    external_files~,
    read_images~,
    xml_budget?,
    diagnostics?,
  )
  notes.append(endnotes.notes)
  annotation_ids.append(endnotes.annotation_ids)
  messages.append(endnotes.messages)
  { notes, annotation_ids, messages: @core.dedupe_messages(messages) }
}

///|
fn read_note_part_at_path(
  zip : ZipArchive,
  note_type~ : String,
  path~ : String,
  styles~ : StableStringMap[StyleInfo],
  numbering~ : NumberingMap,
  content_types~ : ContentTypes,
  external_files? : ExternalFileAccess = default_external_file_access(),
  read_images? : Bool = true,
  xml_budget? : @xml.XmlReadBudget,
  diagnostics? : ReaderDiagnosticCollector,
) -> NotesReadResult raise DocxError {
  if !zip.exists(path) {
    return { notes: [], annotation_ids: [], messages: [] }
  }
  let part_relationships = read_relationships(
    zip,
    relationships_path_for_part(zip, path),
    xml_budget?,
  )
  let reader = BodyReader::{
    styles,
    zip,
    relationship_index: RelationshipIndex::build(part_relationships),
    content_types,
    base_path: split_zip_path(zip.logical_path(path).unwrap_or(path)).0,
    numbering,
    messages: [],
    diagnostics,
    external_files,
    read_images,
  }
  let root = read_xml_part(zip, path, xml_budget?)
  let notes : Array[Note] = []
  let annotation_ids : Array[String?] = []
  for note_element in root.elements_by_tag_name("w:" + note_type) {
    let note_kind = note_element.attributes.get("w:type")
    // separator/continuationSeparator/continuationNotice are Word's
    // plumbing notes (rule glyphs and "continued" notices), not user
    // content — surfacing them would invent phantom notes.
    if note_kind != Some("separator") &&
      note_kind != Some("continuationSeparator") &&
      note_kind != Some("continuationNotice") {
      let annotation_id = note_element.attributes.get("w:id")
      notes.push({
        note_type,
        note_id: annotation_id_or_missing(annotation_id),
        body: reader_items_to_elements(
          reader.read_children(ReaderNode::of(note_element).element_children()),
        ),
      })
      annotation_ids.push(annotation_id)
    }
  }
  { notes, annotation_ids, messages: reader.messages }
}

///|
fn read_comments_for_document(
  zip : ZipArchive,
  styles : StableStringMap[StyleInfo],
  numbering : NumberingMap,
  content_types : ContentTypes,
  document_relationships : Relationships,
  base_path : String,
  external_files? : ExternalFileAccess = default_external_file_access(),
  read_images? : Bool = true,
  xml_budget? : @xml.XmlReadBudget,
  comments_part_path? : String,
  diagnostics? : ReaderDiagnosticCollector,
) -> CommentsReadResult raise DocxError {
  let authoritative = match comments_part_path {
    Some(path) => Some(path)
    None =>
      resolve_unique_internal_part(
        zip,
        document_relationships,
        [TRANSITIONAL_COMMENTS_RELATIONSHIP, STRICT_COMMENTS_RELATIONSHIP],
        base_path,
        "comments",
        reject_multiple_relationships=true,
      )
  }
  let path = authoritative.unwrap_or("word/comments.xml")
  if !zip.exists(path) {
    return { comments: [], annotation_ids: [], messages: [] }
  }
  let part_relationships = read_relationships(
    zip,
    relationships_path_for_part(zip, path),
    xml_budget?,
  )
  let reader = BodyReader::{
    styles,
    zip,
    relationship_index: RelationshipIndex::build(part_relationships),
    content_types,
    base_path: split_zip_path(zip.logical_path(path).unwrap_or(path)).0,
    numbering,
    messages: [],
    diagnostics,
    external_files,
    read_images,
  }
  let root = read_xml_part(zip, path, xml_budget?)
  let comments : Array[Comment] = []
  let annotation_ids : Array[String?] = []
  for comment_element in root.elements_by_tag_name("w:comment") {
    let annotation_id = comment_element.attributes.get("w:id")
    comments.push({
      comment_id: annotation_id_or_missing(annotation_id),
      body: reader_items_to_elements(
        reader.read_children(ReaderNode::of(comment_element).element_children()),
      ),
      author_name: read_optional_attribute(comment_element, "w:author"),
      author_initials: read_optional_attribute(comment_element, "w:initials"),
    })
    annotation_ids.push(annotation_id)
  }
  { comments, annotation_ids, messages: reader.messages }
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
fn read_styles_xml(root : XmlElement) -> StableStringMap[StyleInfo] {
  let styles : StableStringMap[StyleInfo] = SortedMap([])
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
  styles
}

///|
fn style_lookup_key(style_type : String, style_id : String) -> String {
  style_type + ":" + style_id
}

///|
fn StableStringMap::find_style(
  self : StableStringMap[StyleInfo],
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
  styles : StableStringMap[StyleInfo],
  numbering : NumberingMap,
  zip : ZipArchive,
  relationship_index : RelationshipIndex,
  content_types : ContentTypes,
  base_path : String,
  notes : Array[Note],
  comments : Array[Comment],
  external_files? : ExternalFileAccess = default_external_file_access(),
  read_images? : Bool = true,
  diagnostics? : ReaderDiagnosticCollector,
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
    relationship_index,
    content_types,
    base_path,
    numbering,
    messages: [],
    diagnostics,
    external_files,
    read_images,
  }
  {
    document: document(
      reader_items_to_elements(
        reader.read_children(ReaderNode::of(body).element_children()),
      ),
      notes~,
      comments~,
    ),
    messages: reader.messages,
  }
}

///|
priv struct BodyReader {
  styles : StableStringMap[StyleInfo]
  zip : ZipArchive
  relationship_index : RelationshipIndex
  content_types : ContentTypes
  base_path : String
  numbering : NumberingMap
  messages : Array[Message]
  diagnostics : ReaderDiagnosticCollector?
  external_files : ExternalFileAccess
  read_images : Bool
}

///|
fn BodyReader::read_children(
  self : BodyReader,
  children : Array[ReaderNode],
) -> Array[ReaderItem] raise DocxError {
  let items : Array[ReaderItem] = []
  let deleted_paragraph_contents : Array[ReaderNode] = []
  for element in children {
    match element.name() {
      "w:p" if is_deleted_paragraph(element) =>
        deleted_paragraph_contents.append(element.element_children())
      "w:p" if !deleted_paragraph_contents.is_empty() => {
        // deleted-paragraph join: the prefix mechanics stay a named island
        // inside read_paragraph_children until 2c
        items.push(
          self.read_paragraph_elements_with_prefix(
            element, deleted_paragraph_contents,
          ),
        )
        deleted_paragraph_contents.clear()
      }
      _ => items.append(self.read_element(element))
    }
  }
  items
}

///|
fn BodyReader::read_element(
  self : BodyReader,
  element : ReaderNode,
) -> Array[ReaderItem] raise DocxError {
  match element.name() {
    "w:p" =>
      if is_deleted_paragraph(element) {
        []
      } else {
        [self.read_paragraph_elements(element)]
      }
    "w:r" => [self.read_run(element)]
    "w:t" =>
      [
        New({
          source: element,
          local_effects: [],
          shape: ReaderText(element.text()),
        }),
      ]
    "w:tab" => [New({ source: element, local_effects: [], shape: ReaderTab })]
    "w:noBreakHyphen" =>
      [
        New({
          source: element,
          local_effects: [],
          shape: ReaderText("\u{2011}"),
        }),
      ]
    "w:softHyphen" =>
      [
        New({
          source: element,
          local_effects: [],
          shape: ReaderText("\u{00AD}"),
        }),
      ]
    "w:sym" => self.read_symbol(element)
    "w:footnoteReference" =>
      [
        New({
          source: element,
          local_effects: [],
          shape: ReaderNoteReference(
            note_type="footnote",
            note_id=annotation_id_or_missing(element.attribute("w:id")),
          ),
        }),
      ]
    "w:endnoteReference" =>
      [
        New({
          source: element,
          local_effects: [],
          shape: ReaderNoteReference(
            note_type="endnote",
            note_id=annotation_id_or_missing(element.attribute("w:id")),
          ),
        }),
      ]
    "w:footnoteRef" | "w:endnoteRef" => []
    "w:commentReference" =>
      [
        New({
          source: element,
          local_effects: [],
          shape: ReaderCommentReference(
            annotation_id_or_missing(element.attribute("w:id")),
          ),
        }),
      ]
    "w:br" => self.read_break(element)
    "w:bookmarkStart" =>
      match element.attribute("w:name") {
        Some("_GoBack") => []
        None =>
          [
            New({
              source: element,
              local_effects: [],
              shape: ReaderBookmarkStart("undefined"),
            }),
          ]
        Some(name) =>
          [
            New({
              source: element,
              local_effects: [],
              shape: ReaderBookmarkStart(name),
            }),
          ]
      }
    "w:hyperlink" => self.read_hyperlink(element)
    "w:drawing" | "w:object" => self.read_children(element.element_children())
    "w:pict" => []
    "mc:AlternateContent" =>
      self.read_children(
        element.first_or_empty("mc:Fallback").element_children(),
      )
    "wp:inline" | "wp:anchor" =>
      reader_legacy_items(self.read_drawing_element(element))
    "v:roundrect" | "v:shape" | "v:textbox" | "v:group" | "v:rect" =>
      self.read_children(element.element_children())
    "v:imagedata" => reader_legacy_items(self.read_vml_image_data(element))
    "w:tbl" => [self.read_table(element)]
    "w:tr" => self.read_table_row(element)
    "w:tc" => [self.read_table_cell(element)]
    "w:ins" | "w:smartTag" | "w:sdtContent" =>
      self.read_children(element.element_children())
    "w:sdt" => self.read_structured_document_tag(element)
    _ =>
      if is_ignored_body_element(element.name()) {
        []
      } else {
        self.warn_parts([
          "An unrecognised element was ignored: ",
          element.name(),
        ])
        []
      }
  }
}

///|
fn BodyReader::warn(self : BodyReader, message : String) -> Unit {
  push_reader_message(self.messages, self.diagnostics, Warning(message))
}

///|
fn BodyReader::warn_parts(self : BodyReader, parts : ArrayView[String]) -> Unit {
  push_reader_warning_parts(self.messages, self.diagnostics, parts)
}

///|
fn BodyReader::error_parts(
  self : BodyReader,
  parts : ArrayView[String],
) -> Unit {
  push_reader_error_parts(self.messages, self.diagnostics, parts)
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
  name == "w:fldChar" ||
  name == "w:footnoteRef" ||
  name == "w:endnoteRef" ||
  name == "w:instrText" ||
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
  element : ReaderNode,
) -> Array[ReaderItem] {
  ignore(self)
  let font_attribute = element.attribute("w:font")
  let char_attribute = element.attribute("w:char")
  let font = attribute_or_empty(font_attribute)
  let char = attribute_or_empty(char_attribute)
  match symbol_to_unicode(font, char) {
    Some(value) =>
      [New({ source: element, local_effects: [], shape: ReaderText(value) })]
    None => {
      self.warn_parts([
        "A w:sym element with an unsupported character was ignored: char ",
        attribute_or_js_undefined(char_attribute),
        " in font ",
        attribute_or_js_undefined(font_attribute),
      ])
      []
    }
  }
}

///|
fn attribute_or_empty(value : String?) -> String {
  match value {
    Some(value) => value
    None => ""
  }
}

///|
fn attribute_or_js_undefined(value : String?) -> String {
  match value {
    Some(value) => value
    None => "undefined"
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
fn is_deleted_paragraph(element : ReaderNode) -> Bool {
  element.first_or_empty("w:pPr").first_or_empty("w:rPr").first("w:del")
  is Some(_)
}

///|
fn BodyReader::read_paragraph_elements(
  self : BodyReader,
  element : ReaderNode,
) -> ReaderItem raise DocxError {
  self.read_paragraph_elements_with_prefix(element, [])
}

///|
fn BodyReader::read_paragraph_elements_with_prefix(
  self : BodyReader,
  element : ReaderNode,
  prefix : Array[ReaderNode],
) -> ReaderItem raise DocxError {
  let properties = self.read_paragraph_properties(
    element.first_or_empty("w:pPr"),
  )
  // The children still route through the complex-field island; the extras
  // are structural: owned by this paragraph, erased as its siblings. That
  // split is the extras mechanism itself, and the erase walker -- not any
  // caller -- is what flattens it back.
  New({
    source: element,
    local_effects: [],
    shape: ReaderParagraph(
      sources=prefix + [element],
      children=self.read_paragraph_children(prefix + element.element_children()),
      extras=self.read_paragraph_extra_elements(element),
      properties~,
    ),
  })
}

///|
priv enum ComplexField {
  ComplexFieldBegin(checkbox_checked~ : Bool?, source~ : ReaderNode)
  ComplexHyperlink(href~ : String?, anchor~ : String?, source~ : ReaderNode)
  ComplexCheckbox(Bool, source~ : ReaderNode)
  ComplexFieldUnknown
}

///|
fn BodyReader::read_paragraph_children(
  self : BodyReader,
  children : Array[ReaderNode],
) -> Array[ReaderItem] raise DocxError {
  let items : Array[ReaderItem] = []
  let stack : Array[ComplexField] = []
  let mut instruction_text = ""
  for element in children {
    instruction_text += collect_instruction_text(element)
    match read_field_char_type(element) {
      Some("begin") => {
        stack.push(
          ComplexFieldBegin(
            checkbox_checked=read_complex_field_checkbox_checked(element),
            source=element,
          ),
        )
        instruction_text = ""
        items.append(self.read_element(element))
      }
      Some("separate") => {
        match stack.pop() {
          Some(ComplexFieldBegin(checkbox_checked~, source~)) =>
            stack.push(
              parse_complex_field_instruction(
                instruction_text, checkbox_checked, source,
              ),
            )
          Some(field) => stack.push(field)
          None => ()
        }
        instruction_text = ""
        items.append(self.read_element(element))
      }
      Some("end") => {
        match stack.pop() {
          Some(ComplexFieldBegin(checkbox_checked~, source~)) =>
            match
              parse_complex_field_instruction(
                instruction_text, checkbox_checked, source,
              ) {
              ComplexCheckbox(checked, source~) =>
                items.push(reader_field_checkbox_run(checked, source))
              _ => ()
            }
          Some(ComplexCheckbox(checked, source~)) =>
            items.push(reader_field_checkbox_run(checked, source))
          Some(_) => ()
          None => ()
        }
        instruction_text = ""
        items.append(self.read_element(element))
      }
      _ =>
        if element.name() != "w:instrText" {
          items.append(
            wrap_items_with_current_hyperlink(stack, self.read_element(element)),
          )
        }
    }
  }
  items
}

///|
/// The run a FORMCHECKBOX field synthesises at its end marker. Its source is
/// the field-begin node: the synthetic output has no child of its own to
/// blame, and the begin is where the field's identity lives.
fn reader_field_checkbox_run(checked : Bool, source : ReaderNode) -> ReaderItem {
  New({
    source,
    local_effects: [],
    shape: ReaderRun(
      children=[
        New({ source, local_effects: [], shape: ReaderCheckbox(checked) }),
      ],
      properties=RunProperties::default(),
    ),
  })
}

///|
/// Wrap freshly read items in the innermost open HYPERLINK field, at the
/// item level. A run keeps the hyperlink INSIDE it (matching the legacy
/// shape Run(Hyperlink(children))); anything else is wrapped outside. The
/// synthesised hyperlink's source is the field-begin node.
fn wrap_items_with_current_hyperlink(
  stack : Array[ComplexField],
  items : Array[ReaderItem],
) -> Array[ReaderItem] {
  match current_hyperlink_field(stack) {
    Some((href, anchor, source)) => {
      let wrapped : Array[ReaderItem] = []
      for item in items {
        wrapped.push(wrap_item_with_hyperlink(item, href, anchor, source))
      }
      wrapped
    }
    None => items
  }
}

///|
fn wrap_item_with_hyperlink(
  item : ReaderItem,
  href : String?,
  anchor : String?,
  source : ReaderNode,
) -> ReaderItem {
  fn hyperlink_of(children : Array[ReaderItem]) -> ReaderItem {
    New({
      source,
      local_effects: [],
      shape: ReaderHyperlink(children~, href~, anchor~, target_frame=None),
    })
  }

  match item {
    New(
      {
        source: run_source,
        local_effects,
        shape: ReaderRun(children~, properties~),
      }
    ) =>
      New({
        source: run_source,
        local_effects,
        shape: ReaderRun(children=[hyperlink_of(children)], properties~),
      })
    Legacy(Run(children~, properties~)) =>
      New({
        source,
        local_effects: [],
        shape: ReaderRun(
          children=[hyperlink_of(reader_legacy_items(children))],
          properties~,
        ),
      })
    other => hyperlink_of([other])
  }
}

///|
fn collect_instruction_text(element : ReaderNode) -> String raise DocxError {
  let builder = StringBuilder()
  if element.name() == "w:instrText" {
    builder.write_string(element.text())
  }
  for child_element in element.element_children() {
    builder.write_string(collect_instruction_text(child_element))
  }
  builder.to_string()
}

///|
fn read_field_char_type(element : ReaderNode) -> String? {
  if element.name() == "w:fldChar" {
    return element.attribute("w:fldCharType")
  }
  for child_element in element.element_children() {
    match read_field_char_type(child_element) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
fn read_complex_field_checkbox_checked(element : ReaderNode) -> Bool? {
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
fn first_descendant_or_self(element : ReaderNode, name : String) -> ReaderNode? {
  if element.name() == name {
    return Some(element)
  }
  for child_element in element.element_children() {
    match first_descendant_or_self(child_element, name) {
      Some(result) => return Some(result)
      None => ()
    }
  }
  None
}

///|
fn parse_complex_field_instruction(
  instruction_text : String,
  checkbox_checked : Bool?,
  source : ReaderNode,
) -> ComplexField {
  match parse_hyperlink_field_instruction(instruction_text, source) {
    Some(field) => field
    None =>
      parse_non_hyperlink_field_instruction(
        instruction_text, checkbox_checked, source,
      )
  }
}

///|
fn parse_non_hyperlink_field_instruction(
  instruction_text : String,
  checkbox_checked : Bool?,
  source : ReaderNode,
) -> ComplexField {
  if instruction_text.contains("FORMCHECKBOX") {
    ComplexCheckbox(checkbox_checked.unwrap_or(false), source~)
  } else {
    ComplexFieldUnknown
  }
}

///|
fn parse_hyperlink_field_instruction(
  instruction_text : String,
  source : ReaderNode,
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
          Some(ComplexHyperlink(href=None, anchor=Some(location), source~))
        } else {
          Some(ComplexHyperlink(href=Some(location), anchor=None, source~))
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
  for index in start..<value.length() {
    if is_field_whitespace(value[index]) {
      return value[start:index].to_owned()
    }
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
  char is (' ' | '\t' | '\n' | '\r')
}

///|
fn field_starts_with_at(value : String, index : Int, prefix : String) -> Bool {
  index + prefix.length() <= value.length() &&
  value[index:index + prefix.length()].to_owned() == prefix
}

///|
fn current_hyperlink_field(
  stack : Array[ComplexField],
) -> (String?, String?, ReaderNode)? {
  for index = stack.length() - 1; index >= 0; index = index - 1 {
    match stack[index] {
      ComplexHyperlink(href~, anchor~, source~) =>
        return Some((href, anchor, source))
      _ => ()
    }
  }
  None
}

///|
fn BodyReader::read_text_box_elements(
  self : BodyReader,
  element : ReaderNode,
) -> Array[ReaderItem] raise DocxError {
  match element.name() {
    "mc:AlternateContent" =>
      self.read_text_box_elements(element.first_or_empty("mc:Fallback"))
    "w:txbxContent" => self.read_children(element.element_children())
    _ => {
      let items : Array[ReaderItem] = []
      for child_element in element.element_children() {
        items.append(self.read_text_box_elements(child_element))
      }
      items
    }
  }
}

///|
fn BodyReader::read_paragraph_extra_elements(
  self : BodyReader,
  element : ReaderNode,
) -> Array[ReaderItem] raise DocxError {
  let items : Array[ReaderItem] = []
  for child_element in element.element_children() {
    match child_element.name() {
      "w:pict" => items.append(self.read_pict_extra_elements(child_element))
      "mc:AlternateContent" =>
        items.append(self.read_text_box_elements(child_element))
      "w:txbxContent" =>
        items.append(self.read_text_box_elements(child_element))
      _ => items.append(self.read_paragraph_extra_elements(child_element))
    }
  }
  items
}

///|
fn BodyReader::read_pict_extra_elements(
  self : BodyReader,
  element : ReaderNode,
) -> Array[ReaderItem] raise DocxError {
  let items : Array[ReaderItem] = []
  for child_element in element.element_children() {
    match child_element.name() {
      "mc:AlternateContent" =>
        items.append(
          self.read_pict_extra_elements(
            child_element.first_or_empty("mc:Fallback"),
          ),
        )
      "w:txbxContent" =>
        items.append(self.read_children(child_element.element_children()))
      "w:pict"
      | "v:roundrect"
      | "v:shape"
      | "v:textbox"
      | "v:group"
      | "v:rect" => items.append(self.read_pict_extra_elements(child_element))
      _ => items.append(self.read_element(child_element))
    }
  }
  items
}

///|
fn BodyReader::read_structured_document_tag(
  self : BodyReader,
  element : ReaderNode,
) -> Array[ReaderItem] raise DocxError {
  let content = self.read_children(
    element.first_or_empty("w:sdtContent").element_children(),
  )
  match read_structured_checkbox(element.first_or_empty("w:sdtPr")) {
    Some(checked) => {
      let (replaced, found) = replace_first_text_with_checkbox(content, checked)
      if found {
        replaced
      } else {
        // no text to stand in for: the checkbox is synthesized at the
        // control itself
        [New({ source: element, local_effects: [], shape: ReaderCheckbox(checked) })]
      }
    }
    None => content
  }
}

///|
fn read_structured_checkbox(element : ReaderNode) -> Bool? {
  match element.first("w14:checkbox") {
    Some(checkbox_element) =>
      match checkbox_element.first("w14:checked") {
        Some(checked_element) =>
          Some(
            read_boolean_attribute_value(checked_element.attribute("w14:val")),
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
  items : Array[ReaderItem],
  checked : Bool,
) -> (Array[ReaderItem], Bool) {
  let replaced : Array[ReaderItem] = []
  let mut found = false
  for item in items {
    if found {
      replaced.push(item)
    } else {
      let (next, next_found) = replace_first_text_in_item(item, checked)
      replaced.push(next)
      if next_found {
        found = true
      }
    }
  }
  (replaced, found)
}

///|
fn replace_first_text_in_item(
  item : ReaderItem,
  checked : Bool,
) -> (ReaderItem, Bool) {
  match item {
    New(tree) => {
      let (shape, found) = replace_first_text_in_shape(tree.shape, checked)
      (New({ source: tree.source, local_effects: tree.local_effects, shape }), found)
    }
    // legacy producers (images) never hold text; the walk below preserves
    // the erased behaviour exactly and dies with `Legacy`
    Legacy(element) => {
      let (next, found) = replace_first_text_in_element(element, checked)
      (Legacy(next), found)
    }
    Trace(_) => (item, false)
  }
}

///|
fn replace_first_text_in_shape(
  shape : ReaderTreeShape,
  checked : Bool,
) -> (ReaderTreeShape, Bool) {
  match shape {
    ReaderText(value) =>
      if value.length() > 0 {
        (ReaderCheckbox(checked), true)
      } else {
        (shape, false)
      }
    ReaderParagraph(sources~, children~, extras~, properties~) => {
      // the erased pipeline expanded extras as siblings after the
      // paragraph, so the search visits the carrier first, then extras
      let (new_children, found) = replace_first_text_with_checkbox(
        children, checked,
      )
      if found {
        (
          ReaderParagraph(sources~, children=new_children, extras~, properties~),
          true,
        )
      } else {
        let (new_extras, found) = replace_first_text_with_checkbox(
          extras, checked,
        )
        (
          ReaderParagraph(
            sources~,
            children=new_children,
            extras=new_extras,
            properties~,
          ),
          found,
        )
      }
    }
    ReaderRun(children~, properties~) => {
      let (new_children, found) = replace_first_text_with_checkbox(
        children, checked,
      )
      (ReaderRun(children=new_children, properties~), found)
    }
    ReaderHyperlink(children~, href~, anchor~, target_frame~) => {
      let (new_children, found) = replace_first_text_with_checkbox(
        children, checked,
      )
      (
        ReaderHyperlink(children=new_children, href~, anchor~, target_frame~),
        found,
      )
    }
    ReaderTable(children~, properties~) => {
      let (new_children, found) = replace_first_text_with_checkbox(
        children, checked,
      )
      (ReaderTable(children=new_children, properties~), found)
    }
    ReaderTableRow(children~, is_header~) => {
      let (new_children, found) = replace_first_text_with_checkbox(
        children, checked,
      )
      (ReaderTableRow(children=new_children, is_header~), found)
    }
    ReaderTableCell(children~, col_span~, row_span~) => {
      let (new_children, found) = replace_first_text_with_checkbox(
        children, checked,
      )
      (ReaderTableCell(children=new_children, col_span~, row_span~), found)
    }
    _ => (shape, false)
  }
}

///|
/// Element-level twin of `replace_first_text_with_checkbox` for content the
/// remaining legacy producers hand over; dies with `Legacy`.
fn replace_first_text_with_checkbox_elements(
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
      let (new_children, found) = replace_first_text_with_checkbox_elements(
        children, checked,
      )
      (Document(children=new_children, notes~, comments~), found)
    }
    Paragraph(children~, properties~) => {
      let (new_children, found) = replace_first_text_with_checkbox_elements(
        children, checked,
      )
      (Paragraph(children=new_children, properties~), found)
    }
    Run(children~, properties~) => {
      let (new_children, found) = replace_first_text_with_checkbox_elements(
        children, checked,
      )
      (Run(children=new_children, properties~), found)
    }
    Hyperlink(children~, href~, anchor~, target_frame~) => {
      let (new_children, found) = replace_first_text_with_checkbox_elements(
        children, checked,
      )
      (Hyperlink(children=new_children, href~, anchor~, target_frame~), found)
    }
    Table(children~, properties~) => {
      let (new_children, found) = replace_first_text_with_checkbox_elements(
        children, checked,
      )
      (Table(children=new_children, properties~), found)
    }
    TableRow(children~, is_header~) => {
      let (new_children, found) = replace_first_text_with_checkbox_elements(
        children, checked,
      )
      (TableRow(children=new_children, is_header~), found)
    }
    TableCell(children~, col_span~, row_span~) => {
      let (new_children, found) = replace_first_text_with_checkbox_elements(
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
  element : ReaderNode,
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
    alignment: non_empty_attribute(element.first_or_empty("w:jc"), "w:val"),
    indent: self.read_indent(element.first_or_empty("w:ind")),
  }
}

///|
fn BodyReader::read_indent(self : BodyReader, element : ReaderNode) -> Indent {
  ignore(self)
  {
    start: first_some(
      non_empty_attribute(element, "w:start"),
      non_empty_attribute(element, "w:left"),
    ),
    end: first_some(
      non_empty_attribute(element, "w:end"),
      non_empty_attribute(element, "w:right"),
    ),
    first_line: non_empty_attribute(element, "w:firstLine"),
    hanging: non_empty_attribute(element, "w:hanging"),
  }
}

///|
fn BodyReader::read_numbering(
  self : BodyReader,
  style_id : String?,
  element : ReaderNode,
) -> Numbering? {
  let level = element.first_or_empty("w:ilvl").attribute("w:val")
  let num_id = element.first_or_empty("w:numId").attribute("w:val")
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
  element : ReaderNode,
) -> ReaderItem raise DocxError {
  let properties = self.read_run_properties(element.first_or_empty("w:rPr"))
  New({
    source: element,
    local_effects: [],
    shape: ReaderRun(
      children=self.read_children(element.element_children()),
      properties~,
    ),
  })
}

///|
fn BodyReader::read_run_properties(
  self : BodyReader,
  element : ReaderNode,
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
      element.first_or_empty("w:vertAlign").attribute("w:val"),
    ),
    font: non_empty_attribute(element.first_or_empty("w:rFonts"), "w:ascii"),
    font_size: read_font_size(element.first_or_empty("w:sz").attribute("w:val")),
    highlight: read_highlight(
      element.first_or_empty("w:highlight").attribute("w:val"),
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
  self.warn_parts([
    style_warning_label(style_type),
    " style with ID ",
    style_id,
    " was referenced but not defined in the document",
  ])
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
fn read_boolean_element(element : ReaderNode?) -> Bool {
  match element {
    Some(element) => {
      let value = element.attribute("w:val")
      value != Some("false") && value != Some("0")
    }
    None => false
  }
}

///|
fn read_underline(element : ReaderNode?) -> Bool {
  match element {
    Some(element) => {
      let value = element.attribute("w:val")
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
  element : ReaderNode,
) -> Array[ReaderItem] {
  match element.attribute("w:type") {
    None | Some("textWrapping") =>
      [New({ source: element, local_effects: [], shape: ReaderBreak(Line) })]
    Some("page") =>
      [New({ source: element, local_effects: [], shape: ReaderBreak(Page) })]
    Some("column") =>
      [New({ source: element, local_effects: [], shape: ReaderBreak(Column) })]
    Some(break_type) => {
      self.warn_parts(["Unsupported break type: ", break_type])
      []
    }
  }
}

///|
fn BodyReader::read_hyperlink(
  self : BodyReader,
  element : ReaderNode,
) -> Array[ReaderItem] raise DocxError {
  let target_frame = non_empty_attribute(element, "w:tgtFrame")
  let anchor = non_empty_attribute(element, "w:anchor")
  match non_empty_attribute(element, "r:id") {
    Some(id) => {
      let href = match self.relationship_index.find_unique_target_by_id(id) {
        Some(target) =>
          match anchor {
            Some(anchor) => Some(replace_url_fragment(target, anchor))
            None => Some(target)
          }
        None => None
      }
      [
        New({
          source: element,
          local_effects: [],
          shape: ReaderHyperlink(
            children=self.read_children(element.element_children()),
            href~,
            anchor=None,
            target_frame~,
          ),
        }),
      ]
    }
    None =>
      match anchor {
        Some(anchor) =>
          [
            New({
              source: element,
              local_effects: [],
              shape: ReaderHyperlink(
                children=self.read_children(element.element_children()),
                href=None,
                anchor=Some(anchor),
                target_frame~,
              ),
            }),
          ]
        // untargeted and unanchored: the reader flattens, so the child
        // items pass through untouched
        None => self.read_children(element.element_children())
      }
  }
}

///|
fn replace_url_fragment(href : String, fragment : String) -> String {
  let base = match href.find("#") {
    Some(index) => href[:index].to_owned()
    None => href
  }
  base + "#" + fragment
}

///|
fn non_empty_attribute(element : ReaderNode, name : String) -> String? {
  match element.attribute(name) {
    Some(value) => if value == "" { None } else { Some(value) }
    None => None
  }
}

///|
fn BodyReader::read_drawing_element(
  self : BodyReader,
  element : ReaderNode,
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
fn ReaderNode::drawing_blips(self : ReaderNode) -> Array[ReaderNode] {
  let blips : Array[ReaderNode] = []
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
  drawing_element : ReaderNode,
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
  drawing_element : ReaderNode,
) -> String? {
  for
    link in drawing_element
    .first_or_empty("wp:docPr")
    .elements_by_tag_name("a:hlinkClick") {
    match non_empty_attribute(link, "r:id") {
      Some(id) =>
        match self.relationship_index.find_unique_target_by_id(id) {
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
  drawing_element : ReaderNode,
  blip : ReaderNode,
) -> Image? {
  if !self.read_images {
    return None
  }
  let diagnostic_count = self.diagnostic_count()
  let image = match non_empty_attribute(blip, "r:embed") {
    Some(id) =>
      self.read_image_by_relationship(
        id,
        alt_text=read_drawing_alt_text(drawing_element),
      )
    None =>
      match non_empty_attribute(blip, "r:link") {
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
      if self.diagnostic_count() == diagnostic_count {
        self.warn("Could not find image file for a:blip element")
      }
      None
    }
  }
}

///|
fn BodyReader::diagnostic_count(self : BodyReader) -> Int {
  let collected = match self.diagnostics {
    Some(value) => value.received()
    None => 0
  }
  self.messages.length() + collected
}

///|
fn BodyReader::read_vml_image_data(
  self : BodyReader,
  element : ReaderNode,
) -> Array[DocumentElement] {
  if !self.read_images {
    return []
  }
  match non_empty_attribute(element, "r:id") {
    Some(id) =>
      match
        self.read_image_by_relationship(
          id,
          alt_text=element.attribute("o:title"),
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
  match self.relationship_index.find_unique_by_id(relationship_id) {
    Some(rel) =>
      match resolve_part_target(self.base_path, rel.target) {
        Some(path) =>
          match self.zip.read_bytes(path) {
            Some(data) => Some(self.make_image(path, data, alt_text~))
            None => None
          }
        None => None
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
  match self.relationship_index.find_unique_by_id(relationship_id) {
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
    self.error_parts([
      "could not read external image '", target, "', external file access is disabled",
    ])
    return None
  }
  for path in external_file_candidate_paths(target) {
    match (self.external_files.read_file)(path) {
      Some(data) => return Some(self.make_image(path, data, alt_text~))
      None => ()
    }
  }
  self.error_parts([
    "could not find external image '", target, "', path of input document is unknown",
  ])
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
    match uri[index] {
      ':' => return Some(index)
      '/' | '\\' | '?' | '#' => return None
      char => if !is_uri_scheme_char(char) { return None }
    }
  }
  None
}

///|
fn is_uri_scheme_start(char : UInt16) -> Bool {
  char is ('A'..='Z' | 'a'..='z')
}

///|
fn is_uri_scheme_char(char : UInt16) -> Bool {
  is_uri_scheme_start(char) || char is ('0'..='9' | '+' | '-' | '.')
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
  try @utf8.decode(Bytes::from_array(bytes)) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn hex_value(char : UInt16) -> Int? {
  match char {
    '0'..='9' => Some(char.to_int() - '0'.to_int())
    'A'..='F' => Some(char.to_int() - 'A'.to_int() + 10)
    'a'..='f' => Some(char.to_int() - 'a'.to_int() + 10)
    _ => None
  }
}

///|
fn BodyReader::make_image(
  self : BodyReader,
  path : String,
  data : BytesView,
  alt_text~ : String?,
) -> Image {
  let content_type = self.content_types.find_content_type(path, zip=self.zip)
  if !is_supported_web_image_type(content_type) {
    self.warn_parts([
      "Image of type ", content_type, " is unlikely to display in web browsers",
    ])
  }
  { content_type, alt_text, data: data.to_owned() }
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
fn read_drawing_alt_text(element : ReaderNode) -> String? {
  let properties = element.first_or_empty("wp:docPr")
  match properties.attribute("descr") {
    Some(value) =>
      if value.trim().is_empty() {
        properties.attribute("title")
      } else {
        Some(value)
      }
    None => properties.attribute("title")
  }
}

///|
fn resolve_part_target(base_path : String, target : String) -> String? {
  @opc.resolve_part_target(base_path, target)
}

///|
fn BodyReader::read_table(
  self : BodyReader,
  element : ReaderNode,
) -> ReaderItem raise DocxError {
  New({
    source: element,
    local_effects: [],
    shape: ReaderTable(
      children=self.calculate_table_row_spans(
        self.read_children(element.element_children()),
      ),
      properties=self.read_table_properties(element.first_or_empty("w:tblPr")),
    ),
  })
}

///|
fn BodyReader::read_table_properties(
  self : BodyReader,
  element : ReaderNode,
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
  element : ReaderNode,
) -> Array[ReaderItem] raise DocxError {
  let properties = element.first_or_empty("w:trPr")
  if properties.first("w:del") is Some(_) {
    []
  } else {
    let is_header = properties.first("w:tblHeader") is Some(_)
    [
      New({
        source: element,
        local_effects: [],
        shape: ReaderTableRow(
          children=self.read_children(element.element_children()),
          is_header~,
        ),
      }),
    ]
  }
}

///|
fn BodyReader::read_table_cell(
  self : BodyReader,
  element : ReaderNode,
) -> ReaderItem raise DocxError {
  let properties = element.first_or_empty("w:tcPr")
  let col_span = parse_grid_span(
    properties.first_or_empty("w:gridSpan").attribute_or("w:val", "1"),
  )
  New({
    source: element,
    local_effects: [],
    shape: ReaderTableCell(
      children=self.read_children(element.element_children()),
      col_span~,
      row_span=if read_vertical_merge_continue(properties) { 0 } else { 1 },
    ),
  })
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
  match char {
    '0'..='9' => Some(char.to_int() - '0'.to_int())
    _ => None
  }
}

///|
fn read_vertical_merge_continue(properties : ReaderNode) -> Bool {
  match properties.first("w:vMerge") {
    Some(element) =>
      match element.attribute("w:val") {
        None | Some("continue") => true
        _ => false
      }
    None => false
  }
}

///|
fn BodyReader::table_cells_for_span(
  self : BodyReader,
  children : Array[ReaderItem],
) -> Array[TableCellForSpan]? {
  let cells : Array[TableCellForSpan] = []
  for child in children {
    match child {
      New(
        {
          source: cell_source,
          local_effects: _,
          shape: ReaderTableCell(children=cell_children, col_span~, row_span~),
        }
      ) =>
        cells.push({
          children: cell_children,
          col_span,
          row_span,
          source: Some(cell_source),
        })
      // cells the `w:sdt` legacy island erased before this pass; goes away
      // with the island
      Legacy(TableCell(children=cell_children, col_span~, row_span~)) =>
        cells.push({
          children: reader_legacy_items(cell_children),
          col_span,
          row_span,
          source: None,
        })
      _ => {
        self.warn(
          "unexpected non-cell element in table row, cell merging may be incorrect",
        )
        return None
      }
    }
  }
  Some(cells)
}

///|
fn BodyReader::calculate_table_row_spans(
  self : BodyReader,
  items : Array[ReaderItem],
) -> Array[ReaderItem] {
  let typed_rows : Array[TableRowForSpan] = []
  for item in items {
    match item {
      New({ source, local_effects: _, shape: ReaderTableRow(children~, is_header~) }) => {
        guard self.table_cells_for_span(children) is Some(cells) else {
          return items
        }
        typed_rows.push({ cells, is_header, source: Some(source) })
      }
      // rows the `w:sdt` legacy island erased before this pass; goes away
      // with the island
      Legacy(TableRow(children~, is_header~)) => {
        let cells : Array[TableCellForSpan] = []
        for child in children {
          match child {
            TableCell(children=cell_children, col_span~, row_span~) =>
              cells.push({
                children: reader_legacy_items(cell_children),
                col_span,
                row_span,
                source: None,
              })
            _ => {
              self.warn(
                "unexpected non-cell element in table row, cell merging may be incorrect",
              )
              return items
            }
          }
        }
        typed_rows.push({ cells, is_header, source: None })
      }
      _ => {
        self.warn(
          "unexpected non-row element in table, cell merging may be incorrect",
        )
        return items
      }
    }
  }
  self.calculate_typed_table_row_spans(typed_rows)
}

///|
fn BodyReader::calculate_typed_table_row_spans(
  _self : BodyReader,
  elements : Array[TableRowForSpan],
) -> Array[ReaderItem] {
  let row_spans : Array[Array[Int]] = []
  let skip_cells : Array[Array[Bool]] = []
  for row in elements {
    let spans : Array[Int] = []
    let skips : Array[Bool] = []
    for _ in row.cells {
      spans.push(1)
      skips.push(false)
    }
    row_spans.push(spans)
    skip_cells.push(skips)
  }
  let open_cells : Map[Int, (Int, Int)] = Map([])
  for row_index in 0..<elements.length() {
    let mut column_index = 0
    for cell_index in 0..<elements[row_index].cells.length() {
      let cell = elements[row_index].cells[cell_index]
      if cell.row_span == 0 {
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
      column_index = column_index + cell.col_span
    }
  }
  let rows : Array[ReaderItem] = []
  for row_index in 0..<elements.length() {
    let new_children : Array[ReaderItem] = []
    for cell_index in 0..<elements[row_index].cells.length() {
      if !skip_cells[row_index][cell_index] {
        let cell = elements[row_index].cells[cell_index]
        let row_span = row_spans[row_index][cell_index]
        match cell.source {
          Some(cell_source) =>
            new_children.push(
              New({
                source: cell_source,
                local_effects: [],
                shape: ReaderTableCell(
                  children=cell.children,
                  col_span=cell.col_span,
                  row_span~,
                ),
              }),
            )
          None =>
            new_children.push(
              Legacy(
                TableCell(
                  children=reader_items_to_elements(cell.children),
                  col_span=cell.col_span,
                  row_span~,
                ),
              ),
            )
        }
      }
    }
    match elements[row_index].source {
      Some(row_source) =>
        rows.push(
          New({
            source: row_source,
            local_effects: [],
            shape: ReaderTableRow(
              children=new_children,
              is_header=elements[row_index].is_header,
            ),
          }),
        )
      None =>
        rows.push(
          Legacy(
            TableRow(
              children=reader_items_to_elements(new_children),
              is_header=elements[row_index].is_header,
            ),
          ),
        )
    }
  }
  rows
}
