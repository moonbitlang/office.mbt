// Portable structural validation of a docx OPC package — the tier behind
// `docx validate` (native AND wasm; the .NET OpenXML SDK schema tier is a
// separate native-only development gate). Checks are package-structural,
// not schema-deep:
//
//   1. The archive opens, entry names are unique and well-formed, and each
//      entry's data matches its stored CRC-32 (the inflate path tolerates
//      corruption the CRC exposes — raw central-directory entries are used
//      because the map-backed reader wrapper silently drops duplicates).
//   2. `[Content_Types].xml` exists, parses as strict DTD-free XML, and covers
//      every part via an extension default or an exact override; overrides
//      point at parts that exist.
//   3. `_rels/.rels` exists, parses, and names an officeDocument
//      relationship whose target exists (the main document part is found by
//      FOLLOWING that relationship — never a hardcoded `word/document.xml`).
//   4. The main part parses as strict XML with a `document` root.
//   5. Every part's own relationships (`dir/_rels/name.rels`), when
//      present, parse and their internal targets resolve to existing parts.
//
// Returns findings as agent-readable strings; empty means structurally
// valid. Deliberately does NOT validate WordprocessingML content — that is
// the SDK tier's job.

///|
const CONTENT_TYPES_PART : String = "[Content_Types].xml"

///|
const ROOT_RELS_PART : String = "_rels/.rels"

///|
const TRANSITIONAL_OFFICE_DOCUMENT_RELATIONSHIP : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"

///|
const STRICT_OFFICE_DOCUMENT_RELATIONSHIP : String = "http://purl.oclc.org/ooxml/officeDocument/relationships/officeDocument"

///|
const DEFAULT_MAX_FINDINGS : Int = 1024

///|
const DEFAULT_MAX_FINDING_CHARS : Int = 2048

///|
const DEFAULT_MAX_XML_SOURCE_UNITS : Int = 16 * 1024 * 1024

///|
const DEFAULT_MAX_XML_TOKENS : Int = 262_144

///|
const DEFAULT_MAX_XML_MATERIALIZED_CHARS : Int = 8 * 1024 * 1024

///|
const DEFAULT_MAX_XML_TOKEN_CHARS : Int = 4 * 1024 * 1024

///|
priv struct FindingCollector {
  findings : Array[String]
  max_findings : Int
  max_message_chars : Int
  xml_budget : @xml.XmlReadBudget
  mut truncated : Bool
}

///|
fn FindingCollector::new(
  max_findings : Int,
  max_message_chars : Int,
) -> FindingCollector {
  FindingCollector::new_with_xml_limits(
    max_findings,
    max_message_chars,
    DEFAULT_MAX_XML_SOURCE_UNITS,
    DEFAULT_MAX_XML_TOKENS,
    DEFAULT_MAX_XML_MATERIALIZED_CHARS,
    DEFAULT_MAX_XML_TOKEN_CHARS,
  )
}

///|
fn FindingCollector::new_with_xml_limits(
  max_findings : Int,
  max_message_chars : Int,
  max_xml_source_units : Int,
  max_xml_tokens : Int,
  max_xml_materialized_chars : Int,
  max_xml_token_chars : Int,
) -> FindingCollector {
  {
    findings: [],
    max_findings: if max_findings > 0 {
      max_findings
    } else {
      0
    },
    max_message_chars: if max_message_chars > 0 {
      max_message_chars
    } else {
      0
    },
    xml_budget: @xml.xml_read_budget(
      max_source_units=if max_xml_source_units > 0 {
        max_xml_source_units
      } else {
        0
      },
      max_tokens=if max_xml_tokens > 0 { max_xml_tokens } else { 0 },
      max_materialized_chars=if max_xml_materialized_chars > 0 {
        max_xml_materialized_chars
      } else {
        0
      },
      max_token_chars=if max_xml_token_chars > 0 {
        max_xml_token_chars
      } else {
        0
      },
    ),
    truncated: false,
  }
}

