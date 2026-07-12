///|
/// The document formats supported by the `office` facade.
pub(all) enum DocumentFormat {
  Xlsx
  Docx
} derive(Debug, Eq)

///|
/// A deterministic, lowercase name suitable for CLI and JSON output.
pub fn DocumentFormat::name(self : DocumentFormat) -> String {
  match self {
    Xlsx => "xlsx"
    Docx => "docx"
  }
}

///|
pub impl Show for DocumentFormat with fn output(self, logger) {
  logger.write_string(self.name())
}

///|
/// Errors produced while identifying a supported Office package.
pub(all) suberror OfficeError {
  UnsupportedFileExtension(String)
  InvalidPackage(String)
  FormatMismatch(expected~ : DocumentFormat, actual~ : DocumentFormat)
} derive(Debug, Eq)

///|
pub impl Show for OfficeError with fn output(self, logger) {
  match self {
    UnsupportedFileExtension(path) =>
      logger.write_string(
        "unsupported file extension for '\{path}' (expected .xlsx or .docx)",
      )
    InvalidPackage(message) =>
      logger.write_string("invalid Office package: " + message)
    FormatMismatch(expected~, actual~) =>
      logger.write_string(
        "file extension says \{expected.name()}, but package content is \{actual.name()}",
      )
  }
}

///|
const XLSX_MAIN_CONTENT_TYPE : String = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"

///|
const DOCX_MAIN_CONTENT_TYPE : String = "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"

///|
const CONTENT_TYPES_ROOT : String = "{http://schemas.openxmlformats.org/package/2006/content-types}Types"

///|
const CONTENT_TYPES_OVERRIDE : String = "{http://schemas.openxmlformats.org/package/2006/content-types}Override"

///|
const CONTENT_TYPES_DEFAULT : String = "{http://schemas.openxmlformats.org/package/2006/content-types}Default"

///|
const RELATIONSHIPS_ROOT : String = "{http://schemas.openxmlformats.org/package/2006/relationships}Relationships"

///|
const RELATIONSHIP_ELEMENT : String = "{http://schemas.openxmlformats.org/package/2006/relationships}Relationship"

///|
const TRANSITIONAL_OFFICE_DOCUMENT_REL : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"

///|
const STRICT_OFFICE_DOCUMENT_REL : String = "http://purl.oclc.org/ooxml/officeDocument/relationships/officeDocument"

///|
const TRANSITIONAL_WORKBOOK_ROOT : String = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}workbook"

///|
const STRICT_WORKBOOK_ROOT : String = "{http://purl.oclc.org/ooxml/spreadsheetml/main}workbook"

///|
const TRANSITIONAL_DOCUMENT_ROOT : String = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}document"

///|
const STRICT_DOCUMENT_ROOT : String = "{http://purl.oclc.org/ooxml/wordprocessingml/main}document"

///|
fn format_from_extension(path : StringView) -> DocumentFormat raise OfficeError {
  let lower = path.to_owned().to_lower()
  if lower.has_suffix(".xlsx") {
    Xlsx
  } else if lower.has_suffix(".docx") {
    Docx
  } else {
    raise UnsupportedFileExtension(path.to_owned())
  }
}

///|
fn read_xml_part(
  archive : @zip.Archive,
  name : String,
) -> @xml.XmlElement raise OfficeError {
  let bytes = match archive.get(name) {
    Some(bytes) => bytes
    None => raise InvalidPackage("missing required part: \{name}")
  }
  let text = if bytes.length() >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe {
    @utf16.decode(bytes, ignore_bom=true) catch {
      _ => raise InvalidPackage("\{name} is not valid UTF-8 or UTF-16 XML text")
    }
  } else if bytes.length() >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff {
    @utf16.decode(bytes, ignore_bom=true, endianness=Big) catch {
      _ => raise InvalidPackage("\{name} is not valid UTF-8 or UTF-16 XML text")
    }
  } else if bytes.length() >= 2 && bytes[0] == b'<' && bytes[1] == 0x00 {
    @utf16.decode(bytes) catch {
      _ => raise InvalidPackage("\{name} is not valid UTF-8 or UTF-16 XML text")
    }
  } else if bytes.length() >= 2 && bytes[0] == 0x00 && bytes[1] == b'<' {
    @utf16.decode(bytes, endianness=Big) catch {
      _ => raise InvalidPackage("\{name} is not valid UTF-8 or UTF-16 XML text")
    }
  } else {
    @utf8.decode(bytes, ignore_bom=true) catch {
      _ => raise InvalidPackage("\{name} is not valid UTF-8 or UTF-16 XML text")
    }
  }
  @xml.read_xml_string(text) catch {
    _ => raise InvalidPackage("\{name} is not well-formed XML")
  }
}

