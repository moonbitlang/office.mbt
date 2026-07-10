// The package-level read surface: body PLUS sections and header/footer
// stories. `read_docx_package` is a NEW entry point — `read_docx` /
// `read_docx_with_messages` and `DocxReadResult` are frozen public API and
// stay byte-identical (the shared assembly lives in `DocumentParts`).
//
// The reader stays tolerant here, matching the body reader's philosophy:
// a dangling header reference or an unparsable part becomes a Warning and
// the reference is skipped — `docx validate` is the strict gate.

///|
/// Everything `read_docx_with_messages` returns, plus sections and
/// header/footer stories.
pub(all) struct DocxPackageResult {
  document : DocumentElement
  headers : Array[@document.HeaderFooterPart]
  footers : Array[@document.HeaderFooterPart]
  sections : Array[@document.DocumentSection]
  messages : Array[Message]
} derive(Debug, Eq)

///|
/// Reads DOCX bytes into the package-level representation: the body
/// document tree (identical to `read_docx_with_messages`), header/footer
/// parts (each a block-level story, deduplicated by part path in
/// first-reference order), and the sections that reference them.
pub fn read_docx_package(
  docx : BytesView,
  external_file_access? : Bool = false,
  read_external_file? : (String) -> Bytes? = no_external_file_reader,
) -> DocxPackageResult raise DocxError {
  let zip = open_zip(docx)
  let external_files = external_file_access_options(
    external_file_access, read_external_file,
  )
  let parts = DocumentParts::build(zip, external_files~)
  let document_result = parts.read_document()
  let collector = HeaderFooterCollector::new(parts)
  let sections = collect_sections(parts.root, collector)
  let messages : Array[Message] = []
  messages.append(parts.notes_result.messages)
  messages.append(parts.comments_result.messages)
  messages.append(document_result.messages)
  messages.append(collector.messages)
  {
    document: document_result.document,
    headers: collector.headers,
    footers: collector.footers,
    sections,
    messages: @core.dedupe_messages(messages),
  }
}

///|
/// Scans the body for section definitions: a paragraph-level `w:sectPr`
/// (inside `w:pPr`) closes a section after that paragraph; the body-final
/// `w:sectPr` closes the last section. Direct body paragraphs are counted
/// in document order.
fn collect_sections(
  root : XmlElement,
  collector : HeaderFooterCollector,
) -> Array[@document.DocumentSection] raise DocxError {
  let sections : Array[@document.DocumentSection] = []
  guard root.first("w:body") is Some(body) else { return sections }
  let mut paragraph_index = 0
  let mut trailing_sect_pr : XmlElement? = None
  for node in body.children {
    guard node is XmlElement(element) else { continue }
    match element.name {
      "w:p" => {
        paragraph_index += 1
        match paragraph_sect_pr(element) {
          Some(sect_pr) =>
            sections.push(collector.section(sect_pr, Some(paragraph_index)))
          None => ()
        }
      }
      "w:sectPr" => trailing_sect_pr = Some(element)
      _ => ()
    }
  }
  match trailing_sect_pr {
    Some(sect_pr) => sections.push(collector.section(sect_pr, None))
    None => ()
  }
  sections
}

///|
fn paragraph_sect_pr(paragraph : XmlElement) -> XmlElement? {
  match paragraph.first("w:pPr") {
    Some(properties) => properties.first("w:sectPr")
    None => None
  }
}

///|
/// Resolves header/footer references and reads their parts, deduplicating
/// by resolved part path (first-reference order).
priv struct HeaderFooterCollector {
  parts : DocumentParts
  headers : Array[@document.HeaderFooterPart]
  footers : Array[@document.HeaderFooterPart]
  header_index_by_path : Map[String, Int]
  footer_index_by_path : Map[String, Int]
  messages : Array[Message]
}

///|
fn HeaderFooterCollector::new(parts : DocumentParts) -> HeaderFooterCollector {
  {
    parts,
    headers: [],
    footers: [],
    header_index_by_path: Map([]),
    footer_index_by_path: Map([]),
    messages: [],
  }
}

///|
fn HeaderFooterCollector::section(
  self : HeaderFooterCollector,
  sect_pr : XmlElement,
  ends_after_paragraph : Int?,
) -> @document.DocumentSection raise DocxError {
  let headers : Array[@document.SectionRef] = []
  let footers : Array[@document.SectionRef] = []
  for node in sect_pr.children {
    guard node is XmlElement(element) else { continue }
    let is_header = element.name == "w:headerReference"
    let is_footer = element.name == "w:footerReference"
    if !is_header && !is_footer {
      continue
    }
    let variant = element.attributes.get("w:type").unwrap_or("default")
    guard element.attributes.get("r:id") is Some(rel_id) else {
      self.messages.push(
        Warning("A header/footer reference without r:id was ignored"),
      )
      continue
    }
    match self.resolve_part(rel_id, is_header~) {
      Some(index) => {
        let section_ref : @document.SectionRef = { variant, part: index }
        if is_header {
          headers.push(section_ref)
        } else {
          footers.push(section_ref)
        }
      }
      None => ()
    }
  }
  { ends_after_paragraph, headers, footers }
}

///|
/// Returns the part index in `headers`/`footers`, reading the part on its
/// first reference. A dangling id or unreadable part warns and yields None.
fn HeaderFooterCollector::resolve_part(
  self : HeaderFooterCollector,
  rel_id : String,
  is_header~ : Bool,
) -> Int? raise DocxError {
  let kind = if is_header { "header" } else { "footer" }
  guard self.parts.relationships.find_target_by_id(rel_id) is Some(target) else {
    self.messages.push(
      Warning(
        "A \{kind} reference to unknown relationship \{rel_id} was ignored",
      ),
    )
    return None
  }
  let path = resolve_part_target(self.parts.base_path, target)
  let index_by_path = if is_header {
    self.header_index_by_path
  } else {
    self.footer_index_by_path
  }
  match index_by_path.get(path) {
    Some(index) => Some(index)
    None => {
      if !self.parts.zip.exists(path) {
        self.messages.push(
          Warning("A \{kind} part is missing and was ignored: \{path}"),
        )
        return None
      }
      let body = self.read_part_story(path)
      let stories = if is_header { self.headers } else { self.footers }
      stories.push({ body, })
      let index = stories.length() - 1
      index_by_path[path] = index
      Some(index)
    }
  }
}

///|
/// Reads one header/footer part's block content with a body reader bound to
/// the PART'S OWN relationships (images and hyperlinks inside headers
/// resolve through `word/_rels/headerN.xml.rels`, not the document's).
fn HeaderFooterCollector::read_part_story(
  self : HeaderFooterCollector,
  path : String,
) -> Array[DocumentElement] raise DocxError {
  let part_relationships = read_relationships(
    self.parts.zip,
    relationships_path_for_part(path),
  )
  let reader = BodyReader::{
    styles: self.parts.styles,
    zip: self.parts.zip,
    relationships: part_relationships,
    content_types: self.parts.content_types,
    base_path: split_zip_path(path).0,
    numbering: self.parts.numbering,
    messages: [],
    external_files: self.parts.external_files,
    read_images: true,
  }
  let root = read_xml_part(self.parts.zip, path)
  let body = reader.read_children(root.children)
  self.messages.append(reader.messages)
  body
}