///|
fn valid_finding_text(text : String, limit : Int) -> Bool {
  let mut offset = 0
  let mut scalars = 0
  while offset < text.length() {
    let unit = text[offset]
    if unit.is_leading_surrogate() {
      if offset + 1 >= text.length() ||
        !text[offset + 1].is_trailing_surrogate() {
        return false
      }
      offset = offset + 2
    } else if unit.is_trailing_surrogate() {
      return false
    } else {
      offset = offset + 1
    }
    scalars = scalars + 1
    if scalars > limit {
      return false
    }
  }
  true
}

///|
fn bounded_finding_text(text : String, limit : Int) -> String {
  if limit <= 0 {
    return ""
  }
  if valid_finding_text(text, limit) {
    return text
  }
  if !valid_finding_text(text, 0x7fffffff) {
    return bounded_finding_text("<invalid UTF-16>", limit)
  }
  let output = StringBuilder::new()
  let mut count = 0
  let content_limit = if limit > 1 { limit - 1 } else { 0 }
  for character in text {
    if count == content_limit {
      output.write_string("…") |> ignore
      break
    }
    output.write_char(character) |> ignore
    count = count + 1
  }
  output.to_string()
}

///|
fn FindingCollector::text(self : FindingCollector, text : String) -> String {
  bounded_finding_text(text, self.max_message_chars)
}

///|
fn FindingCollector::add(self : FindingCollector, message : String) -> Unit {
  if self.findings.length() >= self.max_findings {
    self.truncated = true
    return
  }
  self.findings.push(bounded_finding_text(message, self.max_message_chars))
}

///|
fn FindingCollector::full(self : FindingCollector) -> Bool {
  self.findings.length() >= self.max_findings
}

///|
fn FindingCollector::stop(self : FindingCollector) -> Unit {
  self.truncated = true
}

///|
fn default_findings(result : (Array[String], Bool)) -> Array[String] {
  let (findings, truncated) = result
  if truncated {
    if findings.length() == DEFAULT_MAX_FINDINGS {
      let _ = findings.pop()
    }
    findings.push("additional validation findings were omitted")
  }
  findings
}

///|
/// Validates docx package structure. Returns bounded findings; empty = valid.
pub fn validate_docx_package(data : BytesView) -> Array[String] {
  default_findings(
    validate_docx_package_limited(
      data,
      max_findings=DEFAULT_MAX_FINDINGS,
      max_message_chars=DEFAULT_MAX_FINDING_CHARS,
    ),
  )
}

///|
/// Validates package bytes while bounding findings as they are produced.
/// `truncated=true` means validation stopped after filling the caller's cap.
pub fn validate_docx_package_limited(
  data : BytesView,
  max_findings~ : Int,
  max_message_chars~ : Int,
  max_xml_source_units? : Int = DEFAULT_MAX_XML_SOURCE_UNITS,
  max_xml_tokens? : Int = DEFAULT_MAX_XML_TOKENS,
  max_xml_materialized_chars? : Int = DEFAULT_MAX_XML_MATERIALIZED_CHARS,
  max_xml_token_chars? : Int = DEFAULT_MAX_XML_TOKEN_CHARS,
) -> (Array[String], Bool) {
  let findings = FindingCollector::new_with_xml_limits(
    max_findings, max_message_chars, max_xml_source_units, max_xml_tokens, max_xml_materialized_chars,
    max_xml_token_chars,
  )
  let archive = @mbtzip.read(data) catch {
    err => {
      findings.add("invalid ZIP archive: \{findings.text(repr(err))}")
      return (findings.findings, findings.truncated)
    }
  }
  validate_docx_archive_into(archive, findings)
  (findings.findings, findings.truncated)
}

///|
/// Validates an already materialized DOCX archive without reading or inflating
/// the package again. The caller retains ownership; validation is read-only.
pub fn validate_docx_archive(archive : @mbtzip.Archive) -> Array[String] {
  default_findings(
    validate_docx_archive_limited(
      archive,
      max_findings=DEFAULT_MAX_FINDINGS,
      max_message_chars=DEFAULT_MAX_FINDING_CHARS,
    ),
  )
}

