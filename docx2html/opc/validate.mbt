// Portable structural validation of a docx OPC package — the tier behind
// `docx validate` (native AND wasm; the .NET OpenXML SDK schema tier is a
// separate native-only development gate). Checks are package-structural,
// not schema-deep:
//
//   1. The archive opens, entry names are unique and well-formed, and each
//      entry's data matches its stored CRC-32 (the inflate path tolerates
//      corruption the CRC exposes — raw central-directory entries are used
//      because the map-backed reader wrapper silently drops duplicates).
//   2. `[Content_Types].xml` exists, parses, and covers every part via an
//      extension default or an exact override; overrides point at parts
//      that exist.
//   3. `_rels/.rels` exists, parses, and names an officeDocument
//      relationship whose target exists (the main document part is found by
//      FOLLOWING that relationship — never a hardcoded `word/document.xml`).
//   4. The main part parses as XML with a `document` root.
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
/// Validates docx package structure. Returns findings; empty = valid.
pub fn validate_docx_package(data : BytesView) -> Array[String] {
  let findings = []
  let archive = @mbtzip.read(data) catch {
    err => {
      findings.push("invalid ZIP archive: \{repr(err)}")
      return findings
    }
  }
  // Raw entry sweep: names + CRC integrity, before any part-level logic.
  let parts : Map[String, Bytes] = Map([])
  let seen : Set[String] = Set([])
  for entry in archive.entries() {
    let name = entry.name()
    if seen.contains(name) {
      findings.push("duplicate entry name: \{name}")
    } else {
      seen.add(name)
    }
    check_entry_name(name, findings)
    if entry.crc32() != @mbtzip.crc32(entry.data()) {
      findings.push("entry data does not match its stored CRC-32: \{name}")
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
  findings
}

///|
fn check_entry_name(name : String, findings : Array[String]) -> Unit {
  if name == "" {
    findings.push("empty entry name")
    return
  }
  if name.has_prefix("/") {
    findings.push("entry name must not start with '/': \{name}")
  }
  if name.find("\\") is Some(_) {
    findings.push("entry name contains a backslash: \{name}")
  }
  for segment in name.split("/") {
    if segment == ".." {
      findings.push("entry name contains a '..' segment: \{name}")
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
  findings : Array[String],
) -> ContentTypes? {
  guard parts.get(CONTENT_TYPES_PART) is Some(bytes) else {
    findings.push("missing required part: \{CONTENT_TYPES_PART}")
    return None
  }
  guard parse_xml_part(CONTENT_TYPES_PART, bytes, findings) is Some(root) else {
    return None
  }
  let defaults : Map[String, String] = Map([])
  let overrides : Map[String, String] = Map([])
  for node in root.children {
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
            findings.push(
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
                findings.push(
                  "\{CONTENT_TYPES_PART}: Override names a missing part: \{part_name}",
                )
              }
            } else {
              findings.push(
                "\{CONTENT_TYPES_PART}: Override PartName must start with '/': \{part_name}",
              )
            }
          }
          _ =>
            findings.push(
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
  findings : Array[String],
) -> Unit {
  for name, _ in parts {
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
    findings.push("no content type for part: \{name}")
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
  findings : Array[String],
) -> Unit {
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
                  findings.push(
                    "officeDocument relationship targets a missing part: \{part}",
                  )
              }
            None =>
              findings.push("\{ROOT_RELS_PART}: no officeDocument relationship")
          }
        }
        None => ()
      }
    None => findings.push("missing required part: \{ROOT_RELS_PART}")
  }
  // Every part's own rels, when present: parse + internal targets resolve.
  for name, bytes in parts {
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
              findings.push(
                "relationship target missing: \{name} -> \{target} (resolved \{resolved})",
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
  findings : Array[String],
) -> Unit {
  match parse_xml_part(name, bytes, findings) {
    Some(root) =>
      if local_name(root.name) != "document" {
        findings.push(
          "main part \{name} root element is '\{local_name(root.name)}', expected a 'document' root",
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
/// climb with `..`.
fn resolve_target(base : String, target : String) -> String {
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
  findings : Array[String],
) -> @xml.XmlElement? {
  let text = @utf8.decode(bytes, ignore_bom=true) catch {
    _ => {
      findings.push("part is not valid UTF-8: \{name}")
      return None
    }
  }
  let root = @xml.read_xml_string(text) catch {
    err => {
      findings.push("malformed XML in \{name}: \{repr(err)}")
      return None
    }
  }
  Some(root)
}