///|
fn normalize_internal_target(target : StringView) -> String? {
  if target == "" ||
    target.contains("\\") ||
    target.contains("?") ||
    target.contains("#") {
    return None
  }
  let path = if target.has_prefix("/") { target[1:] } else { target }
  let segments : Array[String] = []
  for item in path.split("/") {
    let segment = item.to_owned()
    match segment {
      "" | "." => ()
      ".." =>
        if segments.length() == 0 {
          return None
        } else {
          let _ = segments.pop()
        }
      _ => segments.push(segment)
    }
  }
  if segments.length() == 0 {
    None
  } else {
    Some(segments.join("/"))
  }
}

///|
fn normalize_declared_part_name(part_name : StringView) -> String? {
  guard part_name.has_prefix("/") else { return None }
  guard normalize_internal_target(part_name) is Some(normalized) else {
    return None
  }
  if part_name[1:] == normalized {
    Some(normalized)
  } else {
    None
  }
}

///|
fn part_extension(name : String) -> String? {
  match name.rev_find(".") {
    Some(dot) =>
      match name.rev_find("/") {
        Some(slash) if slash > dot => None
        _ if dot + 1 < name.length() =>
          Some(name[dot + 1:].to_owned().to_lower())
        _ => None
      }
    None => None
  }
}

///|
fn relationships_part_for(part : String) -> String {
  match part.rev_find("/") {
    Some(slash) => "\{part[:slash]}/_rels/\{part[slash + 1:]}.rels"
    None => "_rels/\{part}.rels"
  }
}

///|
fn relationships_base_dir(part : String) -> String? {
  if part == "_rels/.rels" {
    return Some("")
  }
  if part.has_prefix("_rels/") {
    let relationship_name = part["_rels/".length():]
    return if relationship_name == "" || relationship_name.contains("/") {
      None
    } else {
      Some("")
    }
  }
  guard part.find("/_rels/") is Some(marker) else { return None }
  let relationship_name = part[marker + "/_rels/".length():]
  if relationship_name == "" || relationship_name.contains("/") {
    None
  } else {
    Some(part[:marker + 1].to_owned())
  }
}

///|
fn resolve_relationship_target(base : String, target : StringView) -> String? {
  if target.has_prefix("/") {
    normalize_internal_target(target)
  } else {
    normalize_internal_target(base + target.to_owned())
  }
}