///|
/// Archive-backed validation with a hard finding count and per-message scalar
/// ceiling applied during production rather than after an unbounded array is
/// built.
pub fn validate_docx_archive_limited(
  archive : @mbtzip.Archive,
  max_findings~ : Int,
  max_message_chars~ : Int,
  max_xml_source_units? : Int = DEFAULT_MAX_XML_SOURCE_UNITS,
  max_xml_tokens? : Int = DEFAULT_MAX_XML_TOKENS,
  max_xml_materialized_chars? : Int = DEFAULT_MAX_XML_MATERIALIZED_CHARS,
  max_xml_token_chars? : Int = DEFAULT_MAX_XML_TOKEN_CHARS,
) -> (Array[String], Bool) {
  let findings = FindingCollector::new_with_xml_limits(
    max_findings, max_message_chars, max_xml_source_units, max_xml_tokens, max_xml_materialized_chars,
    max_xml_token_chars,
  )
  validate_docx_archive_into(archive, findings)
  (findings.findings, findings.truncated)
}

///|
fn validate_docx_archive_into(
  archive : @mbtzip.Archive,
  findings : FindingCollector,
) -> Unit {
  // Raw entry sweep: names + CRC integrity, before any part-level logic.
  let parts : Map[String, BytesView] = Map([])
  let seen : Set[String] = Set([])
  for entry in archive.entries() {
    if findings.full() {
      findings.stop()
      return
    }
    let name = entry.name()
    if seen.contains(name) {
      findings.add("duplicate entry name: \{findings.text(name)}")
    } else {
      seen.add(name)
    }
    check_entry_name(name, findings)
    if entry.crc32() != @mbtzip.crc32(entry.data()) {
      findings.add(
        "entry data does not match its stored CRC-32: \{findings.text(name)}",
      )
    }
    if !name.has_suffix("/") {
      parts[name] = entry.data()
    }
  }
  let content_types = check_content_types(parts, findings)
  check_relationships(parts, findings)
  match content_types {
    Some(types) => check_content_type_coverage(parts, types, findings)
    None => ()
  }
}

///|
fn check_entry_name(name : String, findings : FindingCollector) -> Unit {
  if name == "" {
    findings.add("empty entry name")
    return
  }
  if name.has_prefix("/") {
    findings.add("entry name must not start with '/': \{findings.text(name)}")
  }
  if name.find("\\") is Some(_) {
    findings.add("entry name contains a backslash: \{findings.text(name)}")
  }
  for segment in name.split("/") {
    if segment == ".." {
      findings.add("entry name contains a '..' segment: \{findings.text(name)}")
      break
    }
  }
}

///|
priv struct ContentTypes {
  defaults : Map[String, String]
  overrides : Map[String, String]
}

///|
fn check_content_types(
  parts : Map[String, BytesView],
  findings : FindingCollector,
) -> ContentTypes? {
  guard parts.get(CONTENT_TYPES_PART) is Some(bytes) else {
    findings.add("missing required part: \{CONTENT_TYPES_PART}")
    return None
  }
  guard parse_xml_part(CONTENT_TYPES_PART, bytes, findings) is Some(root) else {
    return None
  }
  let defaults : Map[String, String] = Map([])
  let overrides : Map[String, String] = Map([])
  for node in root.children {
    if findings.full() {
      findings.stop()
      break
    }
    guard node is XmlElement(element) else { continue }
    match local_name(element.name) {
      "Default" =>
        match
          (
            element.attributes.get("Extension"),
            element.attributes.get("ContentType"),
          ) {
          (Some(extension), Some(content_type)) => {
            let key = extension.to_lower()
            if defaults.contains(key) {
              findings.add(
                "\{CONTENT_TYPES_PART}: duplicate Default Extension after case normalization: \{findings.text(key)}",
              )
            } else {
              defaults[key] = content_type
            }
          }
          _ =>
            findings.add(
              "\{CONTENT_TYPES_PART}: Default missing Extension or ContentType",
            )
        }
      "Override" =>
        match
          (
            element.attributes.get("PartName"),
            element.attributes.get("ContentType"),
          ) {
          (Some(part_name), Some(content_type)) =>
            // Only a '/'-prefixed PartName can be resolved to an entry; an
            // empty or slash-less one is itself the finding (and slicing it
            // would abort on attacker-supplied input).
            if part_name.has_prefix("/") {
              let key = normalize_override_part_name(part_name)
              if overrides.contains(key) {
                findings.add(
                  "\{CONTENT_TYPES_PART}: duplicate Override PartName after path normalization: \{findings.text(key)}",
                )
              } else {
                overrides[key] = content_type
              }
              if key != part_name {
                findings.add(
                  "\{CONTENT_TYPES_PART}: Override PartName is not canonical: \{findings.text(part_name)}",
                )
              }
              let target = key[1:].to_owned()
              if !parts.contains(target) {
                findings.add(
                  "\{CONTENT_TYPES_PART}: Override names a missing part: \{findings.text(key)}",
                )
              }
            } else {
              findings.add(
                "\{CONTENT_TYPES_PART}: Override PartName must start with '/': \{findings.text(part_name)}",
              )
            }
          _ =>
            findings.add(
              "\{CONTENT_TYPES_PART}: Override missing PartName or ContentType",
            )
        }
      _ => ()
    }
  }
  Some({ defaults, overrides })
}

