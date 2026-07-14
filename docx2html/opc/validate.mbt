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
const OFFICE_DOCUMENT_RELATIONSHIP_SUFFIX : String = "/officeDocument"

///|
const DEFAULT_MAX_FINDINGS : Int = 1024

///|
const DEFAULT_MAX_FINDING_CHARS : Int = 2048

///|
priv struct FindingCollector {
  findings : Array[String]
  max_findings : Int
  max_message_chars : Int
  mut truncated : Bool
}

///|
fn FindingCollector::new(
  max_findings : Int,
  max_message_chars : Int,
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
) -> (Array[String], Bool) {
  let findings = FindingCollector::new(max_findings, max_message_chars)
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
) -> (Array[String], Bool) {
  let findings = FindingCollector::new(max_findings, max_message_chars)
  validate_docx_archive_into(archive, findings)
  (findings.findings, findings.truncated)
}

///|
fn validate_docx_archive_into(
  archive : @mbtzip.Archive,
  findings : FindingCollector,
) -> Unit {
  // Raw entry sweep: names + CRC integrity, before any part-level logic.
  let parts : Map[String, Bytes] = Map([])
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
  parts : Map[String, Bytes],
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
          (Some(extension), Some(content_type)) =>
            defaults[extension.to_lower()] = content_type
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
          (Some(part_name), Some(content_type)) => {
            overrides[part_name] = content_type
            // Only a '/'-prefixed PartName can be resolved to an entry; an
            // empty or slash-less one is itself the finding (and slicing it
            // would abort on attacker-supplied input).
            if part_name.has_prefix("/") {
              let target = part_name[1:].to_owned()
              if !parts.contains(target) {
                findings.add(
                  "\{CONTENT_TYPES_PART}: Override names a missing part: \{findings.text(part_name)}",
                )
              }
            } else {
              findings.add(
                "\{CONTENT_TYPES_PART}: Override PartName must start with '/': \{findings.text(part_name)}",
              )
            }
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
fn check_content_type_coverage(
  parts : Map[String, Bytes],
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
  parts : Map[String, Bytes],
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
          let mut main_part : String? = None
          for_each_relationship(root, (rel_type, target, external) => {
            if !external &&
              rel_type.has_suffix(OFFICE_DOCUMENT_RELATIONSHIP_SUFFIX) &&
              main_part is None {
              main_part = Some(resolve_target("", target))
            }
          })
          match main_part {
            Some(part) =>
              match parts.get(part) {
                Some(bytes) => check_main_part(part, bytes, findings)
                None =>
                  findings.add(
                    "officeDocument relationship targets a missing part: \{findings.text(part)}",
                  )
              }
            None =>
              findings.add("\{ROOT_RELS_PART}: no officeDocument relationship")
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
        for_each_relationship(root, (_rel_type, target, external) => {
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
  bytes : Bytes,
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
  root : @xml.XmlElement,
  visit : (String, String, Bool) -> Unit,
) -> Unit {
  for node in root.children {
    guard node is XmlElement(element) else { continue }
    if local_name(element.name) != "Relationship" {
      continue
    }
    let rel_type = element.attributes.get("Type").unwrap_or("")
    let target = element.attributes.get("Target").unwrap_or("")
    let external = element.attributes.get("TargetMode") is Some("External")
    visit(rel_type, target, external)
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
  bytes : Bytes,
  findings : FindingCollector,
) -> @xml.XmlElement? {
  let text = @utf8.decode(bytes, ignore_bom=true) catch {
    _ => {
      findings.add("part is not valid UTF-8: \{findings.text(name)}")
      return None
    }
  }
  let root = @xml.read_xml_string_strict(text) catch {
    err => {
      findings.add(
        "malformed XML in \{findings.text(name)}: \{findings.text(repr(err))}",
      )
      return None
    }
  }
  Some(root)
}
