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
/// One scanned section plus the variants it DECLARED explicitly (readable
/// or not): an explicit-but-unreadable reference must still block
/// inheritance of that variant — the author overrode it, we just could not
/// read the override.
priv struct SectionScan {
  section : @document.DocumentSection
  declared_headers : Array[String]
  declared_footers : Array[String]
}

///|
fn collect_sections(
  root : XmlElement,
  collector : HeaderFooterCollector,
) -> Array[@document.DocumentSection] {
  let scans : Array[SectionScan] = []
  guard root.first("w:body") is Some(body) else {
    // Defensive only: the public entry point reads the body first and
    // raises on a missing one, so this branch is unreachable from
    // read_docx_package. Kept so the section invariant ("each body range
    // maps to exactly one section") holds for any caller.
    return [{ ends_after_paragraph: None, headers: [], footers: [] }]
  }
  let mut paragraph_index = 0
  let mut trailing_sect_pr : XmlElement? = None
  for node in body.children {
    guard node is XmlElement(element) else { continue }
    match element.name {
      "w:p" => {
        paragraph_index += 1
        match paragraph_sect_pr(element) {
          Some(sect_pr) =>
            scans.push(collector.section(sect_pr, Some(paragraph_index)))
          None => ()
        }
      }
      "w:sectPr" => trailing_sect_pr = Some(element)
      _ => ()
    }
  }
  match trailing_sect_pr {
    Some(sect_pr) => scans.push(collector.section(sect_pr, None))
    // A document without a body-final sectPr still has a final section
    // running to the body end.
    None =>
      scans.push({
        section: { ends_after_paragraph: None, headers: [], footers: [] },
        declared_headers: [],
        declared_footers: [],
      })
  }
  apply_header_inheritance(scans)
  scans.map(scan => scan.section)
}

///|
/// OOXML header/footer inheritance: a section without an explicit
/// reference for a variant uses the previous section's (effective)
/// reference for that variant. The projection exposes EFFECTIVE
/// associations, so an agent reading `sections[1].headers` sees what the
/// section actually renders with.
fn apply_header_inheritance(scans : Array[SectionScan]) -> Unit {
  for i in 1..<scans.length() {
    inherit_missing_variants(
      scans[i].section.headers,
      scans[i].declared_headers,
      scans[i - 1].section.headers,
    )
    inherit_missing_variants(
      scans[i].section.footers,
      scans[i].declared_footers,
      scans[i - 1].section.footers,
    )
  }
}

///|
/// Appends the previous section's effective refs for variants this section
/// neither carries nor DECLARED (a declared-but-unreadable override blocks
/// inheritance). Ordering: explicit refs stay in XML order; inherited
/// entries follow in the previous section's effective order.
fn inherit_missing_variants(
  current : Array[@document.SectionRef],
  declared : Array[String],
  previous : Array[@document.SectionRef],
) -> Unit {
  for candidate in previous {
    if declared.search(candidate.variant) is Some(_) {
      continue
    }
    let mut present = false
    for existing in current {
      if existing.variant == candidate.variant {
        present = true
        break
      }
    }
    if !present {
      current.push({ variant: candidate.variant, part: candidate.part })
    }
  }
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
) -> SectionScan {
  let headers : Array[@document.SectionRef] = []
  let footers : Array[@document.SectionRef] = []
  let declared_headers : Array[String] = []
  let declared_footers : Array[String] = []
  for node in sect_pr.children {
    guard node is XmlElement(element) else { continue }
    let is_header = element.name == "w:headerReference"
    let is_footer = element.name == "w:footerReference"
    if !is_header && !is_footer {
      continue
    }
    let variant = element.attributes.get("w:type").unwrap_or("default")
    // Declared regardless of resolvability: an explicit override blocks
    // inheritance even when its part cannot be read.
    if is_header {
      declared_headers.push(variant)
    } else {
      declared_footers.push(variant)
    }
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
  {
    section: { ends_after_paragraph, headers, footers },
    declared_headers,
    declared_footers,
  }
}

///|
/// Returns the part index in `headers`/`footers`, reading the part on its
/// first reference. A dangling id or unreadable part warns and yields None.
fn HeaderFooterCollector::resolve_part(
  self : HeaderFooterCollector,
  rel_id : String,
  is_header~ : Bool,
) -> Int? {
  let kind = if is_header { "header" } else { "footer" }
  let path = resolve_header_footer_reference_part(
    self.parts.zip,
    self.parts.relationships,
    self.parts.base_path,
    rel_id,
    is_header,
  ) catch {
    _ => {
      // The package projection remains tolerant. Annotation-aware mutation
      // runs the same resolver without this catch and therefore fails closed.
      self.messages.push(
        Warning(
          "A \{kind} reference through invalid relationship \{rel_id} was ignored",
        ),
      )
      return None
    }
  }
  let index_by_path = if is_header {
    self.header_index_by_path
  } else {
    self.footer_index_by_path
  }
  match index_by_path.get(path) {
    Some(index) => Some(index)
    None => {
      // A malformed part or malformed part-rels must not abort the read —
      // outline/text/get all flow through here, and the body-only surface
      // never raised for a broken header. Warn and skip instead.
      let body = self.read_part_story(path) catch {
        _ => {
          self.messages.push(
            Warning("A \{kind} part could not be read and was ignored: \{path}"),
          )
          return None
        }
      }
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
    xml_budget?=self.parts.xml_budget,
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
  let root = read_xml_part(
    self.parts.zip,
    path,
    xml_budget?=self.parts.xml_budget,
  )
  let body = reader.read_children(root.children)
  self.messages.append(reader.messages)
  body
}
