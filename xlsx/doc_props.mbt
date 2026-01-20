///|
pub struct CoreProperties {
  mut title : String
  mut subject : String
  mut creator : String
  mut keywords : String
  mut description : String
  mut last_modified_by : String
  mut language : String
  mut identifier : String
  mut revision : String
  mut content_status : String
  mut category : String
  mut version : String
  mut created : String
  mut modified : String
}

///|
pub fn CoreProperties::new() -> CoreProperties {
  {
    title: "",
    subject: "",
    creator: "mbtexcel",
    keywords: "",
    description: "",
    last_modified_by: "mbtexcel",
    language: "",
    identifier: "",
    revision: "",
    content_status: "",
    category: "",
    version: "",
    created: "",
    modified: "",
  }
}

///|
pub fn CoreProperties::with_values(
  title? : String,
  subject? : String,
  creator? : String,
  keywords? : String,
  description? : String,
  last_modified_by? : String,
  language? : String,
  identifier? : String,
  revision? : String,
  content_status? : String,
  category? : String,
  version? : String,
  created? : String,
  modified? : String,
) -> CoreProperties {
  let props = CoreProperties::new()
  match title {
    Some(value) => props.title = value
    None => ()
  }
  match subject {
    Some(value) => props.subject = value
    None => ()
  }
  match creator {
    Some(value) => props.creator = value
    None => ()
  }
  match keywords {
    Some(value) => props.keywords = value
    None => ()
  }
  match description {
    Some(value) => props.description = value
    None => ()
  }
  match last_modified_by {
    Some(value) => props.last_modified_by = value
    None => ()
  }
  match language {
    Some(value) => props.language = value
    None => ()
  }
  match identifier {
    Some(value) => props.identifier = value
    None => ()
  }
  match revision {
    Some(value) => props.revision = value
    None => ()
  }
  match content_status {
    Some(value) => props.content_status = value
    None => ()
  }
  match category {
    Some(value) => props.category = value
    None => ()
  }
  match version {
    Some(value) => props.version = value
    None => ()
  }
  match created {
    Some(value) => props.created = value
    None => ()
  }
  match modified {
    Some(value) => props.modified = value
    None => ()
  }
  props
}

///|
pub struct AppProperties {
  mut application : String
  mut doc_security : Int?
  mut scale_crop : Bool?
  mut company : String
  mut links_up_to_date : Bool?
  mut hyperlinks_changed : Bool?
  mut app_version : String
}

///|
pub fn AppProperties::new() -> AppProperties {
  {
    application: "mbtexcel",
    doc_security: None,
    scale_crop: None,
    company: "",
    links_up_to_date: None,
    hyperlinks_changed: None,
    app_version: "",
  }
}

///|
pub fn AppProperties::with_values(
  application? : String,
  doc_security? : Int,
  scale_crop? : Bool,
  company? : String,
  links_up_to_date? : Bool,
  hyperlinks_changed? : Bool,
  app_version? : String,
) -> AppProperties {
  let props = AppProperties::new()
  match application {
    Some(value) => props.application = value
    None => ()
  }
  match doc_security {
    Some(value) => props.doc_security = Some(value)
    None => ()
  }
  match scale_crop {
    Some(value) => props.scale_crop = Some(value)
    None => ()
  }
  match company {
    Some(value) => props.company = value
    None => ()
  }
  match links_up_to_date {
    Some(value) => props.links_up_to_date = Some(value)
    None => ()
  }
  match hyperlinks_changed {
    Some(value) => props.hyperlinks_changed = Some(value)
    None => ()
  }
  match app_version {
    Some(value) => props.app_version = value
    None => ()
  }
  props
}

///|
fn bool_text(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
fn write_core_properties_xml(props : CoreProperties) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\"\n",
  )
  sb.write_view(" xmlns:dc=\"http://purl.org/dc/elements/1.1/\"\n")
  sb.write_view(" xmlns:dcterms=\"http://purl.org/dc/terms/\"\n")
  sb.write_view(" xmlns:dcmitype=\"http://purl.org/dc/dcmitype/\"\n")
  sb.write_view(" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">\n")
  if props.title != "" {
    sb.write_view("  <dc:title>")
    sb.write_view(escape_xml_text(props.title))
    sb.write_view("</dc:title>\n")
  }
  if props.subject != "" {
    sb.write_view("  <dc:subject>")
    sb.write_view(escape_xml_text(props.subject))
    sb.write_view("</dc:subject>\n")
  }
  if props.creator != "" {
    sb.write_view("  <dc:creator>")
    sb.write_view(escape_xml_text(props.creator))
    sb.write_view("</dc:creator>\n")
  }
  if props.keywords != "" {
    sb.write_view("  <cp:keywords>")
    sb.write_view(escape_xml_text(props.keywords))
    sb.write_view("</cp:keywords>\n")
  }
  if props.description != "" {
    sb.write_view("  <dc:description>")
    sb.write_view(escape_xml_text(props.description))
    sb.write_view("</dc:description>\n")
  }
  if props.last_modified_by != "" {
    sb.write_view("  <cp:lastModifiedBy>")
    sb.write_view(escape_xml_text(props.last_modified_by))
    sb.write_view("</cp:lastModifiedBy>\n")
  }
  if props.language != "" {
    sb.write_view("  <dc:language>")
    sb.write_view(escape_xml_text(props.language))
    sb.write_view("</dc:language>\n")
  }
  if props.identifier != "" {
    sb.write_view("  <dc:identifier>")
    sb.write_view(escape_xml_text(props.identifier))
    sb.write_view("</dc:identifier>\n")
  }
  if props.revision != "" {
    sb.write_view("  <cp:revision>")
    sb.write_view(escape_xml_text(props.revision))
    sb.write_view("</cp:revision>\n")
  }
  if props.content_status != "" {
    sb.write_view("  <cp:contentStatus>")
    sb.write_view(escape_xml_text(props.content_status))
    sb.write_view("</cp:contentStatus>\n")
  }
  if props.category != "" {
    sb.write_view("  <cp:category>")
    sb.write_view(escape_xml_text(props.category))
    sb.write_view("</cp:category>\n")
  }
  if props.version != "" {
    sb.write_view("  <cp:version>")
    sb.write_view(escape_xml_text(props.version))
    sb.write_view("</cp:version>\n")
  }
  if props.created != "" {
    sb.write_view("  <dcterms:created xsi:type=\"dcterms:W3CDTF\">")
    sb.write_view(escape_xml_text(props.created))
    sb.write_view("</dcterms:created>\n")
  }
  if props.modified != "" {
    sb.write_view("  <dcterms:modified xsi:type=\"dcterms:W3CDTF\">")
    sb.write_view(escape_xml_text(props.modified))
    sb.write_view("</dcterms:modified>\n")
  }
  sb.write_view("</cp:coreProperties>")
  sb.to_string()
}