///|
fn validate_package_structure(
  archive : @zip.Archive,
  main_part : String,
  require_main_relationships : Bool,
) -> Array[String] raise OfficeError {
  let findings : Array[String] = []
  let parts : Map[String, Int] = Map([])
  for entry in archive.entries() {
    let name = entry.name()
    parts[name] = parts.get(name).unwrap_or(0) + 1
    if name == "" {
      findings.push("empty entry name")
    }
    if name.has_prefix("/") {
      findings.push("entry name must not start with '/': \{name}")
    }
    if name.contains("\\") {
      findings.push("entry name contains a backslash: \{name}")
    }
    for segment in name.split("/") {
      if segment == "." || segment == ".." {
        findings.push("entry name contains a '\{segment}' segment: \{name}")
        break
      }
    }
  }
  for name, count in parts {
    if count > 1 {
      findings.push("duplicate entry name: \{name}")
    }
  }
  if !parts.contains(main_part) {
    findings.push("missing required part: \{main_part}")
  }
  let main_relationships = relationships_part_for(main_part)
  if require_main_relationships && !parts.contains(main_relationships) {
    findings.push("missing required part: \{main_relationships}")
  }

  let defaults : Map[String, String] = Map([])
  let overrides : Map[String, String] = Map([])
  let content_types = read_xml_part(archive, "[Content_Types].xml")
  for child in content_types.children {
    guard child is XmlElement(element) else { continue }
    if element.name == CONTENT_TYPES_DEFAULT {
      match
        (
          element.attributes.get("Extension"),
          element.attributes.get("ContentType"),
        ) {
        (Some(extension), Some(content_type)) if extension != "" &&
          content_type != "" => {
          let extension = extension.to_lower()
          if defaults.contains(extension) {
            findings.push("duplicate content-type default: \{extension}")
          } else {
            defaults[extension] = content_type
          }
        }
        _ =>
          findings.push(
            "[Content_Types].xml: Default missing Extension or ContentType",
          )
      }
    } else if element.name == CONTENT_TYPES_OVERRIDE {
      match
        (
          element.attributes.get("PartName"),
          element.attributes.get("ContentType"),
        ) {
        (Some(part_name), Some(content_type)) if content_type != "" => {
          if overrides.contains(part_name) {
            findings.push("duplicate content-type override: \{part_name}")
          } else {
            overrides[part_name] = content_type
          }
          match normalize_declared_part_name(part_name) {
            Some(target) =>
              if !parts.contains(target) {
                findings.push(
                  "content-type override names a missing part: \{part_name}",
                )
              }
            None =>
              findings.push(
                "content-type override has an invalid PartName: \{part_name}",
              )
          }
        }
        _ =>
          findings.push(
            "[Content_Types].xml: Override missing PartName or ContentType",
          )
      }
    } else {
      findings.push(
        "[Content_Types].xml contains an unexpected element: \{element.name}",
      )
    }
  }
  for entry in archive.entries() {
    let name = entry.name()
    if name == "[Content_Types].xml" || name.has_suffix("/") {
      continue
    }
    if overrides.contains("/" + name) {
      continue
    }
    match part_extension(name) {
      Some(extension) if defaults.contains(extension) => ()
      _ => findings.push("part has no declared content type: \{name}")
    }
  }

  for entry in archive.entries() {
    let relationship_part = entry.name()
    if !relationship_part.has_suffix(".rels") {
      continue
    }
    let base = match relationships_base_dir(relationship_part) {
      Some(base) => base
      None => {
        findings.push(
          "relationship part is not under an _rels directory: \{relationship_part}",
        )
        continue
      }
    }
    let relationships = read_xml_part(archive, relationship_part)
    if relationships.name != RELATIONSHIPS_ROOT {
      findings.push("\{relationship_part} root element is not Relationships")
      continue
    }
    let ids : Map[String, Bool] = Map([])
    for child in relationships.children {
      guard child is XmlElement(element) else { continue }
      if element.name != RELATIONSHIP_ELEMENT {
        findings.push(
          "\{relationship_part} contains an unexpected element: \{element.name}",
        )
        continue
      }
      match element.attributes.get("Id") {
        Some(id) if id != "" =>
          if ids.contains(id) {
            findings.push(
              "duplicate relationship Id in \{relationship_part}: \{id}",
            )
          } else {
            ids[id] = true
          }
        _ => findings.push("relationship in \{relationship_part} has no Id")
      }
      match element.attributes.get("Type") {
        Some(rel_type) if rel_type != "" => ()
        _ => findings.push("relationship in \{relationship_part} has no Type")
      }
      let target = match element.attributes.get("Target") {
        Some(target) if target != "" => target
        _ => {
          findings.push("relationship in \{relationship_part} has no Target")
          continue
        }
      }
      let internal = match element.attributes.get("TargetMode") {
        None | Some("Internal") => true
        Some("External") => false
        Some(mode) => {
          findings.push(
            "relationship in \{relationship_part} has invalid TargetMode: \{mode}",
          )
          false
        }
      }
      if internal {
        match resolve_relationship_target(base, target) {
          Some(resolved) =>
            if !parts.contains(resolved) {
              findings.push(
                "relationship in \{relationship_part} points to a missing part: \{target} -> \{resolved}",
              )
            }
          None =>
            findings.push(
              "relationship in \{relationship_part} has an invalid Target: \{target}",
            )
        }
      }
    }
  }
  findings
}

///|
fn is_office_document_relationship(rel_type : StringView) -> Bool {
  rel_type == TRANSITIONAL_OFFICE_DOCUMENT_REL ||
  rel_type == STRICT_OFFICE_DOCUMENT_REL
}