///|
fn normalize_override_part_name(part_name : String) -> String {
  // Callers establish the leading slash. `resolve_target` removes redundant
  // separators and dot segments, giving declarations one collision key while
  // the separate canonicality finding rejects noncanonical spellings.
  "/" + resolve_target("", part_name[1:].to_owned())
}

///|
fn check_content_type_coverage(
  parts : Map[String, BytesView],
  types : ContentTypes,
  findings : FindingCollector,
) -> Unit {
  for name, _ in parts {
    if findings.full() {
      findings.stop()
      return
    }
    if name == CONTENT_TYPES_PART {
      continue
    }
    if types.overrides.contains("/" + name) {
      continue
    }
    let extension = part_extension(name)
    if extension is Some(ext) && types.defaults.contains(ext) {
      continue
    }
    findings.add("no content type for part: \{findings.text(name)}")
  }
}

///|
fn part_extension(name : String) -> String? {
  match name.rev_find(".") {
    Some(dot) => {
      // The extension must belong to the final path segment.
      let after_slash = match name.rev_find("/") {
        Some(slash) => dot > slash
        None => true
      }
      if after_slash && dot + 1 < name.length() {
        Some(name[dot + 1:].to_owned().to_lower())
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn check_relationships(
  parts : Map[String, BytesView],
  findings : FindingCollector,
) -> Unit {
  if findings.full() {
    findings.stop()
    return
  }
  // Root rels: required, and must carry the officeDocument relationship.
  match parts.get(ROOT_RELS_PART) {
    Some(bytes) =>
      match parse_xml_part(ROOT_RELS_PART, bytes, findings) {
        Some(root) => {
          let main_parts : Array[String] = []
          for_each_relationship(ROOT_RELS_PART, root, findings, (
            _id,
            rel_type,
            target,
            external,
          ) => {
            if rel_type == TRANSITIONAL_OFFICE_DOCUMENT_RELATIONSHIP ||
              rel_type == STRICT_OFFICE_DOCUMENT_RELATIONSHIP {
              if external {
                findings.add(
                  "\{ROOT_RELS_PART}: officeDocument relationship is not internal",
                )
              } else if target == "" {
                findings.add(
                  "\{ROOT_RELS_PART}: officeDocument relationship has no target",
                )
              } else {
                let resolved = resolve_target("", target)
                main_parts.push(resolved)
              }
            }
          })
          match main_parts {
            [part] =>
              match parts.get(part) {
                Some(bytes) => check_main_part(part, bytes, findings)
                None =>
                  findings.add(
                    "officeDocument relationship targets a missing part: \{findings.text(part)}",
                  )
              }
            [] =>
              findings.add("\{ROOT_RELS_PART}: no officeDocument relationship")
            _ =>
              findings.add(
                "\{ROOT_RELS_PART}: multiple officeDocument relationships",
              )
          }
        }
        None => ()
      }
    None => findings.add("missing required part: \{ROOT_RELS_PART}")
  }
  // Every part's own rels, when present: parse + internal targets resolve.
  for name, bytes in parts {
    if findings.full() {
      findings.stop()
      return
    }
    if name == ROOT_RELS_PART || !is_rels_part(name) {
      continue
    }
    match parse_xml_part(name, bytes, findings) {
      Some(root) => {
        let base = rels_base_dir(name)
        for_each_relationship(name, root, findings, (
          _id,
          _rel_type,
          target,
          external,
        ) => {
          if !external {
            let resolved = resolve_target(base, target)
            if !parts.contains(resolved) {
              findings.add(
                "relationship target missing: \{findings.text(name)} -> \{findings.text(target)} (resolved \{findings.text(resolved)})",
              )
            }
          }
        })
      }
      None => ()
    }
  }
}

///|
fn check_main_part(
  name : String,
  bytes : BytesView,
  findings : FindingCollector,
) -> Unit {
  match parse_xml_part(name, bytes, findings) {
    Some(root) =>
      if local_name(root.name) != "document" {
        findings.add(
          "main part \{findings.text(name)} root element is '\{findings.text(local_name(root.name))}', expected a 'document' root",
        )
      }
    None => ()
  }
}

///|
fn for_each_relationship(
  part_name : String,
  root : @xml.XmlElement,
  findings : FindingCollector,
  visit : (String, String, String, Bool) -> Unit,
) -> Unit {
  let ids : Set[String] = Set([])
  for node in root.children {
    if findings.full() {
      findings.stop()
      break
    }
    guard node is XmlElement(element) else { continue }
    if local_name(element.name) != "Relationship" {
      continue
    }
    let id = element.attributes.get("Id").unwrap_or("")
    if id == "" {
      findings.add(
        "\{findings.text(part_name)}: Relationship missing a non-empty Id",
      )
    } else if ids.contains(id) {
      findings.add(
        "\{findings.text(part_name)}: duplicate Relationship Id: \{findings.text(id)}",
      )
    } else {
      ids.add(id)
    }
    let rel_type = element.attributes.get("Type").unwrap_or("")
    let target = element.attributes.get("Target").unwrap_or("")
    let external = element.attributes.get("TargetMode") is Some("External")
    visit(id, rel_type, target, external)
  }
}

///|
/// `dir/_rels/name.rels` describes `dir/name`; its targets resolve against
/// `dir`.
fn is_rels_part(name : String) -> Bool {
  name.has_suffix(".rels") &&
  (name.has_prefix("_rels/") || name.find("/_rels/") is Some(_))
}

///|
fn rels_base_dir(rels_name : String) -> String {
  match rels_name.find("/_rels/") {
    Some(index) => rels_name[:index].to_owned()
    None => ""
  }
}

///|
/// Resolves a relationship target against a base directory: pack-absolute
/// targets (`/word/media/x.png`) are archive-rooted; relative targets may
/// climb with `..` (clamped at the package root) and `.`/empty segments
/// collapse. Shared OPC primitive — the package reader resolves
/// header/footer targets with the same semantics validation checks them by.
pub fn resolve_target(base : String, target : String) -> String {
  if target.has_prefix("/") {
    return target[1:].to_owned()
  }
  let segments : Array[String] = []
  if base != "" {
    for segment in base.split("/") {
      segments.push(segment.to_owned())
    }
  }
  for segment in target.split("/") {
    match segment.to_owned() {
      "" | "." => ()
      ".." => if segments.length() > 0 { let _ = segments.pop() }
      other => segments.push(other)
    }
  }
  segments.join("/")
}

///|
/// The parser emits `prefix:Local` for mapped namespaces and Clark notation
/// `{uri}Local` for unmapped ones; validation matches LOCAL names only (the
/// SDK tier is the namespace-strict gate).
fn local_name(name : String) -> String {
  let after_ns = match name.rev_find("}") {
    Some(index) => name[index + 1:].to_owned()
    None => name
  }
  match after_ns.rev_find(":") {
    Some(index) => after_ns[index + 1:].to_owned()
    None => after_ns
  }
}

///|
fn parse_xml_part(
  name : String,
  bytes : BytesView,
  findings : FindingCollector,
) -> @xml.XmlElement? {
  let root = @xml.read_xml_bytes_strict_limited(bytes, findings.xml_budget) catch {
    InvalidXml(message="XML source is not valid UTF-8") => {
      findings.add("part is not valid UTF-8: \{findings.text(name)}")
      return None
    }
    err => {
      findings.add(
        "malformed XML in \{findings.text(name)}: \{findings.text(repr(err))}",
      )
      return None
    }
  }
  Some(root)
}