///|
fn write_app_properties_xml(props : AppProperties) -> String {
  let sb = StringBuilder::new()
  sb.write_view("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  sb.write_view(
    "<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\"\n",
  )
  sb.write_view(
    " xmlns:vt=\"http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes\">\n",
  )
  if props.application != "" {
    sb.write_view("  <Application>")
    sb.write_view(escape_xml_text(props.application))
    sb.write_view("</Application>\n")
  }
  match props.scale_crop {
    Some(value) => {
      sb.write_view("  <ScaleCrop>")
      sb.write_view(bool_text(value))
      sb.write_view("</ScaleCrop>\n")
    }
    None => ()
  }
  match props.doc_security {
    Some(value) => {
      sb.write_view("  <DocSecurity>")
      sb.write_view("\{value}")
      sb.write_view("</DocSecurity>\n")
    }
    None => ()
  }
  if props.company != "" {
    sb.write_view("  <Company>")
    sb.write_view(escape_xml_text(props.company))
    sb.write_view("</Company>\n")
  }
  match props.links_up_to_date {
    Some(value) => {
      sb.write_view("  <LinksUpToDate>")
      sb.write_view(bool_text(value))
      sb.write_view("</LinksUpToDate>\n")
    }
    None => ()
  }
  match props.hyperlinks_changed {
    Some(value) => {
      sb.write_view("  <HyperlinksChanged>")
      sb.write_view(bool_text(value))
      sb.write_view("</HyperlinksChanged>\n")
    }
    None => ()
  }
  if props.app_version != "" {
    sb.write_view("  <AppVersion>")
    sb.write_view(escape_xml_text(props.app_version))
    sb.write_view("</AppVersion>\n")
  }
  sb.write_view("</Properties>")
  sb.to_string()
}

///|
fn parse_bool(text : StringView) -> Bool {
  let value = text.to_string()
  value == "true" || value == "1"
}

///|
fn parse_core_properties(xml : StringView) -> CoreProperties raise XlsxError {
  let props = CoreProperties::new()
  match extract_tag_body(xml, "dc:title") {
    Some(value) => props.title = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body(xml, "dc:subject") {
    Some(value) => props.subject = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body(xml, "dc:creator") {
    Some(value) => props.creator = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body(xml, "cp:keywords") {
    Some(value) => props.keywords = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body(xml, "dc:description") {
    Some(value) => props.description = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body(xml, "cp:lastModifiedBy") {
    Some(value) => props.last_modified_by = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body(xml, "dc:language") {
    Some(value) => props.language = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body(xml, "dc:identifier") {
    Some(value) => props.identifier = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body(xml, "cp:revision") {
    Some(value) => props.revision = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body(xml, "cp:contentStatus") {
    Some(value) => props.content_status = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body(xml, "cp:category") {
    Some(value) => props.category = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body(xml, "cp:version") {
    Some(value) => props.version = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body(xml, "dcterms:created") {
    Some(value) => props.created = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body(xml, "dcterms:modified") {
    Some(value) => props.modified = unescape_xml_text(value)
    None => ()
  }
  props
}

///|
fn parse_app_properties(xml : StringView) -> AppProperties raise XlsxError {
  let props = AppProperties::new()
  match extract_tag_body(xml, "Application") {
    Some(value) => props.application = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body(xml, "ScaleCrop") {
    Some(value) => props.scale_crop = Some(parse_bool(value))
    None => ()
  }
  match extract_tag_body(xml, "DocSecurity") {
    Some(value) =>
      props.doc_security = Some(
        @strconv.parse_int(unescape_xml_text(value), base=10) catch {
          _ => 0
        },
      )
    None => ()
  }
  match extract_tag_body(xml, "Company") {
    Some(value) => props.company = unescape_xml_text(value)
    None => ()
  }
  match extract_tag_body(xml, "LinksUpToDate") {
    Some(value) => props.links_up_to_date = Some(parse_bool(value))
    None => ()
  }
  match extract_tag_body(xml, "HyperlinksChanged") {
    Some(value) => props.hyperlinks_changed = Some(parse_bool(value))
    None => ()
  }
  match extract_tag_body(xml, "AppVersion") {
    Some(value) => props.app_version = unescape_xml_text(value)
    None => ()
  }
  props
}