///|
fn validate_main_identity(
  archive : @zip.Archive,
  format : DocumentFormat,
  declared_main_part : String,
) -> Unit raise OfficeError {
  let label = if format is Xlsx { "XLSX" } else { "DOCX" }
  let root_rels = read_xml_part(archive, "_rels/.rels")
  if root_rels.name != RELATIONSHIPS_ROOT {
    raise InvalidPackage("_rels/.rels root element is not Relationships")
  }
  let main_targets : Array[String] = []
  for child in root_rels.children {
    guard child is XmlElement(element) && element.name == RELATIONSHIP_ELEMENT else {
      continue
    }
    guard element.attributes.get("Type") is Some(rel_type) &&
      is_office_document_relationship(rel_type) else {
      continue
    }
    match element.attributes.get("TargetMode") {
      None | Some("Internal") => ()
      Some(_) =>
        raise InvalidPackage(
          "\{label} officeDocument relationship is not internal",
        )
    }
    match element.attributes.get("Id") {
      Some(id) if id != "" => ()
      _ =>
        raise InvalidPackage("\{label} officeDocument relationship has no Id")
    }
    let target = match element.attributes.get("Target") {
      Some(target) => target
      None =>
        raise InvalidPackage(
          "\{label} officeDocument relationship has no Target",
        )
    }
    let normalized = match normalize_internal_target(target) {
      Some(target) => target
      None =>
        raise InvalidPackage(
          "\{label} officeDocument relationship has an invalid Target",
        )
    }
    main_targets.push(normalized)
  }
  let main_target = match main_targets {
    [] =>
      raise InvalidPackage(
        "\{label} root relationships do not declare an officeDocument relationship",
      )
    [target] => target
    _ =>
      raise InvalidPackage(
        "\{label} root relationships declare multiple officeDocument relationships",
      )
  }
  if main_target != declared_main_part {
    raise InvalidPackage(
      "\{label} officeDocument relationship targets '\{main_target}', but content types declare '\{declared_main_part}'",
    )
  }
  let main = read_xml_part(archive, main_target)
  let valid_root = match format {
    Xlsx =>
      main.name == TRANSITIONAL_WORKBOOK_ROOT ||
      main.name == STRICT_WORKBOOK_ROOT
    Docx =>
      main.name == TRANSITIONAL_DOCUMENT_ROOT ||
      main.name == STRICT_DOCUMENT_ROOT
  }
  if !valid_root {
    let expected = if format is Xlsx { "workbook" } else { "document" }
    raise InvalidPackage("\{label} main part root element is not \{expected}")
  }
}

///|
fn format_from_package(
  data : BytesView,
) -> (DocumentFormat, String, @zip.Archive) raise OfficeError {
  let archive = @zip.read(data) catch {
    _ => raise InvalidPackage("archive is not a readable ZIP")
  }
  for entry in archive.entries() {
    if entry.crc32() != @zip.crc32(entry.data()) {
      raise InvalidPackage(
        "entry data does not match its stored CRC-32: \{entry.name()}",
      )
    }
  }
  let content_types = read_xml_part(archive, "[Content_Types].xml")
  if content_types.name != CONTENT_TYPES_ROOT {
    raise InvalidPackage("[Content_Types].xml root element is not Types")
  }
  let xlsx_main_parts : Array[String] = []
  let docx_main_parts : Array[String] = []
  for child in content_types.children {
    guard child is XmlElement(element) && element.name == CONTENT_TYPES_OVERRIDE else {
      continue
    }
    let main_parts = match element.attributes.get("ContentType") {
      Some(XLSX_MAIN_CONTENT_TYPE) => xlsx_main_parts
      Some(DOCX_MAIN_CONTENT_TYPE) => docx_main_parts
      _ => continue
    }
    let part_name = match element.attributes.get("PartName") {
      Some(part_name) => part_name
      None => raise InvalidPackage("main content type override has no PartName")
    }
    match normalize_declared_part_name(part_name) {
      Some(part_name) => main_parts.push(part_name)
      None =>
        raise InvalidPackage(
          "main content type override has an invalid PartName",
        )
    }
  }
  let (format, main_part) = match (xlsx_main_parts, docx_main_parts) {
    ([xlsx], []) => (Xlsx, xlsx)
    ([], [docx]) => (Docx, docx)
    ([], []) =>
      raise InvalidPackage(
        "content types do not declare an XLSX or DOCX main part",
      )
    ([_, ..], [_, ..]) =>
      raise InvalidPackage(
        "content types declare both XLSX and DOCX main parts",
      )
    ([_, _, ..], []) =>
      raise InvalidPackage("content types declare multiple XLSX main parts")
    ([], [_, _, ..]) =>
      raise InvalidPackage("content types declare multiple DOCX main parts")
  }
  (format, main_part, archive)
}

///|
fn structural_findings(
  format : DocumentFormat,
  archive : @zip.Archive,
  main_part : String,
) -> Array[String] raise OfficeError {
  validate_package_structure(archive, main_part, format is Xlsx)
}

///|
/// Identifies a structurally valid XLSX or DOCX package.
///
/// The file extension and the OOXML main-part content type must agree. The
/// corresponding portable package validator then checks the package before the
/// format is returned.
pub fn detect_format(
  path : StringView,
  data : BytesView,
) -> DocumentFormat raise OfficeError {
  let expected = format_from_extension(path)
  let (actual, main_part, archive) = format_from_package(data)
  if expected != actual {
    raise FormatMismatch(expected~, actual~)
  }
  validate_main_identity(archive, actual, main_part)
  let findings = structural_findings(actual, archive, main_part)
  if findings.length() > 0 {
    let first = findings[0]
    let suffix = if findings.length() == 1 {
      ""
    } else {
      " (and \{findings.length() - 1} more finding(s))"
    }
    raise InvalidPackage(first + suffix)
  }
  actual
}
